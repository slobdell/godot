extends RefCounted
## Shared setup for the control stream's input tests (test_control_*.gd): an arena, a match with our units in a row
## across the screen and one enemy in sight, a camera, Orders + the executor, and RtsControls. Events go through
## Godot's real input pipeline (Viewport.push_input) at a 1280x720 root viewport (trip-up 31: headless is 64x64).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## Where the units stand: our row at z = 40, the enemy 20 m north of the middle.
const SPOTS := {"Green_Alpha_1": Vector3(-20, 0, 40), "Green_Alpha_2": Vector3(-10, 0, 40), "Green_Alpha_3": Vector3(0, 0, 40),
		"Green_Bravo_1": Vector3(10, 0, 40), "Green_Bravo_2": Vector3(20, 0, 40), "Rust_Alpha_1": Vector3(0, 0, 20)}

var test: TestCase
var game_match: Match
var orders: Orders
var executor: OrderExecutor
var controls: RtsControls
var camera: Camera3D
var rig: RtsCamera
var arena: Node


func _init(p_test: TestCase) -> void:
	test = p_test


## Build everything; `executor` = false leaves units to their brains (pure input tests).
func build(with_executor := true) -> void:
	var tree := test.tree
	tree.root.size = Vector2i(1280, 720)
	arena = test.add_to_tree(ARENA.instantiate())
	game_match = MATCH.instantiate()
	test.add_to_tree(game_match)
	var doctrine := {"name": "Test", "squads": [
			{"name": "Alpha", "units": [{"unit": "tank"}, {"unit": "tank"}, {"unit": "ifv"}]},
			{"name": "Bravo", "units": [{"unit": "ifv"}, {"unit": "scout"}]}]}
	test.assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: green doctrine")
	var rust := {"name": "Test", "squads": [{"name": "Alpha", "units": [{"unit": "tank"}]}]}
	test.assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: rust doctrine")
	for unit_name in SPOTS:
		(game_match.tanks.get_node(unit_name) as Tank).global_position = SPOTS[unit_name]
	camera = Camera3D.new()
	test.add_to_tree(camera)
	camera.make_current()
	rig = RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 35)
	rig.zoom = 0.3
	test.add_to_tree(rig)
	rig.snap()
	orders = Orders.new()
	Orders.attach(game_match, orders)
	if with_executor:
		executor = OrderExecutor.new()
		executor.game_match = game_match
		executor.orders = orders
		test.add_to_tree(executor)
	controls = RtsControls.new()
	controls.game_match = game_match
	controls.orders = orders
	controls.camera = camera
	controls.rig = rig
	controls.reveal_all = true  # no visibility field here: every enemy counts as seen
	test.add_to_tree(controls)
	await test.wait_physics_frames(3)


func tank(unit_name: String) -> Tank:
	return game_match.tanks.get_node(unit_name) as Tank


func screen(unit_name: String) -> Vector2:
	return camera.unproject_position(tank(unit_name).global_position)


func ground(world: Vector3) -> Vector2:
	return camera.unproject_position(world)


func button(at: Vector2, pressed: bool, index := MOUSE_BUTTON_LEFT, shift := false, ctrl := false, double := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = index
	event.pressed = pressed
	event.position = at
	event.global_position = at
	event.shift_pressed = shift
	event.ctrl_pressed = ctrl
	event.double_click = double
	test.tree.root.push_input(event)


func motion(at: Vector2, shift := false, mask := MOUSE_BUTTON_MASK_LEFT) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = mask
	event.shift_pressed = shift
	test.tree.root.push_input(event)


func click(at: Vector2, shift := false, ctrl := false, double := false) -> void:
	button(at, true, MOUSE_BUTTON_LEFT, shift, ctrl, double)
	button(at, false, MOUSE_BUTTON_LEFT, shift, ctrl)
	await test.tree.process_frame


func right_click(at: Vector2, shift := false) -> void:
	button(at, true, MOUSE_BUTTON_RIGHT, shift)
	button(at, false, MOUSE_BUTTON_RIGHT, shift)
	await test.tree.process_frame


func drag(from: Vector2, to: Vector2, shift := false) -> void:
	button(from, true, MOUSE_BUTTON_LEFT, shift)
	for i in range(1, 6):
		motion(from.lerp(to, i / 5.0), shift)
	button(to, false, MOUSE_BUTTON_LEFT, shift)
	await test.tree.process_frame


func key(keycode: Key, shift := false, ctrl := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		event.shift_pressed = shift
		event.ctrl_pressed = ctrl
		test.tree.root.push_input(event)
	await test.tree.process_frame


## Select exactly these units: click the first, shift-click the rest.
func select(names: Array) -> void:
	await click(screen(names[0]))
	for i in range(1, names.size()):
		await click(screen(names[i]), true)
