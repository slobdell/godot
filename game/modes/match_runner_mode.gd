class_name MatchRunnerMode
extends GameMode
## Headless bots-vs-bots, faster than real time under Godot's --fixed-fps; prints
## MATCH_RESULT <json> and quits. Options: --green=N --rust=N (BotControllers) or
## --green-doctrine=PATH --rust-doctrine=PATH (or cpu / cpu:<archetype> with --budget), --score-limit=K --time-limit=SECONDS
## --green-faction=NAME / --rust-faction=NAME (L3: condemned | gangs | law | syndicate) make that side's cpu army a
## faction army, whose SIZE falls out of the faction's costs (Units.BASELINE_BUDGET buys ~30 Condemned vehicles)
## --seed=S --elimination; experiment controls --swap-bases --rust-first --no-navigation, and (round 5) --swap-armies /
## --same-army for which cpu army each team draws (see army_seed)
## --tune=unit_or_weapon.stat=value,... (see Units.apply_tuning); --control adds the center control point;
## --green-commander / --rust-commander give a team a CpuCommander.
## X5 (round 4) scale bench: --bench-units=N spawns N vehicles a side from --bench-faction=NAME's roster, spread
## over each team's half of the arena rather than the spawn grid (100 a side does not fit 52 slots), and
## --no-brains frees every TankBrain so the run measures the SIMULATION's cost alone (ai owns the brain cost).
## The match runner's MATCH_RESULT already carries `speedup` = simulated seconds per real second, so
## ms per tick = 1000 / (60 x speedup). `make scale-bench` runs the ladder.
## --sim-profile (round 5, CP1) prints SIM_PROFILE <json> before the result: ms per physics tick, whole and by section
## (SimProfile; `make sim-profile`).
## --combat-log prints COMBAT_EVENT <json> lines: every K2 weapon_fired / projectile_impact, every destroyed unit, and
## every living unit's pose each COMBAT_LOG_POSE_TICKS (tools/combat_duel.py turns them into a readable timeline).

const COMBAT_LOG_POSE_TICKS := SimClock.TICK_RATE / 2


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
		if flags.has("bench-units"):
			_bench_army(game_match, team, flags.text("bench-faction", Units.DEFAULT_FACTION),
					flags.integer("bench-units", 30))
			continue
		var key := "green" if team == Match.Team.GREEN else "rust"
		if flags.has(key + "-doctrine") or flags.has(key + "-faction"):
			# A doctrine path, or "cpu" / "cpu:<archetype>" for a budgeted army seeded from the match seed. L3:
			# --<side>-faction= alone means "a cpu army of that faction", and it may field more than five squads.
			var lineup := flags.text(key + "-doctrine", "cpu")
			var loaded := Army.load_army(lineup, army_seed(seed_value, team, flags.has("swap-armies"), flags.has("same-army")),
					flags.integer("budget", Units.DEFAULT_BUDGET), flags.text(key + "-faction"))
			if loaded.has("error"):
				push_error(loaded["error"])
				main.get_tree().quit(2)
				return
			game_match.load_doctrine(team, loaded["doctrine"])
		else:
			for i in flags.integer(key, 1):
				game_match.add_bot(team)
	if flags.has("no-brains"):
		for brain in game_match.brains.get_children():
			brain.queue_free()
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
	if flags.has("sim-profile"):
		SimProfile.install(game_match)
	var started_msec := Time.get_ticks_msec()
	game_match.finished.connect(func(result: Dictionary) -> void:
		var real_seconds := (Time.get_ticks_msec() - started_msec) / 1000.0
		result["seed"] = seed_value
		result["real_seconds"] = snappedf(real_seconds, 0.01)
		result["speedup"] = snappedf(result["sim_seconds"] / maxf(real_seconds, 0.001), 0.1)
		if SimProfile.enabled:
			print("SIM_PROFILE " + JSON.stringify(SimProfile.report()))
		print("MATCH_RESULT " + JSON.stringify(result))
		main.get_tree().quit())
	main.hud.set_status("Match runner")
	# With a window (make watch-match), look down on the whole arena.
	main.camera.offset = Vector3(0.0, 105.0, 62.0)
	main.camera.global_position = main.camera.offset
	main.camera.look_at(Vector3.ZERO)


## X5: `count` vehicles of `faction` for `team`, cycling its roster, laid out over that team's half of the arena.
## The spawn grid holds one army (Match.SPAWN_SLOTS); a 100-a-side COST bench is not an army, so it gets its own
## lattice rather than stacking hulls on top of each other and measuring the contact solver instead of the game.
## Round 5 fairness controls: which seed a team's cpu army is drawn from. Normally Green gets seed*2 and Rust
## seed*2+1, so two teams of the same faction field DIFFERENT armies and a series measures army luck as much as
## anything. --swap-armies hands each team the other's army (pair it with the normal run to cancel army strength);
## --same-army gives both teams Green's army (a true mirror: any win-rate gap left is team identity).
static func army_seed(seed_value: int, team: int, swap_armies: bool, same_army: bool) -> int:
	if same_army:
		return seed_value * 2
	var drawn_for := (1 - team) if swap_armies else team
	return seed_value * 2 + drawn_for


func _bench_army(game_match: Match, team: int, faction: String, count: int) -> void:
	var roster := Units.roster(faction)
	if roster.is_empty():
		push_error("no units in faction '%s'" % faction)
		main.get_tree().quit(2)
		return
	var entries: Array = []
	for index in count:
		entries.append({"unit": roster[index % roster.size()]})
	var doctrine := {"name": "Bench %s" % faction, "squads": Army.squads_for_scale(entries)}
	var error := game_match.load_doctrine(team, doctrine)
	if error != "":
		push_error(error)
		main.get_tree().quit(2)
		return
	# 8 m apart, filling the team's own half from just short of the middle back to its wall.
	var spacing := 8.0
	var columns := maxi(1, int(Match.DRIVABLE_LIMIT * 2.0 / spacing))
	var toward_own_wall: float = Match.team_frame(team)["forward"].z * -1.0
	var placed := 0
	for tank in game_match.sorted_team_tanks(team):
		var column := placed % columns
		var row := placed / columns
		tank.global_position = Vector3(-Match.DRIVABLE_LIMIT + spacing * 0.5 + column * spacing, 0.0,
				toward_own_wall * (30.0 + row * spacing))
		tank.rotation.y = Match.spawn_yaw(team)
		tank.reset_physics_interpolation()
		placed += 1


func _log_combat(game_match: Match) -> void:
	game_match.weapon_fired.connect(func(event: Dictionary) -> void: _print_event("fired", event))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void: _print_event("impact", event))
	game_match.tank_destroyed.connect(func(victim: Tank, killer: String) -> void:
		_print_event("destroyed", {"tick": game_match.tick, "victim": String(victim.name), "killer": killer}))
	var ticker := Timer.new()
	ticker.process_callback = Timer.TIMER_PROCESS_PHYSICS
	ticker.wait_time = SimClock.seconds(COMBAT_LOG_POSE_TICKS)
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
