class_name OrderController
extends Node
## Executes STANDING ORDERS for one tank by producing a TankCommand every tick.
##
## This is layer 2 ("Actions") of _agents/squad_ai_design.md. Something slower
## decides the orders; this node carries them out 60 times a second:
##   BotController (server bots)   a tiny built-in policy picks orders
##   AgentBridge   (a client)      Claude picks orders over HTTP (_agents/agent_bridge.md)
##
## Move orders (one at a time):
##   {"type": "stop"}
##   {"type": "move_to", "x": float, "z": float, "reverse": bool (optional), "speed": 0.2..1 (optional),
##    "arrive": 0.5..10 meters (optional, default ARRIVE_RADIUS)}
##       reverse = back up to the point, front armor kept toward where you came from
##       arrive = how close counts as there (brains use ~1 m for hide and peek spots)
##       direct = true: steer straight at the point, no navmesh path (brains' short, already-checked hops)
##   {"type": "drive", "throttle": float, "turn": float, "seconds": float}
##   {"type": "face", "x": float, "z": float}   turn in place to point the hull (front armor) at a spot
## Weapon orders (one at a time):
##   {"type": "hold_fire"}                      keep the turret where it is
##   {"type": "aim", "x": float, "z": float}    point the turret, don't fire
##   {"type": "fire_at_will"}                   engage the nearest visible enemy
##   {"type": "target", "name": String, "fallback": bool (optional)}
##       engage one specific tank when visible; with fallback, shoot the nearest visible
##       enemy meanwhile (brains use this: team intel can pick a target this tank can't see)
## Reflexes (up to MAX_REFLEXES, checked every tick BEFORE orders execute). Each
## fires once, then re-arms when its condition clears. They let a slow commander
## pre-decide "if X happens, do Y" (playtest #1), and they're the smallest version
## of doctrine *phases* (_agents/squad_ai_design.md, layer 4):
##   {"type": "retreat_below_hp", "hp": int, "x": float, "z": float, "reverse": bool (default true)}
##       health < hp → move_to (x, z), backing away with the front armor forward unless reverse=false
##   {"type": "halt_on_contact"}   an enemy comes into sight during a move_to → stop and fight
## Orders and reflexes persist through death and respawn.
##
## TURRET (G5): the turret is independent of the hull. With no target to engage it covers
## `watch_point` (a known threat; brains set it from team intel), or else holds its
## world-space heading, so turning or retreating never drags the gun off the fight.

const ARRIVE_RADIUS := 3.0
## Advance to the next path waypoint within this distance of the current one.
const WAYPOINT_RADIUS := 2.5
## Recompute the path this often even if the goal hasn't moved (other tanks move).
const REPATH_SECONDS := 1.0
## Fire only when the turret is within this angle of the lead point.
const AIM_TOLERANCE_DEG := 2.5
## Driving at >50% throttle but moving slower than this for STUCK_SECONDS = stuck.
const STUCK_SPEED := 0.8
const STUCK_SECONDS := 1.0
const UNSTICK_SECONDS := 0.9
const MOVE_TYPES := ["stop", "move_to", "drive", "face"]
const WEAPON_TYPES := ["hold_fire", "aim", "fire_at_will", "target"]
const REFLEX_TYPES := ["retreat_below_hp", "halt_on_contact"]
const MAX_REFLEXES := 4
const MAX_EVENTS := 8
## At or below this fraction of a full ammo load, only fire inside the weapon's preferred range.
const LOW_AMMO_FRACTION := 0.3
## A held turret heading aims at a point this far out along it.
const HELD_AIM_DISTANCE := 1000.0
## fire_at_will (and target fallbacks) look for the nearest shootable enemy this often, keeping a still
## shootable pick in between: the per-tick scan of every enemy was a top AI cost at 50 units.
const SCAN_EVERY_TICKS := 6

## Measurement only (make ai-perf): microseconds spent in think + compute_command while `profiling` is on.
## Never read by decisions.
static var profiling := false
static var profile_usec := 0

@export var tank: Tank
## Where to look for other tanks (Match/Tanks).
var tanks_root: Node

