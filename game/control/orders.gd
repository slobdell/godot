class_name Orders
extends RefCounted
## K1 Orders API (control X1; CP1): every unit's current order and its queue, for one match. The simulating peer
## owns it; the player's input, the CPU, the agent bridge, and replays all go through issue(). Brains (ai) execute
## current(unit) and call complete(unit) when it's done. See _agents/workstreams.md "K1" and _agents/tactical_map.md.
##
##   issue(command, team = -1) -> String     "" or why not (UnitCommand shape, names, teams, targets)
##   current(unit_name) -> Dictionary         the active order, {} when idle (read-only: don't edit it)
##   queue(unit_name) -> Array                orders waiting after it (shift)
##   complete(unit_name)                      the executor finished the current order: start the next one
##   signal order_changed(unit_name)          the current order changed (new, completed, stopped); brains react
##                                            within 3 ticks (the response guarantee, tested in both streams)
##
## An order (current or queued) is the command resolved for one unit:
##   {"id": int (same for every unit of one issue), "verb", "units": [the group, sorted], "queue": bool,
##    "formation": what the group uses (GroupFormation.choose: a Formations name, "rows", or "single"),
##    "issued_tick": Match.tick at issue, "started_tick": when it became current,
##    "to"?: [x, z] (the group's destination, clamped into the arena), "target"?: unit name,
##    "slot"?: [right, back] meters in the group's frame (this unit's place in the formation),
##    "heading"?: [x, z] (the group's direction of travel, and its facing on arrival),
##    "goal"?: [x, z] (this unit's own destination: to + slot; for follow, see goal_position()),
##    "pace_mps"?: float (the group's slowest member's top speed)}
##   pace_factor(unit_name) -> float           arrive together: the fraction of its top speed a unit drives at now
##   station(unit_name) -> Dictionary          where an idle unit belongs (regroup): {"position": [x, z],
##                                            "heading": [x, z], "units": [its group], "id"}; {} if never ordered
## Deterministic: no clock, no randomness; units are processed in name order.

signal order_changed(unit_name: String)
## A unit's queue changed without its current order changing (a shift-queued waypoint): for waypoint markers.
signal queue_changed(unit_name: String)

## A move counts as arrived within this distance of its goal (meters).
const ARRIVE_RADIUS := 3.0

var game_match: Match
var _current := {}
var _queues := {}
var _next_id := 1
var _stations := {}


func _init(p_match: Match = null) -> void:
	game_match = p_match


## The Orders of a match: `Match.orders` once combat adds the field (K1), else the one attach() stored.
static func of(p_match: Match) -> Orders:
	if p_match == null:
		return null
	var field: Variant = p_match.get("orders")
	if field is Orders:
		return field
	return p_match.get_meta("orders") as Orders if p_match.has_meta("orders") else null


## Make `orders` reachable through Orders.of(match) (sets Match.orders when the field exists).
static func attach(p_match: Match, orders: Orders) -> void:
	orders.game_match = p_match
	if "orders" in p_match:
		p_match.set("orders", orders)
	else:
		p_match.set_meta("orders", orders)


func issue(command: Variant, team: int = -1) -> String:
	var error := UnitCommand.validate(command)
	if error != "":
		return error
	var names: Array = (command["units"] as Array).map(func(unit: Variant) -> String: return String(unit))
	names.sort()
	var group_team := -1
	for unit_name: String in names:
		var tank := _tank(unit_name)
		if tank == null:
			return "no unit named %s" % unit_name
		if not tank.is_alive():
			return "%s is destroyed" % unit_name
		if group_team >= 0 and tank.team != group_team:
			return "one command can't order units from both teams"
		group_team = tank.team
	if team >= 0 and group_team != team:
		return "those units belong to the other team"
	var verb: String = command["verb"]
	var target: Tank = null
	if command.has("target"):
		target = _tank(String(command["target"]))
		if target == null:
			return "no unit named %s" % command["target"]
		if not target.is_alive():
			return "%s is already destroyed" % command["target"]
		if verb == "attack" and target.team == group_team:
			return "attack needs an enemy target (%s is a friend)" % command["target"]
		if verb == "follow":
			names.erase(String(command["target"]))
			if names.is_empty():
				return "a unit can't follow itself"
	var queued: bool = command.get("queue", false) and verb != "stop"
	var id := _next_id
	_next_id += 1
	var base := {"id": id, "verb": verb, "units": names, "queue": queued,
			"formation": String(command.get("formation", UnitCommand.AUTO)), "issued_tick": _tick()}
	if command.has("to"):
		base["to"] = [clampf(float(command["to"][0]), -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT),
				clampf(float(command["to"][1]), -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT)]
	if target != null:
		base["target"] = String(target.name)
	var per_unit := _resolve_group(base, names, queued)
	for unit_name: String in names:
		var order: Dictionary = per_unit[unit_name]
		if queued and not (_current.get(unit_name, {}) as Dictionary).is_empty():
			(_queues.get_or_add(unit_name, []) as Array).append(order)
			queue_changed.emit(unit_name)
			continue
		_queues.erase(unit_name)
		_start(unit_name, order)
	return ""


