extends SceneTree
## Round 28 (brains B3, DECLARED): RECON AT A SPOTTER'S DISTANCE, measured where scout's census found the problem. Plays a
## showmatch seed headless (main.tscn, the census's flags; `--screen-standoff=off` is the control arm) and counts, over
## EVERY unit (not only fixed guns, so a cure that moves the contacts elsewhere shows):
##   contacts        hull touches with an enemy (rising edges), by the toucher's brain option and by its role
##   recon deaths    crews of the recon squads (roster "Eyes") killed
##   alive           each side's living crews at the end (who is winning)
##   screen tasks    screens given or re-aimed by each CPU commander (ElementCommander.screen_tasks), per recon squad-minute
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/tactics/contact_census.gd -- --skirmish --demo-match
##         --clean --seed=<n> --arena=random --mute [--seconds=180] [--screen-standoff=off]
##   CONTACT_CENSUS {"seed", "contacts", "under_move", "by_option": {..}, "by_role": {..}, "recon_deaths",
##                   "recon_crews", "alive": [green, rust], "screen_tasks", "recon_squad_minutes"}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	var seconds := float(_flag("seconds", "180"))
	var report := {"seed": int(_flag("seed", "0")), "contacts": 0, "under_move": 0, "by_option": {},
			"by_role": {}, "recon_deaths": 0, "recon_crews": 0, "alive": [0, 0], "screen_tasks": 0,
			"recon_squad_minutes": 0.0, "screen_off": OS.get_cmdline_user_args().has("--screen-standoff=off")}
	var recon := {}
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		if String(event.get("unit", "")).contains("Eyes"):
			report["recon_deaths"] = int(report["recon_deaths"]) + 1)
	var touching := {}
	var started := -1
	var last_tick := -1
	var frames := 0
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 10:
				break
			continue
		last_tick = tick
		if started < 0:
			started = tick
		if float(tick - started) / SimClock.TICK_RATE > seconds:
			break
		var squads_alive := {}
		for child in game_match.tanks.get_children():
			var tank := child as Tank
			if tank == null or not tank.is_alive():
				continue
			var name := String(tank.name)
			if name.contains("Eyes"):
				recon[name] = true
				squads_alive[name.rsplit("_", true, 1)[0]] = true
			var enemy_touch := ""
			for i in tank.get_slide_collision_count():
				var other := tank.get_slide_collision(i).get_collider() as Tank
				if other != null and other.team != tank.team:
					enemy_touch = String(other.name)
			if enemy_touch != "" and enemy_touch != String(touching.get(name, "")):
				var brain := game_match.brains.get_node_or_null("Brain_" + name) as TankBrain
				var option := String((brain.get("choice") as Dictionary).get("option", "?")) \
						if brain != null and brain.get("choice") is Dictionary else "?"
				var role := Units.role_of(tank.unit_id)
				report["contacts"] = int(report["contacts"]) + 1
				if option == "MOVE":
					report["under_move"] = int(report["under_move"]) + 1
				report["by_option"][option] = int((report["by_option"] as Dictionary).get(option, 0)) + 1
				report["by_role"][role] = int((report["by_role"] as Dictionary).get(role, 0)) + 1
			touching[name] = enemy_touch
		report["recon_squad_minutes"] = float(report["recon_squad_minutes"]) \
				+ float(squads_alive.size()) / SimClock.TICK_RATE / 60.0
	report["recon_crews"] = recon.size()
	if game_match != null and is_instance_valid(game_match):
		for child in game_match.tanks.get_children():
			var tank := child as Tank
			if tank != null and tank.is_alive() and tank.team in [0, 1]:
				report["alive"][tank.team] = int(report["alive"][tank.team]) + 1
		for team in [0, 1]:
			var commander := game_match.get_node_or_null("ElementCommander_%d" % team) as ElementCommander
			if commander != null:
				for count: int in commander.screen_tasks.values():
					report["screen_tasks"] = int(report["screen_tasks"]) + count
	report["recon_squad_minutes"] = snappedf(float(report["recon_squad_minutes"]), 0.01)
	print("CONTACT_CENSUS " + JSON.stringify(report))
	quit(0)
