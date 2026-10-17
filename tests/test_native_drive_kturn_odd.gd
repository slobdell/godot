extends DriveTwinCase
## Split from test_native_drive_kturn (round 33): the same k-turn fight, the native unstick compared on the other half of
## each mover's frames (`(frame + mover) % 2 == 1`); the drive compare stays in test_native_drive_kturn.


func test_the_k_turn_unstick_odd_frames() -> void:
	await _k_turn_case(false, 1, 2, false)
