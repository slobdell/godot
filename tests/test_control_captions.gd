extends TestCase
## Control X2 (round 5): the booth's subtitles get their own caption line, so gameplay messages (kills, losses, orders,
## the control point) keep the message log. Readable at 1920×1080 and 1280×720.

const HUD_SCENE := preload("res://game/ui/hud.tscn")


func _hud(screen: Vector2i) -> Hud:
	tree.root.size = screen
	var hud: Hud = add_to_tree(HUD_SCENE.instantiate())
	await tree.process_frame
	return hud


func test_booth_lines_go_to_the_caption_line_not_the_log() -> void:
	var hud := await _hud(Vector2i(1920, 1080))
	var logged: Array = []
	hud.message_posted.connect(func(text: String, _severity: int) -> void: logged.append(text))
	hud.post_message("CALLER: And the Road Gangs pour through the gap!", Hud.INFO)
	hud.post_caption("VETERAN", "That wedge is textbook.")
	hud.post_message("Hunters lost a Gun Truck, 4 left", Hud.WARNING)
	hud.post_message("Orders: Alpha move", Hud.INFO)
	assert_eq(logged, ["Hunters lost a Gun Truck, 4 left", "Orders: Alpha move"], "only gameplay messages reach the log")
	var caption := hud.caption_line
	assert_true(caption.visible, "the caption line is showing")
	assert_eq([caption.speaker, caption.text], ["VETERAN", "That wedge is textbook."], "the newest line replaces the last")
	var messages := hud.get_node("CyberMessages") as CyberMessages
	assert_true(not messages.status.displayed_text().contains("textbook") and not messages.status.current_text().contains("Road Gangs"),
			"and the info banner never shows a booth line")


func test_a_caption_holds_long_enough_to_read_then_goes() -> void:
	var hud := await _hud(Vector2i(1920, 1080))
	var caption := hud.caption_line
	caption.set_process(false)
	hud.post_caption("CALLER", "Short.")
	caption.advance(CaptionLine.HOLD_MIN - 0.5)
	assert_true(caption.visible, "a short line stays up for the floor")
	caption.advance(1.0)
	assert_true(not caption.visible, "then goes")
	hud.post_caption("PA", "x".repeat(80))
	caption.advance(CaptionLine.HOLD_MIN + 1.0)
	assert_true(caption.visible, "a long line stays up longer")


func test_the_caption_reads_at_both_screen_sizes_and_keeps_clear_of_the_log() -> void:
	for screen: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var hud := await _hud(screen)
		var fake_map := Control.new()
		fake_map.name = "TacticalMap"
		fake_map.set_script(load("res://tests/support/fake_tactical_view.gd"))
		hud.add_child(fake_map)
		await tree.process_frame
		await tree.process_frame
		hud.post_caption("CALLER", "The Syndicate limousines sweep wide on the left and nobody on the Law side has seen them yet")
		var caption := hud.caption_line
		var strip := caption.strip()
		assert_true(caption.font_size() >= CaptionLine.MIN_FONT, "%s: the text is at least %d px (%d)" % [screen, CaptionLine.MIN_FONT, caption.font_size()])
		assert_true(Rect2(Vector2.ZERO, Vector2(screen)).encloses(strip), "%s: the strip is on screen (%s)" % [screen, strip])
		assert_true(strip.end.y <= screen.y * 0.25, "%s: it sits in the top quarter, away from the command card" % screen)
		var messages := hud.get_node("CyberMessages") as CyberMessages
		for column: Rect2 in [messages.status.column, messages.warning.column]:
			assert_true(not column.has_area() or not column.intersects(strip), "%s: it doesn't cover a message column (%s vs %s)" % [screen, strip, column])
		hud.queue_free()
		await tree.process_frame
