extends TrafficTurnsCase
## The crossing on the C++-owned state, the even crews. The case: tests/native/traffic_turns_case.gd (round 32, C32.8).


func test_the_crossing_on_the_owned_state() -> void:
	await _turns_case(true, 0, 2)