var move_order := {"type": "stop"}
var weapon_order := {"type": "hold_fire"}
## Name of the tank currently being engaged ("" if none). For observation/debugging.
var engaged_target := ""
var visible_enemy_names: PackedStringArray = []
var reflexes: Array = []
## World point the turret covers while nothing is engaged (null = hold the current heading).
var watch_point: Variant = null
## Indirect weapons (ARC) may shoot at any enemy this returns true for. Brains set it to "my TEAM
## sees it" (spotting); by default it's the tank's own line of sight.
var spotter: Callable
## Recent notable happenings (reflexes firing), newest last. For observers like the bridge.
var events: PackedStringArray = []

var _reflex_armed: Array[bool] = []
## Flat world direction the turret holds when it has nothing to aim at (ZERO = not set yet).
var _held_aim := Vector3.ZERO

var _drive_elapsed := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath_left := 0.0
var _stuck_time := 0.0
var _unstick_left := 0.0
var _scan_pick: Tank = null
var _scan_left := 0
## Stuck detection (round-3 X1): consecutive ticks a move_to made no progress toward its goal (0 while arrived or not
## driving to a point), and ticks since this unit last pulled the trigger. Brains time out options with them.
var stalled_ticks := 0
## _wheel_radius() per unit type (the catalog doesn't change mid-match).
var _wheel_radius_unit := ""
var _wheel_radius_value := 0.0
var ticks_since_fire := 0
var _progress_goal := Vector3.INF
var _progress_best := INF

## A4 fire discipline: consecutive ticks the gun was ready and aimed but held because a friend was in the line
## of fire (or the splash), and which friend. Brains read it to move and clear the lane.
var lane_blocked_ticks := 0
var lane_blocker := ""
## Brain variants can turn the friendly-fire gate off (BrainVariants "hold_for_friends").
var hold_for_friends := true
## Measurement (not decisions): shots held for friends, by every controller since the process started.
static var held_for_friends := 0
## A blocked lane is re-checked only every this many ticks (a friend doesn't clear a lane in one tick).
const LANE_RECHECK_TICKS := 3
## Local avoidance of friends in the way (see _around_friends), meters.
const AVOID_LOOKAHEAD := 10.0
const AVOID_WIDTH := 3.2
const AVOID_CLEARANCE := 5.0
## Wheels move on to the next path waypoint within this share of their turning radius (at least WAYPOINT_RADIUS).
const WHEELS_WAYPOINT_RADII := 0.8
var _lane_hold_left := 0


func _ready() -> void:
	# Lower priority runs first: the command is ready before the tank consumes it.
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	if tank == null or not is_instance_valid(tank):
		return
	var started := Time.get_ticks_usec() if profiling else 0
	think(delta)
	tank.command = compute_command(delta)
	if profiling:
		profile_usec += Time.get_ticks_usec() - started


## Subclasses decide orders here (called every tick before orders execute).
func think(_delta: float) -> void:
	pass


## Replace one or both orders. Returns "" on success or a human-readable error.
## Validates everything: orders may come from an external process.
func set_orders(new_move: Variant, new_weapon: Variant, new_reflexes: Variant = null) -> String:
	if new_move != null:
		var error := _validate(new_move, MOVE_TYPES)
		if error != "":
			return "move: " + error
	if new_weapon != null:
		var error := _validate(new_weapon, WEAPON_TYPES)
		if error != "":
			return "weapon: " + error
	if new_reflexes != null:
		if typeof(new_reflexes) != TYPE_ARRAY or new_reflexes.size() > MAX_REFLEXES:
			return "reflexes: must be a list of at most %d reflexes" % MAX_REFLEXES
		for reflex in new_reflexes:
			var error := _validate(reflex, REFLEX_TYPES)
			if error != "":
				return "reflexes: " + error
	if new_reflexes != null:
		reflexes = new_reflexes.duplicate(true)
		_reflex_armed.clear()
		for reflex in reflexes:
			_reflex_armed.append(true)
	if new_move != null:
		move_order = new_move
		_drive_elapsed = 0.0
		_repath_left = 0.0
	if new_weapon != null:
		weapon_order = new_weapon
	return ""


