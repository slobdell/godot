extends "res://tests/tactics/pursuit_case.gd"
## Round 32 (C32.8 / R31.9): split from one slow file; what its tests share is in tests/tactics/pursuit_case.gd.


func test_a_target_they_cannot_catch_is_still_chased_not_orbited() -> void:
	await _assert_pursuit_seeds(18.0, 25.0)
