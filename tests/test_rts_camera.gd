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
	RtsCamera.fov = RtsCamera.FOV_DEG  # the default lens (a static: another test may have changed it)
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
	# Round 6 X3: round 5 tilted from 25° to 82° as you zoomed out, so seeing your army cost you a top-down view. Now
	# every zoom out to FAR_TILT_FROM_M looks down at exactly the player's tilt...
	for level in [0.0, 0.2, RtsCamera.level_for(50.0), RtsCamera.level_for(RtsCamera.FAR_TILT_FROM_M)]:
		var pose := RtsCamera.pose_for(Vector3.ZERO, 0.0, level)
		assert_near(rad_to_deg(asin(pose.origin.y / pose.origin.length())), RtsCamera.DEFAULT_PITCH_DEG, 0.01,
				"zoom %.2f looks down at the player's tilt" % level)
	# ...and only past it does a soft floor lift a very low camera, so a whole-army view is ground, not a strip of
	# arena between sky and cut-away stands (the lead's 12°, shell-playtest at 50 s). Never near round 5's top-down.
	var far_tilt := rad_to_deg(asin(far.origin.y / far.origin.length()))
	assert_near(far_tilt, maxf(RtsCamera.DEFAULT_PITCH_DEG, RtsCamera.FAR_TILT_MAX_DEG), 0.01,
			"fully zoomed out: the player's tilt or the far floor, whichever is higher")
	var low_far := RtsCamera.pose_for(Vector3.ZERO, 0.0, 1.0, 12.0)
	assert_near(rad_to_deg(asin(low_far.origin.y / low_far.origin.length())), RtsCamera.FAR_TILT_MAX_DEG, 0.01,
			"a player who tilts to 12° still gets the far floor when fully zoomed out")
	assert_true(RtsCamera.tilt_at(RtsCamera.MIN_PITCH_DEG, RtsCamera.MAX_DISTANCE) <= RtsCamera.FAR_TILT_MAX_DEG,
			"the far floor itself never goes past FAR_TILT_MAX_DEG, nowhere near a bird's eye view")
	var steep_far := RtsCamera.pose_for(Vector3.ZERO, 0.0, 1.0, 48.0)
	assert_near(rad_to_deg(asin(steep_far.origin.y / steep_far.origin.length())), 48.0, 0.01, "a steeper tilt is kept as it is")
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
	# At the lead's 12° the wall itself (3 m) must go too, or its top edge hides every vehicle parked against it (seen in
	# shell-playtest at 12°); a vehicle hugging the wall stays.
	for pitch: float in [12.0, 25.0, 50.0]:
		var low_near := RtsCamera.cutaway_near(focus, 0.0, 50.0, pitch, half)
		var low_view := RtsCamera.pose_at(focus, 0.0, 50.0, pitch).affine_inverse()
		var wall_top := Vector3(0, RtsCamera.WALL_HEIGHT_M, half)
		var hugging := Vector3(0, 2.0, half - 0.5)
		if low_near > RtsCamera.NEAR_DEFAULT:  # (at 50° from here the stands hide nothing, so nothing is cut)
			assert_true(-(low_view * wall_top).z < low_near, "at %d° the wall's top edge is cut away" % pitch)
		assert_true(-(low_view * hugging).z > low_near, "at %d° a vehicle against the wall is drawn" % pitch)
		assert_true(-(low_view * Vector3(0, 0, half)).z > low_near, "at %d° the floor at the wall is drawn" % pitch)
	# A camera among the seats (close framing at 12°, shell-playtest at 3 s: a railing across the whole view) always cuts.
	# (36 m inside the wall, 46 m out: the camera sits 9 m past the wall at 9.6 m, among the seats, where the sight line
	# to the arena clears every sampled profile point: the first version of the rule left the railings standing.)
	var close := Vector3(0, 0, half - 36.0)
	var among := RtsCamera.pose_at(close, 0.0, 46.0, 12.0)
	assert_true(among.origin.z > half + 2.0 and among.origin.z < half + 24.0, "setup: the camera is in the stands (%.1f)" % among.origin.z)
	assert_true(RtsCamera.cutaway_near(close, 0.0, 46.0, 12.0, half) > RtsCamera.NEAR_DEFAULT, "a camera among the seats cuts them")
	# From far out and high up the stands hide nothing: they stay (with their crowd) instead of a black void.
	var mid := Vector3(0, 0, 60.0)
	assert_eq(RtsCamera.cutaway_near(mid, 0.0, 150.0, 30.0, half), RtsCamera.NEAR_DEFAULT,
			"a high camera beyond the stands keeps them as foreground")
	assert_true(RtsCamera.cutaway_near(mid, 0.0, 150.0, 12.0, half) > RtsCamera.NEAR_DEFAULT,
			"a low one looking through them cuts them")
	# Looking the other way from the same spot (camera over the arena), nothing is cut.
	assert_eq(RtsCamera.cutaway_near(focus, PI, 50.0, 25.0, half), RtsCamera.NEAR_DEFAULT, "a camera over the arena cuts nothing")


