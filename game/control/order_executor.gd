class_name OrderExecutor
extends Node
## TEMPORARY adapter (control X1) so today's brains follow K1 orders until they execute Orders.current() themselves
## (ai X1). The moment TankBrain declares `const EXECUTES_ORDERS := true`, this node steps aside by itself.
##
## How it works: when a unit gets its first order, its TankBrain is paused and a plain OrderController drives it
## (pathing, unsticking, fire at will). Orders take effect in the same tick they're issued (the response
## guarantee). Group moves pace every unit so the group arrives together (Orders.pace_factor). When the queue runs
## out, the unit keeps its station (Orders.station: its slot in its group): it returns there if pushed or drawn away,
## faces the group's heading or the nearest visible enemy, and shoots what it can. Units that were never ordered
## keep their brains (and their doctrine squad) untouched.
##
## Verbs: move (drive to the slot; arrive → complete), attack_move (drive, but halt and fight anything in reach),
## attack (close to firing range of the target, shoot it; complete when it's gone), follow (keep the slot behind the
## target; complete if it dies), hold (stay on the spot, turn and shoot; standing), stop (halt now; complete).

## The executor runs before brains and controllers (-10), so orders it applies are computed in the same tick.
const PRIORITY := -20
## A unit keeping station drives back once it's this far from its spot (meters).
const STATION_SLACK := 4.0
## Attack closes to this fraction of the weapon's range before halting to shoot.
const ATTACK_RANGE_FRACTION := 0.8

var game_match: Match
var orders: Orders
## unit name -> OrderController driving it.
var _controllers := {}


## True once brains execute K1 orders natively (ai X1): this adapter then does nothing.
static func brains_execute_orders() -> bool:
	return (TankBrain as Script).get_script_constant_map().get("EXECUTES_ORDERS", false)


func _ready() -> void:
	process_physics_priority = PRIORITY
	if orders != null and not brains_execute_orders():
		orders.order_changed.connect(_on_order_changed)


func is_controlling(unit_name: String) -> bool:
	return _controllers.has(unit_name)


func _on_order_changed(unit_name: String) -> void:
	var tank := _tank(unit_name)
	if tank == null or not tank.is_alive():
		return
	_drive(tank, _take(tank), orders.current(unit_name))


func _physics_process(_delta: float) -> void:
	if orders == null or game_match == null:
		return
	var names := _controllers.keys()
	names.sort()
	for unit_name: String in names:
		var tank := _tank(unit_name)
		var controller: OrderController = _controllers[unit_name]
		if tank == null or not tank.is_alive():
			controller.queue_free()
			_controllers.erase(unit_name)
			continue
		var order := orders.current(unit_name)
		if _done(tank, controller, order):
			orders.complete(unit_name)  # order_changed → _on_order_changed drives the next one
			continue
		_drive(tank, controller, order)


## Round 8: what `unit_name`'s gun is actually on, whoever drives it - this executor's controller when it holds the unit,
## else the unit's brain. The truth the HUD holds an order against ("they shoot at whatever they were already shooting
## at", the lead): an order and what the unit does are two facts, and only showing both makes a refusal visible.
func engaged_target_of(unit_name: String) -> String:
	if _controllers.has(unit_name):
		return (_controllers[unit_name] as OrderController).engaged_target
	var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain if game_match != null else null
	return brain.engaged_target if brain != null else ""


## Pause the unit's brain and hand it to an OrderController (once).
func _take(tank: Tank) -> OrderController:
	var unit_name := String(tank.name)
	if _controllers.has(unit_name):
		return _controllers[unit_name]
	var brain := game_match.brains.get_node_or_null("Brain_" + unit_name) as TankBrain
	if brain != null:
		brain.process_mode = Node.PROCESS_MODE_DISABLED
	var controller := OrderController.new()
	controller.name = "Orders_" + unit_name
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	var team := tank.team
	controller.spotter = func(other: Tank) -> bool: return game_match.is_visible_to(team, other)
	add_child(controller)
	_controllers[unit_name] = controller
	return controller


func _done(tank: Tank, controller: OrderController, order: Dictionary) -> bool:
	if order.is_empty():
		return false
	match String(order["verb"]):
		"move", "attack_move":
			return Orders.reached(order, tank.global_position) and (order["verb"] == "move" or controller.engaged_target == "")
		"attack", "follow":
			var target := _tank(String(order["target"]))
			return target == null or not target.is_alive()
		"stop":
			return tank.estimated_velocity.length() < 0.5
	return false