func compute_command(delta: float) -> TankCommand:
	if not tank.is_alive():
		engaged_target = ""
		_held_aim = Vector3.ZERO
		return TankCommand.new(0.0, 0.0, tank.global_position + tank.turret_forward() * HELD_AIM_DISTANCE)
	if _held_aim == Vector3.ZERO:
		_held_aim = tank.turret_forward()
	# Far away, so the tank's own movement doesn't swing the aim (parallax).
	var cmd := TankCommand.new(0.0, 0.0, tank.global_position + _held_aim * HELD_AIM_DISTANCE)
	ticks_since_fire += 1
	_sense()
	_apply_reflexes()
	var clock := Time.get_ticks_usec() if profiling else 0
	_apply_move(cmd, delta)
	_apply_unstick(cmd, delta)
	if profiling:
		TankBrain.profile_parts["move"] = int(TankBrain.profile_parts.get("move", 0)) + Time.get_ticks_usec() - clock
		clock = Time.get_ticks_usec()
	_apply_weapon(cmd)
	if profiling:
		TankBrain.profile_parts["weapon"] = int(TankBrain.profile_parts.get("weapon", 0)) + Time.get_ticks_usec() - clock
	if cmd.fire:
		ticks_since_fire = 0
	return cmd


## A new order from the player: drop the unstick routine, the old path, and stall bookkeeping, so the new order
## drives this very tick (K1 response guarantee).
func interrupt() -> void:
	_unstick_left = 0.0
	_stuck_time = 0.0
	_repath_left = 0.0
	stalled_ticks = 0
	_progress_goal = Vector3.INF


func _sense() -> void:
	visible_enemy_names = PackedStringArray()
	# Only halt_on_contact reads what this tank sees; skipping the sight rays otherwise was the biggest
	# single AI cost at 50 units (_agents/unit_ai.md "Results").
	if tanks_root == null or not reflexes.any(func(r: Dictionary) -> bool: return r["type"] == "halt_on_contact"):
		return
	for enemy in Perception.enemies_of(tank, tanks_root):
		# G1: a tank sees within its sight radius, and only with a clear line of sight.
		if tank.global_position.distance_to(enemy.global_position) <= tank.sight_radius \
				and Perception.has_line_of_sight(tank, enemy):
			visible_enemy_names.append(enemy.name)


func _apply_reflexes() -> void:
	for i in reflexes.size():
		var reflex: Dictionary = reflexes[i]
		var triggered := false
		match reflex["type"]:
			"retreat_below_hp":
				triggered = tank.sync_health < int(reflex["hp"])
			"halt_on_contact":
				triggered = move_order["type"] == "move_to" and not visible_enemy_names.is_empty()
		if not triggered:
			_reflex_armed[i] = true  # condition cleared: ready to fire again next time
			continue
		if not _reflex_armed[i]:
			continue
		_reflex_armed[i] = false
		match reflex["type"]:
			"retreat_below_hp":
				var reverse: bool = reflex.get("reverse", true)
				move_order = {"type": "move_to", "x": reflex["x"], "z": reflex["z"], "reverse": reverse}
				_repath_left = 0.0
				_log_event("retreat_below_hp: HP %d < %d, %s to (%.0f, %.0f)" % [tank.sync_health,
						int(reflex["hp"]), "backing away" if reverse else "turning to run", reflex["x"], reflex["z"]])
			"halt_on_contact":
				move_order = {"type": "stop"}
				_log_event("halt_on_contact: %s in sight, stopping" % ", ".join(visible_enemy_names))


func _log_event(text: String) -> void:
	events.append("t=%.1fs %s" % [Time.get_ticks_msec() / 1000.0, text])
	if events.size() > MAX_EVENTS:
		events = events.slice(events.size() - MAX_EVENTS)


# ---- Movement ------------------------------------------------------------------------

