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
##      A FACE hands back on its FIRST abort (CP-P1's gate, the wedged semi: the world is the navmesh plus live hulls,
##      so a plan aborted against something unbaked is a plan the next snapshot repeats; today's give-up must report
##      the hull unable within a few seconds, and it runs only once the seam lets go).
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
## SCOPE (R31.7, chosen from the census BEFORE any judged number): the seam takes LONG hulls only, hull length >=
## this (the catalog: the War Rig gang_tank at 14.0 m; the next is tank at 9.7 m), every kind (face, circle plan,
## blocked arc). The brief's target is the long hull in a Terminus street; the census (92721 / 31337) prices the
## press's demand at ~3 ms a tick if every hull were served (six times the cost line), and the long hulls' share of
## it is the row `by_hull` in planner-census. A short hull is never taken: today's code drives it unchanged.
const SCOPE_MIN_HULL_M := 10.0
## Expansions a tick for a pending search: C31.5's cost line (<= 0.5 ms a tick at Sumps 25 a side) over the IN-FIGHT
## price of the seam's own request. planner-census on fd36ecd5's C++ (builder0 light lane, unpinned, load ~12, seeds
## 92721 / 31337, the probe every 30 ticks): a War Rig's face-about on the Sumps navmesh among 49 hulls cost 205-392 us
## an expansion warm (the sphere walks of a long hull; the field's cells are cached, the hull tests distance-culled),
## 257-292 us cold; the Terminus lab fixtures pinned to 4 cpus 100-510 us. SLICE 2 is 0.4-0.8 ms a tick on that box
## under that load, ~0.3 ms pinned; it is COUNTED, never timed (the tick a plan lands must not depend on the machine:
## the lockstep relay). What it buys: the Terminus turnround (7 expansions) lands in 4 ticks, the T-junction (94) in
## 47 (1.6 s), and PENDING_TICKS caps a search at 180 expansions (the census's median in-press face-about is 131; its
## longest quarter 250-500 would be abandoned at the 3 s hold -- the judged run's `abandoned` counts them).
const SLICE := 2
const BUDGET := 1500
const HORIZON_M := 30.0
const PENDING_TICKS := 90          # 3 s of SEARCH (from the tick it begins at rest), the agreed hold
const RETRY_TICKS := SimClock.TICK_RATE
const REPLANS_PER_ORDER := 2
const MOVED_M := 0.5
const REST_MPS := 0.5             # a pending search begins only once the hull has all but stopped
const BRAKE_THROTTLE := 0.7        # Movement.KTURN_THROTTLE: the brake on a rolling hull while it is pending
const YAWED_DEG := 5.0
const FACE_TOL_DEG := 8.0          # Manoeuvre.FACE_ALIGNED_DEG
const KTURN_AIM_DEG := 15.0        # the k-turn's goal: pointing at the waypoint within this, the straight run clear
const NEW_GOAL_JUMP := 3.0         # Movement.NEW_GOAL_JUMP's intent: a goal that jumps this far is a new order
const STALE_TICKS := 2             # a crew `take` has not been asked about for this long is released
const REPORT_LINES := true         # a PLANNER_SEAM_REPORT line at every event's end (measurement; tens a run)

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
static var _last_refusal := {}    # name -> [physics frame, code]: manoeuvre's CP-P1 handover counters read it
static var last_abandoned := {}   # measurement: the last search that ran out the hold (kind, stepped, start, goal, stay, at rest)
static var last_plans: Array = []  # measurement: every plan that landed this reset (tick, name, kind, legs, expansions, start, goal)
static var holds: PackedInt32Array = []   # hull-ticks held before each event's end (a plan landed, refused or abandoned): median/max reported


