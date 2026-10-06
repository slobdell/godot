extends SceneTree
## Round 20 (brains M2): THE OPENING, from the spawns. Both sides start at home, 0 to 0, nothing owned: two CPU elements
## (tank, tank, ifv, ifv) at the Rust spawn under an ElementCommander, his --his-count Law vehicles (default 8: two squads
## of four) at the Green spawn, which set off after --his-delay (default at once) side by side toward --his-to (default:
## the CPU's near ring).
## Round 19's hold probe started the CPU on its depot and ahead (the stage the ambush already won); this is the match he
## plays, where round 19's CPU raced out, turned to hold only when he was 33-35 m off, and never laid an ambush.
##
##   godot --headless --path . --script res://tests/tactics/opening_probe.gd -- --arena=parade --seed=3 --opening=on|off
##         --seconds=90 --his-delay=0 --his-count=8 --his-to=depot|x,z --trace=on
##   OPENING_PROBE {"arena", "seed", "opening", "his_to", "near_ring", "site", "posture_why", "opening_s", "taken",
##                  "sprung", "sprung_s", "refused", "his_lost", "cpu_lost", "his_alive", "cpu_alive", "rust_score",
##                  "green_score", "ring_owner"}

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
	ElementCommander.OPENING_ENABLED = _flag("opening", "on") != "off"
	var trace := _flag("trace", "off") == "on"
	var arena := _flag("arena", "parade")
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	var rust_base := Match.spawn_position(Match.Team.RUST, 0)
	var green_base := Match.spawn_position(Match.Team.GREEN, 0)
	var ring_name := Posture.near_ring(lab.game_match.objectives, rust_base, green_base)
	var ring := {}
	for objective: Dictionary in lab.game_match.objectives:
		if String(objective.get("name", "")) == ring_name:
			ring = objective
	var to := Vector3.ZERO
	var his_to := _flag("his-to", "depot")
	if his_to == "depot" and not ring.is_empty():
		to = ring["position"]
	elif his_to.contains(","):
		to = Vector3(float(his_to.get_slice(",", 0)), 0.0, float(his_to.get_slice(",", 1)))
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var his: Array = []
	var his_kinds := ["law_tank", "law_tank", "law_ifv", "law_ifv"]
	for i in int(_flag("his-count", "8")):
		var at := Match.spawn_position(Match.Team.GREEN, i) + Vector3(jitter.randf_range(-2, 2), 0, jitter.randf_range(-2, 2))
		var yaw := atan2(at.x, at.z)  # facing the middle
		his.append(String(lab.unit(Match.Team.GREEN, "Green_L_%d" % (i + 1), at, yaw, his_kinds[i % 4]).name))
	var kinds := ["tank", "tank", "ifv", "ifv"]
	var cpu_a: Array = []
	var cpu_b: Array = []
	for i in 4:
		var a := Match.spawn_position(Match.Team.RUST, i) + Vector3(jitter.randf_range(-2, 2), 0, jitter.randf_range(-2, 2))
		var b := Match.spawn_position(Match.Team.RUST, i + 4) + Vector3(jitter.randf_range(-2, 2), 0, jitter.randf_range(-2, 2))
		cpu_a.append(String(lab.unit(Match.Team.RUST, "Rust_A_%d" % (i + 1), a, atan2(a.x, a.z), kinds[i]).name))
		cpu_b.append(String(lab.unit(Match.Team.RUST, "Rust_B_%d" % (i + 1), b, atan2(b.x, b.z), kinds[i]).name))
	await lab.start()
	# His squads of up to four (C19.1: an element never holds more than five), ordered together as orders sends them.
	var lines: Array = []
	for first in range(0, his.size(), 4):
		lines.append(lab.elements.form(his.slice(first, first + 4), "His_%d" % (first / 4 + 1)))
	var delay := int(float(_flag("his-delay", "0")) * SimClock.TICK_RATE)
	lab.elements.form(cpu_a, "Alpha")
	lab.elements.form(cpu_b, "Bravo")
	var commander := ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	var cpu_all := cpu_a + cpu_b
	var his_hp := lab.strength(his)
	var cpu_hp := lab.strength(cpu_all)
	var sprung := -1
	var opening_ticks := 0
	var first_why := ""
	for tick in int(float(_flag("seconds", "90")) * SimClock.TICK_RATE):
		if tick == delay:
			# Side by side across his approach, 30 m apart, each in a line (his two-squad click).
			var across := TacticsFormation.flat(to - green_base).cross(Vector3.UP)
			for k in lines.size():
				var at := to + across * (float(k) - (lines.size() - 1) * 0.5) * 30.0
				(lines[k] as Element).assign({"verb": "move", "to": [at.x, at.z], "formation": "line"})
		await lab.step()
		if first_why == "" and String(commander.posture.get("why", "")) != "":
			first_why = String(commander.posture["why"])
		if String(commander.posture.get("why", "")).begins_with("opening"):
			opening_ticks += 1
		if sprung < 0:
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				if element.drill == "spring_ambush":
					sprung = tick
		if trace and tick % int(float(_flag("trace-every", "3")) * SimClock.TICK_RATE) == 0:
			var parts: Array = ["his %s alive %d" % [_v(lab.center_of(his)), lab.alive(his)]]
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				parts.append("%s %s drill=%s at %s" % [element.element_name, element.task.get("verb", "-"), element.drill,
						_v(lab.center_of(Array(element.members())))])
			print("OPENING_TRACE t=%.1fs %s %s | %s" % [tick / float(SimClock.TICK_RATE), commander.posture["posture"],
					commander.posture["why"], " | ".join(parts)])
	var report := {"arena": arena, "seed": seed_value, "opening": ElementCommander.OPENING_ENABLED, "his_to": his_to,
			"near_ring": ring_name, "site": bool(commander.opening.get("site", false)), "posture_why": first_why,
			"opening_s": snappedf(opening_ticks / float(SimClock.TICK_RATE), 0.1), "taken": commander.ambushes_taken,
			"sprung": commander.ambushes_sprung, "sprung_s": snappedf(sprung / float(SimClock.TICK_RATE), 0.1) if sprung >= 0 else -1.0,
			"refused": commander.ambush_refused, "his_lost": snappedf(his_hp - lab.strength(his), 1.0),
			"cpu_lost": snappedf(cpu_hp - lab.strength(cpu_all), 1.0), "his_alive": lab.alive(his), "cpu_alive": lab.alive(cpu_all),
			"rust_score": lab.game_match.control_score[1], "green_score": lab.game_match.control_score[0],
			"ring_owner": int(ring.get("owner", -1)) if not ring.is_empty() else -2}
	print("OPENING_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


func _v(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]
