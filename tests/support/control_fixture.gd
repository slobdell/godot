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
var markers: EdgeMarkers
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
		var spot := game_match.tanks.get_node(unit_name) as Tank
		spot.global_position = SPOTS[unit_name]
		spot.reset_physics_interpolation()
	camera = Camera3D.new()
	test.add_to_tree(camera)
	camera.make_current()
	rig = RtsCamera.new()
	RtsCamera.fov = 55.0  # round 5's lens: these tests are about screen geometry, written for it (the default is the lead's 35° telephoto)
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 35)
	rig.zoom = 0.3
	# Round 6 X3: pitch is its own axis, and the lead's default (25°, FOV 60°) shows most of the arena at once. These
	# tests are about which points are on screen and when the camera tracks, written against round 5's tilt at this
	# zoom (42°), so they pin it instead of inheriting whatever the default look is.
	rig.pitch = 42.0
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
	controls.range_frame = 0.0  # round 7's range framing is tested on its own (test_control_facing_camera)
	test.add_to_tree(controls)
	markers = EdgeMarkers.new()
	markers.controls = controls
	controls.add_child(markers)
	controls.markers = markers
	await test.wait_physics_frames(3)


## Control X4: a big match instead of the fixed row - `per_side` units a side, laid out in a grid so they all
## start on screen, with control groups of five. Everything else (camera, orders, controls) is as in build().
func build_scale(per_side: int) -> void:
	var tree := test.tree
	tree.root.size = Vector2i(1920, 1080)
	arena = test.add_to_tree(ARENA.instantiate())
	game_match = MATCH.instantiate()
	test.add_to_tree(game_match)
	var types := ["tank", "ifv", "scout", "lancer", "burner"]
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var squads: Array = []
		var left := per_side
		var index := 0
		while left > 0:
			var size := mini(5, left)
			var units: Array = []
			for i in size:
				units.append({"unit": types[(index + i) % types.size()]})
			squads.append({"name": "S%d" % (squads.size() + 1), "units": units})
			left -= size
			index += size
		test.assert_eq(game_match.load_doctrine(team, {"name": "Scale", "squads": squads}), "",
				"setup: %s army of %d" % [Match.TEAM_NAMES[team], per_side])
	# Two blocks 60 m apart, 6 m spacing, so every unit is in sight of the camera and of the other side.
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var row := 0
		var column := 0
		for tank_node in game_match.sorted_team_tanks(team):
			tank_node.global_position = Vector3(-36.0 + column * 6.0, 0.0, (30.0 if team == Match.Team.GREEN else -30.0) + row * 6.0)
			tank_node.reset_physics_interpolation()
			column += 1
			if column >= 12:
				column = 0
				row += 1
	camera = Camera3D.new()
	test.add_to_tree(camera)
	camera.make_current()
	rig = RtsCamera.new()
	RtsCamera.fov = 55.0  # round 5's lens: these tests are about screen geometry, written for it (the default is the lead's 35° telephoto)
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3.ZERO
	rig.zoom = 0.75
	test.add_to_tree(rig)
	rig.snap()
	orders = Orders.new()
	Orders.attach(game_match, orders)
	controls = RtsControls.new()
	controls.game_match = game_match
	controls.orders = orders
	controls.camera = camera
	controls.rig = rig
	controls.reveal_all = true
	controls.elements = Elements.install(game_match, orders)
	test.add_to_tree(controls)
	markers = EdgeMarkers.new()
	markers.controls = controls
	controls.add_child(markers)
	controls.markers = markers
	var number := 1
	for squad in game_match.team_squads(Match.Team.GREEN):
		if number > ControlGroups.COUNT:
			break
		controls.groups.save(number, Array(squad.roster))
		controls.groups.label(number, String(squad.squad_name))
		number += 1
	await test.wait_physics_frames(3)


## Teleport a vehicle. Assigning `global_position` alone leaves physics interpolation drawing it at its old spot for a
## tick or two (project.godot: common/physics_interpolation), and anything that follows what the player *sees*
## (`Shown`: the camera, rings, bars, picking) then reads the old place. Game code resets on every teleport
## (`Tank._spawn`, respawn, shells); tests must too, or they race the interpolation.
func place(unit_name: String, at: Vector3) -> Tank:
	var t := tank(unit_name)
	t.global_position = at
	t.reset_physics_interpolation()
	return t


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