class Crew:
	var kind := ""
	var tick_seen := 0
	var asked_tick := 0
	var held_since := 0   # the tick the hull was first held (the ask): its hold = plan tick - held_since
	var pending := true
	var begun := false
	var req: PlanRequest = null
	var at := Vector3.ZERO          # the pose the session began from
	var heading := Vector3.ZERO
	var goal := Vector3.ZERO        # the plan's target: the k-turn's steering point / the face's home
	var order_goal := Vector3.INF   # the ORDER's goal (Movement._goal) for a k-turn, the face's home for a face: the
	                                # new-goal release judges this, never the route's carrot, which slides as the hull moves
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


## The CP-H form (native's ask on the pair tree, a6c6c804): the seam is ON when the flag's state differs from the
## default. OFF by default, `--nav-off=planner` is the opt-in arm (R31.1); the ship change is this one const flipped
## to true, after which `--nav-off=planner` is the OFF arm. (A `--nav-off` name takes the whole native drive off, so a
## tree flipped by the flag could never exercise native's mirror: the const is what the pair-tree gate flips.)
const PLANNER_DEFAULT := false


static func on() -> bool:
	return PLANNER_DEFAULT != Movement.switched_off(SWITCH)


## Is this crew held by the seam (a plan pending or being driven)? False when OFF.
static func live(crew_name: String) -> bool:
	return on() and _crews.has(crew_name)


## Round 31 (manoeuvre's ask through the orchestrator, measurement only): this hull's LAST refusal as
## [physics frame, code] (`PackedPlan.START_BLOCKED` etc.), or [] when there has been none or the switch is OFF.
## Manoeuvre counts an escape begun within 3 s of a START_BLOCKED refusal (`esc_after_refusal`) and the hull moving
## >= 1.5 m within 5 s of one (`refusal_then_free`). Read-only; no Movement member.
static func last_refusal(crew_name: String) -> Array:
	if not on():
		return []
	var last: Variant = _last_refusal.get(crew_name)
	return [] if last == null else (last as Array).duplicate()


static func report() -> Dictionary:
	return {"requests": requests, "plans": plans, "plan_legs": plan_legs, "driven": driven, "aborted": aborted,
			"abandoned": abandoned, "rerequested": rerequested, "refused": refused.duplicate(), "pending_ticks": pending_ticks,
			"driving_ticks": driving_ticks, "queue_waits": queue_waits, "live": _crews.size(), "slice": SLICE,
			"holds": _hold_stats(), "hold_ticks": Array(holds)}   # hold_ticks: the per-event list (the series pools it per arm)


## The hold per event (R31.7's reported line: what he would see a rig stand for): n, median and max hull-ticks.
static func _hold_stats() -> Dictionary:
	if holds.is_empty():
		return {"n": 0, "median": 0, "max": 0}
	var sorted := Array(holds)
	sorted.sort()
	return {"n": sorted.size(), "median": sorted[sorted.size() / 2], "max": sorted[-1]}


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
	_last_refusal = {}
	holds = PackedInt32Array()
	last_plans = []
	_release_all()


static func _release_all() -> void:
	for name: String in _crews.keys():
		_release(name)
	_queue.clear()
	_retry_until.clear()


## The seam's two entries. `take` is called WHERE today's code decides a plan of legs is needed (the k-turn's blocked
## arc, the circle rule, a face at rest that is not aligned): it asks for a plan if the crew is free, or continues the
## one it holds. `hold` is called at the TOP of those functions every tick: it only continues a crew the seam already
## holds (a plan pending or being driven), never asks. `target`: the k-turn's steering point, or the face's home;
## `want`: the face's wanted heading.
static func take(mover: Movement, cmd: TankCommand, kind: String, target: Vector3, delta: float, want := Vector3.ZERO) -> bool:
	if not in_scope(mover.ctl.tank.unit_id) and not _crews.has(String(mover.ctl.tank.name)):
		return false
	return _serve(mover, cmd, kind, target, delta, want, true)


## Is this hull class one the seam takes (SCOPE_MIN_HULL_M)?
static func in_scope(unit_id: String) -> bool:
	var box: Array = Movement.hull_box(unit_id)
	return float(box[2]) >= SCOPE_MIN_HULL_M