func current(unit_name: String) -> Dictionary:
	if not _alive(unit_name):
		return {}
	return _current.get(unit_name, {})


func queue(unit_name: String) -> Array:
	if not _alive(unit_name):
		return []
	return _queues.get(unit_name, [])


func is_idle(unit_name: String) -> bool:
	return current(unit_name).is_empty()


## The current order is done (arrived, target destroyed, stop carried out): start the next queued one, or go idle.
func complete(unit_name: String) -> void:
	if not _current.has(unit_name):
		return
	var waiting: Array = _queues.get(unit_name, [])
	if waiting.is_empty():
		_remember_station(unit_name, _current[unit_name])
		_queues.erase(unit_name)
		_current.erase(unit_name)
		order_changed.emit(unit_name)
		return
	_start(unit_name, waiting.pop_front())


## Units with an active order or a queue, sorted (for executors and waypoint markers).
func ordered_units() -> Array[String]:
	var result: Array[String] = []
	for unit_name: String in _current:
		if _alive(unit_name):
			result.append(unit_name)
	result.sort()
	return result


## Where `unit_name` should be right now for its current order: its goal, or for follow its place behind the
## target (target position + slot in the target's frame). null when the order has no place (attack, stop).
func goal_position(unit_name: String) -> Variant:
	var order := current(unit_name)
	return Orders.goal_of(order, game_match)


static func goal_of(order: Dictionary, p_match: Match) -> Variant:
	if order.is_empty():
		return null
	if order["verb"] == "follow":
		var target := p_match.tanks.get_node_or_null(NodePath(String(order["target"]))) as Tank if p_match != null else null
		if target == null or not target.is_alive():
			return null
		var forward := -target.global_basis.z
		var slot: Array = order.get("slot", [0.0, 10.0])
		return Formations.to_world(Vector3(target.global_position.x, 0.0, target.global_position.z), forward,
				Vector2(slot[0], slot[1]))
	if order.has("goal"):
		return Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
	return null


func station(unit_name: String) -> Dictionary:
	if not _alive(unit_name):
		return {}
	return _stations.get(unit_name, {})


func pace_factor(unit_name: String) -> float:
	var order := current(unit_name)
	var tank := _tank(unit_name)
	if tank == null or not order.has("goal") or (order["units"] as Array).size() <= 1:
		return 1.0
	var group_eta := 0.0
	for member: String in order["units"]:
		var member_order := current(member)
		var member_tank := _tank(member)
		if member_tank == null or member_order.get("id", -1) != order["id"] or member_tank.max_forward_speed <= 0.0:
			continue
		var goal: Vector3 = Orders.goal_of(member_order, game_match)
		group_eta = maxf(group_eta, _flat_distance(member_tank.global_position, goal) / member_tank.max_forward_speed)
	var own_goal: Vector3 = Orders.goal_of(order, game_match)
	return GroupFormation.pace(_flat_distance(tank.global_position, own_goal), tank.max_forward_speed, group_eta)


## True when a unit at `position` has reached a move-like order's goal.
static func reached(order: Dictionary, position: Vector3) -> bool:
	if not order.has("goal"):
		return false
	return Vector2(position.x - float(order["goal"][0]), position.z - float(order["goal"][1])).length() <= ARRIVE_RADIUS


# ---- Internals ----------------------------------------------------------------------------------------------

func _start(unit_name: String, order: Dictionary) -> void:
	var started := order.duplicate()
	started["started_tick"] = _tick()
	_current[unit_name] = started
	order_changed.emit(unit_name)


