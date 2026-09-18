extends TestCase
## Control X3 (round 6's lead gate): `make camera-looks` photographs one frozen fight from a grid of camera poses.
## The photographs need a display; what they are aimed at, and the page that shows them, are tested here.

const Fixture := preload("res://tests/support/control_fixture.gd")


func test_the_camera_aims_at_our_vehicles_in_the_fight_and_looks_at_the_enemy() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	# Our row stands at z = 40 and the enemy 20 m north of its middle (Fixture.SPOTS); Alpha_3 is nearest. Move Bravo_2
	# far away: it is not part of the fight and must not drag the focus.
	f.place("Green_Bravo_2", Vector3(90, 0, 120))
	var focus := CameraLooks.fight_focus(f.game_match, Match.Team.GREEN)
	assert_near(focus.z, 40.0, 0.5, "the focus sits on our row (%s)" % focus)
	assert_true(absf(focus.x) < 10.0, "around the vehicle nearest the enemy, not the straggler (%s)" % focus)
	var heading := CameraLooks.facing_the_enemy(f.game_match, Match.Team.GREEN, focus)
	var pose := RtsCamera.pose_at(focus, heading, 50.0, 35.0)
	var looking := -pose.basis.z
	var toward_enemy := (f.tank("Rust_Alpha_1").global_position - focus)
	toward_enemy.y = 0.0
	assert_true(Vector2(looking.x, looking.z).normalized().dot(Vector2(toward_enemy.x, toward_enemy.z).normalized()) > 0.95,
			"the camera looks from behind our vehicles toward the enemy")
	assert_near(rad_to_deg(asin((pose.origin - focus).y / 50.0)), 35.0, 0.01, "at the pitch asked for")


func test_the_page_shows_round_5_and_every_grid_pose() -> void:
	var frames: Array = []
	for level: float in CameraLooks.WELDED_LEVELS:
		frames.append({"file": "today_%s.jpg" % level, "row": "today", "zoom": level, "pitch": RtsCamera.welded_pitch(level),
				"distance": RtsCamera.distance_for(level), "fov": RtsCamera.FOV_DEG, "height": 1.0})
	for fov: float in CameraLooks.FOVS:
		for pitch: float in CameraLooks.PITCHES:
			for distance: float in CameraLooks.DISTANCES:
				frames.append({"file": "p%d_d%d_f%d.jpg" % [pitch, distance, fov], "row": "grid", "pitch": pitch,
						"distance": distance, "fov": fov, "height": 1.0})
	var html := CameraLooks.page({"arena": "yard", "contact": true, "seconds_in": 30.0, "first_shot_s": 24.0, "frames": frames})
	for frame: Dictionary in frames:
		assert_true(html.contains("src=\"%s\"" % frame["file"]), "the page shows %s" % frame["file"])
	assert_true(html.contains("<title>Camera looks</title>"), "the page has a title")
	assert_true(html.contains("6 s after the first shot"), "and says when the moment is")
	assert_true(RtsCamera.welded_pitch(0.75) > 60.0, "round 5's army-sized view was near top-down (%.0f°)" % RtsCamera.welded_pitch(0.75))
