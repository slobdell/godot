extends GateTwinCase
## The gate twin on the default layout's open ground (tests/native/gate_twin_case.gd: the harness and why): gates
## reached and latched, v4's come-round, inside_circle. Split from test_native_gate (round 33 overnight, item 4).


## The default layout's open ground (brains' latch case): gates reached and latched.
func test_the_latch_drives_as_the_gdscript() -> void:
	if FreshStage.parent(self, "test_the_latch_drives_as_the_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(false, Arena.DEFAULT_LAYOUT)


func test_the_latch_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_latch_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(true, Arena.DEFAULT_LAYOUT)
