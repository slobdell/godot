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
##   {"type": "move_to", "x": float, "z": float, "reverse": bool (optional)}
##       reverse = back up to the point, front armor kept toward where you came from
##   {"type": "drive", "throttle": float, "turn": float, "seconds": float}
## Weapon orders (one at a time):
##   {"type": "hold_fire"}                      keep the turret where it is
##   {"type": "aim", "x": float, "z": float}    point the turret, don't fire
##   {"type": "fire_at_will"}                   engage the nearest visible enemy
##   {"type": "target", "name": String}         engage one specific tank when visible
## Reflexes (up to MAX_REFLEXES, checked every tick BEFORE orders execute). Each
## fires once, then re-arms when its condition clears. They let a slow commander
## pre-decide "if X happens, do Y" (playtest #1), and they're the smallest version
## of doctrine *phases* (_agents/squad_ai_design.md, layer 4):
##   {"type": "retreat_below_hp", "hp": int, "x": float, "z": float, "reverse": bool (default true)}
##       health < hp → move_to (x, z), backing away with the front armor forward unless reverse=false
##   {"type": "halt_on_contact"}   an enemy comes into sight during a move_to → stop and fight
## Orders and reflexes persist through death and respawn.

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
const MOVE_TYPES := ["stop", "move_to", "drive"]
const WEAPON_TYPES := ["hold_fire", "aim", "fire_at_will", "target"]
const REFLEX_TYPES := ["retreat_below_hp", "halt_on_contact"]
const MAX_REFLEXES := 4
const MAX_EVENTS := 8

@export var tank: Tank
## Where to look for other tanks (Match/Tanks).
var tanks_root: Node

var move_order := {"type": "stop"}
var weapon_order := {"type": "hold_fire"}
## Name of the tank currently being engaged ("" if none). For observation/debugging.
var engaged_target := ""
var visible_enemy_names: PackedStringArray = []
var reflexes: Array = []
## Recent notable happenings (reflexes firing), newest last. For observers like the bridge.
var events: PackedStringArray = []

var _reflex_armed: Array[bool] = []

var _drive_elapsed := 0.0
var _path := PackedVector3Array()
var _path_index := 0
var _path_goal := Vector3.INF
var _repath_left := 0.0
var _stuck_time := 0.0
var _unstick_left := 0.0


func _ready() -> void:
	# Lower priority runs first: the command is ready before the tank consumes it.
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	if tank == null or not is_instance_valid(tank):
		return
	think(delta)
	tank.command = compute_command(delta)


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
	var cmd := TankCommand.new(0.0, 0.0, tank.global_position + tank.turret_forward() * 10.0)
	if not tank.is_alive():
		engaged_target = ""
		return cmd
	_sense()
	_apply_reflexes()
	_apply_move(cmd, delta)
	_apply_unstick(cmd, delta)
	_apply_weapon(cmd)
	return cmd


func _sense() -> void:
	visible_enemy_names = PackedStringArray()
	if tanks_root == null:
		return
	for enemy in Perception.enemies_of(tank, tanks_root):
		if Perception.has_line_of_sight(tank, enemy):
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
	match move_order["type"]:
		"move_to":
			var goal := Vector3(move_order["x"], 0.0, move_order["z"])
			var waypoint := _next_waypoint(goal, delta)
			var steer := Steering.reverse_toward if move_order.get("reverse", false) else Steering.drive_toward
			var drive: Vector2 = steer.call(tank.global_position, -tank.global_basis.z, waypoint,
					ARRIVE_RADIUS if waypoint == goal else 0.5, _remaining_path_distance(goal))
			cmd.throttle = drive.x
			cmd.turn = drive.y
		"drive":
			_drive_elapsed += delta
			if _drive_elapsed <= float(move_order["seconds"]):
				cmd.throttle = move_order["throttle"]
				cmd.turn = move_order["turn"]
			else:
				move_order = {"type": "stop"}


## The point to steer at now: the next navmesh waypoint toward `goal`, or `goal`
## itself when there's no path (navigation not baked yet, or already close).
func _next_waypoint(goal: Vector3, delta: float) -> Vector3:
	_repath_left -= delta
	if _repath_left <= 0.0 or _flat_distance(goal, _path_goal) > 1.0:
		_repath_left = REPATH_SECONDS
		_path_goal = goal
		_path = Pathing.find_path(tank, tank.global_position, goal)
		_path_index = 0
	while _path_index < _path.size() \
			and _flat_distance(tank.global_position, _path[_path_index]) < WAYPOINT_RADIUS:
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
	match weapon_order["type"]:
		"aim":
			cmd.aim_point = Vector3(weapon_order["x"], 0.0, weapon_order["z"])
			return
		"fire_at_will":
			if tanks_root != null:
				target = Perception.nearest_enemy(tank, tanks_root, true, Shell.MAX_RANGE)
		"target":
			if tanks_root != null:
				var named := tanks_root.get_node_or_null(NodePath(weapon_order["name"])) as Tank
				if named != null and named.is_alive() and named.team != tank.team \
						and visible_enemy_names.has(named.name):
					target = named
	if target == null:
		return

	engaged_target = target.name
	var muzzle := tank.turret.global_position
	var lead := Ballistics.lead_point(muzzle, target.global_position, target.estimated_velocity,
			Shell.SPEED)
	cmd.aim_point = lead
	var in_range := muzzle.distance_to(lead) <= Shell.MAX_RANGE
	var aimed := Ballistics.aim_error(muzzle, tank.turret_forward(), lead) <= deg_to_rad(AIM_TOLERANCE_DEG)
	cmd.fire = in_range and aimed and tank.reload_fraction() >= 1.0


static func _validate(order: Variant, allowed_types: Array) -> String:
	if typeof(order) != TYPE_DICTIONARY:
		return "order must be an object"
	var type: Variant = order.get("type")
	if not allowed_types.has(type):
		return "type must be one of %s" % [allowed_types]
	var numeric := {"move_to": ["x", "z"], "aim": ["x", "z"], "drive": ["throttle", "turn", "seconds"],
			"retreat_below_hp": ["hp", "x", "z"]}
	for key in numeric.get(type, []):
		var value: Variant = order.get(key)
		if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(value)):
			return "'%s' needs a finite number '%s'" % [type, key]
	if type == "target" and typeof(order.get("name")) != TYPE_STRING:
		return "'target' needs a string 'name'"
	if order.has("reverse") and typeof(order["reverse"]) != TYPE_BOOL:
		return "'reverse' must be true or false"
	return ""