static func hold(mover: Movement, cmd: TankCommand, kind: String, target: Vector3, delta: float) -> bool:
	if not _crews.has(String(mover.ctl.tank.name)):
		return false
	return _serve(mover, cmd, kind, target, delta, Vector3.ZERO, false)


static func _serve(mover: Movement, cmd: TankCommand, kind: String, target: Vector3, delta: float, want: Vector3, may_ask: bool) -> bool:
	var tank := mover.ctl.tank
	var name := String(tank.name)
	if mover.wheel_radius() <= 0.0 or not tank.is_alive() or Traffic.holding(name):
		_release(name)
		return false
	var tick := Engine.get_physics_frames()
	var crew: Crew = _crews.get(name)
	# A k-turn's "new goal" is the ORDER's goal moving (Movement._goal), not the route's steering carrot, which slides
	# along the path as the hull moves (CP-P1's gate: the carrot's 3.7 m released a two-leg plan 4 m into its first leg).
	var moved := 0.0
	if crew != null:
		moved = _flat(mover._goal, crew.order_goal) if crew.kind == "kturn" else _flat(target, crew.goal)
	if crew != null and (crew.kind != kind or tick - crew.tick_seen > STALE_TICKS or moved > NEW_GOAL_JUMP):
		if ManoeuvreCensus.trace_unit == name:
			print("PLANNER_SEAM %s %s: released at tick %d (%s; asked %d ticks ago, goal moved %.1f m; %s)" % [name, crew.kind, tick,
					"another kind" if crew.kind != kind else ("stale" if tick - crew.tick_seen > STALE_TICKS else "new goal"),
					tick - crew.tick_seen, moved,
					"pending" if crew.pending else "driving leg %d, %.1f m left" % [crew.executor.leg_index + 1, crew.executor.left_m]])
		_release(name)  # another kind of order, not asked for a while, or a new goal: whatever was planned is stale
		crew = null
	if crew == null:
		if not may_ask or int(_retry_until.get(name, -1)) > tick:
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
			# Round 31 (CP-P1's first judged series, seed 134's plaza: a rig arrived 4.5 m from its slot, the face's one
			# 3.5 m reverse chord left it 7.4 m out for the rest of the leg): manoeuvre's SLOT LAW, read from its own
			# names so the two cannot drift. (a) The slot = OrderController.face_slot (the last move_to's goal), only
			# under face_slot_on() and within FACE_SLOT_REACH x settle; (b) the plan may not END further from the slot
			# than it starts + FACE_SLOT_SLACK_M (round 30 M1b); (c) under turnhull (M1b(2), parked on main) every
			# pose within max(max(ORDER_ARRIVE, settle) - FACE_KEEP_MARGIN_M, from here) of the slot.
			var slot: Vector3 = mover.ctl.face_slot if Manoeuvre.face_slot_on() and mover.ctl != null else Vector3.INF
			if slot != Vector3.INF:
				var settle := Movement.settle_radius(tank.unit_id)
				var from_slot := Vector2(here.x - slot.x, here.z - slot.z).length()
				if from_slot <= Manoeuvre.FACE_SLOT_REACH * settle:
					var all_m := INF
					if Manoeuvre.turn_hull_on():
						all_m = maxf(maxf(TankBrain.ORDER_ARRIVE, settle) - Manoeuvre.FACE_KEEP_MARGIN_M, from_slot)
					req.keep(slot.x, slot.z, all_m, from_slot + Manoeuvre.FACE_SLOT_SLACK_M)
		"kturn":
			var to := Vector3(target.x - here.x, 0.0, target.z - here.z)
			if to.length() < 0.5:
				return null
			var goal := target
			if to.length() > HORIZON_M:
				goal = here + to.normalized() * (HORIZON_M * 0.8)
			# The k-turn's goal is AIM (CP-P1's gate, manoeuvre's War Rig nose-on: 4 legs where today drives 2): a pose
			# that points at the waypoint within KTURN_AIM_DEG with a clear straight run to it, from which the route's
			# pursuit law drives; standing ON a point 24 m off asked the lattice for ~2 degrees of heading, a wiggle.
			req.to(goal.x, goal.z, to.x, to.z, maxf(mover._arrive, 1.0), KTURN_AIM_DEG)
			req.aim = true
			req.arrive_gear = 1
		_:
			return null
	req.budget = BUDGET
	req.horizon_m = HORIZON_M
	req.in_world(PlannerNavWorld.for_tank(tank, mover.ctl.tanks_root))
	# R31.2 (H), manoeuvre's condition: on the tick a hull is first taken, `mover.yield_to_plan()` ends a half-driven
	# k-turn leg and both escapes and clears the stall and press clocks, so nothing resumes on release (main 298e4498,
	# called directly, no shim: the orchestrator's ruling).
	mover.yield_to_plan()
	var crew := Crew.new()
	crew.kind = kind
	crew.req = req
	crew.goal = target
	crew.order_goal = mover._goal if kind == "kturn" else target
	crew.asked_tick = tick
	crew.held_since = tick
	crew.tick_seen = tick
	crew.at = here
	crew.heading = forward
	_crews[name] = crew
	_queue.append(name)
	requests += 1
	return crew


