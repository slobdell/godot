extends SceneTree
## Round 19 (brains B2): the HOLD posture on parade, his line crossing the floor toward the CPU's depot. The stage of
## tests/test_tactics_cpu_hold.gd with seeds, arms and a trace.
##
##   godot --headless --path . --script res://tests/tactics/hold_probe.gd -- --seed=3 --hold=on|off --ambush=on|off
##         --seconds=60 --trace=on --his-to=36,-24 --his-delay=10 (s before his line sets off)
##   HOLD_PROBE {"seed", "hold", "ambush", "posture", "taken", "sprung", "sprung_s", "spring_x", "his_lost", "his_alive",
##               "cpu_alive", "rust_at_depot_20s", "rust_score", "green_score"}

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seed_value := int(_flag("seed", "3"))
	ElementCommander.POSTURE_ENABLED = _flag("hold", "on") != "off"
	ElementCommander.AMBUSH_ENABLED = _flag("ambush", "on") != "off"
	var trace := _flag("trace", "off") == "on"
	var lab := TacticsLab.create(case, seed_value, _flag("arena", "parade"))
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	# The CPU's depot: the objective nearest its base (parade (36, -24), the Open Yard (-62, -34)).
	var depot := {}
	var rust_base := Match.spawn_position(Match.Team.RUST, 0)
	for objective: Dictionary in lab.game_match.objectives:
		if depot.is_empty() or (objective["position"] as Vector3).distance_to(rust_base) \
				< (depot["position"] as Vector3).distance_to(rust_base):
			depot = objective
	var depot_at: Vector3 = depot["position"]
	var to := _flag("his-to", "%f,%f" % [depot_at.x, depot_at.z]).split(",")
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var his: Array = []
	for i in 4:
		var at := Vector3(-15.0 + i * 10.0 + jitter.randf_range(-3, 3), 0, 95 + jitter.randf_range(-3, 3))
		his.append(String(lab.unit(Match.Team.GREEN, "Green_L_%d" % (i + 1), at, 0.0, "law_tank").name))
	var cpu_a: Array = []
	var cpu_b: Array = []
	var kinds := ["tank", "tank", "ifv", "ifv"]
	for i in 4:
		cpu_a.append(String(lab.unit(Match.Team.RUST, "Rust_A_%d" % (i + 1),
				Vector3(depot_at.x - 14.0 + i * 8.0 + jitter.randf_range(-3, 3), 0, depot_at.z - 10.0), PI, kinds[i]).name))
		cpu_b.append(String(lab.unit(Match.Team.RUST, "Rust_B_%d" % (i + 1),
				Vector3(depot_at.x - 14.0 + i * 8.0 + jitter.randf_range(-3, 3), 0, depot_at.z + 8.0), PI, kinds[i]).name))
	await lab.start()
	depot["owner"] = Match.Team.RUST
	depot["progress"] = -1.0
	lab.game_match._control_ticks = [0.0, 20.0 * SimClock.TICK_RATE]
	lab.game_match.control_score = [0, 20]
	var line := lab.elements.form(his, "His")
	var delay := int(float(_flag("his-delay", "10")) * SimClock.TICK_RATE)
	lab.elements.form(cpu_a, "Alpha")
	lab.elements.form(cpu_b, "Bravo")
	var commander := ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	var his_hp := lab.strength(his)
	var sprung := -1
	var spring_x := 0.0
	var at_depot := 0
	var cpu_all := cpu_a + cpu_b
	for tick in int(float(_flag("seconds", "60")) * SimClock.TICK_RATE):
		if tick == delay:
			line.assign({"verb": "move", "to": [float(to[0]), float(to[1])], "formation": "line"})
		await lab.step()
		if sprung < 0:
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				if element.drill == "spring_ambush":
					sprung = tick
					spring_x = lab.center_of(Array(element.members())).x
		if tick == SimClock.TICK_RATE * 20:
			at_depot = lab.game_match.objective_presence(depot)[Match.Team.RUST]
		if trace and tick % (SimClock.TICK_RATE * 2) == 0:
			var parts: Array = ["his %s alive %d" % [_v(lab.center_of(his)), lab.alive(his)]]
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				parts.append("%s %s %s drill=%s at %s" % [element.element_name, element.task.get("verb", "-"),
						element.task.get("to", element.task.get("target", "")), element.drill,
						_v(lab.center_of(Array(element.members())))])
			print("HOLD_TRACE t=%ds %s %s | %s" % [tick / SimClock.TICK_RATE, commander.posture["posture"],
					commander.posture["why"], " | ".join(parts)])
	var report := {"arena": _flag("arena", "parade"), "depot": _v(depot_at), "seed": seed_value, "his_delay_s": delay / SimClock.TICK_RATE, "hold": ElementCommander.POSTURE_ENABLED, "ambush": ElementCommander.AMBUSH_ENABLED,
			"posture": commander.posture["posture"], "taken": commander.ambushes_taken, "sprung": commander.ambushes_sprung,
			"sprung_s": snappedf(sprung / float(SimClock.TICK_RATE), 0.1) if sprung >= 0 else -1.0,
			"spring_x": snappedf(spring_x, 0.1), "his_lost": snappedf(his_hp - lab.strength(his), 1.0),
			"his_alive": lab.alive(his), "cpu_alive": lab.alive(cpu_all), "rust_at_depot_20s": at_depot,
			"rust_score": lab.game_match.control_score[1], "green_score": lab.game_match.control_score[0]}
	print("HOLD_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


func _v(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]
