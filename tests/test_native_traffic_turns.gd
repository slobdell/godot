extends TrafficTurnsCase
## Round 31 (native, C31.2): traffic's crossing in the native drive, live members, the even crews. The case: tests/native/traffic_turns_case.gd (round 32, C32.8).


func test_the_crossing_drives_as_the_gdscript() -> void:
	await _turns_case(false, 0, 2)
