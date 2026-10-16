extends TrafficHoldCase
## The street hold on the C++-owned state, the even crews. The case: tests/native/traffic_hold_case.gd (round 32, C32.8).


func test_the_street_hold_on_the_owned_state() -> void:
	await _hold_case(true, 0, 2)
