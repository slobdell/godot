class_name Manoeuvre
extends RefCounted
## Round 26 (manoeuvre M1): **a short move behind is a reverse, not a pirouette.**
##
## The lead: *"if I have a unit selected and I select a point to move to that's immediately behind it, the vehicle will
## do this N point turn to clumsily rotate in place and then eventually drive the very short distance to the point. A
## smart vehicle would have just reversed onto the point or did other 3 point turn maneuver (back up so that the target
## point becomes within its turning radius as it drives forward)"*
##
## Measured at main (b57838ed, builder0, `make manoeuvre-behind`): a tracked tank told to a point 5 m astern pivots
## 180 degrees and drives 2.5 m (2.3 s); with a drawn facing it pivots back again (5.4 s, 354 degrees of turning). A
## scout loops forward round its 5 m circle (26 m driven for a 5 m move; with a facing, 57 m, and 176 m of circling for
## 20 m astern).
##
## The decision, made ONCE per goal (a goal that jumps more than Movement.NEW_GOAL_JUMP is a new one): when the goal is
## within MAX_M and BEHIND (more than BEHIND_DEG off the nose, or inside a wheeled hull's forward turning circle), each
## way of getting there is SIMULATED with the plant itself (TankMotion.step_in_place) and the steering law that will
## drive it (Steering's), from the hull's state now, on open ground:
##   - `route`: today's forward drive (a pivot then a run for tracks; pure pursuit with the circle rule's reactive
##     back-up for wheels, which is the "back up until the point is outside the circle, then forward" manoeuvre);
##   - `reverse`: backing onto the point (Steering.reverse_toward / reverse_toward_wheels, whose own circle rule makes
##     it "pull forward, then back on" where one reverse arc cannot reach).
## An option is CLEAR when every simulated pose keeps the hull's whole outline inside the navmesh's clear reach
## (Movement._outline_ok, the planned reverse's own test) and no other hull stands in its swept corridor. The cheaper
## clear option by simulated time wins (`route` on a tie, and `route` is never refused: it is today's behaviour). A
## facing given with the order picks which end arrives first: a facing within FACING_KEEP_DEG of the way the hull
## points now asks for the tail to arrive first (reverse), any other for the nose (route, with its arrival gate).
##
## Executed as an ORDER: `reverse` is the move order with `reverse: true` and no `facing` (its arrival heading is the
## one it has), which drive() — GDScript or native — already drives; nothing below the order changes.

## Goals further than this are always `route` (a long reverse is slower than a pivot or a loop, and blind).
const MAX_M := 25.0
## A goal this far off the nose (degrees) is behind; for wheels, also any goal inside the forward turning circle.
const BEHIND_DEG := 100.0
## A facing within this of the hull's heading asks for a reverse arrival (degrees).
const FACING_KEEP_DEG := 60.0
## The simulation: its step (s), its horizon (s), and how often a pose is checked for clearance (every n steps).
const SIM_DT := 1.0 / 15.0
const SIM_HORIZON_S := 14.0
const CHECK_EVERY := 2
## Another hull's centre nearer than this to a simulated pose's centre (m, beyond both half-widths) blocks it.
const HULL_MARGIN_M := 1.0

static var plans := {}       # option -> plans chosen (measurement)
static var refused := {}     # why reverse was not taken -> count (measurement)


static func reset() -> void:
	plans = {}
	refused = {}
	face_plans = 0
	face_plan_legs = 0
	face_none = 0
	face_refused = 0
	hull_turns = 0
	face_keep_refused = 0
	hull_holds = 0
	off_seat_declines = 0
	arrivals_held = 0
	arrivals_held_ticks = 0
	_arrive_hold_until = {}
	face_keep_by_unit = {}


static func report() -> Dictionary:
	return {"plans": plans.duplicate(), "refused": refused.duplicate()}


## Round 31 (manoeuvre H3, C31.4; the two lead lines in `Gunnery` are manoeuvre's grant): **the aim leads on the motion
## a target really makes** (`Tank.real_velocity`), not the velocity the blocked slide handed back — a hull pinned on a
## wall reported 12 m/s and was led 12 m/s ahead of where it sat. OPT-IN until CP-H judges it: `--gun-off=realspeed`
## turns it ON. Gunnery's C++ twin (`native_gun`) does not read this switch until native mirrors it, so an arm with it
## must run the GDScript path (`--brains-off=native`); the CP-H runner refuses a native arm.
const GUN_OFF_NAMES: Array[String] = ["realspeed"]
static var _gun_off := PackedStringArray()
static var _gun_off_parsed := false


static func gun_switched(name: String) -> bool:
	if not _gun_off_parsed:
		_gun_off_parsed = true
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--gun-off="):
				_gun_off = arg.trim_prefix("--gun-off=").split(",")
				for each: String in _gun_off:
					if not GUN_OFF_NAMES.has(each):
						push_error("--gun-off=%s: no such switch (have %s)" % [each, ", ".join(GUN_OFF_NAMES)])
				break
	return _gun_off.has(name)


const REAL_SPEED_DEFAULT := true  # OPT-IN until CP-H: `--gun-off=realspeed` flips it


static func real_speed_on() -> bool:
	return REAL_SPEED_DEFAULT != gun_switched("realspeed")


## The velocity a gun leads `target` by: its real motion with `realspeed`, else the plant's reading (round 30's).
static func lead_velocity(target: Tank) -> Vector3:
	return target.real_velocity if real_speed_on() else target.estimated_velocity


static func _note(table: Dictionary, key: String) -> void:
	table[key] = int(table.get(key, 0)) + 1


## Is `goal` a short move behind for this hull now (the cheap test that gates the simulation)?
static func behind(tank: Tank, goal: Vector3, radius: float) -> bool:
	var here := tank.global_position
	var to := Vector2(goal.x - here.x, goal.z - here.z)
	var d := to.length()
	if d > MAX_M or d < 0.5:
		return false
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	if absf(nose.angle_to(to)) >= deg_to_rad(BEHIND_DEG):
		return true
	if radius > 0.0:
		# Inside the forward turning circle on the goal's side: no forward arc reaches it.
		var left := Vector2(nose.y, -nose.x)
		var side := 1.0 if nose.angle_to(to) <= 0.0 else -1.0
		var centre := Vector2(here.x, here.z) - left * side * radius
		return centre.distance_to(Vector2(goal.x, goal.z)) < radius
	return false


## The option for `goal`: "reverse" or "route". `mover` supplies the hull, the map and the clearance test.
static func choose(mover: Movement, goal: Vector3, order: Dictionary, arrive: float) -> String:
	var tank := mover.ctl.tank
	var radius := mover.wheel_radius()
	if not behind(tank, goal, radius):
		return "route"
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var want_tail := false
	var want_nose := false
	var facing: Variant = order.get("facing")
	if facing is Array and (facing as Array).size() >= 2:
		var f := Vector2(float(facing[0]), float(facing[1]))
		if f.length_squared() > 1e-6:
			want_tail = absf(nose.angle_to(f)) <= deg_to_rad(FACING_KEEP_DEG)
			want_nose = not want_tail
	if want_nose:
		_note(refused, "facing_nose")
		return "route"
	var reverse := simulate(mover, goal, arrive, -1)
	if not bool(reverse["clear"]):
		_note(refused, String(reverse["blocked"]))
		return "route"
	if not bool(reverse["arrived"]):
		_note(refused, "no_arrival")
		return "route"
	if want_tail:
		return "reverse"
	var route := simulate(mover, goal, arrive, 1)
	if bool(route["arrived"]) and float(route["seconds"]) <= float(reverse["seconds"]):
		_note(refused, "route_faster")
		return "route"
	return "reverse"


