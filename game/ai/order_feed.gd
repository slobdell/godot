class_name OrderFeed
extends RefCounted
## How brains read the player's orders: contract K1 in _agents/workstreams.md (control's `Orders`, reachable as
## `Match.orders`). Brains execute these (round-3 ai X1, _agents/unit_ai.md "Orders always win").
##
## Duck-typed on purpose: ai builds against the contract before checkpoint CP1 lands, so nothing here names
## control's classes. The source is `Match.orders` when that field exists and is set, else an object attached
## with attach() (tests before CP1, tools). It needs `current(unit_name) -> Dictionary`, `complete(unit_name)`,
## and signal `order_changed(unit_name)`.
##
## current() is normalized for brains into
##   {"verb": "move" | "attack" | "attack_move" | "follow" | "hold" | "stop",
##    "goal": Vector3 | null   this unit's own destination: the order's `slot` [x, z] if given (control's
##                             formation slot in world meters), else `to` plus `slot_offset` [dx, dz] (world),
##                             else `to`,
##    "target": String         attack: the enemy; follow: the friend ("" otherwise),
##    "issued_tick": int, "speed": float (0.2..1, a group's pace when control sends one)}
## or {} when the unit has no order.

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


static func current(orders: Object, unit_name: String) -> Dictionary:
	if orders == null:
		return {}
	var raw: Variant = orders.call("current", unit_name)
	return normalize(raw)


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
	if order.get("slot") != null:
		goal = point(order["slot"])
	elif order.get("to") != null:
		goal = point(order["to"])
		if goal != null and order.get("slot_offset") != null:
			var offset: Variant = point(order["slot_offset"])
			if offset != null:
				goal = (goal as Vector3) + (offset as Vector3)
	return {"verb": verb, "goal": goal, "target": String(order.get("target", "")),
			"issued_tick": int(order.get("issued_tick", -1)),
			"speed": clampf(float(order.get("speed", 1.0)), 0.2, 1.0)}


## Identity of an order, to notice a new one even without the signal (same verb and tick can't repeat).
static func key(order: Dictionary) -> String:
	if order.is_empty():
		return ""
	var goal: Variant = order["goal"]
	return "%s|%d|%s|%s" % [order["verb"], order["issued_tick"], order["target"],
			"" if goal == null else "%.1f,%.1f" % [(goal as Vector3).x, (goal as Vector3).z]]


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
