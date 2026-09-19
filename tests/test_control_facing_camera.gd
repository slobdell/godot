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
	var with_range: Array = f.controls.vision_state()["frame"]
	f.controls.range_frame = 0.0
	var without: Array = f.controls.vision_state()["frame"]
	assert_eq(with_range.size(), without.size() + 1, "range framing adds one point, at the selection's reach")
	var middle := Vector3.ZERO
	for p: Vector3 in without.slice(0, 2):
		middle += p
	var reach_point: Vector3 = with_range.back()
	assert_true(reach_point.distance_to(middle / 2.0) > expected * 0.8, "out where the selection can fight (%.0f m)" % reach_point.distance_to(middle / 2.0))
