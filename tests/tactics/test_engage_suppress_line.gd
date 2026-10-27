extends TestCase
## Round 42 (engage v2, R42.12, on R42.2's terms): A CREW DOES NOT STAND TO SUPPRESS INTO A CONTAINER. Bar E1's series left
## 29 stuck crew-seconds under --attack-shot, 81 % of them the brain's SUPPRESS stand: in band, a target its element sees,
## its own line blocked, "suppressing" with its rounds in the box (9609, 9619). Under `--attack-shot-suppress=on` the stand
## asks the same own-line question ENGAGE's hold asks and goes round instead; OFF it faces and fires as before.
## The brain's act step on a built situation (test_ai_arrive_leg's pattern); the line answered by the test seam.


func teardown() -> void:
	TankBrain.SUPPRESS_LINE = false
	super.teardown()


## The crew's move order when its brain is in SUPPRESS on a target `line` reports (a clear or a blocked line of fire).
func _stand(on: bool, line: bool) -> Dictionary:
	var s := AiScenario.create(self, 4)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0, {}, "gang_ifv")
	var target := s.dummy(Match.Team.RUST, "Rust_1", Vector3(0, 0, -20.0), PI, "ifv")
	var brain := s.brain_of(me)
	await s.start()
	for i in 10:
		await s.step()  # perception: the dummy becomes a contact
	TankBrain.SUPPRESS_LINE = on
	brain.line_of_fire = func(_point: Vector3) -> bool: return line
	var situation := brain.build_situation()
	var named := false
	for c: Dictionary in situation["contacts"]:
		named = named or String(c["name"]) == String(target.name)
	assert_true(named, "the target is a contact before the act step (%s)" % [situation["contacts"].map(func(c: Dictionary) -> String: return String(c["name"]))])
	if not named:
		s.dispose()
		return {"type": "", "why": "", "to": Vector3.ZERO, "in_band": false, "distance": 0.0, "band": [], "seen": false}
	var weapon: Dictionary = situation["self"]["weapon"]
	var distance: float = (situation["self"]["position"] as Vector3).distance_to(target.global_position * Vector3(1, 0, 1))
	brain.choice = {"option": "SUPPRESS", "target": String(target.name)}
	brain._act(situation)
	var out := {"type": String(brain.move_order.get("type", "")), "why": brain.why,
			"to": Vector3(float(brain.move_order.get("x", 0.0)), 0.0, float(brain.move_order.get("z", 0.0))),
			"in_band": distance >= float(weapon["preferred_min"]) and distance <= float(weapon["preferred_max"]),
			"distance": distance, "band": [weapon["preferred_min"], weapon["preferred_max"]],
			"seen": situation["contacts"].size() > 0}
	s.dispose()
	return out


func test_off_the_stand_is_todays_whatever_the_line() -> void:
	var clear: Dictionary = await _stand(false, true)
	assert_true(bool(clear["seen"]), "the target is a contact (%s)" % [clear])
	assert_true(bool(clear["in_band"]), "the stage is in the gun's band (%.1f m, band %s)" % [clear["distance"], clear["band"]])
	assert_true(clear["type"] in ["face", "stop"], "OFF, a clear line: the crew stands (a face, or a stop when already facing) (%s)" % [clear])
	var blocked: Dictionary = await _stand(false, false)
	assert_true(blocked["type"] in ["face", "stop"], "OFF, a blocked line: the stand as before (%s)" % [blocked])
	assert_true(not String(blocked["why"]).contains("no line of fire"), "and nothing new in its why (%s)" % blocked["why"])


func test_on_a_blocked_line_goes_round_and_a_clear_one_stands() -> void:
	var blocked: Dictionary = await _stand(true, false)
	assert_eq(blocked["type"], "move_to", "ON, a blocked line: the crew moves (%s)" % [blocked])
	assert_true((blocked["to"] as Vector3).distance_to(Vector3(0, 0, -20.0)) < 1.0, "toward the target (%s)" % [blocked["to"]])
	assert_true(String(blocked["why"]).contains("no line of fire: going round"), "and says so (%s)" % blocked["why"])
	var clear: Dictionary = await _stand(true, true)
	assert_true(clear["type"] in ["face", "stop"], "ON, a clear line: the stand as before (%s)" % [clear])
