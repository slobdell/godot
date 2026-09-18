extends TestCase
## Control stretch: the cinematic camera. It has to find the fighting, hold a shot long enough to watch, cut
## rather than glide across dead ground, and never get so nervous that it is unwatchable.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


func _director(f: Fixture) -> CinematicCamera:
	var director := CinematicCamera.new()
	director.rig = f.rig
	director.game_match = f.game_match
	add_to_tree(director)
	director.start()
	return director


func test_a_place_where_both_sides_meet_outranks_a_quiet_one() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	# Our five sit together in the west; one of ours and the enemy are alone together in the east.
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3", "Green_Bravo_1"]:
		f.tank(unit_name).global_position = Vector3(-90, 0, 90)
		f.tank(unit_name).reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	f.tank("Green_Bravo_2").global_position = Vector3(90, 0, -90)
	f.tank("Green_Bravo_2").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	f.tank("Rust_Alpha_1").global_position = Vector3(94, 0, -94)
	f.tank("Rust_Alpha_1").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await _frames(2)
	var director := _director(f)
	var best := director.best_scene()
	assert_eq(best["why"], "a firefight", "the camera goes where the two sides meet")
	assert_true((best["at"] as Vector3).x > 0.0, "which is the east, not the four parked in the west (%s)" % best["at"])
	var ranked := director.scenes()
	assert_true(ranked.size() >= 2, "the quiet cluster is still a scene, just a worse one")
	assert_true(float(ranked[0]["score"]) > float(ranked[1]["score"]), "ranked best first")


func test_a_vehicle_taking_hits_is_the_moment_inside_the_fight() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var director := _director(f)
	# Nobody has been hit yet: the fixture's opening frames can already land a hitscan round (more game time passes
	# in them at a 30 Hz tick), which would leave nothing for this test to raise.
	for node in f.game_match.tanks.get_children():
		(node as Tank).ticks_since_hit = 1_000_000
	var before := float(director.best_scene()["score"])
	for node in f.game_match.tanks.get_children():
		(node as Tank).ticks_since_hit = 1
	await _frames(1)
	assert_true(float(director.best_scene()["score"]) > before, "rounds landing raises the scene's score")


func test_a_shot_is_held_and_only_something_better_interrupts_it() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var director := _director(f)
	await _frames(3)
	var first := director.shot()
	assert_true(not first.is_empty(), "it picks a shot straight away")
	# Nothing has changed, so the camera must still be on the same place a moment later.
	await _frames(5)
	assert_eq(director.shot()["at"], first["at"], "and holds it instead of twitching every frame")
	assert_true(CinematicCamera.MIN_SHOT_SECONDS > 1.0 and CinematicCamera.SHOT_SECONDS > CinematicCamera.MIN_SHOT_SECONDS,
			"a shot is held for seconds, not frames")


func test_the_camera_stops_obeying_the_players_vision_cap() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 30.0)
	f.rig.vision = func() -> Dictionary: return {"frame": [Vector3.ZERO], "region": region, "destination": null}
	await _frames(RtsCamera.VISION_CAP_EVERY + 2)
	assert_true(f.rig.vision_zoom < 1.0, "the player's camera is capped by what the force can see")
	_director(f)
	await _frames(2)
	assert_eq(f.rig.vision_zoom, 1.0, "the spectator's is not: nobody is earning this view")
	assert_true(not f.rig.vision.is_valid(), "and the vision source is let go, not left fighting for the wheel")


func test_it_frames_the_vehicles_in_shot() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		f.tank(unit_name).global_position = Vector3(60, 0, -60)
		f.tank(unit_name).reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	f.tank("Rust_Alpha_1").global_position = Vector3(64, 0, -64)
	f.tank("Rust_Alpha_1").reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	await _frames(2)
	var director := _director(f)
	await _frames(3)
	var shot := director.shot()
	assert_true(RtsCamera.shows_all(shot["points"], f.rig.focus, f.rig.yaw, f.rig.zoom, 1280.0 / 720.0),
			"everyone in the shot is on screen")
	assert_true(f.rig.zoom >= CinematicCamera.MIN_ZOOM - 0.001, "and it never jams the lens into a hull (%.2f)" % f.rig.zoom)
	print("MEASURE control_cinematic zoom=%.2f units=%d why=%s" % [f.rig.zoom, int(shot["units"]), shot["why"]])
