extends "res://tests/ai_scenarios/delegate_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in delegate_case.gd.


func test_a_move_order_is_executed_within_100_ms_whatever_the_brain_was_doing() -> void:
	await _delegate(ORDERS, "test_a_move_order_is_executed_within_100_ms_whatever_the_brain_was_doing")


func test_attack_move_fights_on_the_way_then_arrives() -> void:
	await _delegate(ORDERS, "test_attack_move_fights_on_the_way_then_arrives")


func test_an_idle_unit_pushed_off_its_post_regroups() -> void:
	await _delegate(ORDERS, "test_an_idle_unit_pushed_off_its_post_regroups")
