class_name PlannerSeam
extends RefCounted
## Round 31 (planner CP-P1, the seam agreed as R31.2 in `_agents/workstreams.md`): **the lattice planner's one door
## into the drive.** Two lines in `movement.gd` call `take()` before today's code makes a plan of legs: the first line of
## `_planned_reverse` (a routed forward move whose forward arc is blocked: today's back-and-fill / circle plan) and
## `face_turn` after its aligned-check (a face at rest: today's `plan_face`). `take` returns true while it owns the hull
## (a plan pending or being driven) and has written `cmd`; false hands the tick to today's code unchanged.
##
## ON only with `--nav-off=planner` (the opt-in form of `leash` / `nosestop`; `on()` reads it). OFF, nothing here is
## reached and every byte of the drive is today's.
##
## What it does, in order, for a wheeled hull the switch covers:
##   1. A REQUEST (`PlanRequest.for_unit`, the k-turn's throttles under the yaw cap; the navmesh and every other living
##      hull as a snapshot): `face` = (home, want) within max(settle radius - 1, 1.5) m / 8 deg, either gear last;
##      `kturn` = the steering point (or the point 0.8 x horizon toward it), heading toward the next route vertex when
##      there is one (else free), within the order's arrive radius, nose first.
##   2. PENDING: the search runs SLICE expansions a tick on the library's session, ONE crew at a time (a FIFO; the
##      others wait their turn), and the hull commands zero/zero (brake straight, the lock off: not the creep) -- every
##      event here is a hull at or near rest. If it still moved > MOVED_M or yawed > YAWED_DEG between the request and
##      the plan, ONE re-request from where it now rests. Over PENDING_TICKS (queue wait included): abandoned, counted,
##      declined for RETRY_TICKS so today's rules run.
##   3. DRIVING: `PlannerExecutor` (the P4 rules: brake on the leg's own lock, never throttle 0 with the lock on, the
##      discrete stopping distance, the arc not the chord) drives the legs. A leg aborted (stall / timeout) is an EVENT:
##      re-plan from the pose with a fresh snapshot, at most REPLANS_PER_ORDER times, then decline for RETRY_TICKS.
##      Driven to the end: released (the route, or the face's aligned test, takes over next tick; a short decline
##      keeps a face from asking twice for the same residual).
##   4. NO_PATH / BUDGET / GOAL_BLOCKED / START_BLOCKED: declined for RETRY_TICKS, counted by code (the layer above --
##      brains' re-seat, traffic's ask -- is what should act on them; nothing does this round, as with `kturn_none`).
##      A new goal, a dead hull, a non-wheeled hull or `Traffic.holding` release the crew.
##
## State lives HERE, keyed by the crew's name (never in Movement's members: `exec_fields.h` is untouched, R31.2 G);
## `capture()` / `restore()` give the twin harnesses the whole of it, a pending session replayed by its expansions.
## Deterministic: the queue is the order `take` was called (the controllers' order, tanks by name); no clock.

const SWITCH := "planner"
## Expansions a tick for a pending search (P6: chosen from CP-P0's cost line on builder0 so a slice is <= 0.5 ms).
const SLICE := 100
const BUDGET := 1500
const HORIZON_M := 30.0
const PENDING_TICKS := 90          # 3 s, the agreed hold
const RETRY_TICKS := SimClock.TICK_RATE
const REPLANS_PER_ORDER := 2
const MOVED_M := 0.5
const YAWED_DEG := 5.0
const FACE_TOL_DEG := 8.0          # Manoeuvre.FACE_ALIGNED_DEG
const NEW_GOAL_JUMP := 3.0         # Movement.NEW_GOAL_JUMP's intent: a goal that jumps this far is a new order
const STALE_TICKS := 2             # a crew `take` has not been asked about for this long is released

