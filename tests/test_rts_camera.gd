extends TestCase
## G4: the RTS camera (pose math, pan/zoom/rotate, touch gestures) and the tactical map in perspective.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _rig() -> RtsCamera:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 40)
	rig.zoom = 0.6
	add_to_tree(rig)
	return rig


func test_zoom_sets_the_distance_and_never_the_tilt() -> void:
	var near := RtsCamera.pose_for(Vector3.ZERO, 0.0, 0.0)
	var far := RtsCamera.pose_for(Vector3.ZERO, 0.0, 1.0)
	assert_near(near.origin.length(), RtsCamera.MIN_DISTANCE, 0.01, "zoomed in: close to the ground point")
	assert_near(far.origin.length(), RtsCamera.MAX_DISTANCE, 0.01, "zoomed out: far from it")
	# Round 6 X3: round 5 tilted from 25° to 82° as you zoomed out, so seeing your army cost you a top-down view.
	for pose: Transform3D in [near, far, RtsCamera.pose_for(Vector3.ZERO, 0.0, 0.5)]:
		assert_near(rad_to_deg(asin(pose.origin.y / pose.origin.length())), RtsCamera.DEFAULT_PITCH_DEG, 0.01,
				"every zoom looks down at the same default tilt")
	assert_true(RtsCamera.DEFAULT_PITCH_DEG <= 50.0, "and the default sees vehicles from the side, not from above")
	var steep := RtsCamera.pose_for(Vector3.ZERO, 0.0, 0.5, 70.0)
	assert_true(steep.origin.y > steep.origin.z * 2.5, "a pitch asked for is the pitch you get")
	assert_near(RtsCamera.level_for(RtsCamera.distance_for(0.37)), 0.37, 0.001, "level_for inverts distance_for")
	assert_true((-near.basis.z).dot((Vector3.ZERO - near.origin).normalized()) > 0.999, "it always looks at the focus")
	assert_true(near.origin.z > 0.0, "yaw 0: the camera sits south of the focus, so north is up the screen")
	var turned := RtsCamera.pose_for(Vector3.ZERO, PI / 2.0, 0.5)
	assert_true(turned.origin.x > 0.0 and absf(turned.origin.z) < 0.01, "yaw 90: the camera swings east of the focus")


func test_ground_points_map_both_ways_in_perspective() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	for spot in [Vector3(-20, 0, 30), Vector3(15, 0, 55), Vector3(0, 0, 40)]:
		var back: Variant = rig.ground_point(rig.camera.unproject_position(spot))
		assert_true(back != null and (back as Vector3).distance_to(spot) < 0.3, "the tilted camera maps %s back to itself (%s)" % [spot, back])


func test_dragging_the_ground_moves_the_view_with_the_finger() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	var center := Vector2(640, 360)
	var under: Vector3 = rig.ground_point(center)
	rig.pan_screen(center, center + Vector2(150, 0))
	var now_under: Vector3 = rig.ground_point(center + Vector2(150, 0))
	assert_true(now_under.distance_to(under) < 1.0, "the ground point stays under the finger (%s vs %s)" % [now_under, under])
	assert_true(rig.focus.x < 0.0, "dragging right shows ground further west")


func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	return event


