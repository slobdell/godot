extends TestCase
## Control X1 (L4): the vision-framed camera. The sight region's math, the auto frame that sits as close as the
## commanded element allows, the zoom-out cap the force's collective sight earns ("no unearned god view"), the
## "look" clamp that keeps a free camera over ground the team can see, and manual override with hand-back.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _rig() -> RtsCamera:
	tree.root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3.ZERO
	rig.zoom = 0.6
	add_to_tree(rig)
	return rig


# ---- VisionRegion: pure math ------------------------------------------------------------------------------

func test_a_sight_disc_contains_what_the_unit_can_see() -> void:
	var region := VisionRegion.new()
	region.add(Vector3(0, 0, 0), 60.0)
	assert_true(region.contains(Vector3(59, 0, 0)), "a point inside the sight radius is seen")
	assert_true(not region.contains(Vector3(61, 0, 0)), "a point past it is not")
	assert_true(region.contains(Vector3(0, 9, 40)), "height is ignored: the region is ground")
	assert_true(VisionRegion.new().is_empty(), "no units, no vision")
	assert_true(not VisionRegion.new().contains(Vector3.ZERO), "an empty region sees nothing")


func test_two_units_see_the_union_of_their_discs() -> void:
	var region := VisionRegion.new()
	region.add(Vector3(-50, 0, 0), 40.0)
	region.add(Vector3(50, 0, 0), 40.0)
	assert_true(region.contains(Vector3(-20, 0, 0)), "inside the west unit's disc")
	assert_true(region.contains(Vector3(20, 0, 0)), "inside the east unit's disc")
	assert_true(not region.contains(Vector3(0, 0, 0)), "the gap between them is not seen")


func test_clamping_pulls_a_point_back_to_the_nearest_thing_the_team_can_see() -> void:
	var region := VisionRegion.new()
	region.add(Vector3(0, 0, 0), 60.0)
	region.add(Vector3(200, 0, 0), 20.0)
	assert_eq(region.clamp_point(Vector3(10, 0, 10)), Vector3(10, 0, 10), "a seen point is left alone")
	var pulled := region.clamp_point(Vector3(120, 0, 0))
	assert_near(pulled.x, 60.0, 0.01, "a point past the near disc lands on its edge")
	assert_near(pulled.z, 0.0, 0.01, "along the line to it")
	var far := region.clamp_point(Vector3(300, 0, 0))
	assert_near(far.x, 220.0, 0.01, "the far disc wins when it is the closest vision")
	assert_eq(VisionRegion.new().clamp_point(Vector3(9, 0, 9)), Vector3(9, 0, 9), "no vision, no clamp")


func test_the_regions_bounds_cover_every_disc() -> void:
	var region := VisionRegion.new()
	region.add(Vector3(-10, 0, 20), 30.0)
	region.add(Vector3(40, 0, -5), 15.0)
	var bounds := region.bounds()
	assert_eq(bounds.size(), 4, "a bounding box has four ground corners")
	var box := AABB(bounds[0], Vector3.ZERO)
	for corner: Vector3 in bounds:
		box = box.expand(corner)
	assert_near(box.position.x, -40.0, 0.01, "west edge = the west disc's rim")
	assert_near(box.end.x, 55.0, 0.01, "east edge = the east disc's rim")
	assert_near(box.position.z, -20.0, 0.01, "north edge")
	assert_near(box.end.z, 50.0, 0.01, "south edge")


# ---- The camera: framing, the cap, the look clamp ----------------------------------------------------------

func _state(frame: Array, region: VisionRegion, destination: Variant = null) -> Callable:
	return func() -> Dictionary:
		return {"frame": frame, "region": region, "destination": destination}


func test_the_camera_frames_the_element_as_close_as_it_can() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	for spot in [Vector3(-10, 0, 0), Vector3(10, 0, 0)]:
		region.add(spot, 80.0)
	rig.vision = _state([Vector3(-10, 0, 0), Vector3(10, 0, 0)], region)
	await wait_physics_frames(2)
	assert_true(rig.is_tracking(), "with a vision source the camera frames by itself")
	assert_eq(rig.tracking_mode(), RtsCamera.Track.VISION, "in vision mode")
	assert_true(rig.zoom < 0.3, "two units 20 m apart are framed close, not from orbit (zoom %.2f)" % rig.zoom)
	assert_true(RtsCamera.shows_all([Vector3(-10, 0, 0), Vector3(10, 0, 0)], rig.focus, rig.yaw, rig.zoom, 16.0 / 9.0),
			"and both are on screen")
	assert_true(rig.zoom < rig.vision_zoom, "closer than the force's horizon allows")


