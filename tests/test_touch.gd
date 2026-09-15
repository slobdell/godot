extends TestCase
## G0 mobile first: every skirmish action works with taps, drags, holds, and on-screen buttons.
## Finger input arrives the way Godot delivers it: touch events plus mouse events emulated from them.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup(screen := Vector2i(1200, 540)) -> Array:
	tree.root.size = screen
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 70)
	rig.zoom = 0.62
	add_to_tree(rig)
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	map.rig = rig
	add_to_tree(map)
	await wait_physics_frames(2)
	return [game_match, map, rig]


func _finger(map: TacticalMap, pressed: bool, at: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	map._gui_input(event)


func _slide(map: TacticalMap, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.position = at
	map._gui_input(event)


func test_tap_ground_sends_the_selected_squad_there() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var spot := Vector3(-30, 0, 55)
	var at := rig.camera.unproject_position(spot)
	_finger(map, true, at)
	_finger(map, false, at)
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "one tap on open ground is a move order (the common order is one gesture)")
	assert_true((squad.destination as Vector3).distance_to(spot) < 1.0, "to the tapped spot (%s)" % [squad.destination])


func test_hold_then_drag_orders_with_a_facing() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var spot := Vector3(20, 0, 50)
	var at := rig.camera.unproject_position(spot)
	var focus_before := rig.focus
	_finger(map, true, at)
	map._update_touch(TacticalMap.LONG_PRESS_SECONDS + 0.05)
	assert_true(map._drag_start != null, "after a hold the ghost formation appears under the finger")
	var toward := rig.camera.unproject_position(spot + Vector3(15, 0, 0))
	_slide(map, toward)
	_finger(map, false, toward)
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "hold-and-drag orders")
	assert_true((squad.destination as Vector3).distance_to(spot) < 1.0, "to where the finger rested (%s)" % [squad.destination])
	assert_true(squad.facing_on_arrival.dot(Vector3.RIGHT) > 0.95, "facing along the drag (east): %s" % squad.facing_on_arrival)
	assert_true(rig.focus.distance_to(focus_before) < 0.01, "and the camera didn't move")


func test_tapping_a_tank_selects_and_a_second_tap_opens_its_card() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var wingman := game_match.tanks.get_node("Green_Bravo_2") as Tank
	# A fat-finger tap a little off the tank's center still counts.
	var at := rig.camera.unproject_position(wingman.global_position) + Vector2(14, 10)
	_finger(map, true, at)
	_finger(map, false, at)
	assert_eq(map.selected_squad, "Bravo", "a tap near a tank selects its squad")
	_finger(map, true, at)
	_finger(map, false, at)
	assert_eq(map.focused_unit, "Green_Bravo_2", "tapping it again opens its unit card")
	(map._buttons["unit:lead"] as Button).pressed.emit()
	assert_eq(game_match.squads["0/Bravo"].commander, "Green_Bravo_2", "and Lead squad makes it commander")
	assert_eq(game_match.squads["0/Bravo"].verb, "hold", "and neither tap ordered a move")


func test_every_command_has_a_thumb_sized_button() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var ids: Array = map._buttons.keys()
	for verb in Squad.VERBS:
		assert_true(ids.has("verb:" + verb), "a button for the %s drill" % verb)
	for formation in ["column", "wedge", "vee", "line", "echelon_right", "coil"]:
		assert_true(ids.has("formation:" + formation), "a button for the %s formation" % formation)
	for id in ["pause", "overview", "follow", "squad:Alpha", "squad:Bravo"]:
		assert_true(ids.has(id), "a button for %s" % id)
	await tree.process_frame
	for id in ids:
		var button := map._buttons[id] as Button
		assert_true(button.custom_minimum_size.y >= TacticalMap.BUTTON_MIN_PX, "%s is at least %d px tall on a phone screen" % [id, TacticalMap.BUTTON_MIN_PX])
	# Buttons do what the keys do.
	(map._buttons["squad:Bravo"] as Button).pressed.emit()
	assert_eq(map.selected_squad, "Bravo", "the Bravo chip selects Bravo")
	(map._buttons["formations"] as Button).pressed.emit()
	assert_true(map._formation_row.visible, "Formation opens the formation row")
	(map._buttons["formation:vee"] as Button).pressed.emit()
	assert_eq(game_match.squads["0/Bravo"].formation, "vee", "tapping Vee sets it")
	assert_true(not map._formation_row.visible, "and closes the row")
	(map._buttons["verb:break_contact"] as Button).pressed.emit()
	assert_eq(game_match.squads["0/Bravo"].verb, "break_contact", "Break contact button orders it")
	(map._buttons["pause"] as Button).pressed.emit()
	assert_true(tree.paused, "Pause pauses")
	(map._buttons["pause"] as Button).pressed.emit()
	assert_true(not tree.paused, "and resumes")
	(map._buttons["overview"] as Button).pressed.emit()
	assert_true(map.rig.is_overview(), "Overview button")
	(map._buttons["overview"] as Button).pressed.emit()
	(map._buttons["squad:Bravo"] as Button).pressed.emit()
	var center := Vector3.ZERO
	for p in map.squad_points("Bravo"):
		center += p / 2.0
	assert_true(map.rig.focus.distance_to(Vector3(center.x, 0, center.z)) < 2.0,
			"tapping the selected squad's chip centers the camera on it (%s)" % map.rig.focus)


func test_buttons_fit_a_phone_screen() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	await tree.process_frame
	await tree.process_frame
	var screen := Vector2(1200, 540)
	for row in [map._command_bar, map._top_row]:
		var rect: Rect2 = (row as Control).get_global_rect()
		assert_true(Rect2(Vector2.ZERO, screen).encloses(rect), "%s fits on a 1200x540 screen (%s)" % [row, rect])


func test_real_touch_events_reach_the_map_through_godot() -> void:
	# End to end: InputEventScreenTouch into Godot's Input, which emulates the mouse for the GUI.
	var setup: Array = await _setup(Vector2i(1280, 720))
	var game_match: Match = setup[0]
	var rig: RtsCamera = setup[2]
	var spot := Vector3(-40, 0, 60)
	var at := rig.camera.unproject_position(spot)
	for pressed in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		Input.flush_buffered_events()
		await tree.process_frame
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "a real screen tap arrives as an order (verb %s)" % squad.verb)


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)  # later test files expect a desktop-sized viewport
	super.teardown()
