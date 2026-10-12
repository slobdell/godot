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


# ---- Round 27 (orders O2): the end shot stays on the arena -----------------------------------------------------------

## Round 26's showmatch end frame (seed 43496, Docks): the bottom third was the floor UNDER the arena. Vehicles by the
## wall on the camera's side put the camera past the wall, where the rig's cutaway near plane slices the ground away.
## The director films them from inside the arena instead.
func test_a_shot_by_the_near_wall_is_filmed_from_inside_the_arena() -> void:
	var f := Fixture.new(self)
	await f.build(false)  # the match's arena and perimeter, as the director sees them
	var south := Vector3(0.0, 0.0, RtsCamera.perimeter_half() - 4.0)  # yaw 0 puts the camera south of the focus
	var points := [south, south + Vector3(30.0, 0.0, 0.0), south + Vector3(-30.0, 0.0, -2.0)]
	assert_true(CinematicCamera.cut_at(points, 0.0, 16.0 / 9.0, RtsCamera.DEFAULT_PITCH_DEG) > RtsCamera.NEAR_DEFAULT,
			"setup: from the south the camera is past the wall and the rig cuts")
	for aspect: float in [16.0 / 9.0, 1200.0 / 540.0]:
		var heading := CinematicCamera.heading_for(points, 0.0, aspect, RtsCamera.DEFAULT_PITCH_DEG)
		assert_true(absf(wrapf(heading - PI, -PI, PI)) < 0.01, "it turns round to film toward the wall (%.2f rad, aspect %.2f)"
				% [heading, aspect])
		assert_true(CinematicCamera.cut_at(points, heading, aspect, RtsCamera.DEFAULT_PITCH_DEG) <= RtsCamera.NEAR_DEFAULT,
				"where nothing is cut")


func test_a_shot_in_the_middle_keeps_its_angle() -> void:
	var points := [Vector3(-10.0, 0.0, 0.0), Vector3(10.0, 0.0, 6.0)]
	for yaw: float in [0.0, 0.7, -2.0]:
		assert_eq(CinematicCamera.heading_for(points, yaw, 16.0 / 9.0, RtsCamera.DEFAULT_PITCH_DEG), yaw,
				"no cut, no turn (yaw %.1f)" % yaw)


func test_the_directed_camera_never_shows_under_the_arena_by_the_wall() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var edge := RtsCamera.perimeter_half() - 4.0
	var i := 0
	for node in f.game_match.tanks.get_children():
		var tank := node as Tank
		tank.global_position = Vector3(-20.0 + 8.0 * i, 0.0, edge)
		tank.reset_physics_interpolation()
		i += 1
	f.rig.yaw = 0.0
	var placed: Array = []
	for node in f.game_match.tanks.get_children():
		placed.append(Vector3((node as Tank).global_position.x, 0.0, (node as Tank).global_position.z))
	assert_true(CinematicCamera.cut_at(placed, 0.0, 16.0 / 9.0, f.rig.pitch) > RtsCamera.NEAR_DEFAULT,
			"setup: round 26's angle would cut the ground here")
	var director := _director(f)
	await _frames(4)
	f.rig.snap()
	await _frames(2)
	assert_true(absf(wrapf(f.rig.yaw, -PI, PI)) > 0.01, "it turned off the angle past the wall (%.2f)" % f.rig.yaw)
	assert_true(f.rig.camera.near <= RtsCamera.NEAR_DEFAULT + 1e-4, "and the rig cuts nothing (near %.2f)" % f.rig.camera.near)
	var size := f.rig.camera.get_viewport().get_visible_rect().size
	var off := CinematicCamera.off_arena(f.rig.camera, size)
	assert_eq(float(off["under"]), 0.0, "no ground cut away (%s, near %.2f)" % [off, f.rig.camera.near])
	assert_true(director.shot().size() > 0, "and it is still filming them")
	assert_true(not f.rig.yaw_follow, "the director owns the angle: the rig's yaw-follow is off")
	var turns := 0
	var last := f.rig.yaw
	for frame in 40:
		await tree.process_frame
		if not is_equal_approx(f.rig.yaw, last):
			turns += 1
			last = f.rig.yaw
	assert_eq(turns, 0, "and it holds that angle instead of flapping between two")


## The orchestrator's question (round 27): the director's yaw-follow switch is the spectator's camera only. A rig no
## director starts (every skirmish the player commands: SkirmishMode adds the director only for --cinematic) keeps
## yaw-follow on, and so does a director told to keep round 26's angle.
func test_the_players_camera_keeps_yaw_follow() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	assert_true(f.rig.yaw_follow, "the player's rig: yaw-follow on, as before")
	await _frames(3)
	assert_true(f.rig.yaw_follow, "nothing but the director turns it off")
	var kept := CinematicCamera.new()
	kept.rig = f.rig
	kept.game_match = f.game_match
	add_to_tree(kept)
	kept.keep_angle = true
	kept.start()
	assert_true(f.rig.yaw_follow, "round 26's director (--cinematic-keep-angle) leaves it on")
	_director(f)
	assert_true(not f.rig.yaw_follow, "the round 27 director owns the angle")