func _apply_move(cmd: TankCommand, delta: float) -> void:
	if move_order["type"] != "move_to":
		stalled_ticks = 0
	match move_order["type"]:
		"move_to":
			var goal := Vector3(move_order["x"], 0.0, move_order["z"])
			# `direct`: the brain already checked the straight line (CombatMotion's short hops), so skip the navmesh path.
			var direct: bool = move_order.get("direct", false)
			var waypoint := _around_friends(goal if direct else _next_waypoint(goal, delta))
			var arrive := clampf(float(move_order.get("arrive", ARRIVE_RADIUS)), 0.5, 10.0) if waypoint == goal else 0.5
			var remaining := _flat_distance(tank.global_position, goal) if direct else _remaining_path_distance(goal)
			var drive: Vector2
			var radius := _wheel_radius()
			if radius > 0.0:
				# K3 wheels drive like cars: pure pursuit, three-point turns (Steering.drive_toward_wheels).
				var wheels := Steering.reverse_toward_wheels if move_order.get("reverse", false) else Steering.drive_toward_wheels
				drive = wheels.call(tank.global_position, -tank.global_basis.z, waypoint, arrive, radius, tank.speed(), remaining)
			else:
				var steer := Steering.reverse_toward if move_order.get("reverse", false) else Steering.drive_toward
				drive = steer.call(tank.global_position, -tank.global_basis.z, waypoint, arrive, remaining)
			cmd.throttle = drive.x * clampf(float(move_order.get("speed", 1.0)), 0.2, 1.0)
			cmd.turn = drive.y
			_track_progress(goal, drive, direct)
		"face":
			var spot := Vector3(move_order["x"], 0.0, move_order["z"])
			var turn_only := Steering.drive_toward(tank.global_position, -tank.global_basis.z, spot, 0.0)
			cmd.turn = turn_only.y if absf(turn_only.y) > 0.08 else 0.0
			if _wheel_radius() > 0.0 and cmd.turn != 0.0 and absf(turn_only.y) >= 1.0:
				# Wheels can't turn standing still: creep round (combat's wheels roll along the arc on a pure turn command).
				cmd.throttle = Steering.WHEELS_MIN_THROTTLE
		"drive":
			_drive_elapsed += delta
			if _drive_elapsed <= float(move_order["seconds"]):
				cmd.throttle = move_order["throttle"]
				cmd.turn = move_order["turn"]
			else:
				move_order = {"type": "stop"}


## Local avoidance: a friend parked in the way within AVOID_LOOKAHEAD meters (within AVOID_WIDTH of the line to the
## waypoint) is passed beside, AVOID_CLEARANCE meters off its center on the side the line already leans to. Navmesh paths
## ignore units, move_and_slide stops a hull against another, and wheels can't pivot round one (a wheeled IFV looped its
## unstick routine against a parked tank for 8 s). Brains only (they share the per-tick tank table).
func _around_friends(waypoint: Vector3) -> Vector3:
	var brain := self as TankBrain
	if brain == null or brain.game_match == null:
		return waypoint
	var here := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
	var to_waypoint := Vector3(waypoint.x, 0.0, waypoint.z) - here
	var distance := to_waypoint.length()
	if distance < 1.0:
		return waypoint
	var direction := to_waypoint / distance
	var nearest := INF
	var detour := waypoint
	for ally: Tank in AiTickCache.team_tanks(brain.game_match, tank.team):
		if ally == tank or not ally.is_alive():
			continue
		var offset := Vector3(ally.global_position.x - here.x, 0.0, ally.global_position.z - here.z)
		var along := offset.dot(direction)
		if along <= 0.0 or along >= minf(distance + AVOID_WIDTH, AVOID_LOOKAHEAD) or along >= nearest:
			continue
		var lateral := offset.x * direction.z - offset.z * direction.x
		if absf(lateral) >= AVOID_WIDTH:
			continue
		nearest = along
		# Pass on the side away from it (ties: its right).
		var across := Vector3(direction.z, 0.0, -direction.x)
		detour = Vector3(ally.global_position.x, 0.0, ally.global_position.z) - across * (AVOID_CLEARANCE if lateral >= 0.0 else -AVOID_CLEARANCE)
	return detour


