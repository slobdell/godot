extends TrafficHoldCase
## Round 29 (native, C29.2): traffic's street hold in the native drive, live members, the even crews. The case: tests/native/traffic_hold_case.gd (round 32, C32.8).


func test_the_street_hold_drives_as_the_gdscript() -> void:
	await _hold_case(false, 0, 2)