## Measurement (statics; `report()` for a probe's row).
static var requests := 0
static var plans := 0
static var plan_legs := 0
static var driven := 0            # plans driven to their end
static var aborted := 0           # legs aborted (each a re-plan event)
static var abandoned := 0         # pending over PENDING_TICKS
static var rerequested := 0       # the hull moved while pending: asked again from rest
static var refused := {}          # code -> count (NO_PATH, BUDGET, GOAL_BLOCKED, START_BLOCKED)
static var pending_ticks := 0     # hull-ticks held at zero/zero
static var driving_ticks := 0
static var queue_waits := 0       # hull-ticks waited behind another crew's search

static var _crews := {}           # name -> Crew
static var _queue: Array[String] = []
static var _retry_until := {}     # name -> tick


class Crew:
	var kind := ""
	var tick_seen := 0
	var asked_tick := 0
	var pending := true
	var begun := false
	var req: PlanRequest = null
	var at := Vector3.ZERO          # the pose the session began from
	var heading := Vector3.ZERO
	var goal := Vector3.ZERO        # the order's goal / face home, for the new-goal release
	var replans := 0
	var rerequests := 0
	var stepped := 0                # expansions handed to the session (replayed by restore)
	var executor: PlannerExecutor = null

	func copy() -> Crew:
		var c := Crew.new()
		for prop: Dictionary in get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0:
				continue
			var key := String(prop["name"])
			if key == "executor":
				c.executor = PlannerExecutor.from_state(executor.to_state()) if executor != null else null
			elif key == "req":
				c.req = req.copy() if req != null else null
			else:
				c.set(key, get(key))
		return c


static func on() -> bool:
	return Movement.switched_off(SWITCH)


## Is this crew held by the seam (a plan pending or being driven)? False when OFF.
static func live(crew_name: String) -> bool:
	return on() and _crews.has(crew_name)


static func report() -> Dictionary:
	return {"requests": requests, "plans": plans, "plan_legs": plan_legs, "driven": driven, "aborted": aborted,
			"abandoned": abandoned, "rerequested": rerequested, "refused": refused.duplicate(), "pending_ticks": pending_ticks,
			"driving_ticks": driving_ticks, "queue_waits": queue_waits, "live": _crews.size(), "slice": SLICE}


static func reset() -> void:
	requests = 0
	plans = 0
	plan_legs = 0
	driven = 0
	aborted = 0
	abandoned = 0
	rerequested = 0
	refused = {}
	pending_ticks = 0
	driving_ticks = 0
	queue_waits = 0
	_release_all()


static func _release_all() -> void:
	for name: String in _crews.keys():
		_release(name)
	_queue.clear()
	_retry_until.clear()


## The seam's one entry. `target`: the k-turn's steering point, or the face's home; `want`: the face's wanted heading.
static func take(mover: Movement, cmd: TankCommand, kind: String, target: Vector3, delta: float, want := Vector3.ZERO) -> bool:
	var tank := mover.ctl.tank
	var name := String(tank.name)
	if mover.wheel_radius() <= 0.0 or not tank.is_alive() or Traffic.holding(name):
		_release(name)
		return false
	var tick := Engine.get_physics_frames()
	var crew: Crew = _crews.get(name)
	if crew != null and (crew.kind != kind or tick - crew.tick_seen > STALE_TICKS or _flat(target, crew.goal) > NEW_GOAL_JUMP):
		_release(name)  # another kind of order, not asked for a while, or a new goal: whatever was planned is stale
		crew = null
	if crew == null:
		if int(_retry_until.get(name, -1)) > tick:
			return false
		crew = _request(mover, kind, target, want, tick)
		if crew == null:
			return false
	crew.tick_seen = tick
	if crew.pending:
		return _pend(mover, cmd, crew, name, tick, delta)
	return _drive(mover, cmd, crew, name, tick, delta)