func test_the_force_cannot_zoom_out_past_what_it_can_see() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 40.0)
	rig.vision = _state([Vector3.ZERO], region)
	await wait_physics_frames(2)
	var cap := rig.vision_zoom
	assert_true(cap < 0.6, "a single 40 m sight disc earns only a low view (cap %.2f)" % cap)
	for i in 40:
		rig.zoom_by(0.1)
	assert_near(rig.zoom, cap, 0.001, "scrolling out stops at the cap: no unearned god view")
	var seeing := VisionRegion.new()
	for x in [-100.0, 100.0]:
		for z in [-100.0, 100.0]:
			seeing.add(Vector3(x, 0, z), 90.0)
	rig.vision = _state([Vector3.ZERO], seeing)
	await wait_physics_frames(2)
	assert_true(rig.vision_zoom > cap + 0.2, "a force spread across the arena earns a much wider view (%.2f)" % rig.vision_zoom)


func test_the_overview_key_shows_what_the_force_sees_not_the_arena() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3(0, 0, 60), 50.0)
	rig.vision = _state([Vector3(0, 0, 60)], region)
	await wait_physics_frames(2)
	rig.toggle_overview(Match.Team.GREEN)
	assert_true(rig.zoom <= rig.vision_zoom + 0.001, "Tab never climbs past the force's horizon (%.2f > %.2f)" % [rig.zoom, rig.vision_zoom])
	assert_true(region.contains(rig.focus), "and it looks at ground the force can see")


func test_looking_around_stays_over_ground_the_team_can_see() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 50.0)
	rig.vision = _state([Vector3.ZERO], region)
	await wait_physics_frames(2)
	rig.pan_world(Vector2(400.0, 0.0))
	assert_true(region.contains(rig.focus), "panning far east stops at the edge of the team's vision")
	assert_near(rig.focus.x, 50.0, 0.5, "on the rim of the disc (%s)" % rig.focus)


func test_the_player_takes_the_camera_and_gets_it_back() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 90.0)
	rig.vision = _state([Vector3(0, 0, 20)], region)
	rig.handback_seconds = 30.0
	await wait_physics_frames(2)
	assert_true(rig.is_tracking(), "the camera starts on the element")
	var ended: Array = []
	rig.tracking_ended.connect(func(reason: String) -> void: ended.append(reason))
	rig.pan_world(Vector2(0.0, -30.0))
	assert_true(not rig.is_tracking(), "a manual pan takes the camera")
	assert_eq(ended, ["manual"], "and says why")
	await wait_physics_frames(3)
	assert_true(not rig.is_tracking(), "it stays the player's while they are still looking")
	rig.handback_seconds = 0.0
	await wait_physics_frames(2)
	assert_true(rig.is_tracking(), "and comes back to the element after the pause")


# ---- Through the controls ---------------------------------------------------------------------------------

func _framed(frame: Array, point: Vector3) -> bool:
	for at: Vector3 in frame:
		if Vector2(at.x - point.x, at.z - point.z).length() < 1.5:
			return true
	return false


func test_selecting_an_element_moves_the_camera_to_it() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	f.rig.vision = f.controls.vision_state
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	await wait_physics_frames(3)
	var frame: Array = f.controls.vision_state()["frame"]
	for unit_name in ["Green_Bravo_1", "Green_Bravo_2"]:
		assert_true(_framed(frame, f.tank(unit_name).global_position), "%s is framed" % unit_name)
	assert_true(not _framed(frame, f.tank("Green_Alpha_1").global_position), "an unselected element is not")
	var middle := (f.tank("Green_Bravo_1").global_position + f.tank("Green_Bravo_2").global_position) / 2.0
	assert_true(Vector2(f.rig.focus.x - middle.x, f.rig.focus.z - middle.z).length() < 25.0,
			"the camera aims near the element (%s vs %s)" % [f.rig.focus, middle])
	assert_true(RtsCamera.shows_all([f.tank("Green_Bravo_1").global_position, f.tank("Green_Bravo_2").global_position],
			f.rig.focus, f.rig.yaw, f.rig.zoom, 1280.0 / 720.0), "and both units are on screen")
	print("MEASURE control_vision_zoom element=2 zoom=%.2f cap=%.2f" % [f.rig.zoom, f.rig.vision_zoom])
	f.controls.selection.clear()
	await wait_physics_frames(2)
	frame = f.controls.vision_state()["frame"]
	for unit_name in Fixture.SPOTS:
		if String(unit_name).begins_with("Green"):
			assert_true(_framed(frame, f.tank(unit_name).global_position), "with nothing selected the camera holds %s" % unit_name)


func test_an_element_frames_the_contacts_it_can_see() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	await f.select(["Green_Alpha_1"])
	var frame: Array = f.controls.vision_state()["frame"]
	assert_true(_framed(frame, f.tank("Green_Alpha_1").global_position), "the element is framed")
	assert_true(_framed(frame, f.tank("Rust_Alpha_1").global_position), "and the enemy it has spotted")
	f.tank("Rust_Alpha_1").global_position = Vector3(0, 0, -110)
	await wait_physics_frames(2)
	frame = f.controls.vision_state()["frame"]
	assert_eq(frame.size(), 1, "an enemy beyond the element's own sight is not framed")