static func _pend(mover: Movement, cmd: TankCommand, crew: Crew, name: String, tick: int, _delta: float) -> bool:
	var tank := mover.ctl.tank
	cmd.throttle = 0.0
	cmd.turn = 0.0
	pending_ticks += 1
	if tick - crew.asked_tick >= PENDING_TICKS:
		abandoned += 1
		holds.append(tick - crew.held_since)
		last_abandoned = {"name": name, "kind": crew.kind, "begun": crew.begun, "stepped": crew.stepped,
				"start": [snappedf(crew.req.start_x, 0.01), snappedf(crew.req.start_z, 0.01), snappedf(crew.req.start_fx, 0.01), snappedf(crew.req.start_fz, 0.01)],
				"goal": [snappedf(crew.req.goal_x, 0.01), snappedf(crew.req.goal_z, 0.01), snappedf(crew.req.goal_fx, 0.01), snappedf(crew.req.goal_fz, 0.01)],
				"stay_m": crew.req.tol_m, "speed": snappedf(tank.speed(), 0.01), "here": [snappedf(tank.global_position.x, 0.01), snappedf(tank.global_position.z, 0.01)]}
		_release(name)
		_retry_until[name] = tick + RETRY_TICKS
		return false
	if _queue.is_empty() or _queue[0] != name:
		queue_waits += 1
		return true
	if not crew.begun:
		# The head of the queue begins its search from where it NOW rests (fresher than the request tick's pose) -- and
		# only once it rests: a search begun from a rolling pose plans from where the hull is not (builder0 005a3837,
		# the rolling-face test: the first search ran out the hold, the retry from rest planned in 4 ticks).
		if absf(tank.speed()) > REST_MPS:
			# BRAKED to rest, not coasted: zero/zero lets a rig at speed roll on for over the 3 s hold (builder0 a073157e,
			# the rolling-face test: abandoned 1 before the fix). The opposite throttle on a straight lock, the k-turn's
			# throttle, as PlannerExecutor brakes a leg.
			cmd.throttle = -signf(tank.speed()) * BRAKE_THROTTLE
			return true
		var here := tank.global_position
		var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
		crew.req.at(here.x, here.z, forward.x, forward.z)
		crew.req.world.refresh_hulls(tank, mover.ctl.tanks_root)
		crew.at = here
		crew.heading = forward
		crew.stepped = 0
		# The 3 s cap (PENDING_TICKS) counts THE SEARCH, from here: a rig braking from 8 m/s spent ~45 of the 90 ticks
		# stopping and its search got 92 expansions (builder0 77db86eb, the rolling-face trace: start 8.8 m past the
		# face's home, stay 5 m, abandoned at 92). The hull's whole hold is pending_ticks; the cap bounds the search.
		crew.asked_tick = tick
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
		holds.append(tick - crew.held_since)
		_last_refusal[name] = [tick, plan.code]
		_release(name)
		_retry_until[name] = tick + RETRY_TICKS
		return false
	plans += 1
	plan_legs += plan.legs.size()
	last_plans.append({"tick": tick, "name": name, "kind": crew.kind, "legs": plan.describe(), "n_legs": plan.legs.size(),
			"expansions": plan.expansions, "metres": plan.metres, "cusps": plan.cusps,
			"start": [snappedf(crew.at.x, 0.01), snappedf(crew.at.z, 0.01)], "goal": [snappedf(crew.goal.x, 0.01), snappedf(crew.goal.z, 0.01)]})
	holds.append(tick - crew.held_since)
	crew.pending = false
	crew.executor = PlannerExecutor.new()
	crew.executor.start(plan, tank)
	if ManoeuvreCensus.trace_unit == name:
		print("PLANNER_SEAM %s %s: %s %s | %s" % [name, crew.kind, plan.code, plan.describe(), plan.why])
	return _drive(mover, cmd, crew, name, tick, _delta)


