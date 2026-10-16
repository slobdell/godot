extends TrafficTurnsCase
## Split from test_native_traffic_turns_owned (C32.8): the C++-owned state, the odd crews. The case: tests/native/traffic_turns_case.gd (round 32, C32.8).


func test_the_crossing_on_the_owned_state_odd_crews() -> void:
	await _turns_case(true, 1, 2)
