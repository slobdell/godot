extends TestCase
## CP43.0 (round 43, native): what the replay of a match recording reads from its header before the first tick.

const ReplaySetup := preload("res://tests/replay/replay_setup.gd")


static func _unit(unit_name: String, id: String, team: int) -> Dictionary:
	return {"name": unit_name, "id": id, "team": team}


func test_an_old_header_gives_his_laptop_cap_and_the_factions_from_the_roster() -> void:
	# His round-42 playtest header (no C43.2 keys): four Green squads on the laptop preset, Gangs v Syndicate.
	var units: Array = []
	for squad in ["Guns", "Hunters", "Spears", "Spears2"]:
		for i in 5:
			units.append(_unit("Green_%s_%d" % [squad, i + 1], "gang_scout", 0))
	units.append(_unit("Rust_Guns_1", "syn_tank", 1))
	var setup := ReplaySetup.from_header({"units": units})
	assert_eq(setup["squad_cap"], 4, "four Green squads: the cap was four")
	assert_eq(setup["player_faction"], "gangs", "Green's faction from its first unit")
	assert_eq(setup["enemy_faction"], "syndicate", "Rust's faction from its first unit")


func test_the_recorded_keys_win_over_the_roster() -> void:
	var setup := ReplaySetup.from_header({"units": [_unit("Green_A_1", "gang_tank", 0)], "squad_cap": 5,
			"factions": {"green": "law", "rust": "condemned"}})
	assert_eq(setup["squad_cap"], 5, "squad_cap as recorded")
	assert_eq(setup["player_faction"], "law", "factions.green as recorded")
	assert_eq(setup["enemy_faction"], "condemned", "factions.rust as recorded")


func test_his_sim_switches_are_passed_on_and_presentation_is_not() -> void:
	var keys := ReplaySetup.match_switches({"flags": {"attack-shot": "off", "arena": "random", "seed": "1",
			"announcer": "voice", "music": "on", "camera-danger": "off", "skirmish": ""}})
	assert_eq(keys, ["attack-shot", "camera-danger"], "the sim's switches, sorted; arena / seed / audio are not")
	assert_eq(ReplaySetup.match_switches({}), [], "an old header has none")


func test_a_roster_difference_names_the_first_unit() -> void:
	assert_eq(ReplaySetup.difference({"A": "x", "B": "y"}, {"A": "x", "B": "y"}), "", "the same rosters")
	assert_true(ReplaySetup.difference({"A": "x"}, {"A": "x", "C": "z"}).begins_with("C only in the replay"), "an extra unit")
	assert_true(ReplaySetup.difference({"A": "x", "B": "y"}, {"A": "x"}).begins_with("B missing"), "a missing unit")
	assert_eq(ReplaySetup.difference({"A": "x"}, {"A": "q"}), "A is q, his was x", "another unit id")


func test_one_click_over_four_squads_is_one_order_again() -> void:
	# His round-42 tick 806: one attack click on Rust_Hunters_4 with four squads selected, written as four rows.
	var rows := [
		{"t": "order", "tick": 806, "verb": "attack", "target": "Rust_Hunters_4", "units": ["G_1", "G_3"], "source": ""},
		{"t": "order", "tick": 806, "verb": "attack", "target": "Rust_Hunters_4", "units": ["H_3"], "source": ""},
		{"t": "order", "tick": 806, "verb": "attack", "target": "Rust_Hunters_4", "units": ["S_1"], "source": "player"},
		{"t": "order", "tick": 806, "verb": "attack", "target": "Rust_Hunters_5", "units": ["X_1"]},
		{"t": "order", "tick": 807, "verb": "attack", "target": "Rust_Hunters_5", "units": ["X_2"]},
	]
	var merged := ReplaySetup.merge_clicks(rows)
	assert_eq(merged.size(), 3, "the three rows of one click merge; another target or tick does not")
	assert_eq(merged[0]["units"], ["G_1", "G_3", "H_3", "S_1"], "the union, in order")
	assert_eq(rows[0]["units"], ["G_1", "G_3"], "the input rows are not changed")
	var moves := [{"t": "order", "tick": 0, "verb": "move", "to": [1, 2], "units": ["A"]},
		{"t": "order", "tick": 0, "verb": "move", "to": [3, 4], "units": ["B"]}]
	assert_eq(ReplaySetup.merge_clicks(moves).size(), 2, "two clicks to two points stay two orders")


func test_his_round41_formation_picks_are_inferred_from_the_task_rows() -> void:
	var units: Array = []
	for i in 5:
		units.append(_unit("Green_Hunters_%d" % (i + 1), "gang_ifv", 0))
		units.append(_unit("Green_Guns_%d" % (i + 1), "gang_tank", 0))
	var rows := [{"t": "match", "units": units},
		{"t": "order", "tick": 0, "verb": "move", "to": [-58.4, 102.2], "units": ["Green_Hunters_1"]},
		# _give_formation's shape: in place, the hulls' forwards summed, drills off.
		{"t": "task", "tick": 0, "team": 0, "element": "Hunters",
			"task": {"drills": false, "facing": [0.0, -5.0], "formation": "column", "to": [-14.6, 91.6], "verb": "move"}},
		# his move carrying the group's shape: no facing, not a pick
		{"t": "task", "tick": 0, "team": 0, "element": "Hunters",
			"task": {"drills": false, "formation": "column", "to": [-58.4, 102.2], "verb": "move"}},
		# a waypoint's task (facing_from): not a pick
		{"t": "task", "tick": 918, "team": 0, "element": "Guns",
			"task": {"facing": [0.6, -0.7], "facing_from": "waypoint", "formation": "column", "to": [1.0, 2.0], "verb": "move"}},
		# the CPU's: not his
		{"t": "task", "tick": 0, "team": 1, "element": "Guns",
			"task": {"drills": false, "facing": [0.0, 5.0], "formation": "line", "to": [0.0, -90.0], "verb": "move"}}]
	var picks := ReplaySetup.inferred_formations(rows)
	assert_eq(picks.size(), 1, "one pick: the Hunters' in-place column")
	assert_eq([picks[0]["tick"], picks[0]["formation"], (picks[0]["units"] as Array).size()], [0, "column", 5], "his squad")
	rows.append({"t": "order", "tick": 3, "verb": "formation", "units": ["Green_Guns_1"], "formation": "line"})
	assert_eq(ReplaySetup.inferred_formations(rows), [], "a recording that holds its picks infers none")
