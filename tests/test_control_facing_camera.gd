extends TestCase
## Round 7, the lead: "the camera's yaw orientation should match the intended facing position of the squad or selected
## unit" (A), and "make the field of view match the range of the vehicle or the max range of the selection" (B).

const Fixture := preload("res://tests/support/control_fixture.gd")


func _face(f: Fixture, unit_name: String, yaw: float) -> void:
	var tank := f.tank(unit_name)
	tank.rotation.y = yaw  # 0 faces north (-Z); -PI/2 faces east (+X): trip-up 2
	tank.reset_physics_interpolation()


func test_the_camera_turns_to_face_where_the_selection_faces() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.rig.facing = f.controls.selection_facing
	f.rig.handback_seconds = 0.0
	f.rig.yaw = 0.0
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2"]:
		_face(f, unit_name, -PI / 2.0)
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	var wanted: Variant = f.controls.selection_facing()
	assert_true(wanted is Vector3 and (wanted as Vector3).dot(Vector3.RIGHT) > 0.99, "the selection faces east (%s)" % [wanted])
	# The camera's side, against a facing that holds still (this fixture's brains keep turning toward the enemy).
	f.rig.facing = func() -> Variant: return Vector3.RIGHT
	# 90° at YAW_FOLLOW_DEG_PER_S takes ~1.3 s: wait on the clock, not a frame count (headless frames are fast).
	var until := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < until:
		await tree.process_frame
	assert_true(absf(angle_difference(f.rig.yaw, RtsCamera.yaw_facing(Vector3.RIGHT))) < deg_to_rad(RtsCamera.YAW_SETTLE_DEG + 1.0),
			"the camera has turned to look east with them (yaw %.0f°)" % rad_to_deg(f.rig.yaw))
	# Mixed: two vehicles facing opposite ways have no facing, and the camera keeps its yaw instead of snapping.
	_face(f, "Green_Alpha_1", -PI / 2.0)
	_face(f, "Green_Alpha_2", PI / 2.0)
	assert_eq(f.controls.selection_facing(), null, "a mixed selection has no facing")
	f.rig.facing = f.controls.selection_facing
	var kept := f.rig.yaw
	for i in 30:
		await tree.process_frame
	assert_near(f.rig.yaw, kept, 0.001, "and the camera stays where it is")


func test_manual_yaw_wins_and_y_turns_following_off() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.rig.facing = f.controls.selection_facing
	f.rig.handback_seconds = 5.0
	_face(f, "Green_Alpha_1", -PI / 2.0)
	await f.select(["Green_Alpha_1"])
	f.rig.rotate_by(0.3)
	var turned := f.rig.yaw
	for i in 20:
		await tree.process_frame
	assert_near(f.rig.yaw, turned, 0.001, "a player who turned the camera keeps it for the hand-back time")
	await f.key(KEY_Y)
	assert_true(not f.rig.yaw_follow, "Y turns yaw-follow off")
	assert_true(f.rig.pose_text().contains("yaw_follow=off"), "and the pasted pose says so")


func test_selected_vehicles_show_which_way_they_point() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	_face(f, "Green_Alpha_1", -PI / 2.0)
	await f.select(["Green_Alpha_1"])
	var marks := f.controls.facing_marks()
	assert_eq(marks.size(), 1, "one facing mark per selected vehicle")
	var arrow: Vector3 = (marks[0]["to"] as Vector3) - (marks[0]["from"] as Vector3)
	assert_true(arrow.normalized().dot(Vector3.RIGHT) > 0.99, "pointing the way its hull points (%s)" % arrow)


func test_the_frame_reaches_out_to_what_the_selection_can_fight() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	await f.select(["Green_Alpha_1", "Green_Bravo_2"])
	var expected := 0.0
	for unit_name in ["Green_Alpha_1", "Green_Bravo_2"]:
		var tank := f.tank(unit_name)
		expected = maxf(expected, minf(Engagement.effective_range(Weapons.profile(tank.weapon_id)), tank.sight_radius))
	assert_near(f.controls.selection_reach(), expected, 0.01, "reach is the selection's longest covering range (%.0f m)" % expected)
	f.controls.range_frame = 1.0
	var with_range: Dictionary = f.controls.vision_state()
	f.controls.range_frame = 0.0
	var without: Dictionary = f.controls.vision_state()
	assert_eq((with_range["frame"] as Array).size(), (without["frame"] as Array).size(),
			"the reach is a lean, not a point the frame must fit (fitting it dropped the squad off the screen)")
	assert_true(without["destination"] == null and with_range["destination"] is Vector3, "the view leans toward the reach")
	var middle := (f.tank("Green_Alpha_1").global_position + f.tank("Green_Bravo_2").global_position) / 2.0
	var lean: Vector3 = with_range["destination"]
	assert_true(Vector2(lean.x - middle.x, lean.z - middle.z).length() > expected * 0.8,
			"out where the selection can fight (%.0f m)" % Vector2(lean.x - middle.x, lean.z - middle.z).length())


## Round 7: the auto camera never pulls further out than auto_frame_max_m, however spread the squad (at the lead's 35°
## a squad strung along the spawn line pulled it to ~220 m).
func test_the_auto_camera_stays_near_the_leads_distance() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	RtsCamera.fov = RtsCamera.FOV_DEG
	f.rig.vision = f.controls.vision_state
	f.place("Green_Alpha_1", Vector3(-110, 0, 40))
	f.place("Green_Alpha_2", Vector3(110, 0, 40))
	await f.select(["Green_Alpha_1", "Green_Alpha_2"])
	f.rig.take_vision()
	for i in 30:
		await tree.process_frame
	assert_true(RtsCamera.distance_for(f.rig.zoom) <= f.rig.auto_frame_max_m + 0.5,
			"a 220 m-wide selection is framed from no further than %.0f m (%.0f m)" % [f.rig.auto_frame_max_m, RtsCamera.distance_for(f.rig.zoom)])
	RtsCamera.fov = 55.0


## Round 7 regression (shell-playtest, planning): with range framing and the distance cap together, the squad fell off
## the bottom of the screen and the enemy filled it. The reach is a lean: the selected squad stays on screen.
func test_leaning_toward_the_reach_keeps_the_squad_on_screen() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	RtsCamera.fov = RtsCamera.FOV_DEG
	f.rig.pitch = RtsCamera.DEFAULT_PITCH_DEG
	f.rig.vision = f.controls.vision_state
	f.controls.range_frame = 2.0  # the most the keys allow
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	f.rig.take_vision()
	var until := Time.get_ticks_msec() + 2500
	while Time.get_ticks_msec() < until:
		await tree.process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		var at := f.camera.unproject_position(f.tank(unit_name).global_position)
		assert_true(not f.camera.is_position_behind(f.tank(unit_name).global_position) and screen.has_point(at),
				"%s stays on screen while the view leans toward the reach (%s)" % [unit_name, at])
	RtsCamera.fov = 55.0
