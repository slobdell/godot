extends TestCase
## C1 one-tap grammar, end to end through Godot's input pipeline: a finger and the left mouse button do
## the same thing (tap a squad, tap the ground or the radar), and nothing needs a right-click.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	tree.root.size = Vector2i(1280, 720)
	var arena := ARENA.instantiate()
	add_to_tree(arena)
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
	var radar := Radar.new()
	radar.game_match = game_match
	radar.map = map
	map.add_child(radar)
	radar.read_arena(arena)
	await wait_physics_frames(2)
	return [game_match, map, rig, radar]


func _finger(index: int, at: Vector2, pressed: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = index
	touch.position = at
	touch.pressed = pressed
	Input.parse_input_event(touch)
	Input.flush_buffered_events()
	await tree.process_frame


func _tap_finger(at: Vector2) -> void:
	await _finger(0, at, true)
	await _finger(0, at, false)


func _mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	tree.root.push_input(event)


func _mouse_motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	tree.root.push_input(event)


func test_tap_a_unit_then_the_ground_sends_that_squad() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var wingman := game_match.tanks.get_node("Green_Bravo_2") as Tank
	await _tap_finger(rig.camera.unproject_position(wingman.global_position))
	assert_eq(map.selected_squad, "Bravo", "a finger tap on a unit selects its squad")
	var spot := Vector3(35, 0, 50)
	await _tap_finger(rig.camera.unproject_position(spot))
	var bravo: Squad = game_match.squads["0/Bravo"]
	assert_eq(bravo.verb, "move", "the next tap on the ground orders that squad")
	assert_true((bravo.destination as Vector3).distance_to(spot) < 1.0, "to the tapped spot (%s)" % [bravo.destination])
	assert_eq(game_match.squads["0/Alpha"].verb, "hold", "the other squad stays put")


func test_the_mouse_uses_the_same_grammar_as_a_finger() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var wingman := game_match.tanks.get_node("Green_Bravo_2") as Tank
	var on_tank := rig.camera.unproject_position(wingman.global_position)
	_mouse(on_tank, true)
	_mouse(on_tank, false)
	assert_eq(map.selected_squad, "Bravo", "a left click on a unit selects its squad")
	# Drag = pan, not an order.
	var focus_before := rig.focus
	var ground := rig.camera.unproject_position(Vector3(-30, 0, 60))
	_mouse(ground, true)
	_mouse_motion(ground + Vector2(80, 0))
	_mouse_motion(ground + Vector2(200, 0))
	_mouse(ground + Vector2(200, 0), false)
	assert_eq(game_match.squads["0/Bravo"].verb, "hold", "a left drag orders nothing")
	assert_true(rig.focus.distance_to(focus_before) > 5.0, "it pans the camera, like a finger (%s -> %s)" % [focus_before, rig.focus])
	# Hold, then drag = go there and face the drag.
	var spot := Vector3(10, 0, 55)
	var at := rig.camera.unproject_position(spot)
	_mouse(at, true)
	map._update_touch(TacticalMap.LONG_PRESS_SECONDS + 0.05)
	var east := rig.camera.unproject_position(spot + Vector3(15, 0, 0))
	_mouse_motion(east)
	_mouse(east, false)
	var bravo: Squad = game_match.squads["0/Bravo"]
	assert_eq(bravo.verb, "move", "hold-and-drag with the mouse orders")
	assert_true((bravo.destination as Vector3).distance_to(spot) < 1.0, "to where the press rested (%s)" % [bravo.destination])
	assert_true(bravo.facing_on_arrival.dot(Vector3.RIGHT) > 0.95, "facing along the drag (%s)" % bravo.facing_on_arrival)


func test_a_real_tap_on_the_radar_sends_the_selected_squad() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var radar: Radar = setup[3]
	var goal := Vector3(-50, 0, 20)
	var at := radar.get_global_rect().position + radar.world_to_radar(goal)
	await _tap_finger(at)
	var alpha: Squad = game_match.squads["0/Alpha"]
	assert_eq(alpha.verb, "move", "a finger tap on the radar orders (verb %s)" % alpha.verb)
	assert_true((alpha.destination as Vector3).distance_to(goal) < 3.0, "to the tapped radar spot (%s)" % [alpha.destination])


func test_a_pinch_that_starts_on_the_ground_never_orders() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var rig: RtsCamera = setup[2]
	var a := rig.camera.unproject_position(Vector3(-20, 0, 60))
	var b := a + Vector2(200, 0)
	await _finger(0, a, true)
	await _finger(1, b, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = b + Vector2(120, 0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	await tree.process_frame
	await _finger(1, drag.position, false)
	await _finger(0, a, false)
	assert_eq(game_match.squads["0/Alpha"].verb, "hold", "lifting the first finger of a pinch is not a tap order")


func test_a_right_click_still_orders_as_a_desktop_shortcut() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var rig: RtsCamera = setup[2]
	var at := rig.camera.unproject_position(Vector3(25, 0, 45))
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = at
	press.global_position = at
	tree.root.push_input(press)
	var release := press.duplicate()
	release.pressed = false
	tree.root.push_input(release)
	assert_eq(game_match.squads["0/Alpha"].verb, "move", "a right click remains a desktop shortcut for an order")


func teardown() -> void:
	tree.root.size = Vector2i(1280, 720)
	super.teardown()
