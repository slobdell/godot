extends TestCase
## Round 32 (C32.8 / R31.9): split from test_tactics_scenarios_4.gd by time (its six-unit fight); the same test, byte for byte.


func test_attack_move_decisions_measured() -> void:
	# Round 7: a measurement first (the bar comes after the fix, from what it measures).
	var result: Dictionary = await TacticsScenarios.attack_move_decisions(self)
	print("MEASURE attack_move_decisions %s" % result)
	assert_true(float(result["unit_minutes"]) > 3.0, "setup: six units fought for most of a minute")
