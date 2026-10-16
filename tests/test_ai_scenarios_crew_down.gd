extends "res://tests/ai_scenarios/delegate_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in delegate_case.gd.


func test_holding_a_crew_down_lets_a_teammate_work_on_it() -> void:
	await _delegate(SUPPRESSION, "test_holding_a_crew_down_lets_a_teammate_work_on_it")
