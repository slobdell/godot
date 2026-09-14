extends TestCase
## The touch-first lobby (game/network/ui/lobby_panel.gd): typing a code on the keypad, and every
## tap target big enough and on screen at desktop and phone sizes (mobile-first constraint).


func _panel(size: Vector2i) -> LobbyPanel:
	tree.root.size = size  # headless root is 64×64 otherwise (trip-up #31)
	var holder := Control.new()
	holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_to_tree(holder)
	var panel := LobbyPanel.new()
	holder.add_child(panel)
	return panel


func test_typing_a_code_on_the_keypad_joins_that_room() -> void:
	var panel := _panel(Vector2i(1280, 720))
	await tree.process_frame
	var joined: Array[String] = []
	panel.join_requested.connect(func(code: String) -> void: joined.append(code))
	for character in "K7QX2Z":
		panel.key_buttons[LobbyPanel.ALPHABET.find(character)].pressed.emit()
	assert_eq(panel.code, "K7QX2", "a sixth character is ignored (codes are 5 long)")
	panel.delete_button.pressed.emit()
	assert_true(panel.join_button.disabled, "JOIN is disabled until the code is complete")
	panel.key_buttons[LobbyPanel.ALPHABET.find("2")].pressed.emit()
	panel.join_button.pressed.emit()
	assert_eq(joined, ["K7QX2"] as Array[String], "JOIN asks for the typed room")


func test_host_button_asks_to_host() -> void:
	var panel := _panel(Vector2i(1280, 720))
	await tree.process_frame
	var asked := [false]
	panel.host_requested.connect(func() -> void: asked[0] = true)
	panel.host_button.pressed.emit()
	assert_true(asked[0], "HOST A MATCH asks to host")


func test_every_target_is_big_enough_and_on_screen_at_desktop_and_phone_sizes() -> void:
	for size in [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1080, 2340), Vector2i(2340, 1080), Vector2i(720, 1280)]:
		var panel := _panel(size)
		for i in 3:
			await tree.process_frame  # containers settle over a couple of frames
		var screen := Rect2(Vector2.ZERO, Vector2(size))
		for button in panel.key_buttons + [panel.host_button, panel.join_button, panel.delete_button]:
			var rect: Rect2 = button.get_global_rect()
			assert_true(rect.size.x >= LobbyPanel.MIN_TARGET_PX and rect.size.y >= LobbyPanel.MIN_TARGET_PX,
					"%s is at least 48 px at %s (got %s)" % [button.text, size, rect.size])
			assert_true(screen.encloses(rect), "%s is fully on screen at %s (%s)" % [button.text, size, rect])
		panel.get_parent().queue_free()
		await tree.process_frame
