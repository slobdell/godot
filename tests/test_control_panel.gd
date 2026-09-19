extends TestCase
## Control X6: the bottom selection panel. Portraits with hull and shield for a group, a detail card for one unit or an
## inspected enemy, the selection's orders in words, and a command card (Stop, Hold, Attack-move, the element tasks,
## Formation) with hotkeys that does what the keys do. Move and Follow are the mouse's (round 6 X1): no buttons.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _setup() -> Array:
	var f := Fixture.new(self)
	await f.build(false)
	var panel := SelectionPanel.new()
	panel.controls = f.controls
	f.controls.add_child(panel)
	await tree.process_frame
	return [f, panel]


func test_a_group_shows_one_portrait_per_unit_heavies_first() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	f.tank("Green_Alpha_1").health = f.tank("Green_Alpha_1").max_health / 4
	f.tank("Green_Bravo_2").shield = 0.0
	f.tank("Green_Bravo_2").ticks_since_hit = 0  # just hit: no recharge yet
	await f.select(["Green_Bravo_2", "Green_Alpha_1", "Green_Alpha_3"])
	var shown := panel.summary()
	assert_eq(shown["mode"], "group", "three units show as a group")
	var portraits: Array = shown["portraits"]
	assert_eq(portraits.map(func(p: Dictionary) -> String: return p["role"]), ["tank", "ifv", "scout"], "one portrait each, heavies first")
	assert_near(portraits[0]["health"], 0.25, 0.02, "the hurt tank's hull bar is a quarter full")
	assert_near(portraits[2]["shield"], 0.0, 0.01, "the scout's shield bar is empty")
	assert_true(panel.visible, "the panel shows while something is selected")
	await f.key(KEY_ESCAPE)
	await tree.process_frame
	assert_eq(panel.summary()["mode"], "none", "nothing selected, nothing shown")


func test_one_unit_gets_a_detail_card_with_its_orders() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	await f.select(["Green_Alpha_1"])
	var card: Dictionary = panel.summary()["card"]
	assert_eq(panel.summary()["mode"], "unit", "one unit shows a card")
	assert_eq(card["name"], "Tank", "the card names the unit type")
	assert_true(String(card["hull"]).contains(str(f.tank("Green_Alpha_1").max_health)), "the card shows hull numbers (%s)" % card["hull"])
	assert_eq(card["orders"], "Idle", "no orders yet")
	await f.right_click(f.ground(Vector3(-15, 0, 15)), false)
	await f.right_click(f.ground(Vector3(-25, 0, 5)), true)
	assert_eq(panel.summary()["card"]["orders"], "Moving (+1 queued)", "the card shows the order and the queue")


func test_an_inspected_enemy_shows_its_card_without_commands() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	await f.click(f.screen("Rust_Alpha_1"))
	var shown := panel.summary()
	assert_eq(shown["mode"], "enemy", "an inspected enemy shows its card")
	assert_eq(shown["card"]["name"], "Tank", "with its type")
	assert_true(shown["commands"].all(func(c: Dictionary) -> bool: return not c["enabled"]), "and no usable commands")


