class_name Movement
extends RefCounted
## N1, the Movement API (round 6, CP1): the one seam between *where a unit is told to be* and *how it gets there*.
## Everything above it (squad's slots, control's orders, a brain's hops) says "be here"; everything below it (path
## planning, avoidance, right-of-way, unsticking, the control law) is nav's. Architecture: _agents/navigation.md.
##
## The static API is what other streams call:
##   Movement.request(unit, to, opts)   drive `unit` (a Tank) to `to`; opts may carry "arrive_radius", "facing", "pace"
##                                      (0.2..1 of top speed), "priority", "reverse", "direct"
##   Movement.state(unit) -> {"phase": "pathing" | "driving" | "yielding" | "blocked" | "arrived", "eta_s",
##                            "remaining_m", "path_points", "blocked_by", "goal", "stalled_s"}
##                           ({} for a unit nothing drives: a player's hull, a client's copy)
##   Movement.eta(unit, to) -> float   seconds to drive there along the navmesh route (the lead's "estimate the
##                                      position and time at which a unit would converge")
##   Movement.cancel(unit)              stop where it stands
##
## The guarantee nav owes every consumer: a unit given a destination ARRIVES or reports `blocked` with a reason in
## `blocked_by` (a unit's name, "terrain" or "no_path"). It never stands still silently.
##
## One Movement instance lives in each OrderController (the composer) and does the per-tick driving of a `move_to`:
## the route, the steps round fire and friends, the steering call, progress, and the unstick routine. It reads the
## controller for the order, the tank and the tick; it never decides where to go.

## Advance to the next path waypoint within this distance of the current one.
const WAYPOINT_RADIUS := 2.5
## Recompute the path this often even if the goal hasn't moved (other tanks move).
const REPATH_SECONDS := 1.0
## Driving at >50% throttle but moving slower than this for STUCK_SECONDS = stuck.
const STUCK_SPEED := 0.8
const STUCK_SECONDS := 1.0
const UNSTICK_SECONDS := 0.9
## No progress (0.5 m closer along the route than its best) for this long and the unit reports `blocked` (N1).
const BLOCKED_SECONDS := 2.0
## A hull whose centre is within this of mine (flat metres), ahead of me, is what I'm blocked by.
const BLOCKER_REACH := 8.0
## ...and "ahead" means within this cosine of the direction I'm trying to go (~60°).
const BLOCKER_AHEAD_COS := 0.5
## A route that ends further than this from the goal did not reach it: the goal is inside something or cut off.
const NO_PATH_MARGIN := 3.0
## Wheels move on to the next path waypoint within this share of their turning radius (at least WAYPOINT_RADIUS).
const WHEELS_WAYPOINT_RADII := 0.8
## eta(): the share of top speed a route is driven at on average (corners, the slow-down at the end).
const ETA_CRUISE_SHARE := 0.85

