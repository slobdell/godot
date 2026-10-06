extends TestCase
## Round 19 (brains B2): the CPU DEFENDS and lies in wait. Round 18 measured that a bay ambush on parade is never in time
## for a CPU that races for the centre (0 ambushes taken in 8 seeds with the in-time rule): both sides start ~100 m
## from the bays. A CPU that is AHEAD on points holds its depot instead, and one element lies in the bay on the flank of
## the floor his line must cross to reach it. Stage: parade, the CPU holds the east depot (36, -24) and leads on points,
## so its two elements stand on and beside the depot (that is how it scored them; the first stage started them at their
## base 64 m back with the lead already on the board, and they were still driving up when his line arrived); his line of
## four Law tanks crosses the floor from his side toward it.

const DEPOT := "the depot (far)"
const BAY_X := 56.0
## His line sets off this long after the CPU starts holding: a side ahead on points has been holding for a while before
## he comes (set off at once, the ambusher is still crossing open ground when his guns see it and springs at x = 41,
## the floor's edge: hold_probe.gd --his-delay=0).
const HIS_DELAY_S := 10


func _stage(hold_on: bool) -> Dictionary:
	var was := ElementCommander.POSTURE_ENABLED
	ElementCommander.POSTURE_ENABLED = hold_on
	var lab := TacticsLab.create(self, 3, "parade")
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	var green: Array = []
	for i in 4:
		green.append(String(lab.unit(Match.Team.GREEN, "Green_L_%d" % (i + 1), Vector3(-15.0 + i * 10.0, 0, 95), 0.0, "law_tank").name))
	var cpu_a: Array = []
	var cpu_b: Array = []
	var kinds := ["tank", "tank", "ifv", "ifv"]
	for i in 4:
		cpu_a.append(String(lab.unit(Match.Team.RUST, "Rust_A_%d" % (i + 1), Vector3(22.0 + i * 8.0, 0, -34), PI, kinds[i]).name))
		cpu_b.append(String(lab.unit(Match.Team.RUST, "Rust_B_%d" % (i + 1), Vector3(22.0 + i * 8.0, 0, -16), PI, kinds[i]).name))
	await lab.start()
	var depot := {}
	for objective: Dictionary in lab.game_match.objectives:
		if String(objective["name"]) == DEPOT:
			depot = objective
	assert_true(not depot.is_empty(), "parade has %s (%s)" % [DEPOT, lab.game_match.objectives])
	depot["owner"] = Match.Team.RUST
	depot["progress"] = -1.0
	lab.game_match._control_ticks = [0.0, 20.0 * SimClock.TICK_RATE]
	lab.game_match.control_score = [0, 20]
	var line := lab.elements.form(green, "Line")
	lab.elements.form(cpu_a, "Alpha")
	lab.elements.form(cpu_b, "Bravo")
	var commander := ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	var green_hp := lab.strength(green)
	var took := -1
	var sprung := -1
	var sprung_x := 0.0
	var at_depot := 0
	for tick in SimClock.TICK_RATE * 60:
		if tick == HIS_DELAY_S * SimClock.TICK_RATE:
			line.assign({"verb": "move", "to": [36.0, -24.0], "formation": "line"})
		await lab.step()
		for element: Element in lab.elements.of_team(Match.Team.RUST):
			if took < 0 and String(element.task.get("verb", "")) == "ambush":
				took = tick
			if sprung < 0 and element.drill == "spring_ambush":
				sprung = tick
				sprung_x = lab.center_of(Array(element.members())).x
		if tick == SimClock.TICK_RATE * 20:
			at_depot = lab.game_match.objective_presence(depot)[Match.Team.RUST]
	var result := {"posture": commander.posture["posture"], "why": commander.posture["why"],
			"took_s": took / float(SimClock.TICK_RATE) if took >= 0 else -1.0,
			"sprung_s": sprung / float(SimClock.TICK_RATE) if sprung >= 0 else -1.0, "x_at_spring": snappedf(sprung_x, 0.1),
			"rust_at_depot_20s": at_depot, "green_lost": snappedf(green_hp - lab.strength(green), 0.01),
			"green_alive": lab.alive(green), "rust_alive": lab.alive(cpu_a + cpu_b), "taken": commander.ambushes_taken}
	lab.dispose()
	ElementCommander.POSTURE_ENABLED = was
	return result


func test_the_cpu_ahead_on_points_holds_its_depot_and_springs_the_bay_ambush() -> void:
	var off: Dictionary = await _stage(false)
	var on: Dictionary = await _stage(true)
	print("MEASURE cpu_hold parade: attack (round 18) %s | hold %s" % [off, on])
	assert_true(float(on["took_s"]) >= 0.0, "the CPU takes an ambush (%s)" % on)
	assert_true(float(on["sprung_s"]) >= 0.0, "and springs it (%s)" % on)
	assert_true(absf(float(on["x_at_spring"])) > BAY_X, "from a bay, off the floor (%s)" % on)
	assert_true(int(on["rust_at_depot_20s"]) > 0, "the rest of the line holds the depot (%s)" % on)
	assert_true(not (float(off["sprung_s"]) >= 0.0 and absf(float(off["x_at_spring"])) > BAY_X),
			"control: attacking, the CPU never springs one from a bay (%s)" % off)
