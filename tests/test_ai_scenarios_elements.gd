extends "res://tests/ai_scenarios/delegate_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in delegate_case.gd.


func test_each_unit_covers_its_own_sector_of_fire() -> void:
	await _delegate(ELEMENTS, "test_each_unit_covers_its_own_sector_of_fire")


func test_a_bounding_unit_rushes_and_halts_on_the_leaders_call() -> void:
	await _delegate(ELEMENTS, "test_a_bounding_unit_rushes_and_halts_on_the_leaders_call")


func test_a_unit_ordered_across_a_swept_lane_keeps_out_of_the_fire() -> void:
	await _delegate(SUPPRESSION, "test_a_unit_ordered_across_a_swept_lane_keeps_out_of_the_fire")
