extends DriveTwinCase
## Split from test_native_drive (round 32, C32.8); the harness is tests/native/drive_twin_case.gd.


## Round 27 (stage 1 E1c): the same fight, the native drive running on the C++-owned state (ExecState, StructView:
## pulled at the start of each drive, synced around every GDScript callback, pushed at its end).
func test_drive_on_the_owned_state_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_drive_on_the_owned_state_is_the_live_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _drive_case(true)
