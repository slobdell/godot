extends SceneTree
## Round 29 (manoeuvre M4, the orchestrator's fights guard): the showmatch's own match headless (main.tscn with the
## showmatch flags, as tests/scout/scout_census.gd), every unit's fight counted, so a change to what `estimated_velocity`
## reads (aim leads, formations, unstick) can be judged on kills, deaths and hit rate:
##
##   shots / hits     rounds fired per team; rounds that struck an ENEMY hull (projectile_impact with a target)
##   kills / deaths   enemy kills per team (unit_destroyed, cause enemy) and losses per team
##   touch_shots / touch_hits   rounds fired at an engaged target that was TOUCHING something (a wall or a hull: its
##               mover's wall contact, or a hull in its slide collisions) when fired, and of those the hits on it
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/fight_census.gd -- --skirmish --demo-match
##         --clean --seed=<n> --arena=random --mute [--seconds=180]
##   FIGHT_CENSUS {"seed", "arena", "factions", "teams": {"0": {...}, "1": {...}}}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _touching(tank: Tank) -> bool:
	var mover := Movement.of(tank)
	if mover != null and mover.contact != null and mover.contact.touching:
		return true
	for i in tank.get_slide_collision_count():
		if tank.get_slide_collision(i).get_collider() is Tank:
			return true
	return false


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	var teams := {}
	var shooter_of := {}  # projectile id -> [shooter team, aimed-at name, aimed-at touching]
	var row := func(team: int) -> Dictionary:
		return teams.get_or_add(str(team), {"shots": 0, "hits": 0, "kills": 0, "deaths": 0, "touch_shots": 0,
				"touch_hits": 0})
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter == null:
			return
		var aimed := ""
		var touching := false
		var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + String(shooter.name))) as TankBrain
		if brain != null and brain.engaged_target != "":
			aimed = brain.engaged_target
			var target := game_match.tanks.get_node_or_null(aimed) as Tank
			touching = target != null and _touching(target)
		var r: Dictionary = row.call(shooter.team)
		r["shots"] = int(r["shots"]) + 1
		if touching:
			r["touch_shots"] = int(r["touch_shots"]) + 1
		shooter_of[event.get("projectile_id", -1)] = [shooter.team, aimed, touching])
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var shot: Variant = shooter_of.get(event.get("projectile_id", -1))
		if shot == null or not event.has("target"):
			return
		var victim := game_match.tanks.get_node_or_null(String(event["target"])) as Tank
		if victim == null or victim.team == int(shot[0]):
			return
		var r: Dictionary = row.call(int(shot[0]))
		r["hits"] = int(r["hits"]) + 1
		if bool(shot[2]) and String(event["target"]) == String(shot[1]):
			r["touch_hits"] = int(r["touch_hits"]) + 1)
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		var lost: Dictionary = row.call(int(event.get("team", -1)))
		lost["deaths"] = int(lost["deaths"]) + 1
		var killer := game_match.tanks.get_node_or_null(String(event.get("killer", ""))) as Tank
		if killer != null and String(event.get("cause", "")) == "enemy":
			var r: Dictionary = row.call(killer.team)
			r["kills"] = int(r["kills"]) + 1)
	var seconds := float(_flag("seconds", "180"))
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
		if (tick - started) / float(SimClock.TICK_RATE) > seconds:
			break
	var flags := SkirmishMode.demo_flags(LaunchFlags.parse(OS.get_cmdline_user_args())) if OS.get_cmdline_user_args().has("--demo-match") else null
	print("FIGHT_CENSUS " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"factions": [flags.text("player-faction"), flags.text("enemy-faction")] if flags != null else [], "teams": teams,
			"h1b": ManoeuvreCensus.h1b_report(), "h1b_on": Movement.h1b_on()}))  # round 32: H1b's counters (measurement only)
	ManoeuvreCensus.print_new_far_rows()  # C32.10 amendment: each far loop with its blocker kind
	quit(0)