func test_command_card_buttons_do_what_the_keys_do() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	var commands: Array = panel.summary()["commands"]
	var ids: Array = commands.map(func(c: Dictionary) -> String: return c["id"])
	# Round 6 X1 (the lead): "buttons like move and follow are already accessible via mouse click, so we shouldn't
	# have buttons for them." The card holds only what the mouse cannot express.
	assert_true(not (ids.has("move")), "no Move button: right-click moves")
	assert_true(not (ids.has("follow")), "no Follow button: right-clicking a friend follows it")
	for id in ["stop", "hold", "attack_move", "formation"]:
		assert_true(ids.has(id), "the card has %s" % id)
	assert_eq(ids, TaskPalette.card().map(func(row: Dictionary) -> String: return row["id"]), "and exactly the palette's card")
	for command: Dictionary in commands:
		assert_true(String(command["hotkey"]).length() == 1, "%s shows its hotkey" % command["id"])
	# The keys stay: M and F still arm their orders, they just don't take room on the card.
	await f.key(KEY_M)
	assert_eq(f.controls.mode, "move", "M still arms a move")
	await f.key(KEY_ESCAPE)
	await f.key(KEY_F)
	assert_eq(f.controls.mode, "follow", "F still arms a follow")
	await f.key(KEY_ESCAPE)
	# X3: screen and support by fire need a leader to carry them out, so a handful of units cannot ask for them.
	for command: Dictionary in commands:
		var expected := not SelectionPanel.ELEMENT_ONLY.has(command["id"])
		assert_eq(command["enabled"], expected, "%s enabled without an element" % command["id"])
	panel.press_command("screen")
	assert_eq(f.controls.mode, "", "and pressing one does nothing")
	panel.press_command("attack_move")
	assert_eq(f.controls.mode, "attack_move", "Attack-move arms attack-move")
	panel.press_command("hold")
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "hold", "Hold holds")
	panel.press_command("formation")
	assert_eq(f.controls.formation, RtsControls.FORMATION_CYCLE[1], "Formation cycles the formation")
	var formation_button: Dictionary = panel.summary()["commands"].filter(
			func(c: Dictionary) -> bool: return String(c["id"]) == "formation")[0]
	assert_true(String(formation_button["label"]).to_lower().contains(RtsControls.FORMATION_CYCLE[1]),
			"the Formation button names the current formation")


func test_clicking_the_card_and_portraits_goes_through_real_mouse_events() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	await f.select(["Green_Alpha_1", "Green_Alpha_3", "Green_Bravo_2"])
	await tree.process_frame
	var stop := panel.command_rect("stop")
	assert_true(stop.size.x > 20.0, "the Stop button has a real size on screen (%s)" % stop)
	await f.click(panel.get_global_rect().position + stop.get_center())
	assert_eq(f.orders.current("Green_Bravo_2").get("verb", ""), "stop", "clicking Stop stops the selection")
	assert_eq(f.controls.selection.units.size(), 3, "and the click didn't reach the map behind the panel")
	var scout := panel.portrait_rect("Green_Bravo_2")
	await f.click(panel.get_global_rect().position + scout.get_center(), true)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Alpha_3"], "shift-clicking a portrait drops that unit")
	var tank := panel.portrait_rect("Green_Alpha_1")
	await tree.process_frame
	await f.click(panel.get_global_rect().position + panel.portrait_rect("Green_Alpha_1").get_center())
	assert_true(tank.size.x > 0.0, "the tank portrait is on screen")
	assert_eq(f.controls.selection.units, ["Green_Alpha_1"], "clicking a portrait selects just that unit")


func test_the_panel_stays_clear_of_the_radar_at_desktop_and_small_windows() -> void:
	for window in [Vector2i(1920, 1080), Vector2i(1280, 720)]:
		var setup: Array = await _setup()
		var f: Fixture = setup[0]
		var panel: SelectionPanel = setup[1]
		tree.root.size = window
		var radar := Radar.new()
		radar.game_match = f.game_match
		radar.controls = f.controls
		f.controls.add_child(radar)
		await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3", "Green_Bravo_1", "Green_Bravo_2"])
		await tree.process_frame
		await tree.process_frame
		assert_true(not panel.get_global_rect().intersects(radar.get_global_rect()), "at %s the panel (%s) doesn't cover the radar (%s)" %
				[window, panel.get_global_rect(), radar.get_global_rect()])
		assert_true(Rect2(Vector2.ZERO, Vector2(window)).encloses(panel.get_global_rect()), "at %s the panel is fully on screen" % window)
		teardown()
	tree.root.size = Vector2i(1280, 720)


