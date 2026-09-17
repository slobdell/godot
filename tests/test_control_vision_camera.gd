extends TestCase
## Control X1 (L4): the vision-framed camera. The sight region's math, the auto frame that sits as close as the
## commanded element allows, the zoom-out cap the force's collective sight earns ("no unearned god view"), the
## "look" clamp that keeps a free camera over ground the team can see, and manual override with hand-back.

const Fixture := preload("res://tests/support/control_fixture.gd")


## The camera runs in _process (it must keep working while the tree is paused), so these tests wait for render
## frames, not physics ticks: a physics frame can pass without _process running at all.
func _frames(count := 2) -> void:
	for i in count:
		await tree.process_frame


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
	# The camera re-clamps its focus every frame, so a clamped point the region then disowns would be nudged for
	# ever. Landing exactly on the rim is a coin toss across machines (it failed once on a loaded builder0), so
	# clamp_point lands just inside it and this invariant has to hold for every direction.
	for i in 16:
		var angle := TAU * i / 16.0
		var outside := Vector3(cos(angle), 0.0, sin(angle)) * 500.0
		assert_true(region.contains(region.clamp_point(outside)), "a point clamped from %.0f deg is seen" % rad_to_deg(angle))
	assert_true(region.contains(region.clamp_point(Vector3(60.0000001, 0, 0))), "including one a hair outside the rim")
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
	await _frames(2)
	assert_true(rig.is_tracking(), "with a vision source the camera frames by itself")
	assert_eq(rig.tracking_mode(), RtsCamera.Track.VISION, "in vision mode")
	print("MEASURE control_vision_frame pair_zoom=%.2f cap=%.2f" % [rig.zoom, rig.vision_zoom])
	assert_true(rig.zoom < 0.35, "two units 20 m apart are framed close, not from orbit (zoom %.2f)" % rig.zoom)
	assert_true(RtsCamera.shows_all([Vector3(-10, 0, 0), Vector3(10, 0, 0)], rig.focus, rig.yaw, rig.zoom, 16.0 / 9.0),
			"and both are on screen")
	assert_true(rig.zoom < rig.vision_zoom, "closer than the force's horizon allows")


func test_the_force_cannot_zoom_out_past_what_it_can_see() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 40.0)
	rig.vision = _state([Vector3.ZERO], region)
	await _frames(2)
	var cap := rig.vision_zoom
	print("MEASURE control_vision_cap sight_40m=%.2f" % cap)
	assert_true(cap < 0.6, "a single 40 m sight disc earns only a low view (cap %.2f)" % cap)
	assert_true(cap >= RtsCamera.VISION_CAP_FLOOR, "but never tighter than the floor")
	for i in 40:
		rig.zoom_by(0.1)
	assert_near(rig.zoom, cap, 0.001, "scrolling out stops at the cap: no unearned god view")
	var seeing := VisionRegion.new()
	for x in [-60.0, 60.0]:
		for z in [-60.0, 60.0]:
			seeing.add(Vector3(x, 0, z), 90.0)
	rig.vision = _state([Vector3.ZERO], seeing)
	await _frames(RtsCamera.VISION_CAP_EVERY + 2)
	print("MEASURE control_vision_cap spread_force=%.2f" % rig.vision_zoom)
	assert_true(rig.vision_zoom > cap + 0.2, "a force spread across the arena earns a much wider view (%.2f)" % rig.vision_zoom)


func test_the_cap_measures_the_ground_the_screen_shows_not_a_bounding_box() -> void:
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 50.0)
	var aspect := 16.0 / 9.0
	var close := RtsCamera.seen_fraction(region, Vector3.ZERO, 0.0, 0.2, aspect)
	var wide := RtsCamera.seen_fraction(region, Vector3.ZERO, 0.0, 0.95, aspect)
	assert_true(close > wide, "zoomed in, more of the screen is ground you can see (%.2f vs %.2f)" % [close, wide])
	assert_true(wide < RtsCamera.VISION_SEEN_FRACTION, "from high up a lone unit's disc cannot fill the screen")
	assert_eq(RtsCamera.seen_fraction(VisionRegion.new(), Vector3.ZERO, 0.0, 0.5, aspect), 0.0, "no vision, nothing seen")
	assert_eq(RtsCamera.horizon_zoom(null, Vector3.ZERO, 0.0, aspect), 1.0, "no region, no cap")
	# A point far outside the region: the screen is mostly ground the force cannot see, so the cap bottoms out.
	assert_near(RtsCamera.horizon_zoom(region, Vector3(400, 0, 400), 0.0, aspect), RtsCamera.VISION_CAP_FLOOR, 0.001,
			"looking at ground nobody can see earns only the floor")


