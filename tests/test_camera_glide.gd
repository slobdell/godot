extends TestCase
## Round 41 (camera K2): the camera glides, waits while he aims, and its shake never moves the ground under the cursor.


func _rig() -> RtsCamera:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	RtsCamera.fov = RtsCamera.FOV_DEG
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 40)
	rig.zoom = 0.4
	add_to_tree(rig)
	return rig


func test_the_spring_starts_and_stops_without_a_jump_in_speed() -> void:
	var x := 0.0
	var v := 0.0
	var dt := 1.0 / 60.0
	var top_accel := 0.0
	var last_v := 0.0
	for i in 600:
		var next := RtsCamera.spring(x, v, 10.0, 3.0, dt)
		x = float(next[0])
		v = float(next[1])
		top_accel = maxf(top_accel, absf(v - last_v) / dt)
		last_v = v
		assert_true(x <= 10.0 + 1e-6, "critically damped: it never overshoots (frame %d: %.4f)" % [i, x])
	assert_near(x, 10.0, 0.001, "it arrives")
	assert_true(top_accel <= 3.0 * 3.0 * 10.0 + 1e-3, "its hardest push is omega^2 x gap (%.1f), never a one-frame lurch" % top_accel)
	# The same glide at 30 fps and at 144: the closed form, not an Euler step.
	var a: Array = [0.0, 0.0]
	var b: Array = [0.0, 0.0]
	for i in 30:
		a = RtsCamera.spring(a[0], a[1], 10.0, 3.0, 1.0 / 30.0)
	for i in 144:
		b = RtsCamera.spring(b[0], b[1], 10.0, 3.0, 1.0 / 144.0)
	assert_near(float(a[0]), float(b[0]), 0.001, "one second at 30 fps lands where one second at 144 fps does")
	var moving: Array = RtsCamera.spring(Vector3.ZERO, Vector3.ZERO, Vector3(4, 0, 0), 3.0, 0.1)
	assert_true((moving[0] as Vector3).x > 0.0 and (moving[1] as Vector3).x > 0.0, "and it works on Vector3 too")


func test_the_leash_holds_inside_its_reach_and_drags_outside() -> void:
	var held := Vector3(0, 0, 0)
	assert_eq(RtsCamera.leash(held, Vector3(1.5, 0, 0), 2.0), held, "a wobble inside the reach leaves the aim point still")
	var dragged := RtsCamera.leash(held, Vector3(5, 0, 0), 2.0)
	assert_near(dragged.x, 3.0, 0.001, "past the reach it is dragged along, reach short of the goal")


func test_his_hand_keeps_its_quick_smoothing_and_the_camera_glides() -> void:
	assert_true(RtsCamera.hand_set("player") and RtsCamera.hand_set("jump") and RtsCamera.hand_set("follow"),
			"his own moves are his")
	for writer in ["auto_frame", "order_track", "yaw_follow", "cap", "frame"]:
		assert_true(not RtsCamera.hand_set(writer), "%s glides" % writer)


func test_an_automatic_move_starts_from_rest() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	assert_true(rig.glide, "glide is on by default (approved behaviour ships ON)")
	var start := rig._shown_focus
	rig.focus = start + Vector3(30, 0, 0)
	rig.wrote["focus"] = "auto_frame"
	var steps: Array = []
	var last := start
	for i in 6:
		rig._process(1.0 / 60.0)
		steps.append(rig._shown_focus.distance_to(last))
		last = rig._shown_focus
	assert_true(float(steps[0]) < float(steps[1]) and float(steps[1]) < float(steps[2]),
			"it gathers speed over frames instead of lurching in the first one: %s" % [steps])
	var old := _rig()
	old.glide = false
	await wait_physics_frames(1)
	var from := old._shown_focus
	old.focus = from + Vector3(30, 0, 0)
	old._process(1.0 / 60.0)
	assert_true(old._shown_focus.distance_to(from) > float(steps[0]) * 4.0,
			"--camera-glide=off is round 40: the lerp jumps out at full speed (%.3f m v %.3f)" % [old._shown_focus.distance_to(from), steps[0]])


