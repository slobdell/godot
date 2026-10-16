extends WallTwinCase
## Split from test_native_wall (round 32, C32.8): the same fight's odd crews. The case: tests/native/wall_twin_case.gd.


func test_the_native_scan_observes_as_the_gdscript_odd_crews() -> void:
	await _scan_case(1, 2)