## Drive `gear` (+1 today's forward law, -1 the reverse law) from the hull's state now to `goal`, on open ground.
## {arrived, seconds, legs, metres, clear, blocked}.
static func simulate(mover: Movement, goal: Vector3, arrive: float, gear: int) -> Dictionary:
	var tank := mover.ctl.tank
	var radius := mover.wheel_radius()
	var state := TankMotion.state_of(tank)
	var map := tank.get_world_3d().navigation_map
	var frame := mover._kturn_frame(tank)
	var start := mover._outline_offs(map, frame, tank.global_position, Vector3(state["forward"]))
	var others := _others(mover)
	var t := 0.0
	var legs := 0
	var last_gear := 0
	var metres := 0.0
	var steps := 0
	var out := {"arrived": false, "seconds": SIM_HORIZON_S, "legs": 0, "metres": 0.0, "clear": true, "blocked": ""}
	while t < SIM_HORIZON_S:
		var at: Vector3 = state["position"]
		var forward: Vector3 = state["forward"]
		var speed := float(state["speed"])
		var remaining := Vector2(goal.x - at.x, goal.z - at.z).length()
		var drive: Vector2
		if radius > 0.0:
			drive = Steering.drive_toward_wheels(at, forward, goal, arrive, radius, speed, remaining) if gear > 0 \
					else Steering.reverse_toward_wheels(at, forward, goal, arrive, radius, speed, remaining)
		else:
			drive = Steering.drive_toward(at, forward, goal, arrive, remaining) if gear > 0 \
					else Steering.reverse_toward(at, forward, goal, arrive, remaining)
		if drive == Vector2.ZERO:
			out["arrived"] = true
			# The hull still has to stop: count the braking from here (v / braking), as the order completes at rest.
			t += absf(speed) / maxf(float(state["braking_mps2"]), 0.1)
			break
		TankMotion.step_in_place(state, drive.x, drive.y, SIM_DT)
		t += SIM_DT
		steps += 1
		var moved: Vector3 = state["position"]
		metres += Vector2(moved.x - at.x, moved.z - at.z).length()
		var v := float(state["speed"])
		var g := 0 if absf(v) <= ManoeuvreCensus.CUSP_DEADBAND else (1 if v > 0.0 else -1)
		if g != 0 and g != last_gear:
			legs += 1
			last_gear = g
		if steps % CHECK_EVERY == 0:
			if not mover._outline_ok(map, frame, moved, Vector3(state["forward"]), start):
				out["clear"] = false
				out["blocked"] = "static"
				break
			var hull := _hull_hit(moved, frame, others, tank.global_position)
			if hull != "":
				out["clear"] = false
				out["blocked"] = hull
				break
	out["seconds"] = t
	out["legs"] = legs
	out["metres"] = metres
	return out


## Every other living hull as [x, z, reach, kind] (reach: both half-widths + HULL_MARGIN_M; kind friendly/enemy).
static func _others(mover: Movement) -> Array:
	var tank := mover.ctl.tank
	var out: Array = []
	if mover.ctl.tanks_root == null:
		return out
	var mine: Array = Movement.hull_box(tank.unit_id)
	for node: Node in mover.ctl.tanks_root.get_children():
		var other := node as Tank
		if other == null or other == tank or not other.is_alive():
			continue
		var theirs: Array = Movement.hull_box(other.unit_id)
		out.append([other.global_position.x, other.global_position.z,
				(float(mine[0]) + float(theirs[0])) * 0.5 + HULL_MARGIN_M,
				"friendly" if other.team == tank.team else "enemy"])
	return out


## The kind of the first hull this pose comes too near, or "": a conservative disc (half the hull's length beyond
## both half-widths and the margin) — and only when the pose is nearer it than the start was (a squadmate parked
## beside the start is not in the way of a move away from it).
static func _hull_hit(at: Vector3, frame: Array, others: Array, from: Vector3) -> String:
	for row: Array in others:
		var d := Vector2(float(row[0]) - at.x, float(row[1]) - at.z).length()
		if d < float(row[2]) + float(frame[1]) * 0.5:
			var d0 := Vector2(float(row[0]) - from.x, float(row[1]) - from.z).length()
			if d < d0 - 0.25:
				return String(row[3])
	return ""


# ---- M1b (C26.9): a wheeled hull facing a new way at rest turns in planned legs, not the creep's 0.5 s shuffle --------
#
# A `face` order on wheels used to command 0.35 throttle at full lock: under the plant's creep threshold (0.5 x |turn|),
# so TankMotion alternated 0.5 s legs forward and back until the heading came round (measured at main: the War Rig
# turning 180 deg at rest took 30-45 s and 27-89 legs). The yaw a wheeled hull gets is metres x turn / R in EITHER gear,
# so every way of turning 180 deg costs the same R x pi metres; the only question is how few cusps. The plan: legs on
# ONE lock (the way the heading must swing), alternating gear, each as long as the hull's whole outline stays clear
# (Movement._outline_ok) and no other hull is approached (the hull discs), the last one exactly as long as the heading
# needs; forward-first or reverse-first, fewer legs then less travel. At most FACE_LEGS legs; none fits: the creep
# stands (counted).

const FACE_STEP_M := 0.5
const FACE_LEGS := 5
const FACE_LEG_MIN_M := 0.75
const FACE_MARGIN_M := 0.25
## Aligned within this (degrees): the last leg is cut to it, and a hull already within it does not plan.
const FACE_ALIGNED_DEG := 8.0
## The most a leg turns the heading (radians): pi/3, so a half turn is a three-point turn.
const FACE_LEG_TURN := PI / 3.0

static var face_plans := 0
static var face_plan_legs := 0
static var face_none := 0
static var face_refused := 0   # planned legs the world refused (timed out): handed back to the creep


