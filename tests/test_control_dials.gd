extends TestCase
## Control X3 (round 5): the lead's three dials from round 4, each a flag with a default. How close the default frame
## sits (--camera-frame), how many alert lines show (--alert-lines), and whether the faction menu opens by default.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _flags(values: Dictionary) -> LaunchFlags:
	var flags := LaunchFlags.new()
	flags.values = values
	return flags


func test_the_frame_distance_is_a_flag_with_three_settings() -> void:
	assert_eq(SkirmishMode.camera_frame_inset(_flags({})), RtsCamera.VISION_FRAME_INSET, "the default is round 4's frame")
	var close := SkirmishMode.camera_frame_inset(_flags({"camera-frame": "close"}))
	var wide := SkirmishMode.camera_frame_inset(_flags({"camera-frame": "wide"}))
	assert_true(close > RtsCamera.VISION_FRAME_INSET and wide < RtsCamera.VISION_FRAME_INSET, "close fills more of the screen, wide less")
	assert_eq(SkirmishMode.camera_frame_inset(_flags({"camera-frame": "nonsense"})), RtsCamera.VISION_FRAME_INSET, "an unknown value keeps the default")
	var points := [Vector3(-20, 0, 0), Vector3(20, 0, 0), Vector3(0, 0, 15)]
	var near: float = RtsCamera.frame_pose(points, 0.0, 16.0 / 9.0, 0.0, close)[1]
	var far: float = RtsCamera.frame_pose(points, 0.0, 16.0 / 9.0, 0.0, wide)[1]
	assert_true(near < far, "the same element frames closer with close than with wide (%.2f vs %.2f)" % [near, far])


func test_the_rig_frames_with_its_inset() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.rig.vision = f.controls.vision_state
	f.controls.recall_group(1)
	for i in 40:
		await tree.process_frame
	var default_zoom := f.rig.zoom
	f.rig.vision_inset = 0.55
	f.controls.recall_group(2)
	f.controls.recall_group(1)
	for i in 40:
		await tree.process_frame
	assert_true(f.rig.zoom > default_zoom + 0.01, "a wider inset pulls the camera back (%.2f vs %.2f)" % [f.rig.zoom, default_zoom])


func test_alert_lines_show_the_newest_unseen_alerts_up_to_the_setting() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var awareness := f.controls.awareness
	awareness.alerts.clear()
	for i in 4:
		awareness.alerts.append({"text": "alert %d" % i, "seen": false, "kind": "contact", "element": 1, "position": Vector3.ZERO,
				"at": awareness.age_of({"at": 0.0})})
	f.markers.alert_lines = 1
	assert_eq(f.markers.prompts().map(func(a: Dictionary) -> String: return a["text"]), ["alert 3"], "one line: the newest")
	f.markers.alert_lines = 3
	assert_eq(f.markers.prompts().map(func(a: Dictionary) -> String: return a["text"]), ["alert 3", "alert 2", "alert 1"],
			"three lines: the newest three, newest first")
	assert_eq(SkirmishMode.alert_lines(_flags({})), 1, "one line by default")
	assert_eq(SkirmishMode.alert_lines(_flags({"alert-lines": "3"})), 3, "--alert-lines=3")
	assert_eq(SkirmishMode.alert_lines(_flags({"alert-lines": "9"})), 3, "never more than three")


func test_the_faction_menu_opens_by_default_and_a_flag_turns_it_off() -> void:
	# Headless runs never open it (see test_control_faction_pick); here the question is only the default's intent.
	assert_true(not SkirmishMode.wants_faction_menu(_flags({"skirmish": "", "pick-faction": "", "no-pick-faction": ""})),
			"--no-pick-faction skips it")
	assert_true(SkirmishMode.wants_faction_menu(_flags({"skirmish": "", "pick-faction": ""})), "--pick-faction forces it")


## Round 5 (orchestrator's ruling): the CPU runs doctrine by default once ai has costed it; a flag keeps brains-only.
func test_which_commander_the_cpu_runs_is_a_flag() -> void:
	assert_eq(SkirmishMode.cpu_runs_elements(_flags({})), SkirmishMode.ELEMENT_CPU_DEFAULT, "the default")
	assert_true(SkirmishMode.cpu_runs_elements(_flags({"element-cpu": ""})), "--element-cpu turns it on")
	assert_true(not SkirmishMode.cpu_runs_elements(_flags({"element-cpu": "", "no-element-cpu": ""})), "--no-element-cpu wins")
	assert_true(not SkirmishMode.cpu_runs_elements(_flags({"element-cpu": "", "no-elements": ""})), "no elements, no element CPU")
