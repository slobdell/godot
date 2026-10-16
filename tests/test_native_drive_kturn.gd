extends DriveTwinCase
## Split from test_native_drive (round 32, C32.8); the harness is tests/native/drive_twin_case.gd.


## Wheeled hulls nose-on to walls with their goal behind them: the k-turn planner, its legs, their ends.
func test_the_k_turn_legs_are_the_live_gdscript() -> void:
	await _k_turn_case(false)