## Round 6: the lead finds the camera himself, in play. Every value is live, the readout shows it, P copies it, and V stops
## the auto camera taking the view back while he hunts.
func test_the_camera_can_be_found_by_hand_and_copied() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	var fov_before := RtsCamera.fov
	rig.fov_by(RtsCamera.FOV_STEP_DEG)
	assert_near(RtsCamera.fov, fov_before + RtsCamera.FOV_STEP_DEG, 0.01, "] widens the field of view")
	rig.snap()
	assert_near(rig.camera.fov, RtsCamera.fov, 0.01, "and the camera draws with it")
	rig.fov_by(-1000.0)
	assert_eq(RtsCamera.fov, RtsCamera.MIN_FOV_DEG, "within limits")
	rig.set_auto_frame(false)
	var pose := rig.pose_text()
	assert_true(pose.begins_with("CAMERA_POSE pitch=") and pose.contains("fov=%d" % roundi(RtsCamera.MIN_FOV_DEG)) and pose.contains("auto_frame=off"),
			"the pose names every value (%s)" % pose)
	var readout := CameraReadout.new()
	readout.rig = rig
	add_to_tree(readout)
	assert_true(readout.lines()[0].contains("FOV %d°" % roundi(RtsCamera.MIN_FOV_DEG)), "the readout shows the live values (%s)" % readout.lines()[0])
	assert_true(readout.lines()[1].contains("P copy pose"), "and the keys")
	RtsCamera.fov = RtsCamera.FOV_DEG  # a static: leave it as the other tests expect


## Round 7: with the arena's own perimeter (arena's Arena.perimeter / perimeter_edges), the cutaway crosses that polygon,
## and the span of wall it crosses says what stands behind it.
func _hexagon(apothem: float) -> PackedVector2Array:
	# Flat sides north and south (vertices at k*60°: the edge from 60° to 120° is flat across +z).
	var radius := apothem / cos(PI / 6.0)
	var poly := PackedVector2Array()
	for k in 6:
		var angle := deg_to_rad(60.0 * k)
		poly.append(Vector2(cos(angle), sin(angle)) * radius)
	return poly


func test_the_cutaway_follows_the_arenas_own_perimeter() -> void:
	var poly := _hexagon(121.0)
	var edges: Array = []
	for i in poly.size():
		var length := poly[i].distance_to(poly[(i + 1) % poly.size()])
		edges.append({"wall_height_m": 3.0, "spans": [{"kind": "stands", "from_m": 0.0, "to_m": length}]})
	# The south side (the edge crossing +z at its middle) has a stretch with nothing behind it in the middle.
	var south := -1
	for i in poly.size():
		var mid := (poly[i] + poly[(i + 1) % poly.size()]) / 2.0
		if mid.y > 100.0:
			south = i
	var length := poly[south].distance_to(poly[(south + 1) % poly.size()])
	edges[south]["spans"] = [{"kind": "stands", "from_m": 0.0, "to_m": length / 2.0 - 10.0},
			{"kind": "none", "from_m": length / 2.0 - 10.0, "to_m": length / 2.0 + 10.0},
			{"kind": "stands", "from_m": length / 2.0 + 10.0, "to_m": length}]
	RtsCamera.perimeter_poly = poly
	RtsCamera.perimeter_edge_data = edges
	var hit := RtsCamera.perimeter_crossing(Vector2(0, 60), Vector2(0, 1))
	assert_near(float(hit["reach"]), 61.0, 0.01, "looking south from z=60, the wall is 61 m away (apothem 121)")
	assert_eq(String(hit["kind"]), "none", "through the middle of the south side, nothing stands behind it")
	var aside := RtsCamera.perimeter_crossing(Vector2(-40, 60), Vector2(0, 1))
	assert_eq(String(aside["kind"]), "stands", "40 m to the side, the stands do")
	# A low camera near the south wall: cut where the stands are; where only the wall is, the plane still clears it.
	var focus_stands := Vector3(-40, 0, 111)
	var near_stands := RtsCamera.cutaway_near(focus_stands, 0.0, 50.0, 21.0, 999.0)
	assert_true(near_stands > RtsCamera.NEAR_DEFAULT, "behind the stands the camera cuts them (near %.1f)" % near_stands)
	# A diagonal side: the polygon, not a square, decides where the wall is.
	var diagonal := RtsCamera.perimeter_crossing(Vector2.ZERO, Vector2(1, 1).normalized())
	assert_true(float(diagonal["reach"]) < 121.0 * sqrt(2.0) - 1.0, "a diagonal wall is nearer than the square's corner (%.0f m)" % diagonal["reach"])
	RtsCamera.perimeter_poly = PackedVector2Array()
	RtsCamera.perimeter_edge_data = []
