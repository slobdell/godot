extends TestCase
## Round 33 (manoeuvre CP-F (r)): the face clip's `--faced-off-deg` changes only the run that names it.


func test_the_faced_drag_draws_60_degrees_off_the_travel_unless_told() -> void:
	assert_eq(ScreenPlaytest.faced_off_deg(LaunchFlags.parse(PackedStringArray([]))), 60.0,
			"no flag: FACED_OFF_TRAVEL_DEG, so the hull-rest workload and every screen run are unchanged")
	assert_eq(ScreenPlaytest.faced_off_deg(LaunchFlags.parse(PackedStringArray(["--faced-off-deg=180"]))), 180.0,
			"the clip's face-behind")
	assert_eq(ScreenPlaytest.faced_off_deg(LaunchFlags.parse(PackedStringArray(["--faced-off-deg=behind"]))), 60.0,
			"a word is not an angle: the default")
