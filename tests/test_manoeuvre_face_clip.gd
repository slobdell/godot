extends TestCase
## Round 33 (manoeuvre CP-F (r)): the face clip's `--faced-off-deg` changes only the run that names it.


func test_the_faced_drag_draws_60_degrees_off_the_travel_unless_told() -> void:
	assert_eq(ScreenPlaytest.faced_off_deg(LaunchFlags.parse(PackedStringArray([]))), 60.0,
			"no flag: FACED_OFF_TRAVEL_DEG, so the hull-rest workload and every screen run are unchanged")
	assert_eq(ScreenPlaytest.faced_off_deg(LaunchFlags.parse(PackedStringArray(["--faced-off-deg=180"]))), 180.0,
			"the clip's face-behind")
	assert_eq(ScreenPlaytest.faced_off_deg(LaunchFlags.parse(PackedStringArray(["--faced-off-deg=behind"]))), 60.0,
			"a word is not an angle: the default")


func test_the_faced_drag_selects_squads_1_and_2_unless_told() -> void:
	assert_eq(ScreenPlaytest.faced_squads(LaunchFlags.parse(PackedStringArray([]))), [1, 2] as Array[int],
			"no flag: squads 1 and 2, as every screen run")
	assert_eq(ScreenPlaytest.faced_squads(LaunchFlags.parse(PackedStringArray(["--faced-squads=1"]))), [1] as Array[int],
			"the War Rig clip's squad 1 alone")
	assert_eq(ScreenPlaytest.faced_squads(LaunchFlags.parse(PackedStringArray(["--faced-squads=x"]))), [1, 2] as Array[int],
			"no number: the default")