## X3 (L2): how far ahead a route is checked for a wall of bullets (meters). Far enough to see one coming: checking
## only the next navmesh waypoint is a few metres, by which time the unit is already in it.
const FIRE_LOOKAHEAD := 34.0
## ...and how far to one side the route can step (meters). All of them are scored; the least-swept wins.
const FIRE_DETOUR_STEPS: Array[float] = [12.0, 24.0, 36.0]
## A sidestep has to be this much safer than carrying straight on before it is worth taking, so a unit doesn't weave
## over a rounding error.
const FIRE_DETOUR_MARGIN := 0.75
## A sidestep is DRIVEN, not re-decided every tick: re-deciding just wobbles along the edge of the fire (measured: 4 m
## off the straight line, and longer in the beaten zone than going straight). It is held until it is reached, or the
## route on is clear, or this many ticks pass.
const FIRE_DETOUR_TICKS := SimClock.TICK_RATE * 2
const FIRE_DETOUR_REACHED := 5.0
## Reaching a step is not "I tried and it didn't work" — it is the step working, so the unit looks again and steps
## again if the way on is still swept. What bounds the whole business is this: once a unit has been going round for
## this long without the fire lifting, it has spent enough and pushes on. Orders win in the end.
const FIRE_AVOID_MAX := SimClock.TICK_RATE * 5
## ...and then the unit pushes on for this long before it looks for a way round again. It only has to be long enough
## to stop the search running on every check tick: FIRE_AVOID_MAX below is what actually guarantees a unit arrives.
## It used to be 240, which swallowed four seconds of a seven-second crossing and made the whole behaviour measure as
## nothing (28 ticks in the beaten zone against a control's 33, where a working version manages 14).
const FIRE_DETOUR_COOLDOWN := SimClock.TICK_RATE
## Going round is ENTERED on `is_beaten_zone` (a hard threshold) but KEPT while the route still carries this share of
## that much fire on average. Without the hysteresis a unit abandons its detour the moment the field dips under the
## threshold between two bursts — and a beaten zone pulses, because the field has a ~1 s half-life and guns fire in
## bursts. That cost the whole behaviour once combat's suppression rework made the field denser and burstier: one
## attempt, three ticks, then the cooldown below and a walk straight through the fire.
const FIRE_KEEP_SHARE := 0.4
## The route is re-checked against the field this often (ticks, staggered per unit) rather than every tick. A detour
## already being driven is re-checked every tick regardless. This is not only a cost knob — it sets how many chances a
## unit gets to notice a wall of bullets while there is still room to go round, and it was measured, in the swept-lane
## scenario (ticks spent in the beaten zone against a control's 33) and with `make ai-perf UNITS=60`:
##     every tick   21 ticks in the fire, 4740 usec        every 3   10 ticks, 4231 usec        every 6   28 ticks
## Three is both the best behaviour and cheaper than one. Six was chosen as a pure cost cut during X2 and quietly cost
## most of the avoidance — a reminder to measure what an optimisation does to behaviour, not just to the clock.
const FIRE_CHECK_TICKS := maxi(1, (SimClock.TICK_RATE + 10) / 20)  # ~20 Hz, rounded to whole ticks
## A step round the fire is kept this long even if the fire seems to lift. A beaten zone PULSES — rounds arrive in
## bursts and the field decays between them — so a momentary reading below the threshold is not the fire ending. Round
## 5, found at 30 Hz: without this the unit dropped its step every other check and picked the other side next time,
## thrashing on the spot inside the lane instead of crossing it (19 ticks in the beaten zone against a control's 16).
const FIRE_LEG_MIN_TICKS := maxi(1, SimClock.TICK_RATE / 4)
## Local avoidance of friends in the way (see _around_friends), meters.
const AVOID_LOOKAHEAD := 10.0
const AVOID_WIDTH := 3.2
const AVOID_CLEARANCE := 5.0

const PHASES := ["pathing", "driving", "yielding", "blocked", "arrived"]

## Tank instance id -> the Movement driving it (the composer binds it every tick).
static var _registry := {}

## The composer this mover belongs to (an OrderController, or a TankBrain).
var ctl: OrderController

## Stuck detection (round-3 X1): consecutive ticks a move_to made no progress toward its goal (0 while arrived or not
## driving to a point). Brains time out options with it; N1 reports `blocked` from it.
var stalled_ticks := 0
var phase := "arrived"
var blocked_by := ""

var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath_left := 0.0
var _stuck_time := 0.0
var _unstick_left := 0.0
var _progress_goal := Vector3.INF
var _progress_best := INF
var _goal := Vector3.INF
var _arrive := 0.0
var _remaining := 0.0
var _blocker_left := 0
## _wheel_radius() per unit type (the catalog doesn't change mid-match).
var _wheel_radius_unit := ""
var _wheel_radius_value := 0.0

## X3: the sidestep being driven right now (null = none) and the tick it gives up at.
var _fire_detour: Variant = null
var _fire_detour_until := 0
var _fire_detour_since := -1000
var _fire_detour_again := 0
## The tick this unit started going round the current wall of bullets (-1 = it isn't).
var _fire_since := -1
var _fire_checked_tick := -1000


func _init(controller: OrderController = null) -> void:
	ctl = controller


