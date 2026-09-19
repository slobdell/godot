class_name ControlGroups
extends RefCounted
## Control X4: control groups 1–9 (ctrl+N saves, shift+N adds, N recalls). Doctrine squads start as groups 1–5, so
## "squads" are just ordinary groups the player can remake at will. Pure data.

signal changed(number: int)

const COUNT := 9

## number (1–9) -> Array[String] of unit names (sorted). Missing = empty.
var _groups := {}
## number -> the element's name in alerts and edge markers (X2). Missing = "Group N".
var _labels := {}


## Name an element. Doctrine squads bring their names ("Alpha"); a group the player makes keeps "Group N".
func label(number: int, name := "") -> String:
	if name != "":
		_labels[number] = name
	return String(_labels.get(number, "Group %d" % number))


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


## Groups 1-9 from the team's doctrine squads, in doctrine order (Match.team_squads sorts by name). Round 8: this used
## to stop at 5 while faction armies field 6-10 squads, so 4-17 vehicles were on no number key - the lead's "orphaned
## units that don't get selected at all". squad now consolidates the player's army to at most 5; `plan` still makes sure
## no army, whatever its generator produces, leaves a vehicle unreachable.
static func from_squads(game_match: Match, team: int) -> ControlGroups:
	var squads: Array = []
	for squad in game_match.team_squads(team):
		squads.append({"name": String(squad.squad_name), "roster": Array(squad.roster)})
	var groups := ControlGroups.new()
	var number := 1
	for entry: Dictionary in plan(squads):
		groups.save(number, entry["roster"])
		groups.label(number, entry["name"])
		number += 1
	return groups


## [{name, roster}] squads -> at most COUNT groups holding every unit. The first COUNT squads keep their own group; each
## squad past that joins the group of its family ("Guns4" -> "Guns"), else the last group.
static func plan(squads: Array) -> Array:
	var result: Array = []
	for entry: Dictionary in squads:
		if result.size() < COUNT:
			result.append({"name": String(entry["name"]), "roster": Array(entry["roster"]).duplicate()})
			continue
		var home: Dictionary = result.back()
		for group: Dictionary in result:
			if family(String(group["name"])) == family(String(entry["name"])):
				home = group
				break
		(home["roster"] as Array).append_array(entry["roster"])
	return result


## "Guns4" -> "Guns": the generator numbers the squads it splits a unit type into.
static func family(squad_name: String) -> String:
	var end := squad_name.length()
	while end > 0 and squad_name[end - 1] >= "0" and squad_name[end - 1] <= "9":
		end -= 1
	return squad_name.substr(0, end).strip_edges()


## Round 8, the lead: "there seem to be orphaned units that don't get selected at all when I cycle through the numbers".
## The team's living vehicles that no group 1-9 holds - every one of them is unreachable by the number keys.
func ungrouped(game_match: Match, team: int) -> Array[String]:
	var result: Array[String] = []
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == team and tank.is_alive() and groups_of(String(tank.name)).is_empty():
			result.append(String(tank.name))
	result.sort()
	return result
