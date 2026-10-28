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


func test_the_trig_probe_reads_this_process() -> void:
	# Through make (the shim on an old glibc, or glibc >= 2.41) it is correctly rounded; test_native_trig pins the same input.
	assert_true(ReplaySetup.trig_is_correctly_rounded(), "atan2f correctly rounded in a make-started test run")


func test_the_re_run_keeps_headless_its_frame_rate_and_the_project() -> void:
	# What Godot 4.7.2 hands a script started as `--headless --fixed-fps 30 --path P --script S -- --orders=x`.
	var args := ReplaySetup.reexec_args(PackedStringArray(["--script", "res://tests/replay_orders.gd"]),
			PackedStringArray(["--orders=x"]), ["--arena=locks"], true, "/p/")
	assert_eq(args, PackedStringArray(["--headless", "--fixed-fps", "30", "--path", "/p/", "--script",
			"res://tests/replay_orders.gd", "--", "--orders=x", "--arena=locks"]), "the engine's own options go back in front")
	var windowed := ReplaySetup.reexec_args(PackedStringArray(["--fixed-fps", "30", "--path", "/q/"]), PackedStringArray(), [],
			false, "/p/")
	assert_true(not windowed.has("--headless"), "a windowed run stays windowed")
	assert_eq(windowed.count("--fixed-fps"), 1, "an option already there is not doubled")
	assert_eq(windowed.count("--path"), 1, "nor the project")



# ---- Round 44 (native N2): his round-43 match, whose seed was not recorded ---------------------------------------------

const HIS_0821 := "res://_agents/streams/references/round43/playtest/2026-10-28T08-21-31-locks.jsonl"


static func _header(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_line()) if file != null else {}


func test_his_seed_text_is_passed_as_typed() -> void:
	assert_eq(ReplaySetup.seed_text({"seed": -1, "flags": {"seed": "56416."}}), "56416.", "the switch as he typed it")
	assert_eq(ReplaySetup.seed_text({"seed": 56416}), "56416", "an old header: the recorded seed")


func test_the_clock_seeds_start_at_the_recorders_second_in_his_zone() -> void:
	# 2026-10-28 08:21:31 PDT (bias -420 min) = unix 1793200891.
	var seeds := ReplaySetup.clock_seeds("build/recordings/2026-10-28T08-21-31-locks.jsonl", -420)
	assert_eq(seeds[0], 891, "the recorder's own second first")
	assert_eq(seeds[1], 890, "then a second earlier")
	assert_true(seeds.has(posmod(1793200891 - 7 * 3600 + 420 * 60, 100000)), "another zone's reading is tried too")
	assert_eq(ReplaySetup.clock_seeds("build/recordings/latest.jsonl", 0), [], "a name without a time stamp: none")


func test_his_0821_army_seed_is_found_from_his_roster_on_his_preset() -> void:
	var header := _header(HIS_0821)
	assert_eq(int(header.get("seed", 0)), -1, "the recording lost the seed")
	var setup := ReplaySetup.from_header(header)
	RenderLevers.apply_preset("laptop", "test")
	var found := ReplaySetup.army_seed(header, setup, 0, ReplaySetup.clock_seeds(String(header["path"]), -420, 5))
	var on_desktop := -2
	RenderLevers.apply_preset("desktop", "test")
	on_desktop = ReplaySetup.army_seed(header, setup, 0, [891])
	assert_eq(found, 891, "the laptop's roll at 891 fields every one of his 40 units")
	assert_eq(on_desktop, -1, "the desktop preset's roll at 891 does not (the laptop caps the roll at 20 vehicles)")


func test_a_group_click_with_its_click_key_replays_as_one_order_at_the_click() -> void:
	# C44.2: one click over four squads writes a row per squad, each with its own laid-out `to` and the shared `click`.
	var rows := [{"t": "order", "tick": 1512, "verb": "move", "to": [-50.5, 15.2], "click": [-48.0, 60.0], "group": 4, "units": ["G_4"]},
		{"t": "order", "tick": 1512, "verb": "move", "to": [-45.9, 69.5], "click": [-48.0, 60.0], "group": 4, "units": ["H_1", "H_2"]},
		{"t": "order", "tick": 1512, "verb": "move", "to": [7.9, 57.7], "click": [-48.0, 60.0], "group": 4, "units": ["S_1"]},
		{"t": "order", "tick": 1520, "verb": "move", "to": [1.0, 1.0], "click": [1.0, 1.0], "units": ["W_1"]}]
	var merged := ReplaySetup.merge_clicks(rows)
	assert_eq(merged.size(), 2, "the three rows of his group click are one order; the next click is its own")
	assert_eq(merged[0]["units"], ["G_4", "H_1", "H_2", "S_1"], "the union, in order")
	assert_eq(merged[0]["to"], [-48.0, 60.0], "the merged order goes to his click, so the replay lays the squads out again")
	assert_eq(merged[1]["to"], [1.0, 1.0], "a one-squad click keeps its recorded point")
	assert_eq(rows[0]["to"], [-50.5, 15.2], "the input rows are not changed")


func test_a_click_given_by_hand_merges_an_old_recordings_group_click() -> void:
	# His 08-21 recording (before C44.2): four rows on tick 1512, four points, no click. `--click=1512:-48,60` supplies it.
	var rows := [{"t": "order", "tick": 0, "verb": "move", "to": [-85.7, 52.6], "units": ["G_1"], "paused": true},
		{"t": "order", "tick": 1512, "verb": "move", "to": [-50.5, 15.2], "units": ["G_4"]},
		{"t": "order", "tick": 1512, "verb": "move", "to": [-45.9, 69.5], "units": ["H_1"]},
		{"t": "order", "tick": 1808, "verb": "move", "to": [-59.5, 19.9], "units": ["G_4"]}]
	var given := ReplaySetup.with_click(rows, "1512:-48,60")
	assert_eq(given[1]["click"], [-48.0, 60.0], "every row of that tick carries the click")
	assert_true(not given[0].has("click") and not given[3].has("click"), "other ticks are left alone")
	assert_eq(ReplaySetup.merge_clicks(given).size(), 3, "the 1512 rows merge into one order")
	assert_eq(ReplaySetup.with_click(rows, ""), rows, "no --click: unchanged")
	assert_eq(ReplaySetup.with_click(rows, "nonsense"), rows, "a malformed --click: unchanged")