# ---- The N1 API (static: what other streams call) ------------------------------------------------------------------

## The Movement driving `unit`, or null (nothing drives it, or its controller is gone).
static func of(unit: Node) -> Movement:
	if unit == null or not is_instance_valid(unit):
		return null
	var mover: Movement = _registry.get(unit.get_instance_id())
	if mover == null or not is_instance_valid(mover.ctl) or mover.ctl.tank != unit:
		return null
	return mover


## Drive `unit` to `to`. Replaces its current move order (the weapon order is untouched).
static func request(unit: Node, to: Vector3, opts: Dictionary = {}) -> void:
	var mover := of(unit)
	if mover == null:
		push_warning("Movement.request: nothing drives %s" % [unit.name if unit != null else "null"])
		return
	var order := {"type": "move_to", "x": to.x, "z": to.z}
	if opts.has("arrive_radius"):
		order["arrive"] = float(opts["arrive_radius"])
	if opts.has("pace"):
		order["speed"] = float(opts["pace"])
	for key: String in ["reverse", "direct"]:
		if opts.has(key):
			order[key] = bool(opts[key])
	if opts.has("facing"):
		order["facing"] = opts["facing"]
	if opts.has("priority"):
		order["priority"] = int(opts["priority"])
	mover.ctl.set_orders(order, null)
	mover.ctl.interrupt()


## Stop where it stands.
static func cancel(unit: Node) -> void:
	var mover := of(unit)
	if mover != null:
		mover.ctl.set_orders({"type": "stop"}, null)


## What the unit's movement is doing now (see the header), or {} when nothing drives it.
static func state(unit: Node) -> Dictionary:
	var mover := of(unit)
	return mover.reading() if mover != null else {}


## Seconds for `unit` to drive to `to`: the navmesh route's length at a cruising share of its top speed, plus the time
## to swing its hull onto the route. Straight-line when the navmesh isn't ready. 0 when there already.
static func eta(unit: Node, to: Vector3) -> float:
	var tank := unit as Tank
	if tank == null or not is_instance_valid(tank) or tank.max_forward_speed <= 0.0:
		return 0.0
	var here := tank.global_position
	var length := _flat_distance(here, to)
	var first := to
	if length > 0.5 and Pathing.enabled and tank.is_inside_tree() and Pathing.is_ready(tank):
		var path := Pathing.find_path(tank, here, to)
		if path.size() >= 2:
			length = _flat_distance(here, path[0])
			for i in range(1, path.size()):
				length += _flat_distance(path[i - 1], path[i])
			first = path[1]
	if length <= 0.5:
		return 0.0
	var seconds := length / (tank.max_forward_speed * ETA_CRUISE_SHARE)
	var forward := -tank.global_basis.z
	var toward := Vector3(first.x - here.x, 0.0, first.z - here.z)
	if toward.length_squared() > 0.01 and tank.hull_turn_rate > 0.0:
		seconds += absf(Vector3(forward.x, 0.0, forward.z).normalized().signed_angle_to(toward, Vector3.UP)) / tank.hull_turn_rate
	return seconds


# ---- Per unit (the composer calls these) ----------------------------------------------------------------------------

## The N1 reading for this unit.
func reading() -> Dictionary:
	var eta_s := -1.0
	var points := PackedVector3Array()
	if phase != "arrived" and ctl.tank != null:
		eta_s = _remaining / (maxf(ctl.tank.max_forward_speed, 0.1) * ETA_CRUISE_SHARE)
		if _path_index < _path.size():
			points = _path.slice(_path_index)
	return {"phase": phase, "eta_s": eta_s, "remaining_m": _remaining if phase != "arrived" else 0.0,
			"path_points": points, "blocked_by": blocked_by if phase == "blocked" else "",
			"goal": _goal if _goal != Vector3.INF else null,
			"stalled_s": float(stalled_ticks) / float(SimClock.TICK_RATE)}


