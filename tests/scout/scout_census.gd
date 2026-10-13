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


## The brain's motion, from its `why`: the gun-lay planner, a hold, the standoff ring, a chase, the orbit, or other.
static func _motion(why: String) -> String:
	if why.contains("laying its gun") or why.contains("backing up to keep"):
		return "lay"
	if why.contains("holding at standoff") or why.contains("short halt") or why.contains("outranging"):
		return "hold"
	if why.contains("firing position"):
		return "ring"
	if why.contains("after it") or why.contains("closing in"):
		return "chase"
	if why.contains("circling") or why.contains("attack run"):
		return "orbit"
	return "other"


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	# Outcomes (the orchestrator's question: do scouts fight less?): fixed guns' kills, damage dealt and deaths. Rounds
	# are matched to their shooter by projectile id (weapon_fired names the shooter, projectile_impact the damage).
	var outcome := {"kills": 0, "damage": 0.0, "deaths": 0}
	var last_doing := {}
	var deaths_by := {}
	var started_at := [0]
	var shooter_of := {}
	var fixed_names := {}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		shooter_of[event.get("projectile_id", -1)] = String(event.get("shooter", "")))
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var shooter := String(shooter_of.get(event.get("projectile_id", -1), ""))
		if fixed_names.has(shooter):
			outcome["damage"] = float(outcome["damage"]) + float(event.get("damage", 0.0)))
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		if fixed_names.has(String(event.get("killer", ""))) and String(event.get("cause", "")) == "enemy":
			outcome["kills"] = int(outcome["kills"]) + 1
		if String(Units.stat(String(event.get("unit_id", "")), "mount", "turret")) == "fixed":
			outcome["deaths"] = int(outcome["deaths"]) + 1
			# Round 28 (scout S2): what it was doing when it died (its last ticked option/motion), and who killed it.
			var victim := String(event.get("unit", ""))
			var doing := String(last_doing.get(victim, "unseen"))
			var killer_unit := ""
			var killer_tank := game_match.tanks.get_node_or_null(String(event.get("killer", ""))) as Tank
			if killer_tank != null:
				killer_unit = killer_tank.unit_id
			deaths_by[doing] = int(deaths_by.get(doing, 0)) + 1
			print("SCOUT_DEATH t=%.1f %s (%s) doing=%s killer=%s (%s) cause=%s" % [(int(event.get("tick", 0)) - started_at[0]) / float(SimClock.TICK_RATE),
					victim, String(event.get("unit_id", "")), doing, String(event.get("killer", "")), killer_unit,
					String(event.get("cause", ""))]))
	var seconds := float(_flag("seconds", "180"))
	var trace := _flag("trace", "")  # SCOUT_TRACE every 5 ticks for scouts whose name contains this
	var dt := 1.0 / SimClock.TICK_RATE
	var per := {}
	var breakdown := {}
	var suppress_by := {}
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
			started_at[0] = tick
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
			fixed_names[name] = true
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
			last_doing[name] = "%s/%s" % [String(choice.get("option", "")), _motion(str(brain.get("why")) if brain != null else "")]
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
			# Round 28 (scout S1): under SUPPRESS the gun is laid on a POINT (TankBrain._suppression_point), and
			# Gunnery's suppress gate is that point in range and within the aim tolerance (no line of sight). Seconds
			# under SUPPRESS, seconds the gun bears on its point, by motion (the move order the brain gave).
			if String(choice.get("option", "")) == "SUPPRESS":
				var spot: Variant = brain.get("_suppress_point")
				var on_point := false
				if spot is Vector3:
					var aim_at := Vector3((spot as Vector3).x, muzzle.y, (spot as Vector3).z)
					on_point = muzzle.distance_to(aim_at) <= float(weapon["range"]) \
							and Ballistics.aim_error(muzzle, scout.turret_forward(), aim_at) <= deg_to_rad(float(weapon["aim_tolerance_deg"]))
				var order: Dictionary = brain.get("move_order")
				var kind := String(order.get("type", "?"))
				if kind == "move_to" and bool(order.get("reverse", false)):
					kind = "reverse"
				var cell_s: Array = suppress_by.get_or_add(kind + "/" + _motion(str(brain.get("why"))), [0.0, 0.0])
				cell_s[0] += dt
				cell_s[1] += dt if on_point else 0.0
				row["suppress_s"] = float(row.get("suppress_s", 0.0)) + dt
				row["suppress_on_s"] = float(row.get("suppress_on_s", 0.0)) + (dt if on_point else 0.0)
			var reachable := muzzle.distance_to(target.global_position) <= float(weapon["range"]) \
					and Perception.has_line_of_sight(scout, target)
			var bearing := reachable and Ballistics.aim_error(muzzle, scout.turret_forward(), target.global_position) \
					<= deg_to_rad(float(weapon["aim_tolerance_deg"]))
			if bearing:
				row["on_target_s"] = float(row["on_target_s"]) + dt
			if trace != "" and name.contains(trace) and (tick - started) % 5 == 0:
				var to := target.global_position - scout.global_position
				var move: Dictionary = brain.get("move_order")
				var goal := "-"
				if move.has("x"):
					var g := Vector3(float(move["x"]), 0.0, float(move["z"])) - scout.global_position
					goal = "%.0fm@%.0f%s" % [Vector2(g.x, g.z).length(), rad_to_deg((-scout.global_basis.z).signed_angle_to(g, Vector3.UP)),
							"R" if bool(move.get("reverse", false)) else ""]
				var poff := "-"
				var spot_t: Variant = brain.get("_suppress_point")
				if String(choice.get("option", "")) == "SUPPRESS" and spot_t is Vector3:
					var tp := (spot_t as Vector3) - scout.global_position
					poff = "%.0f@%.0fm" % [rad_to_deg((-scout.global_basis.z).signed_angle_to(Vector3(tp.x, 0, tp.z), Vector3.UP)),
							Vector2(tp.x, tp.z).length()]
				print("SCOUT_TRACE t=%.2f %s opt=%s poff=%s tgt=%s supp=%.2f d=%.1f off=%.0f tv=%.1f v=%.1f los=%s move=%s goal=%s why=%s" % [t, name,
						String(choice.get("option", "")), poff, target_name, target.suppression, Vector2(to.x, to.z).length(),
						rad_to_deg((-scout.global_basis.z).signed_angle_to(Vector3(to.x, 0, to.z), Vector3.UP)),
						target.estimated_velocity.length(), scout.estimated_velocity.dot(-scout.global_basis.z),
						"y" if reachable else "n", String(move.get("type", "?")), goal, str(brain.get("why"))])
			# Diagnosis (not a decision metric): fight time by option x motion, [seconds, in reach, bearing].
			var label := "%s/%s" % [String(choice.get("option", "")), _motion(str(brain.get("why")))]
			var cell: Array = breakdown.get_or_add(label, [0.0, 0.0, 0.0, 0.0, 0.0])
			cell[0] += dt
			cell[1] += dt if reachable else 0.0
			cell[2] += dt if bearing else 0.0
			# ...and, in reach, the summed range (the range question: does backing up to keep the gun on open it?) and
			# the summed range while bearing.
			var range_m := muzzle.distance_to(target.global_position)
			cell[3] += range_m * dt if reachable else 0.0
			cell[4] += range_m * dt if bearing else 0.0
			var room := 2.0 * float(Units.stat(scout.unit_id, "min_turn_radius_m", 0.0)) \
					+ float(Movement.hull_box(scout.unit_id)[2]) * 0.5 + float(Movement.hull_box(target.unit_id)[0]) * 0.5
			if Vector2(scout.global_position.x - target.global_position.x,
					scout.global_position.z - target.global_position.z).length() < room:
				row["close_s"] = float(row["close_s"]) + dt
			if scout.estimated_velocity.dot(-scout.global_basis.z) < -0.5:
				row["reverse_s"] = float(row["reverse_s"]) + dt
		if fixed_alive == 0 and t > 30.0:
			break
	var total := {"fight_s": 0.0, "on_target_s": 0.0, "close_s": 0.0, "reverse_s": 0.0, "contacts": 0, "contacts_target": 0,
			"suppress_s": 0.0, "suppress_on_s": 0.0}
	for name: String in per:
		for key: String in total:
			total[key] = total[key] + per[name].get(key, 0.0)
	var flags := SkirmishMode.demo_flags(LaunchFlags.parse(OS.get_cmdline_user_args())) if OS.get_cmdline_user_args().has("--demo-match") else null
	var out := {"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"factions": [flags.text("player-faction"), flags.text("enemy-faction")] if flags != null else [],
			"scouts": per.size(), "per_scout": per, "breakdown": breakdown,
			"suppress_by": suppress_by, "deaths_by": deaths_by}
	out.merge(total)
	out.merge(outcome)
	print("SCOUT_CENSUS " + JSON.stringify(out))
	quit(0)