func _drive(tank: Tank, controller: OrderController, order: Dictionary) -> void:
	var unit_name := String(tank.name)
	# Arrive together, in steps of 0.1 so the order isn't re-issued (and re-pathed) every tick.
	var pace := snappedf(orders.pace_factor(unit_name), 0.1)
	var verb: String = order.get("verb", "")
	tank.intent = verb.replace("_", "-")
	match verb:
		"move":
			_order(controller, _move_to(orders.goal_position(unit_name), pace), {"type": "fire_at_will"})
		"attack_move":
			var fighting := controller.engaged_target != ""
			_order(controller, {"type": "stop"} if fighting else _move_to(orders.goal_position(unit_name), pace), {"type": "fire_at_will"})
		"attack":
			var target := _tank(String(order["target"]))
			if target == null:
				return
			var reach := float(tank.weapon["range"]) * ATTACK_RANGE_FRACTION
			var close := tank.global_position.distance_to(target.global_position) <= reach \
					and controller.engaged_target == String(target.name)
			var move := {"type": "stop"} if close else _move_to(target.global_position, 1.0)
			if close and tank.mount == "fixed":
				move = {"type": "face", "x": target.global_position.x, "z": target.global_position.z}
			_order(controller, move, {"type": "target", "name": String(target.name), "fallback": false})
		"follow":
			var spot: Variant = orders.goal_position(unit_name)
			_order(controller, {"type": "stop"} if spot == null else _move_to(spot, 1.0, 4.0), {"type": "fire_at_will"})
		"hold":
			_keep_spot(tank, controller, orders.goal_position(unit_name), _heading(order.get("facing", order.get("heading", []))))
		"stop":
			_order(controller, {"type": "stop"}, {"type": "fire_at_will"})
		_:
			var station := orders.station(unit_name)
			var spot: Variant = null
			if station.has("position"):
				spot = Vector3(float(station["position"][0]), 0.0, float(station["position"][1]))
			_keep_spot(tank, controller, spot, _heading(station.get("heading", [])))


## Stay on `spot`: drive back when pushed off it, else face the nearest enemy in sight (or `facing`) and shoot.
func _keep_spot(tank: Tank, controller: OrderController, spot: Variant, facing: Vector3) -> void:
	if spot != null and _flat(tank.global_position).distance_to(spot) > STATION_SLACK:
		_order(controller, _move_to(spot, 1.0), {"type": "fire_at_will"})
		return
	var look: Variant = null
	var best := INF
	for enemy: Tank in Perception.enemies_of(tank, game_match.tanks):
		var distance := tank.global_position.distance_to(enemy.global_position)
		if distance < best and distance <= float(tank.weapon["range"]) and game_match.is_visible_to(tank.team, enemy):
			best = distance
			look = enemy.global_position
	if look == null and facing != Vector3.ZERO:
		look = tank.global_position + facing * 20.0
	# A turret unit only needs its turret; a fixed gun turns the whole hull (OrderController does that on stop).
	if look != null and tank.mount != "fixed" and controller.engaged_target == "":
		_order(controller, {"type": "face", "x": look.x, "z": look.z}, {"type": "fire_at_will"})
	else:
		_order(controller, {"type": "stop"}, {"type": "fire_at_will"})


## Set orders only when they change: re-setting a move_to every tick would reset path following.
func _order(controller: OrderController, move: Dictionary, weapon: Dictionary) -> void:
	var same_move: bool = move["type"] == controller.move_order.get("type")
	if same_move and move.has("x"):
		same_move = Vector2(float(move["x"]) - float(controller.move_order["x"]), float(move["z"]) - float(controller.move_order["z"])).length() < 1.0 \
				and absf(float(move.get("speed", 1.0)) - float(controller.move_order.get("speed", 1.0))) < 0.05
	var error := controller.set_orders(null if same_move else move, null if weapon.recursive_equal(controller.weapon_order, 2) else weapon)
	if error != "":
		push_error("OrderExecutor: %s" % error)


static func _move_to(point: Variant, pace: float, arrive := Orders.ARRIVE_RADIUS - 1.0) -> Dictionary:
	if point == null:
		return {"type": "stop"}
	var p: Vector3 = point
	return {"type": "move_to", "x": p.x, "z": p.z, "speed": pace, "arrive": arrive}


static func _heading(pair: Array) -> Vector3:
	if pair.size() != 2:
		return Vector3.ZERO
	return Vector3(float(pair[0]), 0.0, float(pair[1]))


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)


func _tank(unit_name: String) -> Tank:
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank if game_match != null else null
