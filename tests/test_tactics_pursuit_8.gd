extends "res://tests/tactics/pursuit_case.gd"
## Round 32 (C32.8 / R31.9): split from one slow file; what its tests share is in tests/tactics/pursuit_case.gd.


func test_a_spotter_retreating_at_8_mps_is_chased_down() -> void:
	await _assert_pursuit_seeds(8.0, 30.0)
