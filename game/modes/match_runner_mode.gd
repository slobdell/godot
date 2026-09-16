class_name MatchRunnerMode
extends GameMode
## Headless bots-vs-bots, faster than real time under Godot's --fixed-fps; prints
## MATCH_RESULT <json> and quits. Options: --green=N --rust=N (BotControllers) or
## --green-doctrine=PATH --rust-doctrine=PATH (or cpu / cpu:<archetype> with --budget), --score-limit=K --time-limit=SECONDS
## --green-faction=NAME / --rust-faction=NAME (L3: condemned | gangs | law | syndicate) make that side's cpu army a
## faction army, whose SIZE falls out of the faction's costs (Units.BASELINE_BUDGET buys ~30 Condemned vehicles)
## --seed=S --elimination; experiment controls --swap-bases --rust-first --no-navigation
## --tune=unit_or_weapon.stat=value,... (see Units.apply_tuning); --control adds the center control point;
## --green-commander / --rust-commander give a team a CpuCommander.
## --combat-log prints COMBAT_EVENT <json> lines: every K2 weapon_fired / projectile_impact, every destroyed unit, and
## every living unit's pose each COMBAT_LOG_POSE_TICKS (tools/combat_duel.py turns them into a readable timeline).

const COMBAT_LOG_POSE_TICKS := 30


func role_name() -> String:
	return "MATCH"


func caps_headless_fps() -> bool:
	return false


func start() -> void:
	var game_match := main.game_match
	game_match.has_local_player = false
	Pathing.enabled = not flags.has("no-navigation")
	Match.swap_bases = flags.has("swap-bases")
	# Experiments: --tune=tank.max_shield=0,cannon.ammo=60 overrides catalog stats for this run.
	var tune_error := Units.apply_tuning(flags.text("tune"))
	if tune_error != "":
		push_error(tune_error)
		main.get_tree().quit(2)
		return
	var seed_value := flags.integer("seed", 0)
	game_match.budget = flags.integer("budget", Units.DEFAULT_BUDGET)
	game_match.seed_spawns(seed_value, 6.0 if flags.has("seed") else 0.0)
	# --rust-first flips spawn (and therefore per-tick processing) order: a fairness probe.
	var order := [Match.Team.RUST, Match.Team.GREEN] if flags.has("rust-first") else [Match.Team.GREEN, Match.Team.RUST]
	for team in order:
		var key := "green" if team == Match.Team.GREEN else "rust"
		if flags.has(key + "-doctrine") or flags.has(key + "-faction"):
			# A doctrine path, or "cpu" / "cpu:<archetype>" for a budgeted army seeded from the match seed. L3:
			# --<side>-faction= alone means "a cpu army of that faction", and it may field more than five squads.
			var lineup := flags.text(key + "-doctrine", "cpu")
			var loaded := Army.load_army(lineup, seed_value * 2 + team, flags.integer("budget", Units.DEFAULT_BUDGET),
					flags.text(key + "-faction"))
			if loaded.has("error"):
				push_error(loaded["error"])
				main.get_tree().quit(2)
				return
			game_match.load_doctrine(team, loaded["doctrine"])
		else:
			for i in flags.integer(key, 1):
				game_match.add_bot(team)
	game_match.elimination = flags.has("elimination")
	game_match.control_point = flags.has("control")
	# Stretch: --green-commander / --rust-commander put a CpuCommander in charge of that team's gun squads.
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		if flags.has(("green" if team == Match.Team.GREEN else "rust") + "-commander"):
			var commander := CpuCommander.new()
			commander.name = "Commander_%s" % Match.TEAM_NAMES[team]
			commander.game_match = game_match
			commander.team = team
			game_match.add_child(commander)
	game_match.start_limits(0 if game_match.elimination else flags.integer("score-limit", 5),
			float(flags.integer("time-limit", 300)))
	if flags.has("combat-log"):
		_log_combat(game_match)
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


func _log_combat(game_match: Match) -> void:
	game_match.weapon_fired.connect(func(event: Dictionary) -> void: _print_event("fired", event))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void: _print_event("impact", event))
	game_match.tank_destroyed.connect(func(victim: Tank, killer: String) -> void:
		_print_event("destroyed", {"tick": game_match.tick, "victim": String(victim.name), "killer": killer}))
	var ticker := Timer.new()
	ticker.process_callback = Timer.TIMER_PROCESS_PHYSICS
	ticker.wait_time = COMBAT_LOG_POSE_TICKS / 60.0
	ticker.timeout.connect(func() -> void:
		var units := []
		for tank: Tank in game_match._sorted_tanks():
			if tank.is_alive():
				var forward := -tank.global_basis.z
				units.append({"name": String(tank.name), "unit": tank.unit_id, "x": snappedf(tank.global_position.x, 0.01),
						"z": snappedf(tank.global_position.z, 0.01), "fx": snappedf(forward.x, 0.001), "fz": snappedf(forward.z, 0.001),
						"speed": snappedf(tank.speed(), 0.01), "health": tank.health, "shield": roundi(tank.shield),
						"intent": tank.intent})
		_print_event("poses", {"tick": game_match.tick, "units": units}))
	game_match.add_child(ticker)
	ticker.start()


static func _print_event(kind: String, event: Dictionary) -> void:
	var line := event.duplicate()
	line["event"] = kind
	print("COMBAT_EVENT " + JSON.stringify(line))
