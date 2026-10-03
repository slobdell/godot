extends SceneTree
## S7 (round 16): what the black box's once-a-second census costs on the tick it lands, with his armies (Law v the
## Condemned at the default budget on the sumps), and what its every-tick task scan costs. Light; runs locally.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/recorder_bench.gd -- [--out=DIR]

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const CENSUSES := 200


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var flags := LaunchFlags.from_environment()
	var arena: Node = ARENA.instantiate()
	arena.layout_name = "sumps"
	root.add_child(arena)
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	for team in 2:
		var faction := "law" if team == Match.Team.GREEN else "condemned"
		game_match.load_doctrine(team, Army.cpu_army("cpu", 92721 + team, Units.BASELINE_BUDGET, faction))
	for i in 3:
		await physics_frame
	var out := flags.text("out", OS.get_user_data_dir().path_join("recorder_bench"))
	var recorder := MatchRecorder.start(game_match, null, null, null, out, "bench", 92721)
	await physics_frame
	var total := 0
	var worst := 0
	for i in CENSUSES:
		recorder._next_census = 0.0
		var started := Time.get_ticks_usec()
		recorder._physics_process(0.0)
		var spent := Time.get_ticks_usec() - started
		total += spent
		worst = maxi(worst, spent)
	var bytes := FileAccess.get_file_as_bytes(recorder.path).size()
	print("RECORDER_BENCH %d units, census %.3f ms avg, %.3f ms worst (%d censuses), %.0f bytes a census"
			% [game_match.tanks.get_child_count(), total / 1000.0 / CENSUSES, worst / 1000.0, CENSUSES,
				float(bytes) / CENSUSES])
	recorder.queue_free()
	quit()
