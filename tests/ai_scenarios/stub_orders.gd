class_name StubOrders
extends RefCounted
## A minimal stand-in for control's K1 `Orders` (_agents/workstreams.md), so ai's order-execution tests run before
## checkpoint CP1. Only what the contract says: issue / current / queue / complete / order_changed. AiScenario.orders()
## uses control's real class instead once it exists, so the same scenarios then test the real thing.

signal order_changed(unit_name: String)

const VERBS := ["move", "attack", "attack_move", "follow", "hold", "stop"]

var game_match: Match
var _current := {}
var _queues := {}


func _init(p_match: Match = null) -> void:
	game_match = p_match


func issue(command: Dictionary) -> String:
	if not VERBS.has(command.get("verb", "")):
		return "verb must be one of %s" % [VERBS]
	if typeof(command.get("units")) != TYPE_ARRAY or (command["units"] as Array).is_empty():
		return "units must be a non-empty list"
	for unit_name: String in command["units"]:
		var order := command.duplicate(true)
		order.erase("units")
		order["units"] = (command["units"] as Array).duplicate()
		order["issued_tick"] = game_match.tick if game_match != null else 0
		if command.has("to") and command["verb"] != "follow":
			order["goal"] = command["to"]  # control resolves each unit's formation slot into `goal`; one spot per unit here
		if bool(command.get("queue", false)) and _current.has(unit_name):
			(_queues.get_or_add(unit_name, []) as Array).append(order)
			continue
		_queues.erase(unit_name)
		_current[unit_name] = order
		order_changed.emit(unit_name)
	return ""


func current(unit_name: String) -> Dictionary:
	return _current.get(unit_name, {})


func queue(unit_name: String) -> Array:
	return _queues.get(unit_name, [])


func complete(unit_name: String) -> void:
	var waiting: Array = _queues.get(unit_name, [])
	if waiting.is_empty():
		_current.erase(unit_name)
	else:
		var next: Dictionary = waiting.pop_front()
		next["issued_tick"] = game_match.tick if game_match != null else 0
		_current[unit_name] = next
	order_changed.emit(unit_name)
