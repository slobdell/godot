extends TestCase
## Render (round 5, the lead's sign-off): a locked 30 fps at 1080p with 30 a side by default, and a 720p 60 fps
## performance option a player can pick.


func test_the_default_desktop_target_is_a_locked_30_at_native_1080p() -> void:
	var settings: Dictionary = FrameTarget.SETTINGS[FrameTarget.Target.LOCKED_30]
	assert_eq(settings["fps"], 30, "locked 30")
	assert_near(FrameTarget.render_scale_for(FrameTarget.Target.LOCKED_30, 1.0, 1080), 1.0, 0.001, "1080p renders native")
	assert_eq(FrameTarget.platform_default(), FrameTarget.Target.LOCKED_30, "desktop starts on the lead's default")


func test_the_performance_option_is_60_fps_at_720p_class_3d() -> void:
	assert_eq(FrameTarget.SETTINGS[FrameTarget.Target.PERFORMANCE_60]["fps"], 60, "60 fps")
	assert_near(FrameTarget.render_scale_for(FrameTarget.Target.PERFORMANCE_60, 1.0, 1080), 720.0 / 1080.0, 0.01, "~720 lines of 3D at 1080p")
	assert_near(FrameTarget.render_scale_for(FrameTarget.Target.PERFORMANCE_60, 1.0, 720), 1.0, 0.001, "a 720p window renders native")
	assert_near(FrameTarget.render_scale_for(FrameTarget.Target.PERFORMANCE_60, 0.75, 720), 0.75, 0.001, "a tier's own lower scale still wins")


func test_targets_parse_from_flags_and_saves() -> void:
	assert_eq(FrameTarget.parse("30"), FrameTarget.Target.LOCKED_30, "30")
	assert_eq(FrameTarget.parse("60"), FrameTarget.Target.PERFORMANCE_60, "60")
	assert_eq(FrameTarget.parse("performance"), FrameTarget.Target.PERFORMANCE_60, "by name too")
	assert_eq(FrameTarget.parse("144"), -1, "nothing else")
