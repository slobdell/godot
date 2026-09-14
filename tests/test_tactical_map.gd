extends TestCase
## The tactical map's input logic without a screen: synthetic keys, clicks, and
## right-drags go into TacticalMap exactly as Godot would deliver them, and we check
## the SquadCommands (and resulting squad state) they produce.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

var _commands: Array = []


func _setup() -> Array:
	# Headless Godot's root viewport is 64×64. Give it a real screen size, or pushed mouse
	# events land outside the map (this once masqueraded as "clicks don't work").
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine loads")
	var camera := FollowCamera.new()
	add_to_tree(camera)
	camera.make_current()
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	add_to_tree(map)
	_commands = []
	map.command_issued.connect(func(command: Dictionary, error: String) -> void: _commands.append([command, error]))
	await wait_physics_frames(2)
	return [game_match, map, camera]


func _key(map: TacticalMap, keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	map._unhandled_key_input(event)


func _mouse(map: TacticalMap, camera: Camera3D, button: MouseButton, pressed: bool, world: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = camera.unproject_position(world)
	map._gui_input(event)


func _motion(map: TacticalMap, camera: Camera3D, world: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = camera.unproject_position(world)
	map._gui_input(event)


func test_screen_and_world_agree() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var camera: Camera3D = setup[2]
	var spot := Vector3(-20, 0, 15)
	var back: Variant = map.screen_to_world(camera.unproject_position(spot))
	assert_true(back != null and (back as Vector3).distance_to(spot) < 0.5, "the top-down camera maps ground points both ways (%s)" % [back])


func test_keys_select_squads_and_change_formation() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	assert_eq(map.selected_squad, "Alpha", "the first squad starts selected")
	_key(map, KEY_2)
	assert_eq(map.selected_squad, "Bravo", "2 selects the second squad")
	_key(map, KEY_C)
	assert_eq(game_match.squads["0/Bravo"].formation, "vee", "C puts the selected squad in a vee")
	_key(map, KEY_B)
	_key(map, KEY_B)
	assert_eq(game_match.squads["0/Bravo"].formation, "echelon_left", "B twice flips echelon to the left")
	assert_eq(game_match.squads["0/Alpha"].formation, "wedge", "the other squad is untouched")


func test_right_drag_orders_destination_and_facing() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var camera: Camera3D = setup[2]
	_key(map, KEY_W)  # next drag: bound
	_mouse(map, camera, MOUSE_BUTTON_RIGHT, true, Vector3(-30, 0, 0))
	_motion(map, camera, Vector3(-30, 0, -10))
	_mouse(map, camera, MOUSE_BUTTON_RIGHT, false, Vector3(-30, 0, -10))
	assert_eq(_commands.size(), 1, "one drag, one command")
	var command: Dictionary = _commands[0][0]
	assert_eq(_commands[0][1], "", "the command is accepted")
	assert_eq(command["verb"], "bound", "the pending drill is used")
	assert_true(Vector2(command["to"][0] + 30.0, command["to"][1]).length() < 0.5, "the press point is the destination (%s)" % [command["to"]])
	assert_true(Vector2(command["facing"][0], command["facing"][1]).normalized().dot(Vector2(0, -1)) > 0.99,
			"the drag direction (north) is the facing (%s)" % [command["facing"]])
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "bound", "the squad is now bounding")


func test_clicking_a_squad_tank_twice_makes_it_commander() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var camera: Camera3D = setup[2]
	var wingman := game_match.tanks.get_node("Green_Bravo_2") as Tank
	_mouse(map, camera, MOUSE_BUTTON_LEFT, true, wingman.global_position)
	assert_eq(map.selected_squad, "Bravo", "clicking a tank selects its squad")
	assert_eq(game_match.squads["0/Bravo"].commander, "Green_Bravo_1", "a first click only selects")
	_mouse(map, camera, MOUSE_BUTTON_LEFT, true, wingman.global_position)
	assert_eq(game_match.squads["0/Bravo"].commander, "Green_Bravo_2", "clicking it again elects it commander")


func test_hold_key_halts_in_place() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var squad: Squad = game_match.squads["0/Alpha"]
	map.order_drag(Vector3(0, 0, 0), Vector3(0, 0, 0))
	assert_eq(squad.verb, "move", "setup: moving")
	var lead := game_match.tanks.get_node(NodePath(squad.commander)) as Tank
	_key(map, KEY_E)
	assert_eq(squad.verb, "hold", "E holds")
	assert_true((squad.destination as Vector3).distance_to(lead.global_position) < 0.5, "right where the commander is")


# ---- End to end through Godot's real input pipeline (Viewport.push_input) ----------
# The tests above call the handlers directly; these make the ENGINE deliver the events,
# so GUI hit-testing, mouse filters, focus, and pause handling are part of what's tested.

func _push_key(keycode: Key) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		tree.root.push_input(event)


func _push_mouse(camera: Camera3D, button: MouseButton, pressed: bool, world: Vector3) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = camera.unproject_position(world)
	event.global_position = event.position
	tree.root.push_input(event)


func _push_motion(camera: Camera3D, world: Vector3) -> void:
	var event := InputEventMouseMotion.new()
	event.position = camera.unproject_position(world)
	event.global_position = event.position
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT
	tree.root.push_input(event)


func test_real_input_pipeline_drives_commander_and_formation() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var camera: Camera3D = setup[2]
	await wait_physics_frames(2)
	_push_key(KEY_2)
	assert_eq(map.selected_squad, "Bravo", "a real key press reaches the map")
	_push_key(KEY_C)
	assert_eq(game_match.squads["0/Bravo"].formation, "vee", "a real formation key changes the formation")
	var wingman := game_match.tanks.get_node("Green_Bravo_2") as Tank
	_push_mouse(camera, MOUSE_BUTTON_LEFT, true, wingman.global_position)
	_push_mouse(camera, MOUSE_BUTTON_LEFT, false, wingman.global_position)
	_push_mouse(camera, MOUSE_BUTTON_LEFT, true, wingman.global_position)
	_push_mouse(camera, MOUSE_BUTTON_LEFT, false, wingman.global_position)
	assert_eq(game_match.squads["0/Bravo"].commander, "Green_Bravo_2", "real clicks elect the commander")
	_push_mouse(camera, MOUSE_BUTTON_RIGHT, true, Vector3(40, 0, 40))
	_push_motion(camera, Vector3(40, 0, 32))
	_push_motion(camera, Vector3(40, 0, 25))
	_push_mouse(camera, MOUSE_BUTTON_RIGHT, false, Vector3(40, 0, 25))
	var squad: Squad = game_match.squads["0/Bravo"]
	assert_eq(squad.verb, "move", "a real right-drag issues a move")
	assert_true(squad.destination != null and (squad.destination as Vector3).distance_to(Vector3(40, 0, 40)) < 1.0,
			"to the pressed point (%s)" % [squad.destination])
	assert_true(squad.facing_on_arrival.dot(Vector3(0, 0, -1)) > 0.99, "facing the drag direction")


func test_orders_work_while_paused() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var camera: Camera3D = setup[2]
	map.set_paused(true)
	_push_key(KEY_X)
	_push_mouse(camera, MOUSE_BUTTON_RIGHT, true, Vector3(-30, 0, 30))
	_push_mouse(camera, MOUSE_BUTTON_RIGHT, false, Vector3(-30, 0, 30))
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "orders are accepted during the tactical pause")
	var lead := game_match.tanks.get_node(NodePath(squad.commander)) as Tank
	var before := lead.global_position
	await tree.create_timer(0.5, true).timeout
	assert_true(lead.global_position.distance_to(before) < 0.01, "nothing moves while paused")
	_push_key(KEY_SPACE)
	assert_true(not tree.paused, "Space resumes")
	await wait_physics_frames(60)
	assert_true(lead.global_position.distance_to(before) > 1.0, "and the squad starts executing (moved %.1f m)" % lead.global_position.distance_to(before))


func test_left_drag_on_open_ground_orders_too() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var camera: Camera3D = setup[2]
	_push_mouse(camera, MOUSE_BUTTON_LEFT, true, Vector3(-60, 0, 20))
	_push_motion(camera, Vector3(-60, 0, 5))
	_push_mouse(camera, MOUSE_BUTTON_LEFT, false, Vector3(-60, 0, 5))
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "a left-drag on open ground is an order (trackpad-friendly)")
	assert_true((squad.destination as Vector3).distance_to(Vector3(-60, 0, 20)) < 1.0, "to the pressed point")
	_push_mouse(camera, MOUSE_BUTTON_LEFT, true, Vector3(60, 0, 20))
	_push_mouse(camera, MOUSE_BUTTON_LEFT, false, Vector3(60, 0, 20))
	assert_true((squad.destination as Vector3).distance_to(Vector3(-60, 0, 20)) < 1.0,
			"but a plain left click on empty ground is NOT an order (no accidental moves)")
