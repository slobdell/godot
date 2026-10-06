extends SceneTree
## Round 18 (brains B5 (a)): HIS squad crossing parade's floor against a CPU commander with squad leaders (elements).
## His element (four Law tanks, a line) is attack-moved from his side across the centre; the CPU (two elements of
## Condemned, cannon tanks and IFVs) starts on its side under ElementCommander, fighting for the centre. Reported: did
## the CPU take an ambush, did it spring it, from where (x: the bays are |x| > 56), what his squad lost and what the CPU
## lost, in 60 s. `--ambush=off` is the control arm (ElementCommander.AMBUSH_ENABLED false).
##
##   godot --headless --path . --script res://tests/tactics/ambush_probe.gd -- --seed=1 --ambush=on|off --seconds=60
##   AMBUSH_PROBE {"seed", "ambush", "taken", "sprung", "sprung_s", "spring_x", "his_lost", "his_alive", "cpu_alive"}

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
	var seed_value := int(_flag("seed", "1"))
	ElementCommander.AMBUSH_ENABLED = _flag("ambush", "on") != "off"
	var lab := TacticsLab.create(case, seed_value, "parade")
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var his: Array = []
	for i in 4:
		var at := Vector3(-15.0 + i * 10.0 + jitter.randf_range(-3, 3), 0, 95 + jitter.randf_range(-3, 3))
		his.append(String(lab.unit(Match.Team.GREEN, "Green_H_%d" % (i + 1), at, 0.0, "law_tank").name))
	var cpu_a: Array = []
	var cpu_b: Array = []
	var kinds := ["tank", "tank", "ifv", "ifv"]
	for i in 4:
		cpu_a.append(String(lab.unit(Match.Team.RUST, "Rust_A_%d" % (i + 1),
				Vector3(-40.0 + i * 8.0 + jitter.randf_range(-3, 3), 0, -88), PI, kinds[i]).name))
		cpu_b.append(String(lab.unit(Match.Team.RUST, "Rust_B_%d" % (i + 1),
				Vector3(16.0 + i * 8.0 + jitter.randf_range(-3, 3), 0, -88), PI, kinds[i]).name))
	await lab.start()
	var line := lab.elements.form(his, "His")
	line.assign({"verb": "move", "to": [0.0, -60.0], "formation": "line"})
	lab.elements.form(cpu_a, "Alpha")
	lab.elements.form(cpu_b, "Bravo")
	var commander := ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	commander.objective_override = Vector3.ZERO
	var his_hp := lab.strength(his)
	var sprung := -1
	var spring_x := 0.0
	var cpu_all := cpu_a + cpu_b
	for tick in int(float(_flag("seconds", "60")) * SimClock.TICK_RATE):
		await lab.step()
		if sprung < 0:
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				if element.drill == "spring_ambush":
					sprung = tick
					spring_x = lab.center_of(Array(element.members())).x
	var report := {"seed": seed_value, "ambush": ElementCommander.AMBUSH_ENABLED, "taken": commander.ambushes_taken,
			"sprung": commander.ambushes_sprung, "sprung_s": snappedf(sprung / float(SimClock.TICK_RATE), 0.1) if sprung >= 0 else -1.0,
			"spring_x": snappedf(spring_x, 0.1), "his_lost": snappedf(his_hp - lab.strength(his), 1.0),
			"his_alive": lab.alive(his), "cpu_alive": lab.alive(cpu_all)}
	print("AMBUSH_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)
