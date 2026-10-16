extends ExecuteTwinCase
## Split from test_native_execute (round 32, C32.8): the same fight's odd crews. The case:
## tests/native/execute_twin_case.gd.


func test_execute_is_the_live_compute_command_odd_crews() -> void:
	await _execute_case(1, 2)
