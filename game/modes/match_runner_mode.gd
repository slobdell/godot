class_name MatchRunnerMode
extends GameMode
## Headless bots-vs-bots, faster than real time under Godot's --fixed-fps; prints
## MATCH_RESULT <json> and quits. Options: --green=N --rust=N (BotControllers) or
## --green-doctrine=PATH --rust-doctrine=PATH, --score-limit=K --time-limit=SECONDS
## --seed=S --elimination; experiment controls --swap-bases --rust-first --no-navigation.


func role_name() -> String:
	return "MATCH"


func caps_headless_fps() -> bool:
	return false


func start() -> void:
	var game_match := main.game_match
	game_match.has_local_player = false
	Pathing.enabled = not flags.has("no-navigation")
	Match.swap_bases = flags.has("swap-bases")
	var seed_value := flags.integer("seed", 0)
	game_match.seed_spawns(seed_value, 6.0 if flags.has("seed") else 0.0)
	# --rust-first flips spawn (and therefore per-tick processing) order: a fairness probe.
	var order := [Match.Team.RUST, Match.Team.GREEN] if flags.has("rust-first") else [Match.Team.GREEN, Match.Team.RUST]
	for team in order:
		var key := "green" if team == Match.Team.GREEN else "rust"
		if flags.has(key + "-doctrine"):
			var loaded := Doctrine.load_file(flags.text(key + "-doctrine"))
			if loaded.has("error"):
				push_error(loaded["error"])
				main.get_tree().quit(2)
				return
			game_match.load_doctrine(team, loaded["doctrine"])
		else:
			for i in flags.integer(key, 1):
				game_match.add_bot(team)
	game_match.elimination = flags.has("elimination")
	game_match.start_limits(0 if game_match.elimination else flags.integer("score-limit", 5),
			float(flags.integer("time-limit", 300)))
	var started_msec := Time.get_ticks_msec()
	game_match.finished.connect(func(result: Dictionary) -> void:
		var real_seconds := (Time.get_ticks_msec() - started_msec) / 1000.0
		result["seed"] = seed_value
		result["real_seconds"] = snappedf(real_seconds, 0.01)
		result["speedup"] = snappedf(result["sim_seconds"] / maxf(real_seconds, 0.001), 0.1)
		print("MATCH_RESULT " + JSON.stringify(result))
		main.get_tree().quit())
	main.hud.set_status("Match runner")
	# With a window (make watch-match), look down on the whole arena.
	main.camera.offset = Vector3(0.0, 105.0, 62.0)
	main.camera.global_position = main.camera.offset
	main.camera.look_at(Vector3.ZERO)
