class_name OrderFeed
extends RefCounted
## How brains read the player's orders: contract K1 in _agents/workstreams.md (control's `Orders`, reachable as
## `Match.orders`). Brains execute these (round-3 ai X1, _agents/unit_ai.md "Orders always win").
##
## Duck-typed on purpose: ai builds against the contract before checkpoint CP1 lands, so nothing here names
## control's classes. The source is `Match.orders` when that field exists and is set, else an object attached
## with attach() (tests before CP1, tools). It needs `current(unit_name) -> Dictionary`, `complete(unit_name)`,
## and signal `order_changed(unit_name)`; it uses control's helpers when present: `goal_position(unit)` (a follow's live
## station), `pace_factor(unit)` (a group's pace), `station(unit)` (where an idle unit regroups).
##
## current() is normalized for brains into
##   {"verb": "move" | "attack" | "attack_move" | "follow" | "hold" | "stop",
##    "goal": Vector3 | null   this unit's own destination in world meters: control's per-unit `goal` [x, z] (the group's
##                             `to` plus this unit's formation slot), else `goal_position(unit)`, else `to`,
##    "target": String         attack: the enemy; follow: the friend ("" otherwise),
##    "issued_tick": int, "speed": float (0.2..1, `pace_factor(unit)` when the source has it),
##    "facing": Vector3 | null  round 7: the ordered facing on arrival (flat, unit length), from the command's `facing`}
## or {} when the unit has no order. Control's `slot` is [right, back] in the group's frame: not a position.

const VERBS := ["move", "attack", "attack_move", "follow", "hold", "stop"]


static func source(game_match: Object) -> Object:
	if game_match == null:
		return null
	if "orders" in game_match:
		var field: Variant = game_match.get("orders")
		if field is Object and is_instance_valid(field):
			return field
	if game_match.has_meta("orders"):
		var attached: Variant = game_match.get_meta("orders")
		if attached is Object and is_instance_valid(attached):
			return attached
	return null


## Use `orders` for this match's brains when the match has no `orders` field yet (before CP1).
static func attach(game_match: Object, orders: Object) -> void:
	game_match.set_meta("orders", orders)


## The team a PLAYER commands in this match, or -1 when nobody does (every CPU match). Set by the mode that gives a
## human the orders — `game_match.set_meta("player_team", Match.Team.GREEN)` in skirmish — and read by brains: a unit
## of that team holds its ground until it is told to do something (round 5, the lead: *"they all also just rush forward
## right away at the start of the game"*). An army that moves without being told isn't an army.
static func player_team(game_match: Object) -> int:
	if game_match == null or not game_match.has_meta("player_team"):
		return -1
	return int(game_match.get_meta("player_team"))


static func current(orders: Object, unit_name: String) -> Dictionary:
	if orders == null:
		return {}
	var order := normalize(orders.call("current", unit_name))
	if order.is_empty():
		return order
	if order["goal"] == null and orders.has_method("goal_position"):
		order["goal"] = point(orders.call("goal_position", unit_name))
	if orders.has_method("pace_factor"):
		order["speed"] = clampf(float(orders.call("pace_factor", unit_name)), 0.2, 1.0)
	return order


## Where an idle unit regroups (control's `station(unit).position`), or null when the source doesn't keep stations.
static func station(orders: Object, unit_name: String) -> Variant:
	if orders == null or not orders.has_method("station"):
		return null
	var found: Variant = orders.call("station", unit_name)
	if typeof(found) != TYPE_DICTIONARY or not (found as Dictionary).has("position"):
		return null
	return point(found["position"])


## Round 7 (nav): which way an idle unit's station faces — the ordered `facing`, else the group's direction of travel
## (control's `station(unit).heading`) — as a flat unit Vector3, or null when the source keeps no stations.
static func station_heading(orders: Object, unit_name: String) -> Variant:
	if orders == null or not orders.has_method("station"):
		return null
	var found: Variant = orders.call("station", unit_name)
	if typeof(found) != TYPE_DICTIONARY:
		return null
	return heading((found as Dictionary).get("heading"))


## [x, z] (or anything point() reads) → a flat unit Vector3, or null for nothing / a zero direction.
static func heading(value: Variant) -> Variant:
	var direction: Variant = point(value)
	if direction == null or (direction as Vector3).length_squared() < 0.000001:
		return null
	return (direction as Vector3).normalized()


static func complete(orders: Object, unit_name: String) -> void:
	if orders != null and orders.has_method("complete"):
		orders.call("complete", unit_name)


## A K1 order dictionary → the brain's shape (see the header). Unknown verbs read as no order.
static func normalize(raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY or (raw as Dictionary).is_empty():
		return {}
	var order: Dictionary = raw
	var verb := String(order.get("verb", ""))
	if not VERBS.has(verb):
		return {}
	var goal: Variant = null
	if order.get("goal") != null:
		goal = point(order["goal"])
	elif order.get("to") != null and order["verb"] != "follow":
		goal = point(order["to"])
	# The identity of this order: fields that never change while it runs (a follow's live goal does, so it isn't one).
	var identity := "%s|%s|%s|%s|%s|%s|%s" % [order.get("id", ""), verb, order.get("issued_tick", ""),
			order.get("started_tick", ""), order.get("target", ""), order.get("goal", ""), order.get("to", "")]
	return {"verb": verb, "goal": goal, "target": String(order.get("target", "")),
			"issued_tick": int(order.get("issued_tick", -1)),
			"speed": clampf(float(order.get("speed", 1.0)), 0.2, 1.0), "identity": identity,
			"facing": heading(order.get("facing"))}


## Identity of an order, to notice a new one even without the signal: its id, verb, ticks, target, and destination as
## issued (normalize's "identity"), never live values like a follow's station or a group's pace.
static func key(order: Dictionary) -> String:
	if order.is_empty():
		return ""
	return String(order.get("identity", "%s|%s|%s" % [order.get("verb"), order.get("issued_tick"), order.get("target")]))


## [x, z], [x, y, z], Vector2(x, z), or Vector3 → a flat Vector3; null otherwise.
static func point(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR3:
			return Vector3((value as Vector3).x, 0.0, (value as Vector3).z)
		TYPE_VECTOR2:
			return Vector3((value as Vector2).x, 0.0, (value as Vector2).y)
		TYPE_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY:
			var list: Array = Array(value)
			if list.size() == 2 and _number(list[0]) and _number(list[1]):
				return Vector3(float(list[0]), 0.0, float(list[1]))
			if list.size() == 3 and _number(list[0]) and _number(list[2]):
				return Vector3(float(list[0]), 0.0, float(list[2]))
	return null


static func _number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