## Legs (Vector2(gear, metres)) that bring the hull at (here, forward) round to `want` (a flat unit heading), with the
## lock in `turn` (+1 right, -1 left). Empty when nothing of at most FACE_LEGS legs fits.
static func plan_face(mover: Movement, here: Vector3, forward: Vector3, want: Vector3, home: Vector3) -> Array:
	var tank := mover.ctl.tank
	var radius := mover.wheel_radius()
	if radius <= 0.0:
		return []
	var error := forward.signed_angle_to(want, Vector3.UP)
	if absf(error) <= deg_to_rad(FACE_ALIGNED_DEG):
		return []
	# Positive error = the heading must turn LEFT (counter-clockwise): turn < 0 (Steering's convention).
	var turn := -1.0 if error > 0.0 else 1.0
	var map := tank.get_world_3d().navigation_map
	var frame := mover._kturn_frame(tank)
	var start := mover._outline_offs(map, frame, here, forward)
	var others := _others(mover)
	# First the even split: n equal legs alternating gear (each at most FACE_LEG_TURN), the fewest n whose whole sweep
	# is clear and that ends within the hull's settle radius of where it stood — a turn AT REST stays at its spot (one
	# 45-degree arc on a War Rig's 12 m lock is a 9 m chord, and its post is then too far to keep). Then, where none
	# fits, legs as long as the clear room allows (`_face_legs`).
	# The settle radius less a metre for the roll past each leg's end (a scout's minute of facings measured 5.1 m off
	# its spot against the creep bound's 4.5 with the whole radius).
	var stay := maxf(Movement.settle_radius(tank.unit_id) - 1.0, 1.5)
	# Round 30 (M1b, from rounds 28-29's M1): the SLOT the hull last drove to. A crew arriving at the edge of its arrive
	# radius turned with legs that carried it further off, the brain sent it back, it arrived at the edge again: a law
	# artillery piece ping-ponged face/move for ~32 s (hull-rest probe, law seed 21, drawn move). A plan may not end
	# further from the slot than where it starts (+ FACE_SLOT_SLACK_M), and of the two first gears the one ending
	# nearer the slot wins. Round 28's version read `mover._goal`, which Movement.idle() clears every tick a face
	# runs, so it anchored nothing; the slot is OrderController.face_slot (the last move_to's goal). `--nav-off=faceslot`.
	var slot := mover.ctl.face_slot if face_slot_on() and mover.ctl != null else Vector3.INF
	if slot != Vector3.INF and _flat(here, slot) > FACE_SLOT_REACH * Movement.settle_radius(tank.unit_id):
		slot = Vector3.INF  # a face nowhere near the last drive's goal: not a slot to keep
	var slot_limit := _flat(here, slot) + FACE_SLOT_SLACK_M if slot != Vector3.INF else INF
	if slot != Vector3.INF:
		face_slot_kept += 1
	# Round 31 (M1b(2), from round 29's facekeep, under `turnhull`): ...and not on the way either. The end alone was
	# checked: a gang catapult 5 m from its slot planned two 5.5 m legs, forward then back, whose cusp was 8 m out, past
	# its arrive radius (5.4 m): the brain re-sent the move mid-plan, the hull drove back, faced again, every second for
	# a minute (hull-rest, gangs seed 1, right-drag). Every pose stays inside the crew's arrive radius (less
	# FACE_KEEP_MARGIN_M), or no further out than it starts. Turn-hull asks wheeled turret hulls for far more faces at
	# the edge of their slot, so the two go together as one switch.
	_keep_slot = slot if turn_hull_on() else Vector3.INF
	_keep_unit = tank.unit_id
	_keep_m = maxf(maxf(TankBrain.ORDER_ARRIVE, Movement.settle_radius(tank.unit_id)) - FACE_KEEP_MARGIN_M, _flat(here, slot))
	for n in range(1, FACE_LEGS + 1):
		if absf(error) / n > FACE_LEG_TURN + 0.001:
			continue
		var chosen: Array = []
		var chosen_m := INF
		for first: int in [1, -1]:
			var even := _face_even(mover, map, frame, start, others, here, forward, turn, radius, first, n,
					absf(error) * radius / n, stay, home)
			if even.is_empty():
				continue
			if slot == Vector3.INF:
				return even
			var off := _flat((mover._fill_end(here, forward, turn, even)[0] as Vector3), slot)
			if off > slot_limit:
				face_slot_refused += 1
			elif off < chosen_m:
				chosen = even
				chosen_m = off
		if not chosen.is_empty():
			return chosen
	var best: Array = []
	for first: int in [1, -1]:
		var plan := _face_legs(mover, map, frame, start, others, here, forward, want, turn, radius, first)
		if plan.is_empty():
			continue
		var end: Array = mover._fill_end(here, forward, turn, plan)
		if Vector2((end[0] as Vector3).x - home.x, (end[0] as Vector3).z - home.z).length() > stay:
			continue  # it would end too far from its spot: the creep (bounded by creepbound) instead
		if _flat(end[0] as Vector3, slot) > slot_limit:
			continue  # it would leave the slot further behind (see above)
		if best.is_empty() or plan.size() < best.size() \
				or (plan.size() == best.size() and Movement._fill_metres(plan) < Movement._fill_metres(best)):
			best = plan
	return best


## Round 30 (M1b): see plan_face. `--nav-off=faceslot` = round 27's plans (no slot anchor).
const FACE_SLOT_SLACK_M := 0.5
const FACE_SLOT_REACH := 2.0
## Arm counters: faces planned with a slot to keep, and even plans refused for leaving it further behind.
static var face_slot_kept := 0
static var face_slot_refused := 0


static func face_slot_on() -> bool:
	return not Movement.switched_off("faceslot")


## Round 31 (M1b(2), his round-28 call "TURN THE WHOLE VEHICLE"): a wheeled TURRET hull given a DRAWN facing turns its
## hull to it (the face planner's legs) instead of leaving it to the turret — `TankBrain._order_move`'s decline is
## lifted for it (C31.8) — and every pose of a face plan keeps inside the arrive radius (facekeep). ONE switch:
## `--nav-off=turnhull` flips TURN_HULL_DEFAULT (false = OPT-IN until its bar passes).
const TURN_HULL_DEFAULT := true
const FACE_KEEP_MARGIN_M := 0.75
static var _keep_slot := Vector3.INF
static var _keep_m := INF
## Round 33 (planner's s69 trace) / round 34 (C34.4 (2), the seam agreed with brains): an arrival declared while a planned
## leg is still driving is a flicker, not an arrival. Reversing on a k-turn leg (seam `kturn OK R+1.0x12.5`), Green_Guns_7
## crossed inside its attack-move goal's 6 m arrival radius; `TankBrain._act`'s arrived branch turned the move into a face
## "from post" mid-leg, the k-turn was dropped, and the held-post rule refused the next move_tos for 36 ticks. While this
## is true the move stands until the leg ends, or until ARRIVE_LEG_HOLD_S of leg time on this order (a leg that never
## ends cannot deny an arrival). Brains' `_act` asks through an adapter with exactly this signature; the switch is
## `--nav-off=arriveleg` (default below).
const ARRIVE_LEG_DEFAULT := true
const ARRIVE_LEG_HOLD_S := 3.0
## Arm counters: arrivals held (once per order, its first held think) and the think ticks they were held.
static var arrivals_held := 0
static var arrivals_held_ticks := 0
## Per mover (by the Movement's instance id, never a crew's name: names repeat in a rematch, C34.6): the last tick this
## order's arrival may be held (Movement.new_order forgets it; a dead mover's entry is pruned). Kept here, not as a
## Movement member: every Movement member is a field of native's exec-state table (exec_fields.h), and this is GDScript
## decision state the C++ never reads.
static var _arrive_hold_until := {}


static func arrive_hold_forget(mover: Object) -> void:
	_arrive_hold_until.erase(mover.get_instance_id())


static func _arrive_hold_prune() -> void:
	for id: int in _arrive_hold_until.keys():
		if not is_instance_id_valid(id):
			_arrive_hold_until.erase(id)


static func arrive_leg_on() -> bool:
	return ARRIVE_LEG_DEFAULT != Movement.switched_off("arriveleg")


static func leg_holds_arrival(brain: TankBrain) -> bool:
	if not arrive_leg_on() or String(brain.move_order.get("type", "")) != "move_to" or not brain.movement.manoeuvring():
		return false
	var tick := Engine.get_physics_frames()
	var mover := brain.movement.get_instance_id()
	if not _arrive_hold_until.has(mover):
		if _arrive_hold_until.size() >= 64:
			_arrive_hold_prune()
		_arrive_hold_until[mover] = tick + int(SimClock.TICK_RATE * ARRIVE_LEG_HOLD_S)
		arrivals_held += 1
	elif tick > int(_arrive_hold_until[mover]):
		return false  # the leg has run its bound on this order: the arrival goes through
	arrivals_held_ticks += 1
	return true


