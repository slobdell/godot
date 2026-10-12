extends SceneTree
## Round 27 (scout S0): THE SCOUT CENSUS. The lead watched `make showmatch` and saw scouts drive into their targets and
## never back up to keep one. This plays the same match headless (main.tscn with the showmatch's own flags, so a seed here
## is the seed `make showmatch SEED=<n>` films) and measures every fixed gun while it fights:
##
##   fight_s      seconds a fixed gun's brain had a fight option (ENGAGE, ORBIT, FLANK, ... with a target)
##   on_target_s  of those, seconds its gun bore on that target (Gunnery's aimed + in range + line of sight)
##   close_s      of those, seconds it sat closer to its target than its turning room (2 turning radii + its half-length +
##               the target's half-width)
##   reverse_s    of those, seconds it drove backwards
##   contacts     hull touches with an enemy (rising edges), and with its own target
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/scout/scout_census.gd -- --skirmish --demo-match
##         --clean --seed=<n> --arena=random --mute [--seconds=180]
##   SCOUT_EVENT t=<s> <scout> contact <enemy> at (x, z)      every contact as it happens (pick a clip moment)
##   SCOUT_CENSUS {"seed", "arena", "factions", "scouts", "fight_s", "on_target_s", "close_s", "reverse_s",
##                 "contacts", "contacts_target", "per_scout": {...}}

const FIGHTS := ["ENGAGE", "ORBIT", "FLANK", "COVER_FIRE", "CLEAR_LANE", "SUPPRESS", "BOMBARD", "PURSUE"]


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
	var dt := 1.0 / SimClock.TICK_RATE
	var per := {}
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
		var t := (tick - started) * dt
		if t > seconds:
			break
		var fixed_alive := 0
		for child in game_match.tanks.get_children():
			var scout := child as Tank
			if scout == null or not scout.is_alive() or scout.mount != "fixed":
				continue
			fixed_alive += 1
			var name := String(scout.name)
			var row: Dictionary = per.get_or_add(name, {"unit": scout.unit_id, "team": scout.team, "alive_s": 0.0,
					"fight_s": 0.0, "on_target_s": 0.0, "close_s": 0.0, "reverse_s": 0.0, "contacts": 0,
					"contacts_target": 0})
			row["alive_s"] = float(row["alive_s"]) + dt
			var enemy_touch := ""
			for i in scout.get_slide_collision_count():
				var other := scout.get_slide_collision(i).get_collider() as Tank
				if other != null and other.team != scout.team:
					enemy_touch = String(other.name)
			var brain := game_match.brains.get_node_or_null("Brain_" + name) as TankBrain
			var choice: Dictionary = brain.get("choice") if brain != null and brain.get("choice") is Dictionary else {}
			var target_name := String(choice.get("target", ""))
			var fighting := FIGHTS.has(String(choice.get("option", ""))) and target_name != ""
			var was: String = touching.get(name, "")
			if enemy_touch != "" and enemy_touch != was:
				row["contacts"] = int(row["contacts"]) + 1
				if enemy_touch == target_name:
					row["contacts_target"] = int(row["contacts_target"]) + 1
				print("SCOUT_EVENT t=%.1f %s contact %s at (%.0f, %.0f) option=%s why=%s" % [t, name, enemy_touch,
						scout.global_position.x, scout.global_position.z, String(choice.get("option", "")),
						str(brain.get("why")) if brain != null else ""])
			touching[name] = enemy_touch
			if not fighting:
				continue
			var target := game_match.tanks.get_node_or_null(target_name) as Tank
			if target == null or not target.is_alive():
				continue
			row["fight_s"] = float(row["fight_s"]) + dt
			var muzzle := scout.turret.global_position
			var weapon := scout.weapon
			if Ballistics.aim_error(muzzle, scout.turret_forward(), target.global_position) \
					<= deg_to_rad(float(weapon["aim_tolerance_deg"])) \
					and muzzle.distance_to(target.global_position) <= float(weapon["range"]) \
					and Perception.has_line_of_sight(scout, target):
				row["on_target_s"] = float(row["on_target_s"]) + dt
			var room := 2.0 * float(Units.stat(scout.unit_id, "min_turn_radius_m", 0.0)) \
					+ float(Movement.hull_box(scout.unit_id)[2]) * 0.5 + float(Movement.hull_box(target.unit_id)[0]) * 0.5
			if Vector2(scout.global_position.x - target.global_position.x,
					scout.global_position.z - target.global_position.z).length() < room:
				row["close_s"] = float(row["close_s"]) + dt
			if scout.estimated_velocity.dot(-scout.global_basis.z) < -0.5:
				row["reverse_s"] = float(row["reverse_s"]) + dt
		if fixed_alive == 0 and t > 30.0:
			break
	var total := {"fight_s": 0.0, "on_target_s": 0.0, "close_s": 0.0, "reverse_s": 0.0, "contacts": 0, "contacts_target": 0}
	for name: String in per:
		for key: String in total:
			total[key] = total[key] + per[name][key]
	var flags := SkirmishMode.demo_flags(LaunchFlags.parse(OS.get_cmdline_user_args())) if OS.get_cmdline_user_args().has("--demo-match") else null
	var out := {"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"factions": [flags.text("player-faction"), flags.text("enemy-faction")] if flags != null else [],
			"scouts": per.size(), "per_scout": per}
	out.merge(total)
	print("SCOUT_CENSUS " + JSON.stringify(out))
	quit(0)