func _drag(index: int, at: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	return event


func test_pinch_zooms_and_twist_rotates() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	rig.handle_touch(_touch(0, Vector2(540, 360), true))
	assert_true(rig.handle_touch(_touch(1, Vector2(740, 360), true)), "two fingers down: a camera gesture")
	var zoom_before := rig.zoom
	rig.handle_touch(_drag(1, Vector2(940, 360)))
	assert_true(rig.zoom < zoom_before - 0.1, "spreading the fingers zooms in (%.2f -> %.2f)" % [zoom_before, rig.zoom])
	var yaw_before := rig.yaw
	rig.handle_touch(_drag(1, Vector2(540 + 400.0 * cos(0.5), 360 + 400.0 * sin(0.5))))
	assert_near(angle_difference(yaw_before, rig.yaw), 0.5, 0.05, "twisting the fingers 0.5 rad clockwise turns the view with them")
	rig.handle_touch(_touch(1, Vector2(900, 500), false))
	assert_eq(rig.finger_count(), 1, "lifting a finger ends the gesture")


func test_wheel_zooms_toward_the_cursor() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = Vector2(1000, 360)
	var zoom_before := rig.zoom
	assert_true(rig.handle_mouse(wheel), "the wheel belongs to the camera")
	assert_true(rig.zoom < zoom_before, "wheel up zooms in")
	assert_true(rig.focus.x > 0.0, "toward the cursor (right of center)")


func _skirmish() -> Array:
	var setup_rig := _rig()
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	setup_rig.focus = Vector3(0, 0, 60)
	setup_rig.snap()
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = setup_rig.camera
	map.rig = setup_rig
	add_to_tree(map)
	await wait_physics_frames(2)
	return [game_match, map, setup_rig]


func test_the_map_orders_through_the_tilted_camera() -> void:
	var setup: Array = await _skirmish()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	assert_true(not rig.is_overview(), "skirmish starts in the tilted view, not the overview")
	var target := Vector3(-20, 0, 50)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	press.position = rig.camera.unproject_position(target)
	map._gui_input(press)
	var release := press.duplicate()
	release.pressed = false
	map._gui_input(release)
	var squad: Squad = game_match.squads["0/Alpha"]
	assert_eq(squad.verb, "move", "a right click on the ground orders a move")
	assert_true((squad.destination as Vector3).distance_to(target) < 0.5, "to the ground point under the cursor (%s)" % [squad.destination])


func test_f_follows_the_selected_squad_and_tab_toggles_overview() -> void:
	var setup: Array = await _skirmish()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_F
	map._unhandled_key_input(key)
	assert_eq(rig.tracking_mode(), RtsCamera.Track.FOLLOW, "F follows the selected squad")
	for member in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		(game_match.tanks.get_node(member) as Tank).global_position += Vector3(30, 0, -40)
	for i in 3:
		await tree.process_frame
	var center := Vector3.ZERO
	for p in map.squad_points("Alpha"):
		center += p / 3.0
	assert_true(rig.focus.distance_to(Vector3(center.x, 0, center.z)) < 8.0, "and the focus rides along (%s vs %s)" % [rig.focus, center])
	key.keycode = KEY_TAB
	map._unhandled_key_input(key)
	assert_true(rig.is_overview() and rig.zoom > 0.9, "Tab jumps to the overview")
	map._unhandled_key_input(key)
	assert_true(not rig.is_overview(), "and Tab again returns")
	key.keycode = KEY_F
	map._unhandled_key_input(key)
	map._unhandled_key_input(key)
	assert_eq(rig.tracking_mode(), RtsCamera.Track.NONE, "F is a toggle")


func test_a_one_finger_drag_on_open_ground_pans_instead_of_ordering() -> void:
	var setup: Array = await _skirmish()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var focus_before := rig.focus
	var press := InputEventMouseButton.new()
	press.device = InputEvent.DEVICE_ID_EMULATION  # what Godot sends for a finger
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = rig.camera.unproject_position(Vector3(40, 0, 70))
	map._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.device = InputEvent.DEVICE_ID_EMULATION
	motion.position = press.position + Vector2(-200, 0)
	map._gui_input(motion)
	var release := press.duplicate()
	release.pressed = false
	release.position = motion.position
	map._gui_input(release)
	assert_eq(game_match.squads["0/Alpha"].verb, "hold", "no order from a finger drag on open ground")
	assert_true(rig.focus.x > focus_before.x + 5.0, "it panned the view (%s -> %s)" % [focus_before, rig.focus])


## Round 6 X3: tilt is its own axis. Zooming leaves it alone; Page Up/Down and ctrl+wheel move it within the player's
## range; the overview is the one deliberate top-down view, and gives the tilt back when it closes.
func test_tilt_is_its_own_axis() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	assert_eq(rig.pitch, RtsCamera.DEFAULT_PITCH_DEG, "the camera starts at the default tilt")
	rig.zoom_by(0.3)
	assert_eq(rig.pitch, RtsCamera.DEFAULT_PITCH_DEG, "zooming out does not tilt the camera")
	rig.zoom_by(-0.5)
	assert_eq(rig.pitch, RtsCamera.DEFAULT_PITCH_DEG, "nor does zooming in")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	wheel.ctrl_pressed = true
	wheel.position = Vector2(640, 360)
	var zoom_before := rig.zoom
	rig.handle_mouse(wheel)
	assert_near(rig.pitch, RtsCamera.DEFAULT_PITCH_DEG + RtsCamera.WHEEL_TILT_DEG, 0.01, "ctrl+wheel down tilts steeper")
	assert_eq(rig.zoom, zoom_before, "and does not zoom")
	rig.tilt_by(90.0)
	assert_eq(rig.pitch, RtsCamera.MAX_PITCH_DEG, "the player's tilt stops at MAX_PITCH_DEG")
	rig.tilt_by(-90.0)
	assert_eq(rig.pitch, RtsCamera.MIN_PITCH_DEG, "and at MIN_PITCH_DEG")
	rig.toggle_overview(Match.Team.GREEN)
	assert_eq(rig.pitch, RtsCamera.OVERVIEW_PITCH_DEG, "the overview looks down on the map")
	rig.toggle_overview(Match.Team.GREEN)
	assert_eq(rig.pitch, RtsCamera.MIN_PITCH_DEG, "and closing it gives the player's tilt back")
	rig.reset_tilt()
	assert_eq(rig.pitch, RtsCamera.DEFAULT_PITCH_DEG, "Home resets the tilt")
	rig.snap()
	var shown := rig.camera.global_transform.origin - rig.focus
	assert_near(rad_to_deg(asin(shown.y / shown.length())), rig.pitch, 0.1, "the camera is drawn at that tilt")


## Round 6 X3: at the lead's low camera, a squad near the wall is framed from a camera that sits past the wall, inside
## the grandstand, and the railing and crowd hide the squad (seen in `make shell-playtest` at 50 s). The camera cuts
## away whatever stands between it and the wall: its near plane sits just short of where the wall meets the floor.
func test_a_camera_past_the_wall_cuts_away_the_stands_between() -> void:
	var half := 121.0
	# In the middle of the arena, nothing to cut: the default near plane.
	assert_eq(RtsCamera.cutaway_near(Vector3.ZERO, 0.0, 50.0, 25.0, half), RtsCamera.NEAR_DEFAULT, "mid-arena: no cutaway")
	# Ten metres from the south wall, looking north: the camera is ~35 m past the wall, in the stands.
	var focus := Vector3(0, 0, half - 10.0)
	var near := RtsCamera.cutaway_near(focus, 0.0, 50.0, 25.0, half)
	var pose := RtsCamera.pose_at(focus, 0.0, 50.0, 25.0)
	assert_true(pose.origin.z > half + 10.0, "setup: the camera is outside the wall (%.1f)" % pose.origin.z)
	var view := pose.affine_inverse()
	var depth := func(p: Vector3) -> float: return -(view * p).z
	var rail := Vector3(0, 5.0, half + 1.0)  # the stands' front rail, just outside the wall
	var seat := Vector3(0, 12.0, half + 12.0)  # a crowd row between the camera and the arena
	var wall_foot := Vector3(0, 0, half)
	var squad := Vector3(0, 1.0, half - 4.0)  # a vehicle hugging the wall
	assert_true(depth.call(rail) < near and depth.call(seat) < near, "the rail and the seats are cut away (near %.1f; rail %.1f, seat %.1f)" %
			[near, depth.call(rail), depth.call(seat)])
	assert_true(depth.call(wall_foot) > near and depth.call(squad) > near, "the floor at the wall and a vehicle on it are drawn")
	# Looking the other way from the same spot (camera over the arena), nothing is cut.
	assert_eq(RtsCamera.cutaway_near(focus, PI, 50.0, 25.0, half), RtsCamera.NEAR_DEFAULT, "a camera over the arena cuts nothing")