## A new order: drop the unstick routine, the old path, the fire detour and the stall bookkeeping, so the new order
## drives this very tick (K1 response guarantee).
func reset() -> void:
	_fire_detour = null
	_fire_detour_again = 0
	_fire_since = -1
	_unstick_left = 0.0
	_stuck_time = 0.0
	_repath_left = 0.0
	stalled_ticks = 0
	_progress_goal = Vector3.INF


## Make this mover the one Movement.state(tank) reads (the composer calls it every tick: a dictionary lookup).
func bind() -> void:
	var id := ctl.tank.get_instance_id()
	if _registry.get(id) != self:
		_registry[id] = self


## Forget the route (a new move order): the next drive() repaths at once.
func new_order() -> void:
	_repath_left = 0.0


## The move order isn't a move_to (stop, face, drive, or a dead hull): nothing to report but "arrived".
func idle() -> void:
	stalled_ticks = 0
	phase = "arrived"
	blocked_by = ""
	_goal = Vector3.INF
	_remaining = 0.0


## Execute a move_to: fill cmd's throttle and turn for this tick.
func drive(cmd: TankCommand, order: Dictionary, delta: float) -> void:
	var tank := ctl.tank
	var goal := Vector3(order["x"], 0.0, order["z"])
	_goal = goal
	# `direct`: the brain already checked the straight line (CombatMotion's short hops), so skip the navmesh path.
	var direct: bool = order.get("direct", false)
	var lap := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var routed := goal if direct else _next_waypoint(goal, delta)
	lap = OrderController._lap("move.path", lap)
	var around_fire := _around_fire(routed, goal, order)
	lap = OrderController._lap("move.fire", lap)
	var waypoint := _around_friends(around_fire)
	lap = OrderController._lap("move.friends", lap)
	_arrive = clampf(float(order.get("arrive", OrderController.ARRIVE_RADIUS)), 0.5, 10.0)
	var arrive := _arrive if waypoint == goal else 0.5
	var remaining := _flat_distance(tank.global_position, goal) if direct else _remaining_path_distance(goal)
	_remaining = remaining
	lap = OrderController._lap("move.remaining", lap)
	var drive_vector: Vector2
	var radius := wheel_radius()
	if radius > 0.0:
		# K3 wheels drive like cars: pure pursuit, three-point turns (Steering.drive_toward_wheels).
		# Direct calls rather than a Callable picked every tick (round-5 X1).
		if order.get("reverse", false):
			drive_vector = Steering.reverse_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
		else:
			drive_vector = Steering.drive_toward_wheels(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
	elif order.get("reverse", false):
		drive_vector = Steering.reverse_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
	else:
		drive_vector = Steering.drive_toward(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
	cmd.throttle = drive_vector.x * clampf(float(order.get("speed", 1.0)), 0.2, 1.0)
	cmd.turn = drive_vector.y
	_track_progress(goal, drive_vector, remaining)
	_update_phase(goal, drive_vector, direct)
	OrderController._lap("move.steer", lap)


## N1: what this tick amounts to. Arrived when steering has nothing left to do, blocked after BLOCKED_SECONDS without
## progress (with the cause), pathing while the navmesh isn't ready, else driving.
func _update_phase(goal: Vector3, drive_vector: Vector2, direct: bool) -> void:
	if drive_vector == Vector2.ZERO and _flat_distance(ctl.tank.global_position, goal) <= _arrive + 0.5:
		phase = "arrived"
		blocked_by = ""
		return
	if stalled_ticks >= int(BLOCKED_SECONDS * SimClock.TICK_RATE):
		# The cause is re-read twice a second, not every tick (it walks the neighbours).
		_blocker_left -= ctl._step
		if phase != "blocked" or _blocker_left <= 0:
			_blocker_left = SimClock.TICK_RATE / 2
			blocked_by = _blocker(goal, direct)
		phase = "blocked"
		return
	blocked_by = ""
	if not direct and Pathing.enabled and _path.is_empty() and not Pathing.is_ready(ctl.tank):
		phase = "pathing"
	else:
		phase = "driving"


## What this unit is up against: the nearest hull ahead of it within BLOCKER_REACH (friend or enemy), else "no_path"
## when its route doesn't reach the goal, else "terrain".
func _blocker(goal: Vector3, direct: bool) -> String:
	var tank := ctl.tank
	var here := tank.global_position
	var toward := (_path[_path_index] if _path_index < _path.size() and not direct else goal) - here
	toward.y = 0.0
	if toward.length_squared() < 0.01:
		toward = -tank.global_basis.z
	toward = toward.normalized()
	var best := ""
	var best_distance := BLOCKER_REACH
	if ctl.tanks_root != null:
		for other in ctl.tanks_root.get_children():
			var hull := other as Tank
			if hull == null or hull == tank or not hull.is_alive():
				continue
			var offset := hull.global_position - here
			offset.y = 0.0
			var distance := offset.length()
			if distance >= best_distance or distance < 0.01:
				continue
			if offset.dot(toward) / distance < BLOCKER_AHEAD_COS:
				continue
			best = String(hull.name)
			best_distance = distance
	if best != "":
		return best
	if not direct and not _path.is_empty() and _flat_distance(_path[_path.size() - 1], goal) > NO_PATH_MARGIN:
		return "no_path"
	return "terrain"


## X3 (L2): a route through a wall of bullets is stepped around. The lead: *"vehicles make decisions to avoid walking
## into a wall of bullets that will kill them."* Navmesh paths know nothing about fire, and this is where every move
## passes — an order, an element's bound, a drill — so it is the one place that covers all of them. Sides are tried
## nearest first; if every way through is swept it goes anyway, because standing still in the open is worse.
func _around_fire(waypoint: Vector3, goal: Vector3, order: Dictionary) -> Vector3:
	var brain := ctl as TankBrain
	var tank := ctl.tank
	if brain == null or brain.game_match == null \
			or not bool(BrainVariants.for_team(tank.team).get("avoid_beaten", true)):
		return waypoint
	# A move that IS the escape (running to cover, breaking contact) is driven as given: re-routing it round the fire
	# is how a hurt tank ends up never reaching the cover it was running to.
	if bool(order.get("to_safety", false)):
		return waypoint
	var fields := brain._suppression_fields(brain.game_match)
	if fields == null:
		return waypoint
	var here := tank.global_position
	var to := Vector3(waypoint.x - here.x, 0.0, waypoint.z - here.z)
	var distance := to.length()
	if distance < 1.0:
		return waypoint
	var direction := to / distance
	var reach := minf(FIRE_LOOKAHEAD, maxf(_flat_distance(here, goal), 1.0))
	var tick := brain.game_match.tick
	var stride := ctl._stride
	if _fire_detour == null:
		# Under execution LOD the check can't wait for an exact multiple of FIRE_CHECK_TICKS (it may be an off tick):
		# it runs on the first executed tick at least FIRE_CHECK_TICKS - 1 after the last one instead.
		if stride == 1 and (tick + brain.think_offset) % FIRE_CHECK_TICKS != 0:
			return waypoint
		# Under a controller stride the check can't wait for an exact multiple (that tick may not run): it looks on the
		# first run at least FIRE_CHECK_TICKS after the last look.
		if stride > 1 and tick - _fire_checked_tick < FIRE_CHECK_TICKS:
			return waypoint
		_fire_checked_tick = tick
	var ahead := here + direction * reach
	var ahead_beaten := SuppressionFeed.beaten(fields, tank.team, here, ahead)
	# Already going round. Reaching the step, or spending long enough on it, counts as having tried: push on for a
	# while afterwards so a wall across the whole frontage can't stop a unit forever (orders win in the end). The fire
	# simply lifting is different — carry straight on, with no cooldown, because nothing was spent.
	var still_swept := SuppressionFeed.along(fields, tank.team, here, ahead) >= Match.BEATEN_ZONE_DENSITY * FIRE_KEEP_SHARE
	if _fire_detour != null:
		var leg: Vector3 = _fire_detour
		if not still_swept and tick - _fire_detour_since >= FIRE_LEG_MIN_TICKS:
			_fire_detour = null  # the fire lifted: carry on, nothing spent
			_fire_since = -1
		elif _fire_since >= 0 and tick - _fire_since >= FIRE_AVOID_MAX:
			_fire_detour = null  # long enough: push on
			_fire_since = -1
			_fire_detour_again = tick + FIRE_DETOUR_COOLDOWN
		elif tick >= _fire_detour_until or _flat_distance(here, leg) <= FIRE_DETOUR_REACHED:
			_fire_detour = null  # that step is done; look again below and take another if it is still needed
		else:
			OrderController.fire_detours += ctl._step
			return leg
	if not still_swept:
		_fire_since = -1
	if not ahead_beaten or tick < _fire_detour_again:
		return waypoint
	var across := Vector3(-direction.z, 0.0, direction.x)
	var limit := Match.DRIVABLE_LIMIT - 4.0
	# The way round is a step SIDEWAYS first, not a shallower line to the same place: a lane swept across your front is
	# crossed by leaving it, then going on. Every step is SCORED rather than tested for being perfectly clear — a
	# beaten zone pulses and its edges are soft, so "is this clear" is the wrong question and "which of these is least
	# swept" is the right one (Match.threat_along exists for exactly this). A route is as dangerous as its worst leg.
	var straight := SuppressionFeed.along(fields, tank.team, here, ahead)
	var best: Variant = null
	var best_threat := straight * FIRE_DETOUR_MARGIN
	for step: float in FIRE_DETOUR_STEPS:
		for side: float in [1.0, -1.0]:
			var beside := here + across * (side * step)
			beside.x = clampf(beside.x, -limit, limit)
			beside.z = clampf(beside.z, -limit, limit)
			var threat := maxf(SuppressionFeed.along(fields, tank.team, here, beside),
					SuppressionFeed.along(fields, tank.team, beside, beside + direction * reach))
			if threat < best_threat:
				best_threat = threat
				best = beside
	if best != null:
		_fire_detour = best
		_fire_detour_until = tick + FIRE_DETOUR_TICKS
		_fire_detour_since = tick
		if _fire_since < 0:
			_fire_since = tick
		OrderController.fire_detours += ctl._step
		return best
	# Looked and found nothing: every way round is swept too. Push on rather than looking again every few ticks.
	OrderController.fire_no_way_round += 1
	_fire_since = -1
	_fire_detour_again = tick + FIRE_DETOUR_COOLDOWN
	return waypoint


## Local avoidance: a friend parked in the way within AVOID_LOOKAHEAD meters (within AVOID_WIDTH of the line to the
## waypoint) is passed beside, AVOID_CLEARANCE meters off its center on the side the line already leans to. Navmesh paths
## ignore units, move_and_slide stops a hull against another, and wheels can't pivot round one (a wheeled IFV looped its
## unstick routine against a parked tank for 8 s). Brains only (they share the per-tick tank table).
func _around_friends(waypoint: Vector3) -> Vector3:
	var brain := ctl as TankBrain
	if brain == null or brain.game_match == null:
		return waypoint
	var tank := ctl.tank
	var here_x := tank.global_position.x
	var here_z := tank.global_position.z
	var to_x := waypoint.x - here_x
	var to_z := waypoint.z - here_z
	var distance := sqrt(to_x * to_x + to_z * to_z)
	if distance < 1.0:
		return waypoint
	var dir_x := to_x / distance
	var dir_z := to_z / distance
	var nearest := minf(distance + AVOID_WIDTH, AVOID_LOOKAHEAD)
	var detour := waypoint
	# X2: the tick's shared living-ally table (positions already extracted; every controller runs before any tank
	# moves, so these are this tick's positions), and a squared-distance reject before any of the lane math. At 60
	# units this loop was the single biggest cost of executing orders.
	var my_name := String(tank.name)
	var reach_squared := nearest * nearest + AVOID_WIDTH * AVOID_WIDTH
	# Round-5 X1: typed columns instead of a dictionary per ally (same tanks, same order, same float values).
	var columns := AiTickCache.ally_columns(brain.game_match, tank.team)
	var xs: PackedFloat32Array = columns[0]
	var zs: PackedFloat32Array = columns[1]
	var names: PackedStringArray = columns[2]
	for i in xs.size():
		var position := Vector3(xs[i], 0.0, zs[i])
		var dx := position.x - here_x
		var dz := position.z - here_z
		if dx * dx + dz * dz >= reach_squared or names[i] == my_name:
			continue
		var along := dx * dir_x + dz * dir_z
		if along <= 0.0 or along >= nearest:
			continue
		var lateral := dx * dir_z - dz * dir_x
		if absf(lateral) >= AVOID_WIDTH:
			continue
		nearest = along
		# Pass on the side away from it (ties: its right).
		var clearance := AVOID_CLEARANCE if lateral >= 0.0 else -AVOID_CLEARANCE
		detour = Vector3(position.x - dir_z * clearance, 0.0, position.z + dir_x * clearance)
	return detour


## The minimum turning radius when this unit rolls on wheels (K3 `locomotion` "wheels", `min_turn_radius_m`), else 0.
func wheel_radius() -> float:
	var tank := ctl.tank
	if _wheel_radius_unit != tank.unit_id:
		_wheel_radius_unit = tank.unit_id
		_wheel_radius_value = 0.0
		if String(Units.stat(tank.unit_id, "locomotion", "tracks")) == "wheels":
			_wheel_radius_value = maxf(float(Units.stat(tank.unit_id, "min_turn_radius_m", 0.0)), 0.5)
	return _wheel_radius_value


## Counts ticks without getting at least 0.5 m closer (along the path) to the current move goal. `remaining` is the
## distance the caller already worked out for steering — computing it again here walked the whole path a second time
## every tick for every moving unit (X2).
func _track_progress(goal: Vector3, drive_vector: Vector2, remaining: float) -> void:
	if _flat_distance(goal, _progress_goal) > 2.0 or drive_vector == Vector2.ZERO:
		_progress_goal = goal
		_progress_best = remaining
		stalled_ticks = 0
	elif remaining < _progress_best - 0.5:
		_progress_best = remaining
		stalled_ticks = 0
	else:
		stalled_ticks += ctl._step


## The point to steer at now: the next navmesh waypoint toward `goal`, or `goal`
## itself when there's no path (navigation not baked yet, or already close).
func _next_waypoint(goal: Vector3, delta: float) -> Vector3:
	var tank := ctl.tank
	_repath_left -= delta
	if _repath_left <= 0.0 or _flat_distance(goal, _path_goal) > 1.0:
		_repath_left = REPATH_SECONDS
		_path_goal = goal
		_path = Pathing.find_path(tank, tank.global_position, goal)
		_path_index = 0
	# Wheels can't thread a waypoint the way tracks pivot onto one: they move on to the next one a turning radius out.
	var reach := maxf(WAYPOINT_RADIUS, wheel_radius() * WHEELS_WAYPOINT_RADII)
	while _path_index < _path.size() \
			and _flat_distance(tank.global_position, _path[_path_index]) < reach:
		_path_index += 1
	if _path_index >= _path.size():
		return goal
	var waypoint := _path[_path_index]
	return Vector3(waypoint.x, 0.0, waypoint.z)


func _remaining_path_distance(goal: Vector3) -> float:
	var tank := ctl.tank
	if _path_index >= _path.size():
		return _flat_distance(tank.global_position, goal)
	var total := _flat_distance(tank.global_position, _path[_path_index])
	for i in range(_path_index, _path.size() - 1):
		total += _flat_distance(_path[i], _path[i + 1])
	return total


## Blind unsticking: driving hard but not moving for STUCK_SECONDS → back off for UNSTICK_SECONDS.
func unstick(cmd: TankCommand, order: Dictionary, delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		cmd.throttle = 1.0 if order.get("reverse", false) else -1.0  # back off the way you were NOT going
		cmd.turn = 1.0
		return
	if absf(cmd.throttle) > 0.5 and ctl.tank.estimated_velocity.length() < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_stuck_time = 0.0
			_unstick_left = UNSTICK_SECONDS
	else:
		_stuck_time = 0.0


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