## Round 35 (W2, C35.7, CP-F attempt 5, the face side): A FACE NO PLAN FITS GIVES UP CLEANLY. Attempt 4 (R34.18) turned
## the hull right wherever a plan fitted and failed on settling: a face whose plans kept failing crept at the 0.35 lock to
## the stage's judge (face_creep at the judge: screen 8 v 0, attack-move 4 v 0). Now FACE_SETTLE_FAILS failed plans in a
## row (none fitted, or one the world refused) for the same want (within Movement.FACE_REPLAN_DEG) end the face as it is:
## the hull stands still and the turret keeps the facing; between the failed tries it waits still instead of creeping.
## The want swinging further, a new order, or a gap in the face re-arms it. `--nav-off=facesettle` flips the default.
## TURRET hulls only: a hull-fixed scout's hull is its gun's arc, so it keeps creeping round (the dev read, lab/cpf5 bdacb1786,
## builder0, hull-rest 460-463 drawn: with fixed hulls included, wheels/fixed crews >= 45 deg off rose 33 -> 48 over six tasks).
## State per mover by its INSTANCE id (M2's precedent: every Movement member is a field of native's exec table, and this
## is GDScript decision state; wheeled faces are handed back to GDScript, reason 3, so nothing here runs in C++).
const FACE_SETTLE_DEFAULT := true
const FACE_SETTLE_FAILS := 3
## Arm counters: faces that gave up (once per want), and failed plans counted toward it.
static var face_settles := 0
static var face_settle_fails := 0
static var _face_settle := {}  # mover instance id -> [fails, want (flat unit), given up]


static func face_settle_on() -> bool:
	return FACE_SETTLE_DEFAULT != Movement.switched_off("facesettle")


## The faces the give-up acts on (the design note to the orchestrator, round 35): ONLY a facing he gave that turnhull lifted to
## the HULL of a wheeled TURRET crew -- `from` "drawn" (drawn_face), or "order"/"sector" (which reach a wheeled turret hull only
## through the lift, or as a told face). Every plain face (a lab's or a probe's, the planner seam's wedged semi) keeps round 9's
## creep and its give-up window bit for bit; a hull-fixed scout's hull is its gun's arc, so it keeps trying.
const FACE_SETTLE_FROM: Array[String] = ["drawn", "order", "sector"]


static func face_settles_here(mover: Movement) -> bool:
	if not face_settle_on() or not turn_hull_on() or mover.ctl == null or mover.ctl.tank.mount == "fixed":
		return false
	return FACE_SETTLE_FROM.has(String(mover.ctl.move_order.get("from", "")))


static func _same_want(a: Vector3, b: Vector3) -> bool:
	return absf(a.signed_angle_to(b, Vector3.UP)) <= deg_to_rad(Movement.FACE_REPLAN_DEG)


## A plan for `want` failed on this mover; true when that makes FACE_SETTLE_FAILS in a row (the face gives up now).
static func face_failed_id(id: int, want: Vector3) -> bool:
	var row: Array = _face_settle.get(id, [0, want, false])
	if not _same_want(row[1], want):
		row = [0, want, false]
	row[0] = int(row[0]) + 1
	face_settle_fails += 1
	var gives_up := int(row[0]) >= FACE_SETTLE_FAILS and not bool(row[2])
	if gives_up:
		row[2] = true
		face_settles += 1
	if _face_settle.size() >= 64 and not _face_settle.has(id):
		for key: int in _face_settle.keys():
			if not is_instance_id_valid(key):
				_face_settle.erase(key)
	_face_settle[id] = row
	return gives_up


## Has this mover's face for `want` given up? A want swung beyond FACE_REPLAN_DEG re-arms it (forgets the row).
static func face_given_up_id(id: int, want: Vector3) -> bool:
	var row: Variant = _face_settle.get(id)
	if row == null:
		return false
	if not _same_want((row as Array)[1], want):
		_face_settle.erase(id)
		return false
	return bool((row as Array)[2])


## A face plan for `want` failed on `mover` (none fitted, or `refused`: a planned leg the world would not turn). Counts toward
## the give-up only AT REST (a plan made while the hull still rolls is not "no plan fits": planner's rolling-face test, the seam
## asks again from rest). Reporting is round 9's own window, run while the face stands (Movement._face_still).
const FACE_SETTLE_REST_MPS := 0.5


static func face_plan_failed(mover: Movement, want: Vector3, refused := false) -> void:
	if not refused and absf(mover.ctl.tank.speed()) > FACE_SETTLE_REST_MPS:
		return
	face_failed_id(mover.get_instance_id(), want)


## Per mover: the face began with the hull rolling and it has not yet come to rest (its home follows it until then).
static var _face_rolling := {}


static func face_roll_begin(id: int, rolling: bool) -> void:
	if rolling:
		if _face_rolling.size() >= 64:
			for key: int in _face_rolling.keys():
				if not is_instance_id_valid(key):
					_face_rolling.erase(key)
		_face_rolling[id] = true
	else:
		_face_rolling.erase(id)


static func face_still_rolling(id: int, speed: float) -> bool:
	if not _face_rolling.has(id):
		return false
	if speed <= FACE_SETTLE_REST_MPS:
		_face_rolling.erase(id)
		return false
	return true


static func face_settle_forget_id(id: int) -> void:
	_face_settle.erase(id)


## The last face tick of a mover: [tick, want, aligned that tick] (for face_settled_id).
static var _face_now := {}


static func face_note_id(id: int, tick: int, want: Vector3, aligned: bool) -> void:
	if _face_now.size() >= 64 and not _face_now.has(id):
		for key: int in _face_now.keys():
			if not is_instance_id_valid(key):
				_face_now.erase(key)
	_face_now[id] = [tick, want, aligned]


static func face_settled_id(id: int, planned_leg: bool, since_tick: int) -> bool:
	var row: Variant = _face_now.get(id)
	if row == null or int((row as Array)[0]) < since_tick:
		return false
	if bool((row as Array)[2]):
		return true
	return not planned_leg and face_given_up_id(id, (row as Array)[1])


## Round 35 (W1c, R35.12): THE STALL GATE READS THE DRIVE'S INTENT AGAINST A FRIENDLY HULL. Brains' E1 census: attack-move
## legs waited on crews holding a move but making < 0.5 m/s 20-50 m off their slots for up to 71 s; traced (references/round35/
## manoeuvre/w1c-trace): law-605 Green_Eyes_4 sat 70 s nose-on to a parked crew of another squad (Green_Eyes II_5, whose one
## give-way drove it 2.4 m and left it touching), law-607 Green_Guns_6 23 m off its goal in a pack of friends. ORCA throttled
## both drives to pace 0.05-0.09, so the command was 0.05-0.09 while the drive asked for full: unstick's |throttle| > 0.5 (driving
## hard, not moving) never ran its clock, H1's escape (ask, reverse, stand) never started and nobody asked the parked crew again.
## With this on, a ROUTED move (move_to, not direct) touching a friendly hull, or `blocked` by one, is tested on |throttle| /
## pace (pace < 1); every other case keeps the command. `--nav-off=stallintent` flips STALL_INTENT_DEFAULT (false = OPT-IN).
const STALL_INTENT_DEFAULT := false
## The pace floor the intent divides by (a pace-0 drive is a Traffic hold or a stop: unstick does not run on a hold).
const STALL_INTENT_MIN_PACE := 0.05
## Arm counter: unstick ticks whose throttle test passed only by the intent reading (stride ticks by their stride).
static var stall_intent_ticks := 0


static func stall_intent_on() -> bool:
	return STALL_INTENT_DEFAULT != Movement.switched_off("stallintent")


