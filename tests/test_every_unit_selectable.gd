extends TestCase
## Round 8 (the lead): *"not all units belong to a squad. There seem to be orphaned units that don't get selected at all
## when I cycle through the numbers on my keyboard (1, 2, 3, 4…)."* A unit no selection gesture reaches is disobedient by
## definition. So the absence is asserted: no unit of the player's army exists that no control group contains, for the
## armies the skirmish actually builds (every faction, the budget it plays at, several seeds).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const SEEDS := [1, 7, 42]


func _orphans(faction: String, seed_value: int) -> Dictionary:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var plan := SkirmishMode.lineup_plan("player_default", "cpu", faction, "", 0)
	var loaded := Army.load_army(String(plan[Match.Team.GREEN]["lineup"]), seed_value, int(plan["budget"]), faction)
	assert_eq(String(loaded.get("error", "")), "", "setup: %s's army rolls" % faction)
	# As SkirmishMode builds the player's side (the last test checks it does).
	var doctrine := SquadConsolidation.for_player(loaded["doctrine"])
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: and spawns")
	var groups := ControlGroups.from_squads(game_match, Match.Team.GREEN)
	var grouped := {}
	# The number keys the lead cycles: 1-5 (ControlGroups seeds 1-5; the tactical map's keys are 1-5).
	for number in range(1, 6):
		for unit_name: String in groups.members(number):
			grouped[unit_name] = number
	var squadless: Array = []
	var ungrouped: Array = []
	var units := 0
	for tank in game_match.sorted_team_tanks(Match.Team.GREEN):
		units += 1
		if game_match.squad_for(tank) == null:
			squadless.append(String(tank.name))
		if not grouped.has(String(tank.name)):
			ungrouped.append(String(tank.name))
	var result := {"units": units, "squads": game_match.team_squads(Match.Team.GREEN).size(), "squadless": squadless,
			"ungrouped": ungrouped}
	game_match.queue_free()
	return result


func test_every_unit_of_the_players_army_is_in_a_control_group() -> void:
	for faction: String in ["", "gangs", "law", "syndicate", "condemned"]:
		for seed_value: int in SEEDS:
			var result := await _orphans(faction, seed_value)
			print("MEASURE selectable %s seed %d: %s" % [faction if faction != "" else "(no faction)", seed_value, result])
			assert_true(int(result["units"]) > 0, "setup: %s has an army" % faction)
			assert_eq((result["squadless"] as Array).size(), 0, "%s seed %d: every unit is in a squad (%s)"
					% [faction, seed_value, result["squadless"]])
			assert_eq((result["ungrouped"] as Array).size(), 0, "%s seed %d: every unit is in a control group 1-5 (%s of %d squads)"
					% [faction, seed_value, result["ungrouped"], result["squads"]])


func test_the_family_folds_first_then_the_smallest_by_role() -> void:
	var doctrine := {"name": "x", "squads": [
		{"name": "Hunters", "directive": {"role": "assault"}, "units": [{"unit": "a"}, {"unit": "a"}]},
		{"name": "Battery", "directive": {"role": "support"}, "units": [{"unit": "b"}]},
		{"name": "Hunters2", "directive": {"role": "assault"}, "units": [{"unit": "a"}]},
		{"name": "Eyes", "directive": {"role": "recon"}, "units": [{"unit": "c"}, {"unit": "c"}, {"unit": "c"}]},
		{"name": "Wrenches", "directive": {"role": "support"}, "units": [{"unit": "d"}, {"unit": "d"}]},
		{"name": "Lances", "directive": {"role": "assault"}, "units": [{"unit": "e"}, {"unit": "e"}, {"unit": "e"}]},
		{"name": "Guns", "directive": {"role": "assault"}, "units": [{"unit": "f"}, {"unit": "f"}, {"unit": "f"}, {"unit": "f"}]}]}
	var folded := SquadConsolidation.for_player(doctrine)
	var names: Array = (folded["squads"] as Array).map(func(q: Dictionary) -> String: return String(q["name"]))
	var total := 0
	for squad: Dictionary in folded["squads"]:
		total += (squad["units"] as Array).size()
	assert_eq(total, 16, "no unit lost")
	assert_eq(names.size(), 5, "five squads (%s)" % [names])
	assert_true(not names.has("Hunters2"), "Hunters2 folded into Hunters (%s)" % [names])
	assert_true(not names.has("Battery"), "the smallest (Battery, 1) joined the smallest support squad, Wrenches (%s)" % [names])
	assert_eq(SquadConsolidation.family_of("Spears12"), "Spears", "a family is the name without its number")
	var two := SquadConsolidation.for_player({"squads": [
		{"name": "Eyes", "units": range(21).map(func(_i: int) -> Dictionary: return {"unit": "c"})},
		{"name": "Eyes2", "units": range(21).map(func(_i: int) -> Dictionary: return {"unit": "c"})}]})
	var sizes: Array = (two["squads"] as Array).map(func(q: Dictionary) -> int: return (q["units"] as Array).size())
	assert_true((two["squads"] as Array).size() <= 5 and sizes.max() <= 11, "42 of one family becomes squads of a squad's size (%s)" % [sizes])
	assert_eq(sizes.reduce(func(a: int, b: int) -> int: return a + b, 0), 42, "no unit lost")


func test_the_skirmish_builds_the_players_army_through_it() -> void:
	# The rule, enforced (lesson 47): the seam the test above exercises is the one the game uses.
	var source := FileAccess.get_file_as_string("res://game/modes/skirmish_mode.gd")
	assert_true(source.find("SquadConsolidation.for_player(") >= 0,
			"SkirmishMode folds the player's army (SquadConsolidation.for_player) before it spawns")
