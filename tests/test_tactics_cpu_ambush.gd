extends TestCase
## Round 18 (brains): the CPU sets an ambush. His map item: a centre where *"a line abreast formation could get ambushed
## by another formation that was orthogonal"*. On parade (the map built for it) the CPU never used the bays: 7 % of its
## unit-time near cover against 26 % on the Sumps, with or without elements, because ElementCommander never gave an
## ambush task. Now a line element out of contact takes one from a spot hidden on the flank of the ground the enemy must
## cross (AmbushSite), holds fire, and springs it when they enter the kill zone.

const RUST_AT := Vector3(-70, 0, -30)


func _stage(ambush_on: bool, hides_line := true) -> Dictionary:
	var was := ElementCommander.AMBUSH_ENABLED
	ElementCommander.AMBUSH_ENABLED = ambush_on
	ElementCommander.AMBUSH_HIDES_LINE = hides_line
	var lab := TacticsLab.create(self, 3, "parade")
	var green: Array = []
	for i in 4:
		green.append(String(lab.unit(Match.Team.GREEN, "Green_L_%d" % (i + 1), Vector3(-15.0 + i * 10.0, 0, 95), 0.0, "law_tank").name))
	var rust: Array = []
	for i in 4:
		rust.append(String(lab.unit(Match.Team.RUST, "Rust_A_%d" % (i + 1), RUST_AT + Vector3((i - 1.5) * 9.0, 0, 0), PI, "law_tank").name))
	await lab.start()
	var green_element := lab.elements.form(green, "Line")
	green_element.assign({"verb": "move", "to": [0.0, -60.0], "formation": "line"})
	lab.elements.form(rust, "Alpha")
	var commander := ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	commander.objective_override = Vector3.ZERO
	var green_hp := lab.strength(green)
	var took := -1
	var sprung := -1
	var sprung_x := 0.0
	for tick in SimClock.TICK_RATE * 60:
		await lab.step()
		var rust_element: Element = null
		for element: Element in lab.elements.of_team(Match.Team.RUST):
			rust_element = element
		if rust_element == null:
			continue
		if took < 0 and String(rust_element.task.get("verb", "")) == "ambush":
			took = tick
		if sprung < 0 and rust_element.drill == "spring_ambush":
			sprung = tick
			sprung_x = lab.center_of(rust).x
	var result := {"took_s": took / float(SimClock.TICK_RATE) if took >= 0 else -1.0,
			"sprung_s": sprung / float(SimClock.TICK_RATE) if sprung >= 0 else -1.0, "rust_x_at_spring": snappedf(sprung_x, 0.1),
			"green_strength_lost": snappedf(green_hp - lab.strength(green), 0.01), "rust_alive": lab.alive(rust),
			"green_alive": lab.alive(green), "taken": commander.ambushes_taken, "refused": commander.ambush_refused.duplicate()}
	lab.dispose()
	ElementCommander.AMBUSH_ENABLED = was
	ElementCommander.AMBUSH_HIDES_LINE = true
	return result


func test_the_cpu_lies_in_the_bay_and_ambushes_a_line_crossing_the_floor() -> void:
	var off: Dictionary = await _stage(false)
	var on: Dictionary = await _stage(true)
	var point: Dictionary = await _stage(true, false)
	print("MEASURE cpu_ambush parade: without %s | with %s | round 19's point search %s" % [off, on, point])
	assert_true(float(on["took_s"]) >= 0.0, "the CPU element takes an ambush (%s)" % on)
	assert_true(float(on["sprung_s"]) >= 0.0, "and springs it (%s)" % on)
	assert_true(float(on["rust_x_at_spring"]) < -40.0, "from the flank, out of the floor (%s)" % on)
	assert_true(float(off["took_s"]) < 0.0, "control: without it the commander never gives an ambush (%s)" % off)
