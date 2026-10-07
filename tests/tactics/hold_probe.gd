extends SceneTree
## Round 19 (brains B2): the HOLD posture on parade, his line crossing the floor toward the CPU's depot. The stage of
## tests/test_tactics_cpu_hold.gd with seeds, arms and a trace.
##
##   godot --headless --path . --script res://tests/tactics/hold_probe.gd -- --seed=3 --hold=on|off --ambush=on|off
##         --hides=line|point (round 20, M3) --fallback=on|off (round 21, stretch a) --duck=on|off (round 22, B1)
##         --his-units=law_tank (round 22: lancer) --cpu-units=tank,tank,ifv,ifv (round 22: syn_ifv,syn_ifv,syn_tank,syn_scout)
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
	# Round 20 (M3): `--hides=point` is round 19's site search (the line's centre hidden), `line` every crew.
	ElementCommander.AMBUSH_HIDES_LINE = _flag("hides", "line") != "point"
	# Round 21 (stretch a, shipped off): `--fallback=on` lets a losing post or ambush give one bound; off is round 19.
	ElementCommander.HOLD_FALLBACK_ENABLED = _flag("fallback", "off") == "on"
	# Round 22 (B1): a crew under fire it cannot return leaves its post (UnansweredFire); off is round 21.
	UnansweredFire.ENABLED = _flag("duck", "on") != "off"
	UnansweredFire.CLOSE_LEASH_M = float(_flag("duck-leash", "inf")) if _flag("duck-leash", "inf") != "inf" else INF
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
	# Round 22 (B1): `--his-units=lancer` is his recording's Lancers (out-ranging a Syndicate holder); round 19's Law tanks
	# by default.
	var his_units: PackedStringArray = _flag("his-units", "law_tank").split(",")
	for i in 4:
		var at := Vector3(-15.0 + i * 10.0 + jitter.randf_range(-3, 3), 0, 95 + jitter.randf_range(-3, 3))
		his.append(String(lab.unit(Match.Team.GREEN, "Green_L_%d" % (i + 1), at, 0.0, his_units[i % his_units.size()]).name))
	var cpu_a: Array = []
	var cpu_b: Array = []
	var kinds: PackedStringArray = _flag("cpu-units", "tank,tank,ifv,ifv").split(",")
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
		if tick % 3 == 0:
			_tally_ducks(lab)
		if sprung < 0:
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				if element.drill == "spring_ambush":
					sprung = tick
					spring_x = lab.center_of(Array(element.members())).x
		if tick == SimClock.TICK_RATE * 20:
			at_depot = lab.game_match.objective_presence(depot)[Match.Team.RUST]
		if trace and tick % int(float(_flag("trace-every", "2")) * SimClock.TICK_RATE) == 0:
			var parts: Array = ["his %s alive %d hp %.0f knows %s" % [_v(lab.center_of(his)), lab.alive(his), lab.strength(his),
					",".join(PackedStringArray(lab.game_match.intel[Match.Team.GREEN].keys()))],
					"cpu hp %.0f" % lab.strength(cpu_all)]
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				parts.append("%s %s %s drill=%s at %s" % [element.element_name, element.task.get("verb", "-"),
						element.task.get("to", element.task.get("target", "")), element.drill,
						_v(lab.center_of(Array(element.members())))])
			print("HOLD_TRACE t=%.1fs %s %s | %s" % [tick / float(SimClock.TICK_RATE), commander.posture["posture"],
					commander.posture["why"], " | ".join(parts)])
	var report := {"arena": _flag("arena", "parade"), "his_units": ",".join(his_units), "cpu_units": ",".join(kinds), "depot": _v(depot_at), "seed": seed_value, "his_delay_s": delay / SimClock.TICK_RATE, "hold": ElementCommander.POSTURE_ENABLED, "ambush": ElementCommander.AMBUSH_ENABLED,
			"hides": "line" if ElementCommander.AMBUSH_HIDES_LINE else "point",
			"fallback": "on" if ElementCommander.HOLD_FALLBACK_ENABLED else "off", "fallbacks": commander.fallbacks,
			"duck": "on" if UnansweredFire.ENABLED else "off",
			"duck_leash": -1 if UnansweredFire.CLOSE_LEASH_M == INF else int(UnansweredFire.CLOSE_LEASH_M), "ducks": _duck_tally,
			"posture": commander.posture["posture"], "taken": commander.ambushes_taken, "sprung": commander.ambushes_sprung,
			"sprung_s": snappedf(sprung / float(SimClock.TICK_RATE), 0.1) if sprung >= 0 else -1.0,
			"spring_x": snappedf(spring_x, 0.1), "his_lost": snappedf(his_hp - lab.strength(his), 1.0),
			"his_alive": lab.alive(his), "cpu_alive": lab.alive(cpu_all), "rust_at_depot_20s": at_depot,
			"rust_score": lab.game_match.control_score[1], "green_score": lab.game_match.control_score[0]}
	print("HOLD_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


## Round 22 (B1): crews that left a post under unanswered fire, by outcome (each crew counted once per outcome; both
## sides: his line's element runs the rule too).
var _duck_tally := {}


func _tally_ducks(lab: TacticsLab) -> void:
	for element: Element in lab.elements.all():
		for unit_name: String in element.ducks:
			var outcome := String((element.ducks[unit_name] as Dictionary).get("outcome", ""))
			if outcome == "":
				continue
			var key := "%s:%s" % [unit_name, outcome]
			if not _seen_ducks.has(key):
				_seen_ducks[key] = true
				_duck_tally[outcome] = int(_duck_tally.get(outcome, 0)) + 1


var _seen_ducks := {}


func _v(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]