## The throttle unstick's stall rule tests: the command, or under `stallintent` against a friendly hull its intent.
static func stall_throttle(mover: Movement, cmd: TankCommand, order: Dictionary) -> float:
	var command := absf(cmd.throttle)
	if command > 0.5 or not stall_intent_on() or mover.pace_now >= 1.0:
		return command
	if String(order.get("type", "")) != "move_to" or bool(order.get("direct", false)) or order.get("reverse", false):
		return command
	if not _against_friend(mover):
		return command
	var intent := command / maxf(mover.pace_now, STALL_INTENT_MIN_PACE)
	if intent > 0.5:
		stall_intent_ticks += mover.ctl._step
	return intent


static func _against_friend(mover: Movement) -> bool:
	var tank := mover.ctl.tank
	for i in tank.get_slide_collision_count():
		var hull := tank.get_slide_collision(i).get_collider() as Tank
		if hull != null and hull.team == tank.team:
			return true
	if mover.phase == "blocked" and mover.blocked_by != "" and mover.ctl.tanks_root != null:
		var blocker := mover.ctl.tanks_root.get_node_or_null(NodePath(mover.blocked_by)) as Tank
		return blocker != null and blocker.team == tank.team
	return false


## Arm counters: drawn faces a wheeled turret hull took with its hull (the decline lifted); face-plan steps refused
## for leaving the arrive radius.
static var hull_turns := 0
static var face_keep_refused := 0


static func turn_hull_on() -> bool:
	return TURN_HULL_DEFAULT != Movement.switched_off("turnhull")


## Did the player DRAW this crew's facing (its element task, or its own K1 order, carries one)? Read by the brain's
## decline (`TankBrain._order_move`) under `turnhull`.
static func drawn_facing(brain: TankBrain) -> bool:
	return drawn_direction(brain) != null


## The facing he DREW for this crew as a flat unit direction (its element task's, else its own K1 order's, else -- with
## no order current -- the station its last order left it at when that order named a facing), or null.
static func drawn_direction(brain: TankBrain) -> Variant:
	var source: Variant = brain.get("_element_source")
	if source != null:
		var mine: Variant = ElementFeed.element_of(source, String(brain.tank.name))
		if mine != null and "task" in mine:
			var task: Variant = mine.get("task")
			return TankBrain._direction_of((task as Dictionary).get("facing")) if task is Dictionary else null
	if brain._ordered_facing():
		return brain.intended_facing()
	# Round 33 (CP-F, the orchestrator's call): a plain move with a drawn facing COMPLETES on arrival, and the contact that follows is the
	# commonest case of all; the station keeps whether its heading was drawn (`Orders._remember_station`).
	var orders: Variant = brain._order_source
	if orders == null or not orders.has_method("station") or not OrderFeed.current(orders, String(brain.tank.name)).is_empty():
		return null
	var post: Variant = orders.call("station", String(brain.tank.name))
	if not post is Dictionary or not bool((post as Dictionary).get("drawn", false)):
		return null
	return TankBrain._direction_of((post as Dictionary).get("heading"))


## The brain's decline is lifted for this order (turn-hull ON, a face from the crew's order, a drawn facing).
static func hull_takes_face(brain: TankBrain, order: Dictionary) -> bool:
	# "order": the facing on the crew's own K1 order. "sector": a crew in an ELEMENT gets his drawn facing through its
	# element task, and the brain sends that face as its sector watch (`TankBrain._sector_source`). Judged run 1 lifted
	# only "order", which missed every gang element crew (gang_ifv 2195 `stop` rows v 141 `face`; at rest within 15 deg
	# 37 % v artillery's 95 %); `drawn_facing` is what says the facing is his, the label only says which way it came.
	if not turn_hull_on() or not String(order.get("from", "")) in ["order", "sector"] or not drawn_facing(brain):
		return false
	if off_seat(brain):
		return false
	hull_turns += 1
	return true


## Round 33 (CP-F attempt 3, R33.23): a crew standing further from its held seat than it may and still be ARRIVED is on its
## way there, so neither lift applies and the decline stands (`stop`): the move finishes first and the hull turns once
## seated. Traced (builder2, --fixed-fps, hull-rest gangs SBF s44/s45): Guns_5 stood 6.5-8 m from its seat, its dressing
## move reversed toward it for a second, then the lifted face replaced the move and crept it, every second to the 75 s
## judge (support-by-fire movers 8 v 3).
## R32.3's ARRIVED_M (workstreams.md): a crew within this of its seat at completion HAS arrived, the definition the bar's
## (f) reads. ORDER_ARRIVE's 3.5 m left crews seated 3.5-7 m out unturned (builder0, 40-45: attack-move within 15 deg
## 78.8 -> 58.8 %).
const SEAT_ARRIVED_M := 7.0


static func off_seat(brain: TankBrain) -> bool:
	var seat: Vector3 = brain.face_slot
	if seat == Vector3.INF:
		return false
	var here := brain.tank.global_position
	if _flat(here, seat) <= maxf(SEAT_ARRIVED_M, Movement.settle_radius(brain.tank.unit_id)):
		return false
	off_seat_declines += 1
	return true


## Round 33 (CP-F, F1): ...and a face the brain DECLINES under turnhull (round 8: a contact the turret takes) keeps the
## HULL on his drawn heading instead of becoming `stop`. Traced (builder0, hull-rest gangs s66 faced_move, turnhull ON):
## the War Rig's planned face was cut to `stop` mid-leg each time the quiet enemy came into sight at ~74 m, and it ended
## 44-126 deg off. The turret still fights the contact (gunnery picks its own target); the front armour stays where he
## pointed. {} when off, or nothing was drawn (the round-8 decline stands).
static func drawn_face(brain: TankBrain) -> Dictionary:
	if not turn_hull_on():
		return {}
	var direction: Variant = drawn_direction(brain)
	if direction == null or off_seat(brain):
		return {}
	var here := brain.tank.global_position
	var look: Vector3 = Vector3(here.x, 0.0, here.z) + (direction as Vector3) * 20.0
	hull_holds += 1
	return {"type": "face", "x": look.x, "z": look.z, "from": "drawn"}


## Arm counter: declined faces that kept the hull on his drawn heading instead (drawn_face).
static var hull_holds := 0
## Arm counter (R33.23): faces left declined because the crew was still off its seat (`off_seat`).
static var off_seat_declines := 0


static func _kept(at: Vector3) -> bool:
	if _flat(at, _keep_slot) > _keep_m:
		face_keep_refused += 1
		face_keep_by_unit[_keep_unit] = int(face_keep_by_unit.get(_keep_unit, 0)) + 1
		return false
	return true


## Measurement: face_keep_refused per unit id (the orchestrator's ask for attempt 2: is facekeep what stops the
## newly lifted crews?), and the unit whose plan is being made.
static var face_keep_by_unit := {}
static var _keep_unit := ""


static func _flat(a: Vector3, b: Vector3) -> float:
	if b == Vector3.INF:
		return 0.0
	return Vector2(a.x - b.x, a.z - b.z).length()


