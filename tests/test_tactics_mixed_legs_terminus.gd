extends "res://tests/tactics/mixed_legs_case.gd"
## Round 32 (C32.8 / R31.9): split from one slow file; what its tests share is in tests/tactics/mixed_legs_case.gd.


func test_a_two_scout_squad_attack_moved_across_the_terminus_arrives() -> void:
	var mixed: Dictionary = await _attack_move(["law_scout", "law_scout", "law_ifv", "law_tank"], "terminus", 1)
	var tanks: Dictionary = await _attack_move(["law_tank", "law_tank", "law_tank", "law_tank"], "terminus", 1)
	print("MEASURE mixed_legs terminus seed 1: two scouts %s | four tanks %s" % [mixed, tanks])
	assert_true(float(tanks["arrived_s"]) > 0.0, "control: four tanks arrive (%s)" % tanks)
	assert_true(float(mixed["arrived_s"]) > 0.0, "a two-scout mixed squad arrives too, not stalled after one leg (%s)" % mixed)