## One order per unit: slots, goals, heading, and pace for group verbs.
func _resolve_group(base: Dictionary, names: Array, queued: bool) -> Dictionary:
	var result := {}
	var verb: String = base["verb"]
	var tanks: Array[Tank] = []
	for unit_name: String in names:
		tanks.append(_tank(unit_name))
	var pace := INF
	for tank in tanks:
		pace = minf(pace, tank.max_forward_speed)
	# Where the group starts from: its centroid now, or where its last queued order leaves it.
	var start := Vector3.ZERO
	var forward := Vector3.ZERO
	for i in tanks.size():
		var from: Variant = _last_destination(names[i]) if queued else null
		start += from if from != null else Vector3(tanks[i].global_position.x, 0.0, tanks[i].global_position.z)
		forward += -tanks[i].global_basis.z
	start /= tanks.size()
	forward = Vector3(forward.x, 0.0, forward.z)
	forward = forward.normalized() if forward.length_squared() > 1e-6 else Vector3.FORWARD

	var slots := {}
	var heading := forward
	var anchor: Variant = null
	var formation := GroupFormation.choose(tanks, String(base["formation"]), verb)
	if verb in ["move", "attack_move"] or (verb == "hold" and base.has("to")):
		anchor = Vector3(float(base["to"][0]), 0.0, float(base["to"][1]))
		var travel: Vector3 = anchor - start
		if travel.length() > 2.0:
			heading = travel.normalized()
		slots = GroupFormation.slots(tanks, formation, heading, anchor, verb)
	elif verb == "follow":
		slots = GroupFormation.follow_slots(tanks)
		formation = "rows" if tanks.size() > 1 else "single"
	for i in tanks.size():
		var unit_name: String = names[i]
		var order := base.duplicate()
		order["formation"] = formation
		if slots.has(unit_name):
			var slot: Vector2 = slots[unit_name]
			order["slot"] = [slot.x, slot.y]
		if anchor != null:
			var goal := Formations.to_world(anchor, heading, slots[unit_name])
			order["goal"] = [clampf(goal.x, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT),
					clampf(goal.z, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT)]
			order["heading"] = [heading.x, heading.z]
		elif verb == "hold":
			order["goal"] = [tanks[i].global_position.x, tanks[i].global_position.z]
			order["heading"] = [(-tanks[i].global_basis.z).x, (-tanks[i].global_basis.z).z]
		if tanks.size() > 1 and verb in ["move", "attack_move", "follow"]:
			order["pace_mps"] = pace
		result[unit_name] = order
	return result


## The destination a unit's queue ends at (for chaining shift-queued waypoints), or null.
func _last_destination(unit_name: String) -> Variant:
	var chain: Array = [_current.get(unit_name, {})] + (_queues.get(unit_name, []) as Array)
	for i in range(chain.size() - 1, -1, -1):
		var order: Dictionary = chain[i]
		if order.has("goal"):
			return Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
	return null


## Where a unit that just finished its orders belongs: its slot for orders with a goal (so a pushed or distracted unit
## returns to its group), else where it stopped.
func _remember_station(unit_name: String, order: Dictionary) -> void:
	var tank := _tank(unit_name)
	var position: Array = order.get("goal", [])
	var heading: Array = order.get("heading", [])
	if tank != null:
		if position.is_empty():
			position = [tank.global_position.x, tank.global_position.z]
		if heading.is_empty():
			heading = [(-tank.global_basis.z).x, (-tank.global_basis.z).z]
	if position.is_empty():
		return
	_stations[unit_name] = {"position": position, "heading": heading, "units": order["units"], "id": order["id"]}


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _tank(unit_name: String) -> Tank:
	if game_match == null or game_match.tanks == null:
		return null
	return game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


## Dead units drop their orders (lazily, so no signal wiring per spawned tank).
func _alive(unit_name: String) -> bool:
	if not _current.has(unit_name) and not _queues.has(unit_name) and not _stations.has(unit_name):
		return true
	var tank := _tank(unit_name)
	if tank != null and tank.is_alive():
		return true
	_current.erase(unit_name)
	_queues.erase(unit_name)
	_stations.erase(unit_name)
	return false


func _tick() -> int:
	return game_match.tick if game_match != null else 0