static func _drive(mover: Movement, cmd: TankCommand, crew: Crew, name: String, tick: int, delta: float) -> bool:
	# A FACE plan that touches a wall is a plan through something the snapshot did not hold (the navmesh and the live
	# hulls are all it knows): hand back on the first touch, not after STALL_S of grinding, so today's give-up reports
	# the hull unable within seconds (CP-P1's gate, the wedged semi). The k-turn kind keeps R31.2's stall/timeout abort.
	if crew.kind == "face" and mover.contact.touching and crew.executor.legs_driven + 1 <= crew.executor.plan.legs.size():
		aborted += 1
		if ManoeuvreCensus.trace_unit == name:
			print("PLANNER_SEAM %s face: aborted (wall contact on leg %d)" % [name, crew.executor.leg_index + 1])
		_release(name)
		_retry_until[name] = tick + RETRY_TICKS
		cmd.throttle = 0.0
		cmd.turn = 0.0
		return false
	var out := crew.executor.tick(delta)
	cmd.throttle = out.throttle
	cmd.turn = out.turn
	driving_ticks += 1
	if crew.executor.aborted:
		aborted += 1
		if ManoeuvreCensus.trace_unit == name:
			print("PLANNER_SEAM %s %s: aborted (%s), replans %d" % [name, crew.kind, crew.executor.reason, crew.replans])
		if crew.replans >= REPLANS_PER_ORDER or crew.kind == "face":
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
	# The run's report (CP-P1 bar line (a): "PlannerSeam.report() printed per run"): the drive harnesses are nav's
	# files, so the seam prints its own cumulative line at every event's end; the LAST one in a log is the run's.
	if REPORT_LINES:
		print("PLANNER_SEAM_REPORT " + JSON.stringify(report()))


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
	return {"crews": crews, "queue": _queue.duplicate(), "retry": _retry_until.duplicate(), "counters": report(),
			"last_refusal": _last_refusal.duplicate(true), "holds": holds.duplicate(), "last_plans": last_plans.duplicate(true)}


static func restore(snapshot: Dictionary) -> void:
	if not _queue.is_empty():
		Planner.cancel_session()
	_crews.clear()
	for name: String in snapshot["crews"]:
		_crews[name] = (snapshot["crews"][name] as Crew).copy()
	_queue.assign(snapshot["queue"])
	_retry_until = (snapshot["retry"] as Dictionary).duplicate()
	_last_refusal = (snapshot.get("last_refusal", {}) as Dictionary).duplicate(true)
	holds = PackedInt32Array(snapshot.get("holds", PackedInt32Array()))
	last_plans = (snapshot.get("last_plans", []) as Array).duplicate(true)   # native's note: else a twin appends twice a tick
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
