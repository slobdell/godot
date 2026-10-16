extends TrafficTurnsCase
## Split from test_native_traffic_turns (C32.8): the live members, the odd crews. The case: tests/native/traffic_turns_case.gd (round 32, C32.8).


func test_the_crossing_drives_as_the_gdscript_odd_crews() -> void:
	await _turns_case(false, 1, 2)
