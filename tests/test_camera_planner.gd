extends TestCase
## Round 46 (camera C2): ONE planner decides the camera's pose (CameraPlanner): its cost, its candidates, its stability,
## and the rig behind `--camera-planner=on`.

const NORTH := Vector3(0, 0, -1)


## A Terminus-like street: two 40 m x 24 m blocks with a 20 m street between them along z (x -10..10).
func _street() -> Dictionary:
	return {"obstacles": [
		{"type": "block", "position": [30.0, 0.0], "size": [40.0, 24.0, 200.0]},
		{"type": "block", "position": [-30.0, 0.0], "size": [40.0, 24.0, 200.0]},
	]}


func _world(own: Array, data: Dictionary, travel: Variant = null, action: Array = []) -> Dictionary:
	var middle := Vector3.ZERO
	for p: Vector3 in own:
		middle += p
	middle /= float(own.size())
	return {"own": own, "pad": 2.0, "path": CameraPlanner.path_ahead(middle, travel), "lean": null, "action": action,
			"fresh": false, "aspect": 16.0 / 9.0, "pitch": RtsCamera.DEFAULT_PITCH_DEG, "inset": RtsCamera.VISION_FRAME_INSET,
			"bottom": RtsCamera.VISION_FRAME_BOTTOM, "floor_level": RtsCamera.VISION_MIN_ZOOM,
			"cap_level": RtsCamera.level_for(RtsCamera.AUTO_FRAME_MAX_M), "data": data}


func _squad(at: Vector3) -> Array:
	return [at + Vector3(-3, 0, 0), at + Vector3(3, 0, 0), at + Vector3(0, 0, 8)]


func _score(w: Dictionary, yaw_deg: float, current_deg: float) -> Dictionary:
	var fitted := CameraPlanner.fit(w["own"], null, deg_to_rad(yaw_deg), w)
	var solids := CameraPlanner.near_solids(w["data"], w["own"], 200.0)
	return CameraPlanner.score(deg_to_rad(yaw_deg), fitted[0], float(fitted[1]), deg_to_rad(current_deg), w, solids)


func test_a_building_between_the_camera_and_the_squad_costs_more_than_the_view_down_the_street() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	var w := _world(_squad(Vector3(0, 0, 0)), _street(), NORTH * 6.0)
	var across := _score(w, 90.0, 0.0)  # looking west: the boom runs east, through the east block
	var along := _score(w, 0.0, 0.0)  # looking north up the street it drives: the boom runs down the street
	assert_true(float(across["terms"]["sight"]) > 0.0, "across the block, the rays to his crews are blocked: %s" % [across["terms"]])
	assert_near(float(along["terms"]["sight"]), 0.0, 0.001, "down the street they are clear: %s" % [along["terms"]])
	# Same turn cost for both (measured from a yaw between them would differ): compare without it.
	var a := float(across["cost"]) - float(across["terms"]["turn"])
	var b := float(along["cost"]) - float(along["terms"]["turn"])
	assert_true(a > b + CameraPlanner.SWITCH_MARGIN, "the corridor view wins by more than the switch margin (%.2f v %.2f)" % [a, b])


func test_driving_a_corridor_with_the_view_turned_across_it_the_plan_turns_down_the_street() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	var w := _world(_squad(Vector3(0, 0, 20)), _street(), NORTH * 6.0)
	var planner := CameraPlanner.new()
	var out := planner.plan(w, deg_to_rad(-127.0))  # his recording, 72 s: the danger look faced SE across the blocks
	var yaw := rad_to_deg(float(out["yaw"]))
	var off_axis := minf(absf(angle_difference(deg_to_rad(yaw), 0.0)), absf(angle_difference(deg_to_rad(yaw), PI)))
	assert_true(rad_to_deg(off_axis) <= 30.0, "the plan looks along the street (yaw %.0f, %.0f deg off its axis): %s" % [
			yaw, rad_to_deg(off_axis), [out["terms"]]])
	assert_true(bool(out["switched"]), "and that is a switch from the across-the-block view")


func test_equal_costs_never_flip_flop() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	var w := _world(_squad(Vector3(0, 0, 0)), {"obstacles": []})  # open ground, parked, nothing in play: every yaw ties
	var planner := CameraPlanner.new()
	var yaw := deg_to_rad(37.0)
	for i in 20:
		var out := planner.plan(w, yaw)
		assert_near(float(out["yaw"]), yaw, 1e-6, "plan %d keeps the current yaw" % i)
		assert_true(not bool(out["switched"]), "and does not switch")
		yaw = float(out["yaw"])


func test_a_small_gain_does_not_swing_the_view() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	# A contact a little off the view's edge: worth a look, but a turn of 30 deg for a part of W_ACTION is within the margin
	# only when the gain is small. Here nothing differs but the turn: the current wins.
	var w := _world(_squad(Vector3(0, 0, 0)), {"obstacles": []}, NORTH * 6.0)
	var planner := CameraPlanner.new()
	var out := planner.plan(w, deg_to_rad(10.0))
	assert_near(rad_to_deg(float(out["yaw"])), 10.0, 0.01, "10 deg off his drive in the open: the view stays (%s)" % [out["terms"]])


