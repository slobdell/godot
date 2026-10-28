extends TestCase
## C43.2 (round 43, native): the recording GROWS, never changes. The `match` row gains what a replay needs (squad_cap,
## factions, preset, native, flags, spawn, frame) and the `order` row gains `frame` and `paused`; every key that was
## there keeps its meaning (tools/recording_arrivals.py and the replay read old recordings as before).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_the_replay_keys_hold_the_cap_the_factions_and_every_spawn_at_full_precision() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	m.load_doctrine(Match.Team.GREEN, {"squads": [{"name": "A", "units": [{"unit": "gang_tank"}, {"unit": "gang_scout"}]}]})
	m.load_doctrine(Match.Team.RUST, {"squads": [{"name": "B", "units": [{"unit": "syn_ifv"}]}]})
	await wait_physics_frames(2)
	var keys := MatchRecorder.replay_keys(m, LaunchFlags.parse(PackedStringArray(["--squad-cap=3", "--attack-shot=off"])))
	assert_eq(keys["squad_cap"], 3, "the pinned cap")
	assert_eq(keys["factions"], {"green": "gangs", "rust": "syndicate"}, "each side's faction")
	assert_eq(keys["flags"], {"squad-cap": "3", "attack-shot": "off"}, "the launch switches as read")
	assert_eq(keys["native"], BrainSwitches.native, "whether the C++ library ran the crews")
	assert_true(keys["preset"] is String and String(keys["preset"]) != "", "the render preset")
	assert_true(keys["frame"] is int, "the start frame")
	var tanks := m.sorted_team_tanks(0) + m.sorted_team_tanks(1)
	assert_eq((keys["spawn"] as Dictionary).size(), tanks.size(), "every unit's spawn")
	for tank: Tank in tanks:
		var at: Array = keys["spawn"][String(tank.name)]
		assert_eq(at, [tank.global_position.x, tank.global_position.z, tank.rotation.y], "%s unrounded" % tank.name)
	# JSON keeps them: the replay reads them back as numbers.
	var back: Dictionary = JSON.parse_string(JSON.stringify(keys))
	assert_eq(int(back["squad_cap"]), 3, "squad_cap survives JSON")


func test_an_order_row_keeps_its_keys_and_gains_frame_and_paused() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	var dir := "user://test_recorder_replay_keys"
	var recorder := MatchRecorder.start(m, null, null, null, dir, "keys")
	await wait_physics_frames(1)
	recorder._on_command({"verb": "move", "units": ["Green_A_1"], "source": "player", "to": [1.0, 2.0], "queue": true}, "")
	recorder._exit_tree()
	var rows: Array = []
	for line in FileAccess.get_file_as_string(recorder.path).split("\n"):
		if line.strip_edges() != "":
			rows.append(JSON.parse_string(line))
	var header: Dictionary = rows[0]
	for key in ["t", "path", "arena", "seed", "tick_rate", "tuning", "units"]:
		assert_true(header.has(key), "the match row still has %s" % key)
	for key in ["squad_cap", "factions", "preset", "native", "flags", "spawn", "frame"]:
		assert_true(header.has(key), "the match row gains %s" % key)
	var order: Dictionary = rows.filter(func(r: Dictionary) -> bool: return r["t"] == "order")[0]
	assert_eq([order["verb"], order["units"], order["source"], order["to"], order["queue"]],
			["move", ["Green_A_1"], "player", [1.0, 2.0], true], "the order's keys as before")
	assert_true(order.has("frame") and order.has("paused"), "the order row gains frame and paused")
	assert_eq(order["paused"], false, "not paused")
	DirAccess.remove_absolute(recorder.path)


class FakeControls extends Node:
	signal formation_changed(id: String)
	var selection := Selection.new()


func test_a_formation_pick_is_an_order_row() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	var controls := FakeControls.new()
	add_to_tree(controls)
	controls.selection.set_units(["Green_A_1", "Green_A_2"])
	var recorder := MatchRecorder.start(m, null, controls, null, "user://test_recorder_replay_keys", "pick")
	await wait_physics_frames(1)
	controls.formation_changed.emit("column")
	recorder._exit_tree()
	var picks: Array = []
	for line in FileAccess.get_file_as_string(recorder.path).split("\n"):
		var row: Variant = JSON.parse_string(line) if line.strip_edges() != "" else null
		if row is Dictionary and row["t"] == "order":
			picks.append(row)
	assert_eq(picks.size(), 1, "one row for the pick")
	assert_eq([picks[0]["verb"], picks[0]["formation"], picks[0]["units"]], ["formation", "column", ["Green_A_1", "Green_A_2"]],
			"the verb, the shape and the selection it applied to")
	assert_true(not picks[0].has("to"), "no `to`: recording_arrivals.py skips it")
	DirAccess.remove_absolute(recorder.path)
