extends TestCase
## Round 14 (G4; round 13's tour at 20:9: "there's debug text over the HUD"): the camera readout is the lead's tool,
## off for a player, and when on it sits in the gap between the HUD's message columns, clear of the status block.


func test_the_camera_readout_is_off_unless_asked_for() -> void:
	assert_true(not CameraReadout.wanted(LaunchFlags.parse([])), "a player's launch: off")
	assert_true(not CameraReadout.wanted(LaunchFlags.parse(["--camera-readout=off"])), "off when told")
	assert_true(CameraReadout.wanted(LaunchFlags.parse(["--camera-readout=on"])), "the lead's flag: on")


func test_the_readout_sits_clear_of_the_status_block_and_the_columns_at_both_aspects() -> void:
	for screen: Vector2 in [Vector2(1920, 1080), Vector2(1800, 810), Vector2(2400, 1080)]:
		var s := CyberStyle.ui_scale(screen)
		var widest_at_1px := 60.0  # line one of the readout is ~110 characters
		var place := CameraReadout.placement(screen, widest_at_1px)
		var at: Vector2 = place["at"]
		var px := float(place["px"])
		var right := at.x + widest_at_1px * px
		var status_right := screen.x * HudSkin.BLOCK_FRACTION
		assert_true(at.x > status_right, "%s: starts at x %d, right of the status block (%d)" % [screen, at.x, status_right])
		var margin := 12.0 * s
		var column_width := clampf((screen.x - screen.y) / 2.0 - margin * 2.0, 220.0 * s, screen.x * 0.26)
		assert_true(at.x > margin + column_width, "%s: right of the info column" % screen)
		assert_true(right < screen.x - margin - column_width, "%s: ends at %d, left of the warning column" % [screen, right])
		assert_true(px >= 9.0, "%s: still readable (%d px)" % [screen, px])
