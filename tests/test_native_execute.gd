extends ExecuteTwinCase
## Round 27 (native, stage 1 E5): `OrderController.compute_command` as one native call against the live GDScript, the
## Sumps fight's even crews. The case and its harness: tests/native/execute_twin_case.gd (round 32, C32.8); `_odd`
## compares the other crews.


func test_execute_is_the_live_compute_command() -> void:
	await _execute_case(0, 2)