func test_a_gun_firing_at_his_squad_from_behind_the_view_is_brought_on_screen() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	var from := Vector3(0, 0, 0)
	var gun := [Vector3(0, 0, 60), 5.0]  # south of him, firing; the view looks north
	var w := _world(_squad(from), {"obstacles": []}, null, [gun])
	var planner := CameraPlanner.new()
	var out := planner.plan(w, 0.0)
	var view := RtsCamera.pose_at(out["focus"], float(out["yaw"]), RtsCamera.distance_for(float(out["level"])),
			RtsCamera.tilt_at(RtsCamera.DEFAULT_PITCH_DEG, RtsCamera.distance_for(float(out["level"])))).affine_inverse()
	assert_true(CameraPlanner.on_screen(CameraPlanner.screen_of(view, gun[0] + Vector3(0, 1, 0), 16.0 / 9.0), RtsCamera.VISION_FRAME_BOTTOM),
			"the gun is on screen (yaw %.0f, %s)" % [rad_to_deg(float(out["yaw"])), out["terms"]])
	for p: Vector3 in w["own"]:
		assert_true(CameraPlanner.on_screen(CameraPlanner.screen_of(view, p + Vector3(0, 1, 0), 16.0 / 9.0), RtsCamera.VISION_FRAME_BOTTOM),
				"and so is every crew of his")


func test_the_candidates_are_the_current_yaw_and_the_fixed_headings() -> void:
	var yaws := CameraPlanner.candidate_yaws(deg_to_rad(17.0))
	assert_near(float(yaws[0]), deg_to_rad(17.0), 1e-6, "the current yaw comes first")
	assert_eq(yaws.size(), CameraPlanner.YAW_STEPS + 1, "plus every 30 deg (none within 5 deg of 17)")
	assert_eq(CameraPlanner.candidate_yaws(0.0).size(), CameraPlanner.YAW_STEPS, "0 is itself a heading: not tried twice")


func test_the_path_ahead_is_empty_when_parked() -> void:
	assert_eq(CameraPlanner.path_ahead(Vector3.ZERO, null).size(), 0, "no drive, no path")
	assert_eq(CameraPlanner.path_ahead(Vector3.ZERO, Vector3(0.5, 0, 0)).size(), 0, "creeping is parked")
	var ahead := CameraPlanner.path_ahead(Vector3.ZERO, NORTH * 6.0)
	assert_eq(ahead.size(), 4, "40 m ahead, every 10 m")
	assert_near((ahead[3] as Vector3).z, -40.0, 0.001, "along the drive")


func _planner_rig(frame: Array, names: Array) -> RtsCamera:
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
	rig.zoom = RtsCamera.level_for(49.0)
	add_to_tree(rig)
	rig.planner_on = true
	rig.set_meta("frame", frame)
	rig.set_meta("names", names)
	rig.vision = func() -> Dictionary:
		var f: Array = rig.get_meta("frame")
		return {"frame": f, "own": f.size(), "pad_m": 2.0, "destination": null, "region": null}
	rig.selection = func() -> Array: return rig.get_meta("names")
	return rig


func test_a_new_selection_off_screen_is_on_screen_within_a_second_while_his_hand_is_on_the_mouse() -> void:
	var rig := _planner_rig(_squad(Vector3(0, 0, 40)), ["a"])
	rig.aiming = func() -> bool: return true  # his cursor rests on a unit: today's aim hold would freeze the pan
	for i in 120:
		rig._process(1.0 / 60.0)
	assert_true(rig._selection_shown(), "the first squad is framed")
	rig.set_meta("frame", _squad(Vector3(110, 0, -90)))  # another squad, far off his screen
	rig.set_meta("names", ["b"])
	var frames := 0
	for i in 180:
		rig._mouse_moved_at = rig._clock  # his hand keeps moving the mouse
		rig._process(1.0 / 60.0)
		frames += 1
		if rig._selection_shown():
			break
	assert_true(rig._selection_shown(), "the new squad comes on screen")
	# 170 m off at his 49 m: ~1.4 s at URGENT_SCREENS_PER_S 1.3 (the snap-free cap; 4.0 took 0.8 s and snapped).
	assert_true(frames <= 90, "within 1.5 s of the selection (%d frames at 60 fps)" % frames)


func test_his_hand_still_wins_over_the_planner() -> void:
	var rig := _planner_rig(_squad(Vector3(0, 0, 40)), ["a"])
	for i in 30:
		rig._process(1.0 / 60.0)
	rig.rotate_by(deg_to_rad(60.0))
	var his := rig.yaw
	for i in 60:  # one second: inside the hand-back time
		rig._process(1.0 / 60.0)
	assert_near(rig.yaw, his, 1e-4, "the yaw he turned to stays his for the hand-back time")


func test_near_the_wall_the_view_looks_into_the_arena_not_at_the_stands() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	var edge := RtsCamera.perimeter_half() - 15.0
	var w := _world(_squad(Vector3(0, 0, edge)), {"obstacles": []})  # parked by his own (south) wall
	var out_view := _score(w, 180.0, 0.0)  # looking south, over the wall
	var in_view := _score(w, 0.0, 0.0)  # looking north, into the arena
	assert_true(float(out_view["terms"]["arena"]) > float(in_view["terms"]["arena"]),
			"the stands cost more than the floor (%s v %s)" % [out_view["terms"], in_view["terms"]])


func test_the_plan_spread_over_frames_decides_as_the_whole_plan_does() -> void:
	RtsCamera.fov = RtsCamera.FOV_DEG
	var w := _world(_squad(Vector3(0, 0, 20)), _street(), NORTH * 6.0)
	var whole := CameraPlanner.new().plan(w, deg_to_rad(-127.0))
	var spread := CameraPlanner.new()
	var out := {}
	var calls := 0
	while out.is_empty() and calls < 40:
		out = spread.step(w, deg_to_rad(-127.0), 0.0, 1)
		calls += 1
	assert_true(calls <= CameraPlanner.candidate_yaws(deg_to_rad(-127.0)).size() + 1,
			"one pose a call; no contacts, so the wide frames are skipped (%d calls)" % calls)
	assert_near(float(out["yaw"]), float(whole["yaw"]), 1e-6, "and it picks the same yaw")
