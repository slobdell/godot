extends DriveTwinCase
## Split from test_native_drive (round 32, C32.8); the harness is tests/native/drive_twin_case.gd.


## Round 27 (stage 1 E1c): the same, the native drive running on the C++-owned state (ExecState, StructView).
func test_the_k_turn_legs_on_the_owned_state() -> void:
	await _k_turn_case(true)
