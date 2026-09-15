class_name Selection
extends RefCounted
## Control X2: what the player has selected. `units` are commandable friendlies (sorted names); `inspected` is one
## enemy shown in the panel but never commanded. Pure data: RtsControls fills it from mouse input, the selection
## panel, rings, and orders read it.

signal changed

var units: Array[String] = []
## An enemy being looked at ("" = none). Exclusive with `units`.
var inspected := ""


func set_units(names: Array) -> void:
	var sorted := _sorted(names)
	if sorted == units and inspected == "":
		return
	units = sorted
	inspected = ""
	changed.emit()


func add(names: Array) -> void:
	set_units(units + _sorted(names))


func remove(names: Array) -> void:
	var kept: Array[String] = []
	for unit_name in units:
		if not names.has(unit_name):
			kept.append(unit_name)
	set_units(kept)


## Shift-click: remove a selected unit, or add an unselected one.
func toggle(unit_name: String) -> void:
	if units.has(unit_name):
		remove([unit_name])
	else:
		add([unit_name])


func inspect(enemy_name: String) -> void:
	if inspected == enemy_name and units.is_empty():
		return
	units = []
	inspected = enemy_name
	changed.emit()


func clear() -> void:
	if units.is_empty() and inspected == "":
		return
	units = []
	inspected = ""
	changed.emit()


func has(unit_name: String) -> bool:
	return units.has(unit_name) or inspected == unit_name


func is_empty() -> bool:
	return units.is_empty() and inspected == ""


## Drop destroyed or missing units (and a destroyed inspected enemy). Returns true if anything changed.
func prune(game_match: Match) -> bool:
	var kept: Array[String] = []
	for unit_name in units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			kept.append(unit_name)
	var enemy := game_match.tanks.get_node_or_null(NodePath(inspected)) as Tank if inspected != "" else null
	var keep_inspected := inspected != "" and enemy != null and enemy.is_alive()
	if kept.size() == units.size() and (inspected == "" or keep_inspected):
		return false
	units = kept
	if not keep_inspected:
		inspected = ""
	changed.emit()
	return true


static func _sorted(names: Array) -> Array[String]:
	var seen := {}
	var result: Array[String] = []
	for unit_name in names:
		if not seen.has(String(unit_name)):
			seen[String(unit_name)] = true
			result.append(String(unit_name))
	result.sort()
	return result
