extends GateTwinCase
## The gate twin on the Sumps (tests/native/gate_twin_case.gd: the harness and why). The open ground's latch is
## test_native_gate_foundry (round 33 overnight, item 4: split by case).


## Sumps: tight ground (gates shortened, cramped, given up).
func test_the_gate_rule_drives_as_the_gdscript() -> void:
	if FreshStage.parent(self, "test_the_gate_rule_drives_as_the_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(false, "sumps")


func test_the_gate_rule_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_gate_rule_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(true, "sumps")