static func _request(mover: Movement, kind: String, target: Vector3, want: Vector3, tick: int) -> Crew:
	var tank := mover.ctl.tank
	var name := String(tank.name)
	var req := PlanRequest.for_unit(tank.unit_id)
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	req.at(here.x, here.z, forward.x, forward.z)
	match kind:
		"face":
			if want.length_squared() < 0.01:
				return null
			var stay := maxf(Movement.settle_radius(tank.unit_id) - 1.0, 1.5)
			req.to(target.x, target.z, want.x, want.z, stay, FACE_TOL_DEG)
			req.arrive_gear = 0
		"kturn":
			var to := Vector3(target.x - here.x, 0.0, target.z - here.z)
			if to.length() < 0.5:
				return null
			var goal := target
			if to.length() > HORIZON_M:
				goal = here + to.normalized() * (HORIZON_M * 0.8)
			var heading := _route_heading_at(mover, target)
			if heading == Vector3.ZERO:
				req.to(goal.x, goal.z, to.x, to.z, maxf(mover._arrive, 1.0), 180.0)  # a free heading: any pose at the point
			else:
				req.to(goal.x, goal.z, heading.x, heading.z, maxf(mover._arrive, 1.0), FACE_TOL_DEG)
			req.arrive_gear = 1
		_:
			return null
	req.budget = BUDGET
	req.horizon_m = HORIZON_M
	req.in_world(PlannerNavWorld.for_tank(tank, mover.ctl.tanks_root))
	var crew := Crew.new()
	crew.kind = kind
	crew.req = req
	crew.goal = target
	crew.asked_tick = tick
	crew.tick_seen = tick
	crew.at = here
	crew.heading = forward
	_crews[name] = crew
	_queue.append(name)
	requests += 1
	return crew


## The heading the route continues with past `target` (the vertex after the one `target` is), or ZERO for none.
static func _route_heading_at(mover: Movement, target: Vector3) -> Vector3:
	var path := mover._path
	for i in range(mover._path_index, path.size() - 1):
		if _flat(path[i], target) <= 1.0:
			var next := path[i + 1]
			var d := Vector3(next.x - target.x, 0.0, next.z - target.z)
			if d.length() > 0.5:
				return d.normalized()
			return Vector3.ZERO
	return Vector3.ZERO


static func _pend(mover: Movement, cmd: TankCommand, crew: Crew, name: String, tick: int, _delta: float) -> bool:
	var tank := mover.ctl.tank
	cmd.throttle = 0.0
	cmd.turn = 0.0
	pending_ticks += 1
	if tick - crew.asked_tick >= PENDING_TICKS:
		abandoned += 1
		_release(name)
		_retry_until[name] = tick + RETRY_TICKS
		return false
	if _queue.is_empty() or _queue[0] != name:
		queue_waits += 1
		return true
	if not crew.begun:
		# The head of the queue begins its search from where it NOW rests (fresher than the request tick's pose).
		var here := tank.global_position
		var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
		crew.req.at(here.x, here.z, forward.x, forward.z)
		crew.req.world.refresh_hulls(tank, mover.ctl.tanks_root)
		crew.at = here
		crew.heading = forward
		crew.stepped = 0
		Planner.begin_session(crew.req)
		crew.begun = true
	crew.stepped += SLICE
	if not Planner.step_session(SLICE):
		return true
	var plan := Planner.session_result()
	Planner.cancel_session()
	_queue.pop_front()
	crew.begun = false
	var here := tank.global_position
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	if plan.code == PackedPlan.OK and crew.rerequests < 1 \
			and (_flat(here, crew.at) > MOVED_M or rad_to_deg(absf(forward.signed_angle_to(crew.heading, Vector3.UP))) > YAWED_DEG):
		# It was still rolling when the search began: the plan starts where the hull is not. Once more, from rest.
		crew.rerequests += 1
		rerequested += 1
		_queue.append(name)
		return true
	if plan.code == PackedPlan.ALREADY_THERE:
		_release(name)
		return false
	if plan.code != PackedPlan.OK:
		refused[plan.code] = int(refused.get(plan.code, 0)) + 1
		_release(name)
		_retry_until[name] = tick + RETRY_TICKS
		return false
	plans += 1
	plan_legs += plan.legs.size()
	crew.pending = false
	crew.executor = PlannerExecutor.new()
	crew.executor.start(plan, tank)
	if ManoeuvreCensus.trace_unit == name:
		print("PLANNER_SEAM %s %s: %s %s | %s" % [name, crew.kind, plan.code, plan.describe(), plan.why])
	return _drive(mover, cmd, crew, name, tick, _delta)


