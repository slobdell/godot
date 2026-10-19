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
const TURN_HULL_DEFAULT := false
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
## Per crew (by name): the last tick this order's arrival may be held (Movement.new_order forgets it). Kept here, not as
## a Movement member: every Movement member is a field of native's exec-state table (exec_fields.h), and this is
## GDScript decision state the C++ never reads.
static var _arrive_hold_until := {}


static func arrive_hold_forget(crew: String) -> void:
	_arrive_hold_until.erase(crew)


static func arrive_leg_on() -> bool:
	return ARRIVE_LEG_DEFAULT != Movement.switched_off("arriveleg")


static func leg_holds_arrival(brain: TankBrain) -> bool:
	if not arrive_leg_on() or String(brain.move_order.get("type", "")) != "move_to" or not brain.movement.manoeuvring():
		return false
	var tick := Engine.get_physics_frames()
	var crew := String(brain.tank.name)
	if not _arrive_hold_until.has(crew):
		_arrive_hold_until[crew] = tick + int(SimClock.TICK_RATE * ARRIVE_LEG_HOLD_S)
		arrivals_held += 1
	elif tick > int(_arrive_hold_until[crew]):
		return false  # the leg has run its bound on this order: the arrival goes through
	arrivals_held_ticks += 1
	return true


## Arm counters: drawn faces a wheeled turret hull took with its hull (the decline lifted); face-plan steps refused
## for leaving the arrive radius.
static var hull_turns := 0
static var face_keep_refused := 0


static func turn_hull_on() -> bool:
	return TURN_HULL_DEFAULT != Movement.switched_off("turnhull")


## Did the player DRAW this crew's facing (its element task, or its own K1 order, carries one)? Read by the brain's
## decline (`TankBrain._order_move`) under `turnhull`.
static func drawn_facing(brain: TankBrain) -> bool:
	var source: Variant = brain.get("_element_source")
	if source != null:
		var mine: Variant = ElementFeed.element_of(source, String(brain.tank.name))
		if mine != null and "task" in mine:
			var task: Variant = mine.get("task")
			return task is Dictionary and TankBrain._direction_of((task as Dictionary).get("facing")) != null
	return brain._ordered_facing()


## The brain's decline is lifted for this order (turn-hull ON, a face from the crew's order, a drawn facing).
static func hull_takes_face(brain: TankBrain, order: Dictionary) -> bool:
	# "order": the facing on the crew's own K1 order. "sector": a crew in an ELEMENT gets his drawn facing through its
	# element task, and the brain sends that face as its sector watch (`TankBrain._sector_source`). Judged run 1 lifted
	# only "order", which missed every gang element crew (gang_ifv 2195 `stop` rows v 141 `face`; at rest within 15 deg
	# 37 % v artillery's 95 %); `drawn_facing` is what says the facing is his, the label only says which way it came.
	if not turn_hull_on() or not String(order.get("from", "")) in ["order", "sector"] or not drawn_facing(brain):
		return false
	hull_turns += 1
	return true


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
