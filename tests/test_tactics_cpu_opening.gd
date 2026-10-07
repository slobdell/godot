extends TestCase
## Round 20 (brains M2): THE OPENING. On parade the CPU spawns nearer its depot than he does, and the bay beside the floor
## is an ambush site: from 0 to 0 it goes to the depot and HOLDS it from the start (one element lying in ambush), instead
## of attacking and turning to hold only when he is 33-35 m off (round 19's census in his frame: 0 ambushes). The
## control arm attacks first, as round 19 did. SHIPPED OFF (measured: element_commander.gd OPENING_ENABLED); this test
## keeps the rule working for the next series (`--cpu-opening`).

const SECONDS := 20.0


func teardown() -> void:
	ElementCommander.OPENING_ENABLED = false  # shipped off (element_commander.gd)
	super.teardown()


## Two CPU elements at the Rust spawn, his four tanks parked at home (nobody comes): {why, posture, taken, opening}.
func _opening(enabled: bool) -> Dictionary:
	ElementCommander.OPENING_ENABLED = enabled
	var lab := TacticsLab.create(self, 3, "parade")
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	var his: Array = []
	for i in 4:
		var at := Match.spawn_position(Match.Team.GREEN, i)
		his.append(String(lab.unit(Match.Team.GREEN, "Green_L_%d" % (i + 1), at, atan2(at.x, at.z), "law_tank").name))
	var kinds := ["tank", "tank", "ifv", "ifv"]
	var cpu_a: Array = []
	var cpu_b: Array = []
	for i in 4:
		var a := Match.spawn_position(Match.Team.RUST, i)
		var b := Match.spawn_position(Match.Team.RUST, i + 4)
		cpu_a.append(String(lab.unit(Match.Team.RUST, "Rust_A_%d" % (i + 1), a, atan2(a.x, a.z), kinds[i]).name))
		cpu_b.append(String(lab.unit(Match.Team.RUST, "Rust_B_%d" % (i + 1), b, atan2(b.x, b.z), kinds[i]).name))
	await lab.start()
	lab.elements.form(his, "His")  # a squad of his, standing at home (bare brains would roam to the objective)
	lab.elements.form(cpu_a, "Alpha")
	lab.elements.form(cpu_b, "Bravo")
	var commander := ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	var first_why := ""
	for tick in int(SECONDS * SimClock.TICK_RATE):
		await lab.step()
		if first_why == "" and String(commander.posture.get("why", "")) != "":
			first_why = String(commander.posture["why"])
	var result := {"first_why": first_why, "posture": String(commander.posture["posture"]), "why": String(commander.posture["why"]),
			"zone": String((commander.posture["zone"] as Dictionary).get("name", "")), "taken": commander.ambushes_taken,
			"opening": commander.opening.duplicate()}
	lab.dispose()
	return result


func test_on_parade_the_cpu_takes_its_depot_first_and_lies_in_wait() -> void:
	var on: Dictionary = await _opening(true)
	var off: Dictionary = await _opening(false)
	print("MEASURE cpu_opening parade seed 3: opening %s | control %s" % [on, off])
	assert_true(bool(on["opening"].get("site", false)), "parade gives its near ring an ambush site (%s)" % on)
	assert_true(String(on["first_why"]).begins_with("opening"), "from the first think it holds for the opening (%s)" % on)
	assert_eq(on["posture"], "hold", "still holding at %.0f s (%s)" % [SECONDS, on])
	assert_eq(on["zone"], String(on["opening"]["name"]), "its near ring")
	assert_true(int(on["taken"]) >= 1, "an element lies in ambush before he has come (%s)" % on)
	assert_true(String(off["first_why"]).begins_with("holds no objective"), "control: it attacks first, as round 19 (%s)" % off)
