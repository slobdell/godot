extends GateTwinCase
## The gate twin on the default layout's open ground (tests/native/gate_twin_case.gd: the harness and why): gates
## reached and latched, v4's come-round, inside_circle. Split from test_native_gate (round 33 overnight, item 4).


## The default layout's open ground (brains' latch case): gates reached and latched.
func test_the_latch_drives_as_the_gdscript() -> void:
	if FreshStage.parent(self, "test_the_latch_drives_as_the_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	var holdway_was := Traffic.off("holdway")
	Traffic.set_off("holdway", true)  # Round 46 (R46.30): holdway ON changes who waits at a street mouth, so this staging no longer reaches its case; the gate / yield twins are staged on the traffic they were built for (holdway's own drive equality: test_native_drive, test_native_drive_backout*).
	await _case(false, Arena.DEFAULT_LAYOUT)
	Traffic.set_off("holdway", holdway_was)


func test_the_latch_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_latch_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	var holdway_was := Traffic.off("holdway")
	Traffic.set_off("holdway", true)  # Round 46 (R46.30): holdway ON changes who waits at a street mouth, so this staging no longer reaches its case; the gate / yield twins are staged on the traffic they were built for (holdway's own drive equality: test_native_drive, test_native_drive_backout*).
	await _case(true, Arena.DEFAULT_LAYOUT)
	Traffic.set_off("holdway", holdway_was)
