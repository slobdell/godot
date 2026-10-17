extends DriveTwinCase
## Split from test_native_drive (round 32, C32.8); the harness is tests/native/drive_twin_case.gd. Round 33: the unstick
## compare's other half of the frames is test_native_drive_kturn_odd (the same fight; this file keeps the drive compare).


## Wheeled hulls nose-on to walls with their goal behind them: the k-turn planner, its legs, their ends.
func test_the_k_turn_legs_are_the_live_gdscript() -> void:
	await _k_turn_case(false, 0, 2)