func test_while_he_aims_the_automatic_moves_wait() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	var aiming := [false]
	rig.aiming = func() -> bool: return aiming[0]
	rig.focus = rig._shown_focus + Vector3(30, 0, 0)
	rig.wrote["focus"] = "auto_frame"
	for i in 20:
		rig._process(1.0 / 60.0)
	assert_true(rig._focus_velocity.length() > 1.0, "setup: the camera is on its way")
	aiming[0] = true
	var screen := Vector2(640, 300)
	# His hand has just come to rest on the target (a hover with no hand for HOVER_HOLD_S is a resting mouse, not aim).
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	rig._input(motion)
	for i in 30:
		rig._process(1.0 / 60.0)
	var under: Vector3 = rig.ground_point(screen)
	for i in 30:
		rig._process(1.0 / 60.0)
	assert_true(rig.holding, "it says it is holding")
	assert_true((rig.ground_point(screen) as Vector3).distance_to(under) < 0.05,
			"the ground under his cursor stays put while he aims (moved %.3f m)" % (rig.ground_point(screen) as Vector3).distance_to(under))
	aiming[0] = false
	for pressed in [true, false]:  # he clicks: the aim is spent
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = pressed
		click.position = screen
		rig._input(click)
	var before := rig._shown_focus
	for i in 30:
		rig._process(1.0 / 60.0)
	assert_true(rig._shown_focus.distance_to(before) > 0.5, "and it goes on its way after")


func test_a_moving_hand_alone_is_not_aiming_and_a_click_spends_the_aim() -> void:
	var rig := _rig()
	await wait_physics_frames(1)
	var on_unit := [false]
	rig.aiming = func() -> bool: return on_unit[0]
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300, 300)
	rig._input(motion)
	assert_true(not rig.aiming_now(), "an RTS hand never rests: a sweeping mouse is not aiming")
	rig._clock += RtsCamera.DWELL_S + 0.05
	assert_true(rig.aiming_now(), "a hand that has stopped has found what it will click")
	motion.position = Vector2(305, 300)
	rig._input(motion)
	on_unit[0] = true
	assert_true(rig.aiming_now(), "the cursor on a unit, his hand on the mouse: he aims")
	rig._clock += RtsCamera.HOVER_HOLD_S + 0.1
	assert_true(not rig.aiming_now(), "a cursor left resting on a unit does not freeze the camera")
	motion.position = Vector2(310, 300)
	rig._input(motion)
	assert_true(rig.aiming_now(), "his hand is back")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_RIGHT
		click.pressed = pressed
		click.position = Vector2(310, 300)
		rig._input(click)
	assert_true(not rig.aiming_now(), "his click spends the aim: the camera may go on")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = Vector2(300, 300)
	rig._input(press)
	rig._clock += 5.0
	on_unit[0] = false
	assert_true(rig.aiming_now(), "a button held (a box, a drag) is aiming however long it lasts")


func test_no_automatic_move_crosses_the_screen_faster_than_its_top_speed() -> void:
	var rig := _rig()
	await wait_physics_frames(2)
	var top := rig.glide_top_speed()
	var height := 2.0 * RtsCamera.distance_for(rig._shown_zoom) * tan(deg_to_rad(RtsCamera.fov) / 2.0)
	assert_near(top, RtsCamera.GLIDE_SCREENS_PER_S * height, 0.01, "the cap is in screens, not metres")
	rig.focus = rig._shown_focus + Vector3(200, 0, 0)
	rig.wrote["focus"] = "auto_frame"
	var fastest := 0.0
	for i in 240:
		var before := rig._shown_focus
		rig._process(1.0 / 60.0)
		fastest = maxf(fastest, rig._shown_focus.distance_to(before) * 60.0)
	assert_true(fastest <= top * 1.001, "a long re-frame tops out at %.1f m/s (cap %.1f)" % [fastest, top])
	assert_true(fastest >= top * 0.9, "and it does reach it (%.1f m/s)" % fastest)


func test_a_pivoted_shake_keeps_the_cursor_ground_on_its_pixel() -> void:
	var pose := RtsCamera.pose_at(Vector3(0, 0, 0), 0.3, 49.0, 21.0)
	var around := Vector3(6, 0, -4)
	var shaken := CameraShake.pivoted(pose, Vector2(0.7, -0.5), around)
	var before := CameraTrace.project_pose(pose, 35.0, Vector2(1920, 1080), around) as Vector2
	var after := CameraTrace.project_pose(shaken, 35.0, Vector2(1920, 1080), around) as Vector2
	assert_true(before.distance_to(after) < 0.01, "the pivot stays on its pixel (%s -> %s)" % [before, after])
	var elsewhere := Vector3(-25, 0, -30)
	var far_before := CameraTrace.project_pose(pose, 35.0, Vector2(1920, 1080), elsewhere) as Vector2
	var far_after := CameraTrace.project_pose(shaken, 35.0, Vector2(1920, 1080), elsewhere) as Vector2
	assert_true(far_before.distance_to(far_after) > 1.0, "and the rest of the view still shakes (%.1f px)" % far_before.distance_to(far_after))
