extends TrafficHoldCase
## Split from test_native_traffic_hold (C32.8): the live members, the odd crews. The case: tests/native/traffic_hold_case.gd (round 32, C32.8).


func test_the_street_hold_drives_as_the_gdscript_odd_crews() -> void:
	await _hold_case(false, 1, 2)