func test_the_overview_key_shows_what_the_force_sees_not_the_arena() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3(0, 0, 60), 50.0)
	rig.vision = _state([Vector3(0, 0, 60)], region)
	await _frames(2)
	rig.toggle_overview(Match.Team.GREEN)
	assert_true(rig.zoom <= rig.vision_zoom + 0.001, "Tab never climbs past the force's horizon (%.2f > %.2f)" % [rig.zoom, rig.vision_zoom])
	assert_true(region.contains(rig.focus), "and it looks at ground the force can see")


func test_looking_around_stays_over_ground_the_team_can_see() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 50.0)
	rig.vision = _state([Vector3.ZERO], region)
	await _frames(2)
	rig.pan_world(Vector2(400.0, 0.0))
	assert_true(region.contains(rig.focus), "panning far east stops at the edge of the team's vision")
	assert_near(rig.focus.x, 50.0, 0.5, "just inside the rim of the disc (%s)" % rig.focus)


func test_the_player_takes_the_camera_and_gets_it_back() -> void:
	var rig := _rig()
	var region := VisionRegion.new()
	region.add(Vector3.ZERO, 90.0)
	rig.vision = _state([Vector3(0, 0, 20)], region)
	rig.handback_seconds = 30.0
	await _frames(2)
	assert_true(rig.is_tracking(), "the camera starts on the element")
	var ended: Array = []
	rig.tracking_ended.connect(func(reason: String) -> void: ended.append(reason))
	rig.pan_world(Vector2(0.0, -30.0))
	assert_true(not rig.is_tracking(), "a manual pan takes the camera")
	assert_eq(ended, ["manual"], "and says why")
	await _frames(3)
	assert_true(not rig.is_tracking(), "it stays the player's while they are still looking")
	rig.handback_seconds = 0.0
	await _frames(2)
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
	await _frames(3)
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
	await _frames(2)
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
	await _frames(2)
	frame = f.controls.vision_state()["frame"]
	assert_eq(frame.size(), 1, "an enemy beyond the element's own sight is not framed")


## Round 5 (the lead: "it ends up focusing on the enemy instead of our own friendly units"): a big enemy army in sight
## may widen the frame, but the camera stays centred on the element it is framing, and the element stays on screen.
func test_a_mass_of_contacts_never_pulls_the_camera_off_your_element() -> void:
	var f := Fixture.new(self)
	await f.build_scale(30)
	f.rig.vision = f.controls.vision_state
	f.controls.recall_group(1)
	await _frames(40)
	var element: Array = []
	var middle := Vector3.ZERO
	for unit_name in f.controls.groups.members(1):
		element.append(f.tank(unit_name).global_position)
		middle += f.tank(unit_name).global_position
	middle /= element.size()
	var enemy := Vector3.ZERO
	var enemies := f.game_match.sorted_team_tanks(Match.Team.RUST)
	for tank in enemies:
		enemy += tank.global_position
	enemy /= enemies.size()
	var aim := f.rig.focus
	var to_element := Vector2(aim.x - middle.x, aim.z - middle.z).length()
	var to_enemy := Vector2(aim.x - enemy.x, aim.z - enemy.z).length()
	assert_true(to_element < to_enemy, "the screen's centre is nearer your element than the enemy (%.0f m vs %.0f m)" % [to_element, to_enemy])
	assert_true(RtsCamera.shows_all(element, f.rig.focus, f.rig.yaw, f.rig.zoom, 1920.0 / 1080.0, 1.0),
			"every vehicle of the element is on screen (focus %s zoom %.2f)" % [f.rig.focus, f.rig.zoom])


## Round 5 (combat's 30 Hz tick with physics interpolation): what follows a vehicle on screen reads where it is drawn.
func test_on_screen_followers_read_the_drawn_position_and_the_camera_is_not_interpolated_twice() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var tank := f.tank("Green_Alpha_1")
	assert_eq(Shown.at(tank), tank.get_global_transform_interpolated().origin, "Shown reads the interpolated transform")
	assert_eq(Shown.ground(tank).y, 0.0, "ground points sit on the ground")
	assert_eq(f.camera.physics_interpolation_mode, Node.PHYSICS_INTERPOLATION_MODE_OFF,
			"the rig's camera moves every frame by itself, so physics interpolation stays off it")