## n legs of `metres` each, alternating gear from `first`, stepped and checked like _face_legs; empty when a step is not
## clear or the end is further than `stay` from `here`.
static func _face_even(mover: Movement, map: RID, frame: Array, start: PackedFloat32Array, others: Array, here: Vector3,
		forward: Vector3, turn: float, radius: float, first: int, n: int, metres: float, stay: float, home: Vector3) -> Array:
	var at := here
	var heading := forward
	var gear := first
	var legs: Array = []
	for leg in n:
		var travelled := 0.0
		while travelled < metres - 0.001:
			var step := minf(FACE_STEP_M, metres - travelled)
			var next := Movement._fill_step(at, heading, gear, turn, radius, step)
			if not mover._outline_ok(map, frame, next[0], next[1], start) or _hull_hit(next[0], frame, others, here) != "" \
					or not _kept(next[0]):
				return []
			at = next[0]
			heading = next[1]
			travelled += step
		legs.append(Vector2(gear, metres))
		gear = -gear
	if Vector2(at.x - home.x, at.z - home.z).length() > stay:
		return []
	return legs


static func _face_legs(mover: Movement, map: RID, frame: Array, start: PackedFloat32Array, others: Array, here: Vector3,
		forward: Vector3, want: Vector3, turn: float, radius: float, first: int) -> Array:
	var at := here
	var heading := forward
	var gear := first
	var legs: Array = []
	for leg in FACE_LEGS:
		var travelled := 0.0
		var poses: Array = []
		var done := false
		var blocked := false
		# A leg swings the heading at most FACE_LEG_TURN: a half turn is three legs (forward, back, forward), and the
		# hull stays within about a turning radius of where it stood (one 37 m arc took a War Rig 25 m off its spot).
		var cap := radius * FACE_LEG_TURN
		while travelled < cap - 0.001:
			var left := absf(heading.signed_angle_to(want, Vector3.UP))
			if left <= deg_to_rad(FACE_ALIGNED_DEG) * 0.5:
				done = true
				break
			var step := minf(minf(FACE_STEP_M, left * radius), cap - travelled)
			var from_at: Vector3 = at if poses.is_empty() else poses[-1][0]
			var from_heading: Vector3 = heading if poses.is_empty() else poses[-1][1]
			var next := Movement._fill_step(from_at, from_heading, gear, turn, radius, step)
			if not mover._outline_ok(map, frame, next[0], next[1], start) or _hull_hit(next[0], frame, others, here) != "" \
					or not _kept(next[0]):
				blocked = true
				break
			poses.append(next)
			travelled += step
			heading = next[1]
		if not done and not blocked:
			# The cap, not a wall: the leg is whole; does the heading now need nothing more?
			done = absf(heading.signed_angle_to(want, Vector3.UP)) <= deg_to_rad(FACE_ALIGNED_DEG) * 0.5
			if not done:
				at = poses[-1][0]
				legs.append(Vector2(gear, travelled))
				gear = -gear
				continue
		if done:
			if travelled > 0.0:
				legs.append(Vector2(gear, travelled))
			return legs
		var usable := travelled - FACE_MARGIN_M
		if usable < FACE_LEG_MIN_M:
			return []
		# Back off the margin: the last pose at or before `usable`.
		var steps := maxi(int(floor(usable / FACE_STEP_M)), 1)
		at = poses[steps - 1][0]
		heading = poses[steps - 1][1]
		legs.append(Vector2(gear, steps * FACE_STEP_M))
		gear = -gear
	return []


## Round 33 (C33.9, his playtest: a lone law scout circled by a faster attacker "was repeatedly driving forward and
## backward trying to yaw right", out-turned and hit without a shot). A FIXED gun on WHEELS facing a target that moves
## round it does not shuffle (the face creep, 38 gear changes in 30 s on the laptop stage) but TURNS IN: forward on the
## turning circle toward the target's side, never a reverse leg, at the speed that yaws it at the bearing's rate plus a
## catch-up on the error. A car turns fastest rolling forward, and rolling is the evasion he asked for. A spot that
## stands still keeps the face planner (`plan_face`). ON (the lead shipped attempt 1, R33.24 option 1, judged builder2
## seeds 31-36 on 781801da0: in-reach exchange 0.20 -> 1.77, (a) 23.9 % v 25 and out-of-reach hits 42 -> 57 accepted):
## `--nav-off=turnin` turns it off.
const TURN_IN_DEFAULT := true
## Catch-up: yaw this much faster than the bearing per degree of error (1/s). The least throttle (share of top speed) is
## above TankMotion.WHEEL_CREEP_THROTTLE at full lock, the only lock a turn-in uses: the tightest circle stays nearest the
## post and its velocity swings fastest (a 0.6 throttle at part lock drove 18 m circles: the scout closed on the
## orbiter, 27 -> 19 m at the 30 m orbit, and was hit 0.39 -> 0.58 of shots).
const TURN_IN_GAIN := 3.0
const TURN_IN_ROLL := 0.55
## On target it keeps rolling and JINKS: its speed swaps between a low and a high share of top speed on uneven dwells
## (TURN_IN_JINK_S, stretched by up to the same again from a hash of the match tick and the hull's name: deterministic), each
## at the lock that holds the yaw. A shooter's turret lays on a lead point from the target's velocity, and a velocity
## that keeps changing keeps that lay from settling: braked or on a steady circle, the orbiter fired 2-5x more (builder0
## seeds 21-23, 640d9535 / 66411eb7: the 45 m gang_ifv orbit 42 shots OFF v 198 braked).
const TURN_IN_JINK_LOW := 0.2
const TURN_IN_JINK_S := 0.5
## A hull that turns in but does not yaw TURN_IN_STALL_DEG in TURN_IN_STALL_S (a wall, a wreck) hands back to the face
## planner and its creep.
const TURN_IN_STALL_S := 1.0
const TURN_IN_STALL_DEG := 5.0
## The player's post leashes a turn-in: past TURN_IN_LEASH_M from it the hull turns toward the post's side instead of the
## target's (16 m let it close on the orbiter: the 30 m orbit's mean range 27 -> 19 m; 10 m, once the leash held its side,
## held the hull on 418 of 807 turn-in ticks).
const TURN_IN_LEASH_M := 14.0
## The leash lets go once the hull heads this far toward the post (cosine), not the moment it stops heading away.
const TURN_IN_HOME_DOT := 0.5
## Round 34: between TURN_IN_LEASH_M and this (m) the leash SLOWS THE DANCE instead of steering: no fast dwell, the
## tightest circle that still tracks the target (the creep-line share and the lock it needs), so the hull stops drifting
## out while keeping its aim (a full lock the shortest way home was the target's far side half the time, and lost a
## 48 deg/s orbiter for a lap: law_scout v syn_scout 30 m seed 11, in-arc 71 -> 13 %). Past it, the shortest way home at
## full lock, as round 33 did (the target's side alone let a gang_scout spiral 65 m from its post, seed 17).
const TURN_IN_LEASH_HOME_M := 18.0
## A target further round than this keeps the side the hull was already turning to.
const TURN_IN_BEHIND_DEG := 150.0
## Arm counters: ticks a hull turned in, turn-ins that stalled, and ticks the leash turned it home.
static var turn_in_ticks := 0
static var turn_in_stalls := 0
static var turn_in_leashed := 0
## ...and ticks a `stop`'s swing (gunnery's R2) went through the turn-in instead of the creep.
static var turn_in_stops := 0
## ...and ticks it only evaded out of its gun's reach (835da0875's candidate, not chosen: always 0 here).
static var turn_in_evades := 0


static func turn_in_on() -> bool:
	return TURN_IN_DEFAULT != Movement.switched_off("turnin")


