class_name ControlGroups
extends RefCounted
## Control X4: control groups 1–9 (ctrl+N saves, shift+N adds, N recalls). Doctrine squads start as groups 1–5, so
## "squads" are just ordinary groups the player can remake at will. Pure data.

signal changed(number: int)

const COUNT := 9

## number (1–9) -> Array[String] of unit names (sorted). Missing = empty.
var _groups := {}


func save(number: int, names: Array) -> void:
	if number < 1 or number > COUNT:
		return
	_groups[number] = Selection._sorted(names)
	changed.emit(number)


func add(number: int, names: Array) -> void:
	save(number, members(number) + Array(names))


func members(number: int) -> Array[String]:
	var result: Array[String] = []
	result.assign(_groups.get(number, []))
	return result


func is_empty(number: int) -> bool:
	return members(number).is_empty()


## Non-empty group numbers in order.
func numbers() -> Array[int]:
	var result: Array[int] = []
	for number in range(1, COUNT + 1):
		if not is_empty(number):
			result.append(number)
	return result


## The group after `number` that has units (wrapping), or 0 when there are none.
func next_after(number: int) -> int:
	var filled := numbers()
	if filled.is_empty():
		return 0
	for candidate in filled:
		if candidate > number:
			return candidate
	return filled[0]


## Which group numbers `unit_name` belongs to.
func groups_of(unit_name: String) -> Array[int]:
	var result: Array[int] = []
	for number in numbers():
		if members(number).has(unit_name):
			result.append(number)
	return result


## Drop destroyed units from every group (a group whose units all died stays, empty).
func prune(game_match: Match) -> void:
	for number in numbers():
		var kept: Array[String] = []
		for unit_name in members(number):
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive():
				kept.append(unit_name)
		if kept.size() != members(number).size():
			_groups[number] = kept
			changed.emit(number)


## Groups 1–5 from the team's doctrine squads, in doctrine order (Match.team_squads sorts by name).
static func from_squads(game_match: Match, team: int) -> ControlGroups:
	var groups := ControlGroups.new()
	var number := 1
	for squad in game_match.team_squads(team):
		if number > 5:
			break
		groups.save(number, Array(squad.roster))
		number += 1
	return groups
