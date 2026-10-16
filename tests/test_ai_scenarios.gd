extends "res://tests/ai_scenarios/delegate_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in delegate_case.gd.


func test_a_brain_fires_at_a_visible_enemy_with_a_clear_lane() -> void:
	await _delegate(FIRE_DISCIPLINE, "test_a_brain_fires_at_a_visible_enemy_with_a_clear_lane")


func test_a_hurt_tank_under_fire_gets_out_of_sight() -> void:
	await _delegate(COVER, "test_a_hurt_tank_under_fire_gets_out_of_sight")


func test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane() -> void:
	await _delegate(FIRE_DISCIPLINE, "test_a_tank_blocked_by_a_parked_friend_moves_to_clear_the_lane")


func test_no_option_is_kept_forever() -> void:
	await _delegate(ORDERS, "test_no_option_is_kept_forever")
