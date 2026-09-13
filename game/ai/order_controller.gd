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
##   {"type": "move_to", "x": float, "z": float}
##   {"type": "drive", "throttle": float, "turn": float, "seconds": float}
## Weapon orders (one at a time):
##   {"type": "hold_fire"}                      keep the turret where it is
##   {"type": "aim", "x": float, "z": float}    point the turret, don't fire
##   {"type": "fire_at_will"}                   engage the nearest visible enemy
##   {"type": "target", "name": String}         engage one specific tank when visible

const ARRIVE_RADIUS := 3.0
## Fire only when the turret is within this angle of the lead point.
const AIM_TOLERANCE_DEG := 2.5
## Driving at >50% throttle but moving slower than this for STUCK_SECONDS = stuck.
const STUCK_SPEED := 0.8
const STUCK_SECONDS := 1.0
const UNSTICK_SECONDS := 0.9
const MOVE_TYPES := ["stop", "move_to", "drive"]
const WEAPON_TYPES := ["hold_fire", "aim", "fire_at_will", "target"]

@export var tank: Tank
## Where to look for other tanks (Match/Tanks).
var tanks_root: Node

var move_order := {"type": "stop"}
var weapon_order := {"type": "hold_fire"}
## Name of the tank currently being engaged ("" if none). For observation/debugging.
var engaged_target := ""
var visible_enemy_names: PackedStringArray = []

var _drive_elapsed := 0.0
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
func set_orders(new_move: Variant, new_weapon: Variant) -> String:
	if new_move != null:
		var error := _validate(new_move, MOVE_TYPES)
		if error != "":
			return "move: " + error
	if new_weapon != null:
		var error := _validate(new_weapon, WEAPON_TYPES)
		if error != "":
			return "weapon: " + error
	if new_move != null:
		move_order = new_move
		_drive_elapsed = 0.0
	if new_weapon != null:
		weapon_order = new_weapon
	return ""


func compute_command(delta: float) -> TankCommand:
	var cmd := TankCommand.new(0.0, 0.0, tank.global_position + tank.turret_forward() * 10.0)
	if not tank.is_alive():
		engaged_target = ""
		return cmd
	_apply_move(cmd, delta)
	_apply_unstick(cmd, delta)
	_apply_weapon(cmd)
	return cmd


# ---- Movement ------------------------------------------------------------------------

func _apply_move(cmd: TankCommand, delta: float) -> void:
	match move_order["type"]:
		"move_to":
			var goal := Vector3(move_order["x"], 0.0, move_order["z"])
			var drive := Steering.drive_toward(tank.global_position, -tank.global_basis.z, goal,
					ARRIVE_RADIUS)
			cmd.throttle = drive.x
			cmd.turn = drive.y
		"drive":
			_drive_elapsed += delta
			if _drive_elapsed <= float(move_order["seconds"]):
				cmd.throttle = move_order["throttle"]
				cmd.turn = move_order["turn"]
			else:
				move_order = {"type": "stop"}


func _apply_unstick(cmd: TankCommand, delta: float) -> void:
	if _unstick_left > 0.0:
		_unstick_left -= delta
		cmd.throttle = -1.0
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
	visible_enemy_names = PackedStringArray()
	if tanks_root != null:
		for enemy in Perception.enemies_of(tank, tanks_root):
			if Perception.has_line_of_sight(tank, enemy):
				visible_enemy_names.append(enemy.name)

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
	var numeric := {"move_to": ["x", "z"], "aim": ["x", "z"], "drive": ["throttle", "turn", "seconds"]}
	for key in numeric.get(type, []):
		var value: Variant = order.get(key)
		if not (typeof(value) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(float(value)):
			return "'%s' needs a finite number '%s'" % [type, key]
	if type == "target" and typeof(order.get("name")) != TYPE_STRING:
		return "'target' needs a string 'name'"
	return ""
