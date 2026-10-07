class_name ControlGroups
extends RefCounted
## Control X4: control groups on the number keys (ctrl+N saves, shift+N adds, N recalls). Doctrine squads start as
## groups 1–10, so "squads" are just ordinary groups the player can remake at will. Pure data.
## Round 22 (orders O1, C22.5): ten groups for ten squads. Keys 1–9 are groups 1–9 and 0 is group 10, the keyboard's
## order (StarCraft's too); a group's number is shown as its KEY ("0" for 10) wherever he is told to press it.

signal changed(number: int)

## How many groups (and so how many squads reach a number key): one per squad of the largest army.
## TODO(round 22 CP1): read `Units.MAX_SQUADS` (C22.1 amended, 4936bb01) once army's CP1 is on main.
const MAX_GROUPS := 10
const COUNT := MAX_GROUPS

## number (1–10) -> Array[String] of unit names (sorted). Missing = empty.
var _groups := {}
## number -> the element's name in alerts and edge markers (X2). Missing = "Group N".
var _labels := {}
## Round 19 (orders): number -> the formation the player gave that group's squad (missing = AUTO). A squad's own
## element carries its formation in its task while it has one; this is the same choice for the squad between
## elements (before its first task, or after a direct order dissolved it), so the next task it gets carries it again.
## Saving the group over different units forgets it: that is a new squad.
var _formations := {}


## The group a number key stands for: KEY_1..KEY_9 -> 1..9, KEY_0 -> 10, anything else 0.
static func number_for_key(keycode: int) -> int:
	if keycode >= KEY_1 and keycode <= KEY_9:
		return keycode - KEY_0
	if keycode == KEY_0 and MAX_GROUPS >= 10:
		return 10
	return 0


## The key that recalls group `number` (KEY_0 for 10).
static func key_for_number(number: int) -> Key:
	return KEY_0 if number == 10 else (KEY_0 + number) as Key


## What he presses for group `number`, as text: "4", and "0" for group 10.
static func key_label(number: int) -> String:
	return "0" if number == 10 else str(number)


## Group numbers as the keys he presses, runs of three or more joined: [1, 2, 3, 4, 6, 8, 9, 10] -> "1–4 6 8–0"
## (round 22: ten squads' numbers did not fit on a formation card). 0 stands for a squad on no key: "·".
static func keys_text(numbers: Array) -> String:
	var sorted := numbers.duplicate()
	sorted.sort()
	var parts: PackedStringArray = []
	var i := 0
	while i < sorted.size():
		var number := int(sorted[i])
		if number <= 0:
			parts.append("·")
			i += 1
			continue
		var j := i
		while j + 1 < sorted.size() and int(sorted[j + 1]) == int(sorted[j]) + 1:
			j += 1
		if j - i >= 2:
			parts.append("%s–%s" % [key_label(number), key_label(int(sorted[j]))])
		else:
			for k in range(i, j + 1):
				parts.append(key_label(int(sorted[k])))
		i = j + 1
	return " ".join(parts)


## The formation the player gave group `number`'s squad (UnitCommand.AUTO when none).
func formation(number: int) -> String:
	return String(_formations.get(number, UnitCommand.AUTO))


func set_formation(number: int, id: String) -> void:
	if number < 1 or number > COUNT:
		return
	if id == UnitCommand.AUTO:
		_formations.erase(number)
	else:
		_formations[number] = id


## Name an element. Doctrine squads bring their names ("Alpha"); a group the player makes keeps "Group N".
func label(number: int, name := "") -> String:
	if name != "":
		_labels[number] = name
	return String(_labels.get(number, "Group %d" % number))


func save(number: int, names: Array) -> void:
	if number < 1 or number > COUNT:
		return
	var sorted := Selection._sorted(names)
	if sorted != members(number):
		_formations.erase(number)
	_groups[number] = sorted
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
	# Round 16 (hud H4): over the stored lists, not numbers()/members() (two copies of every group, every frame).
	for number in range(1, COUNT + 1):
		var current: Array = _groups.get(number, [])
		if current.is_empty():
			continue
		var kept: Array[String] = []
		for unit_name: String in current:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null and tank.is_alive():
				kept.append(unit_name)
		if kept.size() != current.size():
			_groups[number] = kept
			changed.emit(number)


## Groups 1-10 from the team's doctrine squads, by name (the garage's Alpha … Juliet are 1 … 10, Juliet on the 0 key).
## Round 8: this used to stop at 5 while faction armies field 6-10 squads, so 4-17 vehicles were on no number key -
## the lead's "orphaned units that don't get selected at all". `plan` still makes sure no army, whatever its generator
## produces, leaves a vehicle unreachable.
static func from_squads(game_match: Match, team: int) -> ControlGroups:
	var squads: Array = []
	for squad in game_match.team_squads(team):
		squads.append({"name": String(squad.squad_name), "roster": Array(squad.roster)})
	var groups := ControlGroups.new()
	var number := 1
	for entry: Dictionary in plan(ordered(squads)):
		groups.save(number, entry["roster"])
		groups.label(number, entry["name"])
		number += 1
	return groups


## [{name, ...}] in name order, numbers as numbers ("Guns2" before "Guns10"; Match.team_squads sorts plain text).
static func ordered(squads: Array) -> Array:
	var result := squads.duplicate()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return result


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
## The team's living vehicles that no group 1-10 holds - every one of them is unreachable by the number keys.
func ungrouped(game_match: Match, team: int) -> Array[String]:
	var result: Array[String] = []
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == team and tank.is_alive() and groups_of(String(tank.name)).is_empty():
			result.append(String(tank.name))
	result.sort()
	return result
