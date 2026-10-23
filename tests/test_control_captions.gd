extends TestCase
## Control X2 (round 5): the booth's subtitles get their own caption line, so gameplay messages (kills, losses, orders,
## the control point) keep the message log. Round 38 (feedback F5, his note: "the announcer text messages (we don't need
## those)"): the lines no longer show at all; they still stay out of the log, and the caption widget itself still works.

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
	assert_true(not hud.caption_line.visible, "round 38: and nothing is written on screen")
	var messages := hud.get_node("CyberMessages") as CyberMessages
	assert_true(not messages.status.displayed_text().contains("textbook") and not messages.status.current_text().contains("Road Gangs"),
			"and the info banner never shows a booth line")


func test_a_caption_holds_long_enough_to_read_then_goes() -> void:
	var hud := await _hud(Vector2i(1920, 1080))
	var caption := hud.caption_line
	caption.set_process(false)
	caption.show_line("CALLER", "Short.")  # the widget (no longer fed by the Hud since round 38)
	caption.advance(CaptionLine.HOLD_MIN - 0.5)
	assert_true(caption.visible, "a short line stays up for the floor")
	caption.advance(1.0)
	assert_true(not caption.visible, "then goes")
	caption.show_line("PA", "x".repeat(80))
	caption.advance(CaptionLine.HOLD_MIN + 1.0)
	assert_true(caption.visible, "a long line stays up longer")


func test_no_booth_line_is_written_on_screen_at_either_size() -> void:
	for screen: Vector2i in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var hud := await _hud(screen)
		hud.post_caption("CALLER", "The Syndicate limousines sweep wide on the left and nobody on the Law side has seen them yet")
		await tree.process_frame
		assert_true(not hud.caption_line.visible, "%s: the top of the screen stays the far field" % screen)
		hud.queue_free()
		await tree.process_frame