static func _drive(mover: Movement, cmd: TankCommand, crew: Crew, name: String, tick: int, delta: float) -> bool:
	var out := crew.executor.tick(delta)
	cmd.throttle = out.throttle
	cmd.turn = out.turn
	driving_ticks += 1
	if crew.executor.aborted:
		aborted += 1
		if ManoeuvreCensus.trace_unit == name:
			print("PLANNER_SEAM %s %s: aborted (%s), replans %d" % [name, crew.kind, crew.executor.reason, crew.replans])
		if crew.replans >= REPLANS_PER_ORDER:
			_release(name)
			_retry_until[name] = tick + RETRY_TICKS
			return false
		var kind := crew.kind
		var goal := crew.goal
		var want := Vector3(crew.req.goal_fx, 0.0, crew.req.goal_fz)
		var replans := crew.replans + 1
		_release(name)
		var again := _request(mover, kind, goal, want, tick)
		if again == null:
			_retry_until[name] = tick + RETRY_TICKS
			return false
		again.replans = replans
		cmd.throttle = 0.0
		cmd.turn = 0.0
		return true
	if crew.executor.done:
		driven += 1
		_release(name)
		_retry_until[name] = tick + RETRY_TICKS  # the route or the face's aligned test takes it from here
		return true
	return true


static func _release(name: String) -> void:
	var crew: Crew = _crews.get(name)
	if crew == null:
		return
	if crew.begun and not _queue.is_empty() and _queue[0] == name:
		Planner.cancel_session()
	_crews.erase(name)
	_queue.erase(name)


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


# ---- the twin harnesses (MoverState / TrafficTwin snapshot statics; this is the seam's) --------------------------------
## Everything above as one value: the crews (copied, their executors' state copied), the queue, the retry windows, the
## counters. A pending session is not copied: `restore` begins it again from the crew's request and steps it the same
## number of expansions, which the slice proof (tests/test_native_planner.gd) makes the same search.
static func capture() -> Dictionary:
	var crews := {}
	for name: String in _crews:
		crews[name] = (_crews[name] as Crew).copy()
	return {"crews": crews, "queue": _queue.duplicate(), "retry": _retry_until.duplicate(), "counters": report()}


static func restore(snapshot: Dictionary) -> void:
	if not _queue.is_empty():
		Planner.cancel_session()
	_crews.clear()
	for name: String in snapshot["crews"]:
		_crews[name] = (snapshot["crews"][name] as Crew).copy()
	_queue.assign(snapshot["queue"])
	_retry_until = (snapshot["retry"] as Dictionary).duplicate()
	var counters: Dictionary = snapshot["counters"]
	requests = int(counters["requests"])
	plans = int(counters["plans"])
	plan_legs = int(counters["plan_legs"])
	driven = int(counters["driven"])
	aborted = int(counters["aborted"])
	abandoned = int(counters["abandoned"])
	rerequested = int(counters["rerequested"])
	refused = (counters["refused"] as Dictionary).duplicate()
	pending_ticks = int(counters["pending_ticks"])
	driving_ticks = int(counters["driving_ticks"])
	queue_waits = int(counters["queue_waits"])
	if not _queue.is_empty():
		var head: Crew = _crews.get(_queue[0])
		if head != null and head.begun:
			Planner.begin_session(head.req)
			if head.stepped > 0:
				Planner.step_session(head.stepped)
