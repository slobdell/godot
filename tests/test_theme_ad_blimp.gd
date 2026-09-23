extends TestCase
## Contract R7 (round 10, feel): the low ad blimp he sees while he PLAYS. The lead: *"we're missing the blimp I
## wanted."* It is art and must stay art (no collider; the sim baseline pre-registered unmoved), posed from the fixed
## tick, and it has to be where his camera can see it -- which at 21 deg means lower than the camera, over the streets.

const PITCH_DEG := 21.0
const FOV_DEG := 35.0
const BOOM_M := 49.0


func _blimp() -> AdBlimp:
	var blimp := AdBlimp.new(AdBlimp.route_for({"name": "terminus"}))
	add_to_tree(blimp)
	return blimp


func test_the_blimp_carries_no_collision_of_any_kind() -> void:
	var blimp := _blimp()
	for class_kind in ["CollisionObject3D", "CollisionShape3D", "StaticBody3D", "Area3D", "CharacterBody3D"]:
		assert_eq(blimp.find_children("*", class_kind, true, false).size(), 0, "no %s under the blimp" % class_kind)
	assert_true(blimp.find_children("*", "MeshInstance3D", true, false).size() > 0, "but it does draw something")


func test_its_pose_comes_from_the_fixed_tick_and_is_a_closed_circuit() -> void:
	var blimp := _blimp()
	var lap := blimp.lap_ticks()
	assert_true(lap > 0, "the Terminus has a route")
	assert_true(blimp.pose_at(0).origin.distance_to(blimp.pose_at(lap).origin) < 1.0, "a lap returns it to the start")
	assert_true(blimp.pose_at(0).origin.distance_to(blimp.pose_at(lap / 4).origin) > 20.0, "and it moves in between")
	assert_true(blimp.pose_at(1234).is_equal_approx(blimp.pose_at(1234)), "the same tick is the same pose")
	# A walking pace: ten seconds on the first straight leg (it starts on a fillet) move it ~10 x SPEED_MPS.
	var start := int(SimClock.TICK_RATE * 20)
	var a := blimp.pose_at(start).origin
	var b := blimp.pose_at(start + int(SimClock.TICK_RATE * 10)).origin
	assert_near(Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) / 10.0, AdBlimp.SPEED_MPS, 0.3, "at a walking pace")


func test_it_flies_down_the_streets_and_never_over_a_block() -> void:
	## (The first route, round the ring roads, passed this and was invisible from the bases -- make blimp-look -- so this
	## is necessary, not sufficient; the sweep is the other half.)
	## At 12 m it is below the Terminus rooftops (24 m), so it must stay on the declared lanes with its envelope
	## inside the street. Read from the layout, so a lane arena moves or narrows (CP2) fails here, not in a frame.
	var layout: Dictionary = Arena.load_layout("terminus")["layout"]
	var lanes: Array = layout.get("lanes", [])
	assert_true(lanes.size() > 0, "the Terminus declares its lanes")
	var samples := AdBlimp.sample_route(AdBlimp.route_for(layout))
	assert_true(samples.size() > 100, "the route is sampled")
	var worst := 0.0
	for p: Vector2 in samples:
		var best := INF
		for lane: Dictionary in lanes:
			var points: Array = lane["points"]
			var room := float(lane["width"]) / 2.0 - AdBlimp.ENVELOPE_DIAMETER / 2.0
			for i in points.size() - 1:
				var s0 := Vector2(float(points[i][0]), float(points[i][1]))
				var s1 := Vector2(float(points[i + 1][0]), float(points[i + 1][1]))
				var closest := Geometry2D.get_closest_point_to_segment(p, s0, s1)
				best = minf(best, p.distance_to(closest) - room)
		worst = maxf(worst, best)
	assert_true(worst <= 0.0, "every point of the route keeps the envelope inside a street (worst overhang %.2f m)" % worst)


func test_it_is_in_his_frame_when_he_looks_at_the_street_it_is_over() -> void:
	## The geometry that makes R7 possible at all, held so an edit cannot fly it back into the blind spot: at his
	## pose the frame spans 3.5 to 38.5 deg below the horizon, and a blimp over the point he is looking at sits at
	## atan((camera height - altitude) / boom's ground run) below it.
	var camera_y := BOOM_M * sin(deg_to_rad(PITCH_DEG))
	var run := BOOM_M * cos(deg_to_rad(PITCH_DEG))
	var top := PITCH_DEG - FOV_DEG / 2.0
	var bottom := PITCH_DEG + FOV_DEG / 2.0
	assert_true(AdBlimp.ALTITUDE + AdBlimp.ENVELOPE_DIAMETER / 2.0 + AdBlimp.BOB_M < camera_y,
			"its top stays under his camera (%.1f m)" % camera_y)
	var depression := rad_to_deg(atan((camera_y - AdBlimp.ALTITUDE) / run))
	assert_true(depression > top and depression < bottom,
			"over his focus it is %.1f deg below the horizon, inside his frame's %.1f..%.1f" % [depression, top, bottom])
	# ...and clear of everything that drives or stands on the street: the tallest hull and R3's lamp-head line.
	var lowest := AdBlimp.ALTITUDE - AdBlimp.BOB_M - AdBlimp.ENVELOPE_DIAMETER / 2.0 - 1.8
	assert_true(lowest > 6.2, "its lowest point (%.2f m, the gondola) is above 6.2 m" % lowest)


func test_its_screens_join_the_arena_channel() -> void:
	var blimp := _blimp()
	var screens := blimp.find_children("Screen*", "MeshInstance3D", true, false)
	assert_eq(screens.size(), 4, "two screens a flank, fore and aft")
	for screen: MeshInstance3D in screens:
		assert_true(screen.material_override == AdBroadcast.channel(blimp, "arena").screen_material,
				"%s shows the arena channel's one material" % screen.name)


func test_maps_without_a_route_get_no_blimp() -> void:
	assert_true(AdBlimp.route_for({"name": "foundry"}).is_empty(), "no route, no blimp")