## The minimum turning radius when this unit rolls on wheels (K3 `locomotion` "wheels", `min_turn_radius_m`), else 0.
func _wheel_radius() -> float:
	if _wheel_radius_unit != tank.unit_id:
		_wheel_radius_unit = tank.unit_id
		_wheel_radius_value = 0.0
		if String(Units.stat(tank.unit_id, "locomotion", "tracks")) == "wheels":
			_wheel_radius_value = maxf(float(Units.stat(tank.unit_id, "min_turn_radius_m", 0.0)), 0.5)
	return _wheel_radius_value


## Counts ticks without getting at least 0.5 m closer (along the path) to the current move goal.
func _track_progress(goal: Vector3, drive: Vector2, direct := false) -> void:
	var remaining := _flat_distance(tank.global_position, goal) if direct else _remaining_path_distance(goal)
	if _flat_distance(goal, _progress_goal) > 2.0 or drive == Vector2.ZERO:
		_progress_goal = goal
		_progress_best = remaining
		stalled_ticks = 0
	elif remaining < _progress_best - 0.5:
		_progress_best = remaining
		stalled_ticks = 0
	else:
		stalled_ticks += 1


## The point to steer at now: the next navmesh waypoint toward `goal`, or `goal`
## itself when there's no path (navigation not baked yet, or already close).
func _next_waypoint(goal: Vector3, delta: float) -> Vector3:
	_repath_left -= delta
	if _repath_left <= 0.0 or _flat_distance(goal, _path_goal) > 1.0:
		_repath_left = REPATH_SECONDS
		_path_goal = goal
		_path = Pathing.find_path(tank, tank.global_position, goal)
		_path_index = 0
	# Wheels can't thread a waypoint the way tracks pivot onto one: they move on to the next one a turning radius out.
	var reach := maxf(WAYPOINT_RADIUS, _wheel_radius() * WHEELS_WAYPOINT_RADII)
	while _path_index < _path.size() \
			and _flat_distance(tank.global_position, _path[_path_index]) < reach:
		_path_index += 1
	if _path_index >= _path.size():
		return goal
	var waypoint := _path[_path_index]
	return Vector3(waypoint.x, 0.0, waypoint.z)


