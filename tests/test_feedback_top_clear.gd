extends TestCase
## Round 38 (feedback F5, his note 2026-10-22 evening): the top of the screen is the far field. The score bug moves to the lower
## left, the bottom refits around it, the announcer's captions and the camera readout go, the pause line leaves the top.

const SCREENS := {"his laptop": Vector2(1854, 1011), "desktop": Vector2(1920, 1080), "phone": Vector2(1800, 810),
		"portrait phone": Vector2(810, 1800)}


func teardown() -> void:
	CyberStyle.set_touch_boost(-1.0)
	super()


func _rects(screen: Vector2) -> Dictionary:
	return {"bug": HudLayout.bug_rect(screen), "panel": HudLayout.panel_rect(screen), "radar": HudLayout.radar_rect(screen)}


func test_the_bottom_hud_stays_out_of_the_top_third_and_off_each_other() -> void:
	for boost in [1.0, 1.5]:
		CyberStyle.set_touch_boost(boost)
		for name: String in SCREENS:
			var screen: Vector2 = SCREENS[name]
			var rects := _rects(screen)
			var whole := Rect2(Vector2.ZERO, screen)
			for key: String in rects:
				var r: Rect2 = rects[key]
				assert_true(r.position.y >= screen.y / 3.0, "%s x%.1f: the %s is below the top third (%s)" % [name, boost, key, r])
				assert_true(whole.encloses(r.grow(-0.5)), "%s x%.1f: the %s is on screen (%s)" % [name, boost, key, r])
			var footprint := Rect2(rects["bug"].position, Vector2(rects["bug"].size.x,
					screen.y - HudLayout.MARGIN - rects["bug"].position.y))
			assert_true(not footprint.intersects(rects["panel"]), "%s x%.1f: the bug and the command bar apart" % [name, boost])
			assert_true(not footprint.intersects(rects["radar"]), "%s x%.1f: the bug and the radar apart" % [name, boost])
			assert_true(not rects["panel"].intersects(rects["radar"]), "%s x%.1f: the command bar and the radar apart" % [name, boost])


func test_the_bug_keeps_most_of_its_size_on_his_laptop() -> void:
	var k := HudLayout.bug_scale(SCREENS["his laptop"])
	assert_true(k >= 0.75, "the bug shrinks only as much as the command bar needs (%.2f)" % k)
	assert_true(HudLayout.panel_rect(SCREENS["his laptop"]).size.x >= SelectionPanel.MAX_WIDTH * 0.9,
			"the command bar keeps its width")


func test_the_message_columns_and_the_pause_line_start_below_the_top_third() -> void:
	for name: String in SCREENS:
		var screen: Vector2 = SCREENS[name]
		for column: Rect2 in HudLayout.message_columns(screen, 300.0, 110.0):
			assert_true(column.position.y >= screen.y / 3.0, "%s: a message column starts below the top third" % name)
		var y := HudLayout.pause_line_y(screen, HudLayout.panel_rect(screen).position.y - 40.0, 3, 22.0)
		assert_true(y >= screen.y / 3.0 and y < HudLayout.panel_rect(screen).position.y, "%s: the pause line over the bottom HUD (%.0f)" % [name, y])


func test_the_camera_readout_is_a_debug_flag() -> void:
	assert_true(not CameraReadout.wanted(LaunchFlags.parse(PackedStringArray(["--camera-readout=on"]))),
			"make skirmish's `on` no longer shows it to him")
	assert_true(CameraReadout.wanted(LaunchFlags.parse(PackedStringArray(["--camera-readout=debug"]))), "debug shows it to us")


func test_the_announcer_speaks_but_writes_nothing_on_screen() -> void:
	var hud: Hud = add_to_tree(preload("res://game/ui/hud.tscn").instantiate())
	var heard: Array[String] = []
	hud.caption_posted.connect(func(speaker: String, text: String) -> void: heard.append(speaker + ": " + text))
	hud.post_message("CALLER: Artillery opens the night!", Hud.INFO)
	await tree.process_frame
	assert_eq(heard.size(), 1, "the line still goes out (transcripts, the voice)")
	assert_true(not hud.caption_line.visible, "but nothing is written on screen")