## R33.38 (the ship check: a plain face round the compass rolled a scout 24.5 m off its spot, and a stop's swing at a
## parked target never came round) and round 34 (M0, R33.39): the turn-in is for the case he reported, a crew whose
## fixed gun on wheels faces a LIVE ENEMY it cannot yaw onto at rest. A threat face (a brain's own, no `from`) and a
## stop's swing need a live hostile hull within TURN_IN_CONTACT_M of the spot (a contact's position, or gunnery's lead
## point), and every turn-in a crew with a BRAIN (TankBrain: every judged cell was one; a scripted OrderController with
## no brain, scenario_suppression's tracking scout at `stop`, keeps gunnery's swing and its held fire). Any other face
## or swing keeps the face planner and the creep, as before C33.9. The enemy's SPEED is not a condition (round 33's
## fc809b60a asked for > 1.5 m/s: the stage's orbiter starts from rest and stops when the scout sits on its nose, and
## each miss handed a live threat face to the face planner, whose first leg reversed: seed 36, 13 reverse ticks). A
## live enemy that stands still is handled here instead (TURN_IN_STILL_S below), never by the planner.
const TURN_IN_CONTACT_M := 10.0
## An enemy slower than this (m/s) is a target that stands: in the arc the hull HOLDS STILL and shoots (the jink only
## rolled it past a stopped orbiter 3 m away and lost the arc: seed 36's trace); out of the arc it keeps coming round
## forward (a car turns fastest rolling), never the planner's reverse legs while the enemy is live.
const TURN_IN_STILL_MPS := 0.5
## Ticks a hull held still in its arc on a standing target.
static var turn_in_holds := 0


## The live enemy hull the spot stands for: the nearest within TURN_IN_CONTACT_M of it, for a brain's crew; null if none.
static func live_enemy_near(ctl: OrderController, spot: Vector3) -> Tank:
	if ctl.tanks_root == null or not ctl is TankBrain:
		return null
	var best: Tank = null
	var best_d := TURN_IN_CONTACT_M
	for enemy in Perception.enemies_of(ctl.tank, ctl.tanks_root):
		var d := Vector2(enemy.global_position.x - spot.x, enemy.global_position.z - spot.z).length()
		if d <= best_d:
			best = enemy
			best_d = d
	return best


## Drive this tick's face (or a stop's swing, `swing`) at `spot` as a turn-in; false leaves it to the face planner (or
## gunnery's swing). Round 34 (M0): the spot is resolved to the LIVE ENEMY HULL it stands for (the nearest within
## TURN_IN_CONTACT_M), and the bearing, its rate and whether the target stands are read from that hull every tick.
## Round 33 read the rate from the spot's steps across the brain's thinks, and the brain re-issues a face spot only
## when it moves (seed 36's trace: the spot sat 1.8 m from where the enemy had stopped, 7 deg at 14 m, half the gun's
## arc; a hull holding on that spot could not fire). A spot with no live enemy at it (a memory, a drawn or sector
## facing, a scripted order) never turns in.
static func turn_in(ctl: OrderController, cmd: TankCommand, spot: Vector3, delta: float, swing := false) -> bool:
	var tank := ctl.tank
	if not turn_in_on() or tank.mount != "fixed" or ctl.movement.wheel_radius() <= 0.0 or not ctl is TankBrain:
		return false
	if not swing and String(ctl.move_order.get("from", "")) != "":
		return false  # a drawn, post, sector or squad facing is not a threat face: the planner, as before C33.9
	var tick := Engine.get_physics_frames()
	if tick < ctl._turn_in_rest:
		return false
	var enemy := live_enemy_near(ctl, spot)
	if enemy == null:
		return false
	var here := tank.global_position
	var to := Vector3(enemy.global_position.x - here.x, 0.0, enemy.global_position.z - here.z)
	if to.length_squared() < 1.0:
		# An enemy on top of the hull (an orbiter that rams it) has no bearing to turn to: hold, and never hand it to
		# the face planner, whose leftover leg reversed for a tick each time (gang_scout v gang_ifv at 15 m, seed 19:
		# 14 commanded gear changes, 3.8 m between the hulls).
		cmd.throttle = 0.0
		cmd.turn = 0.0
		return true
	var bearing := to.normalized()
	var forward := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	# The TARGET's swing of the bearing from its own velocity (d(theta)/dt = (p x v).y / |p|^2), smoothed a tick; the
	# hull's own travel is added below as `own`, so neither can chase the other.
	var v_t: Vector3 = enemy.real_velocity
	var target_rate := rad_to_deg(to.cross(Vector3(v_t.x, 0.0, v_t.z)).y / to.length_squared())
	ctl._turn_in_rate = lerpf(ctl._turn_in_rate, target_rate, 0.5)
	var still := Vector2(v_t.x, v_t.z).length() < TURN_IN_STILL_MPS
	var rate := ctl._turn_in_rate
	var error := rad_to_deg(forward.signed_angle_to(bearing, Vector3.UP))  # + = the enemy is to the left
	var half_arc := float(Units.stat(tank.unit_id, "fire_arc_deg", 0.0)) * 0.5
	# The yaw it wants (yaw = speed / turning radius at full lock): the bearing's rate, the catch-up on the error, and the
	# swing the hull's own travel puts on the bearing, which the yaw must also match.
	var travel: Vector3 = tank.velocity
	var own := rad_to_deg(to.cross(-Vector3(travel.x, 0.0, travel.z)).y / to.length_squared())
	var want_yaw := rate + own + TURN_IN_GAIN * error  # deg/s, + = to the left
	var radius := ctl.movement.wheel_radius()
	var top_speed := maxf(tank.max_forward_speed, 0.1)
	# Out of the gun's effective reach there is nothing to shoot: the hull never holds still and the leash never slows
	# its dance (both made a steadier target of a scout facing an IFV that outranges it: gang_scout v gang_ifv 30 m, dev
	# 11-23, hits 86 -> 133). It keeps turning in and jinking at speed; leaving is brains' call (C34.5).
	var in_reach := to.length() <= Engagement.effective_range(tank.weapon)
	if still and absf(error) <= half_arc and in_reach:
		# A target that stands, in the arc: hold still and shoot. (Seed 36's trace: the jink rolled the hull past a
		# stopped orbiter 3 m away, the arc was lost, and the hand-off to the planner reversed.)
		cmd.throttle = 0.0
		cmd.turn = 0.0
		ctl._turn_in_live = false
		ctl._turn_in_window = TURN_IN_STALL_S
		ctl._turn_in_yawed = 0.0
		ctl._turn_in_leash_sign = 0.0
		turn_in_holds += 1
		turn_in_ticks += 1
		return true
	# Catching up (full lock, below) once the enemy leaves the arc, until it is back in the arc's inner half; on target
	# between those, a jink.
	if not ctl._turn_in_live and absf(error) > half_arc:
		ctl._turn_in_live = true
		ctl._turn_in_window = TURN_IN_STALL_S
		ctl._turn_in_heading = forward
		ctl._turn_in_yawed = 0.0
	elif ctl._turn_in_live and absf(error) <= half_arc * 0.5:
		ctl._turn_in_live = false
	# The jink's clock runs on target and catching up alike (the catch-up reads it only for the dwell's phase).
	ctl._turn_in_pulse -= delta
	if ctl._turn_in_pulse <= 0.0:
		ctl._turn_in_fast = not ctl._turn_in_fast
		# The MATCH's tick, never the engine's frame count (a second match in one process, or a replay, starts on
		# another frame: the same seed then jinked differently).
		var game_match: Variant = ctl.get("game_match")
		var sim_tick: int = int(game_match.tick) if game_match != null else 0
		ctl._turn_in_pulse = TURN_IN_JINK_S * (1.0 + float(hash([String(tank.name), sim_tick]) % 1000) / 1000.0)
	# The share x lock that yaws it as wanted (yaw = speed / turning radius at full lock), the least share that keeps
	# that yaw above the creep line (share >= WHEEL_CREEP_THROTTLE x lock, with a margin: the plant reads a slower throttle
	# as a multi-point turn and swaps gear every half second), and the share past which full lock reaches the hull's yaw
	# cap (past it the yaw stops growing and the travel only swings the bearing away faster: the 15 m orbit at 16 m/s held
	# 65 deg off at the 124 deg/s cap).
	var yaw_share := deg_to_rad(absf(want_yaw)) * radius / top_speed
	# The creep line's floor is for a PART lock (the lock is yaw_share / share, below); at full lock it is TURN_IN_ROLL,
	# never more (round 34: sqrt(yaw_share x 0.55) read 1.15 for a 310 deg/s want, so the hull ran at 16 m/s, past the
	# speed at which full lock reaches its yaw cap, and sat 60 deg off a 15 m orbiter for 25 s: law_scout v syn_scout
	# 15 m, every dev seed, 0 damage dealt).
	var floor_share := minf(sqrt(yaw_share * TankMotion.WHEEL_CREEP_THROTTLE * 1.1), TURN_IN_ROLL)
	var cap_share := minf(tank.max_forward_speed, deg_to_rad(float(Units.stat(tank.unit_id, "hull_turn_rate_deg", 360.0))) * radius) / top_speed
	cap_share = maxf(cap_share, floor_share)
	if not ctl._turn_in_live:
		# On target: the jink's dwell, slow or fast.
		cmd.throttle = maxf(cap_share if ctl._turn_in_fast else TURN_IN_JINK_LOW, floor_share)
	else:
		# On target is progress: a hull inside its arc yaws only as fast as the bearing, and read as stalled it handed back
		# to the creep, which reversed (the 45 m orbit: +4 / -3 m/s every think, 27 gear changes in 30 s). The yaw is SUMMED
		# tick by tick: the angle between the window's first heading and this one read a full lap at 146 deg/s as no yaw at
		# all, and handed a hull at 11.8 m/s to the face planner's reverse legs (gang_scout, 30 m orbit, seed 23).
		ctl._turn_in_yawed += rad_to_deg(absf(ctl._turn_in_heading.signed_angle_to(forward, Vector3.UP)))
		ctl._turn_in_heading = forward
		if absf(error) <= half_arc:
			ctl._turn_in_window = TURN_IN_STALL_S
			ctl._turn_in_yawed = 0.0
		ctl._turn_in_window -= delta
		if ctl._turn_in_window <= 0.0:
			if ctl._turn_in_yawed < TURN_IN_STALL_DEG:
				turn_in_stalls += 1
				ctl._turn_in_live = false
				ctl._turn_in_rest = tick + int(SimClock.TICK_RATE * TURN_IN_STALL_S)  # sit out a second: the planner has it
				return false
			ctl._turn_in_window = TURN_IN_STALL_S
			ctl._turn_in_yawed = 0.0
		# Catching up: no jink (jinking the catch-up too cost the aim it is for: builder2 d7cf8cbf, dev seeds 11-23,
		# in-arc 23.0 -> 18.3 %, hits 72 -> 78), at the speed that yaws it as wanted. Round 34: that speed was floored
		# at TURN_IN_ROLL with a FULL lock whatever the want, which chattered left-right every tick once the want was
		# small and, worse, drove a hull with an 11 deg error nearly straight at 6.9 m/s, out past its leash every time
		# (law_scout v syn_scout 30 m, seed 11: leashed 416 of 786 ticks, far 31 m, in-arc 71 -> 10 %). Now the creep
		# line is the floor and the lock is proportional, as on target.
		if deg_to_rad(absf(rate + own)) * radius / top_speed > cap_share:
			# The bearing swings faster than full lock at the cap can yaw (a syn_scout at 17 m/s swings 65 deg/s round a
			# hull 10 m away, and the hull's own travel adds as much again): a smooth chase cannot catch it and is the
			# easiest motion to hit (the orbiter's lead settles: law_scout v syn_scout 15 m, 13 dev seeds, 0 damage dealt,
			# hits 118 -> 157). Jink instead, at full lock: the dwell's speed swaps as on target, and the target comes round
			# into the arc on its own lap. (The ERROR's share is not the test: a 90 deg error wants more than the cap too,
			# and is caught up with.)
			cmd.throttle = cap_share if ctl._turn_in_fast else maxf(TURN_IN_JINK_LOW, floor_share)
		else:
			cmd.throttle = clampf(yaw_share, floor_share, cap_share)
	# A target nearly behind keeps the way it was being turned to: the error's sign flips across 180 deg, and a full lock
	# that followed it wiggled left-right in place of coming round (the trace: err +177 -> -121).
	if absf(error) > TURN_IN_BEHIND_DEG and ctl._turn_in_sign != 0.0:
		want_yaw = absf(want_yaw) * ctl._turn_in_sign
	ctl._turn_in_sign = signf(want_yaw)
	cmd.turn = -signf(want_yaw) * clampf(yaw_share / maxf(cmd.throttle, 0.01), 0.0, 1.0)  # Steering's convention: turn < 0 turns left
	_turn_in_leash(ctl, cmd, here, forward, yaw_share, floor_share, in_reach)
	turn_in_ticks += 1
	return true