func _remaining_path_distance(goal: Vector3) -> float:
	if _path_index >= _path.size():
		return _flat_distance(tank.global_position, goal)
	var total := _flat_distance(tank.global_position, _path[_path_index])
	for i in range(_path_index, _path.size() - 1):
		total += _flat_distance(_path[i], _path[i + 1])
	return total


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _apply_unstick(cmd: TankCommand, delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		cmd.throttle = 1.0 if move_order.get("reverse", false) else -1.0  # back off the way you were NOT going
		cmd.turn = 1.0
		return
	if absf(cmd.throttle) > 0.5 and tank.estimated_velocity.length() < STUCK_SPEED:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_stuck_time = 0.0
			_unstick_left = UNSTICK_SECONDS
	else:
		_stuck_time = 0.0


# ---- Weapon --------------------------------------------------------------------------

func _apply_weapon(cmd: TankCommand) -> void:
	engaged_target = ""

	var target: Tank = null
	if tank.weapon["kind"] == Weapons.Kind.ARC:
		_apply_indirect(cmd)
		return
	match weapon_order["type"]:
		"aim":
			_cover(Vector3(weapon_order["x"], 0.0, weapon_order["z"]), cmd)
			return
		"fire_at_will":
			if tanks_root != null:
				target = _scanned_shootable()
		"target":
			if tanks_root != null:
				var named := _named_tank(String(weapon_order["name"]))
				if named != null and named.is_alive() and named.team != tank.team and _shootable(named):
					target = named
				elif weapon_order.get("fallback", false):
					target = _scanned_shootable()
	if target == null:
		if watch_point != null:
			_cover((watch_point as Vector3), cmd)
		return

	engaged_target = target.name
	var weapon := tank.weapon
	var muzzle := tank.turret.global_position
	var aim := target.global_position
	if weapon["kind"] == Weapons.Kind.PROJECTILE:
		aim = Ballistics.lead_point(muzzle, target.global_position, target.estimated_velocity, Shell.SPEED)
	_cover(aim, cmd)
	# Rules R2 (minimal hook; the ai stream owns the real behavior): a fixed-mount gun (the scout) only
	# points inside its fire arc, so a halted unit swings its hull onto the target.
	if tank.mount == "fixed" and move_order["type"] == "stop":
		cmd.turn = Steering.drive_toward(tank.global_position, -tank.global_basis.z, aim, 0.0).y
	var distance := muzzle.distance_to(aim)
	var in_range: bool = distance <= float(weapon["range"])
	# G7 ammo discipline: with few shells left, skip long-odds shots (spread makes them mostly miss).
	if tank.ammo_fraction() <= LOW_AMMO_FRACTION and distance > float(weapon["preferred_max"]):
		in_range = false
	var aimed: bool = Ballistics.aim_error(muzzle, tank.turret_forward(), aim) <= deg_to_rad(float(weapon["aim_tolerance_deg"]))
	cmd.fire = _clear_to_fire(in_range and aimed and tank.ready_to_fire(), aim)


## Direct fire needs a clear line of sight from this tank AND the target being seen: by the team when a
## spotter is set (brains: a scout's sight lets a tank use its full gun range), else by this tank.
func _shootable(enemy: Tank) -> bool:
	if tank.global_position.distance_to(enemy.global_position) > float(tank.weapon["range"]):
		return false
	var seen: bool = spotter.call(enemy) if spotter.is_valid() \
			else tank.global_position.distance_to(enemy.global_position) <= tank.sight_radius
	return seen and Perception.has_line_of_sight(tank, enemy)


## _nearest_shootable(), re-scanned every SCAN_EVERY_TICKS while the last pick is still shootable (a nearer enemy
## may have appeared), and every tick while there's nothing to shoot (a delay there leaves loaded guns idle).
func _scanned_shootable() -> Tank:
	_scan_left -= 1
	if _scan_left > 0 and _scan_pick != null and is_instance_valid(_scan_pick) and _scan_pick.is_alive() and _shootable(_scan_pick):
		return _scan_pick
	_scan_left = SCAN_EVERY_TICKS
	_scan_pick = _nearest_shootable()
	return _scan_pick


func _nearest_shootable() -> Tank:
	var best: Tank = null
	var best_distance := INF
	for enemy: Tank in _enemies():
		var distance := tank.global_position.distance_to(enemy.global_position)
		if distance < best_distance and _shootable(enemy):
			best = enemy
			best_distance = distance
	return best


## A tank by name: the brains' shared per-tick table (no NodePath parsing every tick), else a node lookup.
func _named_tank(tank_name: String) -> Tank:
	var brain := self as TankBrain
	if brain != null and brain.game_match != null and brain.game_match.tanks == tanks_root:
		return AiTickCache.tanks_by_name(brain.game_match).get(tank_name) as Tank
	return tanks_root.get_node_or_null(NodePath(tank_name)) as Tank


## Living enemies in scene order: shared per tick for brains (AiTickCache), scanned otherwise.
func _enemies() -> Array:
	var brain := self as TankBrain
	if brain != null and brain.game_match != null and brain.game_match.tanks == tanks_root:
		return AiTickCache.enemies(brain.game_match, tank.team)
	return Perception.enemies_of(tank, tanks_root)


## ARC weapons: lob at a spotted enemy inside the [min_range, range] window, leading it by the flight time.
func _apply_indirect(cmd: TankCommand) -> void:
	if tanks_root == null or weapon_order["type"] in ["hold_fire", "aim"]:
		if weapon_order["type"] == "aim":
			_cover(Vector3(weapon_order["x"], 0.0, weapon_order["z"]), cmd)
		elif watch_point != null:
			_cover(watch_point as Vector3, cmd)
		return
	var weapon := tank.weapon
	var sees: Callable = spotter if spotter.is_valid() else func(other: Tank) -> bool: return Perception.has_line_of_sight(tank, other)
	var in_window := func(other: Tank) -> bool:
		var d := tank.global_position.distance_to(other.global_position)
		return d >= float(weapon["min_range"]) and d <= float(weapon["range"])
	var target: Tank = null
	if weapon_order["type"] == "target":
		var named := _named_tank(String(weapon_order["name"]))
		if named != null and named.is_alive() and named.team != tank.team and sees.call(named) and in_window.call(named):
			target = named
	if target == null and (weapon_order["type"] == "fire_at_will" or weapon_order.get("fallback", false)):
		var best_distance := INF
		for enemy: Tank in _enemies():
			var d := tank.global_position.distance_to(enemy.global_position)
			if d < best_distance and in_window.call(enemy) and sees.call(enemy):
				best_distance = d
				target = enemy
	if target == null:
		engaged_target = ""
		if watch_point != null:
			_cover(watch_point as Vector3, cmd)
		return
	engaged_target = target.name
	var flight := tank.global_position.distance_to(target.global_position) / float(weapon["flight_speed"])
	var aim := target.global_position + target.estimated_velocity * flight
	_cover(aim, cmd)
	var aimed: bool = Ballistics.aim_error(tank.turret.global_position, tank.turret_forward(), aim) <= deg_to_rad(float(weapon["aim_tolerance_deg"]))
	cmd.fire = _clear_to_fire(aimed and tank.ready_to_fire(), aim)


## A4: the last gate before the trigger. A shot that would pass through (or splash) a friend is held, and
## counted in lane_blocked_ticks. Only checked when the gun would otherwise fire, so it costs one check per
## reload, not per tick.
func _clear_to_fire(would_fire: bool, aim: Vector3) -> bool:
	if not would_fire:
		return false
	if not hold_for_friends:
		return true
	if _lane_hold_left > 0:
		_lane_hold_left -= 1
		lane_blocked_ticks += 1
		held_for_friends += 1
		return false
	var blockers := FireLanes.for_shot(tanks_root, tank, aim)
	if blockers.is_empty():
		lane_blocked_ticks = 0
		lane_blocker = ""
		return true
	lane_blocked_ticks += 1
	lane_blocker = String(blockers[0])
	held_for_friends += 1
	_lane_hold_left = LANE_RECHECK_TICKS - 1
	return false


## Point the turret at a world spot, and remember that heading for when the spot is gone.
func _cover(point: Vector3, cmd: TankCommand) -> void:
	cmd.aim_point = point
	var flat := Vector3(point.x - tank.global_position.x, 0.0, point.z - tank.global_position.z)
	if flat.length_squared() > 0.25:
		_held_aim = flat.normalized()


static func _validate(order: Variant, allowed_types: Array) -> String:
	if typeof(order) != TYPE_DICTIONARY:
		return "order must be an object"
	var type: Variant = order.get("type")
	if not allowed_types.has(type):
		return "type must be one of %s" % [allowed_types]
	var numeric := {"move_to": ["x", "z"], "face": ["x", "z"], "aim": ["x", "z"], "drive": ["throttle", "turn", "seconds"],
			"retreat_below_hp": ["hp", "x", "z"]}
	for key in numeric.get(type, []):
		var value: Variant = order.get(key)
		if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(value)):
			return "'%s' needs a finite number '%s'" % [type, key]
	if type == "target" and typeof(order.get("name")) != TYPE_STRING:
		return "'target' needs a string 'name'"
	if order.has("reverse") and typeof(order["reverse"]) != TYPE_BOOL:
		return "'reverse' must be true or false"
	if order.has("direct") and typeof(order["direct"]) != TYPE_BOOL:
		return "'direct' must be true or false"
	if order.has("fallback") and typeof(order["fallback"]) != TYPE_BOOL:
		return "'fallback' must be true or false"
	if order.has("speed") and not (typeof(order["speed"]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(order["speed"]))):
		return "'speed' must be a number"
	if order.has("arrive") and not (typeof(order["arrive"]) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(order["arrive"]))):
		return "'arrive' must be a number"
	return ""
