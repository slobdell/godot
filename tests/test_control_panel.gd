extends TestCase
## Control X6: the bottom selection panel. Portraits with hull and shield for a group, a detail card for one unit or an
## inspected enemy, the selection's orders in words, and a command card (Move, Stop, Hold, Attack-move, Follow,
## Formation) with hotkeys that does what the keys do.

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
	assert_eq(commands.map(func(c: Dictionary) -> String: return c["id"]), ["move", "stop", "hold", "attack_move", "follow", "formation"],
			"the command card has Move, Stop, Hold, Attack-move, Follow, Formation")
	assert_eq(commands.map(func(c: Dictionary) -> String: return c["hotkey"]), ["M", "S", "H", "A", "F", "G"], "each shows its hotkey")
	panel.press_command("attack_move")
	assert_eq(f.controls.mode, "attack_move", "Attack-move arms attack-move")
	panel.press_command("hold")
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "hold", "Hold holds")
	panel.press_command("formation")
	assert_eq(f.controls.formation, RtsControls.FORMATION_CYCLE[1], "Formation cycles the formation")
	assert_true(String(panel.summary()["commands"][5]["label"]).to_lower().contains(RtsControls.FORMATION_CYCLE[1]),
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