## Past TURN_IN_LEASH_M from the player's post, heading away from it, the hull turns full lock toward the post's side.
static func _turn_in_leash(ctl: OrderController, cmd: TankCommand, here: Vector3, forward: Vector3, yaw_share: float, floor_share: float, in_reach := true) -> void:
	var post: Variant = ctl.get("_player_post")
	if post is Vector3:
		var home := Vector3((post as Vector3).x - here.x, 0.0, (post as Vector3).z - here.z)
		if in_reach and home.length() > TURN_IN_LEASH_M and home.length() <= TURN_IN_LEASH_HOME_M and home.normalized().dot(forward) < TURN_IN_HOME_DOT:
			# The first tier: the tightest circle that tracks (see TURN_IN_LEASH_HOME_M).
			cmd.throttle = minf(cmd.throttle, floor_share)
			cmd.turn = signf(cmd.turn) * clampf(yaw_share / maxf(cmd.throttle, 0.01), 0.0, 1.0)
			ctl._turn_in_leash_sign = 0.0
			turn_in_leashed += 1
			return
		if home.length() > (TURN_IN_LEASH_HOME_M if in_reach else TURN_IN_LEASH_M) and home.normalized().dot(forward) < TURN_IN_HOME_DOT:
			# Its side is chosen once and held until the hull heads home: with the post nearly behind, the side's sign
			# flipped every tick and the full lock wiggled while the hull drove straight away (gang_scout, 30 m orbit,
			# seed 23: 31.5 m out, the leash on 408 of 829 face ticks).
			if ctl._turn_in_leash_sign == 0.0:
				ctl._turn_in_leash_sign = signf(forward.signed_angle_to(home, Vector3.UP))
				if ctl._turn_in_leash_sign == 0.0:
					ctl._turn_in_leash_sign = 1.0
			cmd.turn = -ctl._turn_in_leash_sign  # full lock: one turning circle past the leash
			cmd.throttle = maxf(cmd.throttle, TURN_IN_ROLL)  # ...above the creep line, whatever the jink asked
			turn_in_leashed += 1
			return
	ctl._turn_in_leash_sign = 0.0