## Round 6 X2 (N4): every button reads by its tactical task graphic and its doctrinal name, and says in one sentence
## what the units will do. The lead found support-by-fire labelled "Base of fire" and could not name "Screen".
func test_every_button_has_a_symbol_a_doctrinal_name_and_one_sentence() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await tree.process_frame
	var commands: Array = panel.summary()["commands"]
	var labels: Array = commands.map(func(c: Dictionary) -> String: return c["label"])
	assert_eq(TaskPalette.row("support_by_fire")["name"], "Support by Fire", "support by fire goes by its doctrinal name")
	assert_true(not (labels.has("Base of fire")), "not the name the lead couldn't find")
	for command: Dictionary in commands:
		var id := String(command["id"])
		if id != "formation":
			assert_true(CommandIcons.has_task_graphic(id), "%s has a task graphic" % id)
			assert_eq(CommandIcons.task_texture(id).get_width(), CommandIcons.TASK_TEXTURE_PX, "%s's graphic is drawn" % id)
		assert_true(String(command["line"]).ends_with("."), "%s says in one sentence what happens (%s)" % [id, command["line"]])
	# Hovering a button shows its name and sentence.
	var hold := panel.get_global_rect().position + panel.command_rect("hold").get_center()
	f.motion(hold, false, 0)
	await tree.process_frame
	var tip := panel.tooltip()
	assert_eq(tip.get("id", ""), "hold", "hovering Hold shows its tooltip")
	assert_true(String(tip.get("title", "")).contains("[H]"), "with its key (%s)" % tip.get("title", ""))
	assert_eq(String(tip.get("line", "")), String(TaskPalette.row("hold")["line"]), "and says what holding does")


## N4: a task gets a button only once squad has shown its behaviour, and the table in tactical_map.md is the same
## table as the code.
func test_the_palette_shows_only_earned_tasks_and_the_doc_lists_every_row() -> void:
	var card_ids: Array = TaskPalette.card().map(func(row: Dictionary) -> String: return row["id"])
	for row: Dictionary in TaskPalette.ROWS:
		assert_eq(card_ids.has(row["id"]), bool(row["earned"]), "%s is on the card only if earned" % row["id"])
		if String(row["id"]) != "formation":
			assert_true(CommandIcons.has_task_graphic(String(row["id"])), "%s's symbol is ready" % row["id"])
	for verb in TaskPalette.MOUSE_VERBS:
		assert_true(not (card_ids.has(verb)), "%s is the mouse's, not a button" % verb)
	var doc := FileAccess.get_file_as_string("res://_agents/tactical_map.md")
	assert_true(doc.contains("## Task palette (N4)"), "tactical_map.md has the palette table")
	for row: Dictionary in TaskPalette.ROWS:
		assert_true(doc.contains("| `%s` |" % row["id"]), "the doc's table has a row for %s" % row["id"])


## Round 7 (C3), the lead: "some of them seem to be actions that require a follow on click, and other seem to be buttons
## that are applied passively (if I click the attack button will they do something or do I need to direct them?)".
## Every row says which, the card draws the two differently, and the tooltip says it in words.
func test_buttons_that_need_a_click_say_so() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var panel: SelectionPanel = setup[1]
	for row: Dictionary in TaskPalette.ROWS:
		assert_true(row.has("then"), "%s says whether it needs a click" % row["id"])
	assert_eq(TaskPalette.row("attack_move")["then"], "click", "Attack-move waits for a click")
	assert_eq(TaskPalette.row("stop")["then"], "now", "Stop happens at once")
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	await tree.process_frame
	var commands: Array = panel.summary()["commands"]
	for command: Dictionary in commands:
		assert_eq(command["then"], TaskPalette.row(command["id"])["then"], "%s's button carries it" % command["id"])
	f.motion(panel.get_global_rect().position + panel.command_rect("attack_move").get_center(), false, 0)
	await tree.process_frame
	assert_true(String(panel.tooltip().get("title", "")).contains("then click"), "the tooltip says a click follows (%s)" % panel.tooltip().get("title", ""))
	f.motion(panel.get_global_rect().position + panel.command_rect("stop").get_center(), false, 0)
	await tree.process_frame
	assert_true(String(panel.tooltip().get("title", "")).contains("at once"), "and when it does not (%s)" % panel.tooltip().get("title", ""))
