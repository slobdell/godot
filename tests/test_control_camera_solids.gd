extends TestCase
## Round 9, control item 3, from the lead playing the Terminus: *"the camera often ends up inside a building and we
## can't see what's going on inside the alleyways. We need to make it so the camera is forced outside the solid for
## these cases."*
##
## The Terminus is 40 x 24 x 40 m blocks with 20 m streets. At his pose (21 deg, FOV 35, 49 m) the camera sits 17.6 m
## up and 45.7 m back, so a boom from a street crosses a block almost every time and 17.6 m is well under the roof.
## `RtsCamera.clear_pose` lifts the camera over the roof rather than pulling it in - the numbers are in rts_camera.gd,
## and the short version is that pulling in collapses 49 m to ~11 m and still leaves the far side of the street in
## the way, while lifting to 32 deg keeps 41.5 m of reach and looks DOWN INTO the alley.

const TERMINUS := "terminus"
## His pose, and the one every frame of this item is shot at.
const HIS_PITCH := 21.0
const HIS_DISTANCE := 49.0


## `Arena.load_layout` returns {"layout": ...} already normalized, or {"error": ...}.
func _layout(name: String) -> Dictionary:
	var loaded := Arena.load_layout(name)
	assert_true(not loaded.has("error"), "setup: %s loads (%s)" % [name, loaded.get("error", "")])
	return loaded.get("layout", {})


## Every ground point a unit could be standing on, on a grid across the arena: the focus is always somewhere a
## vehicle is, and a vehicle is never inside a building.
func _street_points(data: Dictionary) -> Array:
	var spots: Array = []
	var half: float = float(data.get("half_size", 140.0)) - 10.0
	var step := 10.0
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			var at := Vector3(x, 0.0, z)
			if RtsCamera.roof_over(at + Vector3.UP * 1.5, data) < 0.0:
				spots.append(at)
			z += step
		x += step
	return spots


func test_on_the_terminus_the_camera_is_never_left_inside_a_building() -> void:
	var data := _layout(TERMINUS)
	var streets := _street_points(data)
	assert_true(streets.size() > 100, "setup: the Terminus has open ground to stand on (%d spots)" % streets.size())
	var inside_before := 0
	var inside_after := 0
	var lifted := []
	var pulled := 0
	# A pan across the arena and a follow are both "the focus moves through the streets", and the camera can be
	# pointing any way while it happens: walk the whole grid at eight yaws, which is every frame of both.
	for at: Vector3 in streets:
		for step in 8:
			var yaw := TAU * float(step) / 8.0
			var asked := RtsCamera.pose_at(at, yaw, HIS_DISTANCE, HIS_PITCH).origin
			if RtsCamera.roof_over(asked, data) >= 0.0:
				inside_before += 1
			var clear := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, HIS_PITCH, data)
			var got := RtsCamera.pose_at(at, yaw, float(clear["distance"]), float(clear["pitch_deg"])).origin
			if RtsCamera.roof_over(got, data) >= 0.0:
				inside_after += 1
			if float(clear["lifted_deg"]) > 0.01:
				lifted.append(float(clear["lifted_deg"]))
			elif float(clear["distance"]) < HIS_DISTANCE - 0.01:
				pulled += 1
	var worst := 0.0
	for degrees: float in lifted:
		worst = maxf(worst, degrees)
	print("MEASURE terminus_camera_solids ", JSON.stringify({"poses": streets.size() * 8, "inside_before": inside_before,
			"inside_after": inside_after, "lifted": lifted.size(), "worst_lift_deg": snappedf(worst, 0.1),
			"pulled_in": pulled, "pitch_deg": HIS_PITCH, "distance_m": HIS_DISTANCE}))
	assert_true(inside_before > 0, "setup: the problem he reported is real at his pose (%d poses inside a block)" % inside_before)
	assert_eq(inside_after, 0, "after the fix the camera is outside every solid, at every spot and every yaw")
	assert_true(worst <= RtsCamera.MAX_PITCH_DEG - HIS_PITCH + 0.01,
			"and it never tilts past the range the player himself can reach (worst lift %.1f deg)" % worst)


func test_a_camera_in_the_open_is_left_exactly_where_the_player_put_it() -> void:
	# The yard has no cityscape: nothing here may move, or the fix has become a tax on every other arena.
	var data := _layout("yard")
	var touched := 0
	for at: Vector3 in _street_points(data):
		for step in 8:
			var clear := RtsCamera.clear_pose(at, TAU * float(step) / 8.0, HIS_DISTANCE, HIS_PITCH, data)
			if float(clear["lifted_deg"]) > 0.001 or not is_equal_approx(float(clear["distance"]), HIS_DISTANCE):
				touched += 1
	assert_eq(touched, 0, "an arena with nothing tall to be inside of leaves the camera alone")


func test_the_lift_is_what_it_takes_to_clear_that_roof_and_no_more() -> void:
	# One block, one camera aimed straight into it: the arithmetic, on its own, where it can be read.
	var data := {"half_size": 140.0, "obstacles": [
			{"type": "block", "position": [0.0, -40.0], "size": [40.0, 24.0, 40.0], "rotation_deg": 0.0}]}
	# yaw 0 puts the camera south of the focus; the focus just south of the block, looking north into it.
	var at := Vector3(0.0, 0.0, -10.0)
	var under := RtsCamera.pose_at(at, PI, HIS_DISTANCE, HIS_PITCH).origin
	assert_true(RtsCamera.roof_over(under, data) >= 0.0, "setup: the asked-for camera is inside the block (%s)" % [under])
	var clear := RtsCamera.clear_pose(at, PI, HIS_DISTANCE, HIS_PITCH, data)
	assert_true(is_equal_approx(float(clear["distance"]), HIS_DISTANCE),
			"the boom keeps its length: the view scale he chose does not change")
	var got := RtsCamera.pose_at(at, PI, float(clear["distance"]), float(clear["pitch_deg"])).origin
	assert_true(got.y >= 24.0 + RtsCamera.SOLID_CLEAR_M - 0.01,
			"the camera ends above the roof with room for its near plane (y %.1f)" % got.y)
	assert_true(got.y <= 24.0 + RtsCamera.SOLID_CLEAR_M + 1.5,
			"and no higher than it takes: this is an override of his tilt, so it spends the least it can (y %.1f)" % got.y)
	assert_true(float(clear["lifted_deg"]) > 0.0, "and it says it lifted, so the readout can tell him")


func test_a_solid_taller_than_the_boom_pulls_the_camera_in_instead() -> void:
	# The pathological case the lift cannot answer: no tilt short of straight down clears a roof higher than the
	# boom is long. The camera must still end up outside, and it must not end up on top of the focus.
	var data := {"half_size": 140.0, "obstacles": [
			{"type": "block", "position": [0.0, -40.0], "size": [40.0, 90.0, 40.0], "rotation_deg": 0.0}]}
	var at := Vector3(0.0, 0.0, -10.0)
	assert_true(RtsCamera.roof_over(RtsCamera.pose_at(at, PI, HIS_DISTANCE, HIS_PITCH).origin, data) >= 0.0,
			"setup: the asked-for camera is inside the tower")
	var clear := RtsCamera.clear_pose(at, PI, HIS_DISTANCE, HIS_PITCH, data)
	var got := RtsCamera.pose_at(at, PI, float(clear["distance"]), float(clear["pitch_deg"])).origin
	assert_eq(RtsCamera.roof_over(got, data), -1.0, "it is outside the tower (%s)" % [got])
	assert_true(float(clear["distance"]) < HIS_DISTANCE, "by pulling the boom in, since no tilt could clear it")
	assert_true(float(clear["distance"]) >= RtsCamera.SOLID_MIN_DISTANCE_M,
			"and never onto the focus itself (%.1f m)" % float(clear["distance"]))


## The OTHER half of his sentence. A camera outside every building can still be looking at the side of one, and
## "we can't see what's going on inside the alleyways" is that half. `sight_blocked` is the test the alley frames
## label themselves with, and the primitive an occlusion cutaway would need if the frames call for one.
func test_a_sight_line_knows_when_a_building_is_in_the_way() -> void:
	var data := {"half_size": 140.0, "obstacles": [
			{"type": "block", "position": [0.0, 0.0], "size": [40.0, 24.0, 40.0], "rotation_deg": 0.0}]}
	# Straight through the middle of the block, at street height.
	assert_true(RtsCamera.sight_blocked(Vector3(-60, 1.5, 0), Vector3(60, 1.5, 0), data), "through the block")
	# Down the street beside it: 30 m out on x, the block only reaches 20.
	assert_true(not RtsCamera.sight_blocked(Vector3(-60, 1.5, 30), Vector3(60, 1.5, 30), data), "down the street beside it")
	# Over the roof: 24 m is the roof, so 30 m clears it at both ends.
	assert_true(not RtsCamera.sight_blocked(Vector3(-60, 30, 0), Vector3(60, 30, 0), data), "over the roof")
	# A segment that stops short of the block is not blocked by it: the test is the SEGMENT, not the ray.
	assert_true(not RtsCamera.sight_blocked(Vector3(-60, 1.5, 0), Vector3(-30, 1.5, 0), data), "stopping short of it")
	# A rotated box is tested in ITS OWN frame, not by its bounding box. A 40 x 8 m slab turned 90 degrees runs
	# along world Z and is only 8 m wide in X, so a sight line down Z at x = 15 misses it - and would have been
	# blocked by the same slab unturned, whose 40 m length lies along X.
	var turned := {"half_size": 140.0, "obstacles": [
			{"type": "block", "position": [0.0, 0.0], "size": [40.0, 24.0, 8.0], "rotation_deg": 90.0}]}
	assert_true(not RtsCamera.sight_blocked(Vector3(15, 1.5, -40), Vector3(15, 1.5, 40), turned),
			"past the turned slab's narrow side, where its unturned self would have been in the way")
	assert_true(RtsCamera.sight_blocked(Vector3(-20, 1.5, 0), Vector3(20, 1.5, 0), turned),
			"and straight through its 8 m width")


## What the lift buys on the real map, as a number rather than a claim: how often the alley is behind a wall before
## and after. This is the measurement the frames are read against - if the lift left the alley just as walled, the
## mechanism would be answering his sentence and not his problem.
func test_the_lift_does_not_trade_being_inside_a_block_for_staring_at_one() -> void:
	var data := _layout(TERMINUS)
	var inside := 0
	var walled_before := 0
	var walled_after := 0
	var poses := 0
	for at: Vector3 in _street_points(data):
		for step in 8:
			var yaw := TAU * float(step) / 8.0
			var asked := RtsCamera.pose_at(at, yaw, HIS_DISTANCE, HIS_PITCH).origin
			if RtsCamera.roof_over(asked, data) < 0.0:
				continue  # only the poses he complained about
			poses += 1
			inside += 1
			var eye := at + Vector3.UP * 1.5
			if RtsCamera.sight_blocked(asked, eye, data):
				walled_before += 1
			var clear := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, HIS_PITCH, data)
			if RtsCamera.sight_blocked(RtsCamera.pose_at(at, yaw, float(clear["distance"]), float(clear["pitch_deg"])).origin, eye, data):
				walled_after += 1
	print("MEASURE terminus_alley_sight ", JSON.stringify({"poses_inside_a_block": poses,
			"alley_walled_before": walled_before, "alley_walled_after": walled_after,
			"pitch_deg": HIS_PITCH, "distance_m": HIS_DISTANCE}))
	assert_true(poses > 0, "setup: there are poses to judge")
	assert_true(walled_after <= walled_before,
			"the fix never makes the alley MORE hidden than it already was (%d -> %d of %d)" % [walled_before, walled_after, poses])


## Item 3's SECOND half and its pre-registered falsifier (the orchestrator, 2026-09-20): with the building between
## the camera and what it is aimed at not drawn, the sight line blocked at his pose on the Terminus goes from **518
## to under 50** over the same 703 poses. The remainder is cover, which is deliberately never cut: a container
## between the camera and the fight is *information*, and hiding it would hide why a unit stopped where it did.
func test_cutting_the_building_in_the_way_clears_the_alley() -> void:
	var data := _layout(TERMINUS)
	var poses := 0
	var walled := 0
	var still_walled := 0
	for at: Vector3 in _street_points(data):
		for step in 8:
			var yaw := TAU * float(step) / 8.0
			if RtsCamera.roof_over(RtsCamera.pose_at(at, yaw, HIS_DISTANCE, HIS_PITCH).origin, data) < 0.0:
				continue  # the 703 poses he complained about, and nothing else
			poses += 1
			var clear := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, HIS_PITCH, data)
			var eye := RtsCamera.pose_at(at, yaw, float(clear["distance"]), float(clear["pitch_deg"])).origin
			var aim := at + Vector3.UP * BlockCutaway.AIM_HEIGHT_M
			if RtsCamera.sight_blocked(eye, aim, data):
				walled += 1
			# What the player sees once the cutaway has run: every solid at least MIN_HEIGHT_M tall between the
			# camera and the aim point is not drawn, so only shorter things can still be in the way.
			if RtsCamera.sight_blocked(eye, aim, data, 0.0) and not RtsCamera.sight_blocked(eye, aim, data, BlockCutaway.MIN_HEIGHT_M):
				pass  # blocked only by cover, which stays drawn on purpose
			if RtsCamera.sight_blocked(eye, aim, data, 0.0) and RtsCamera.sight_blocked(eye, aim, data, BlockCutaway.MIN_HEIGHT_M):
				still_walled += 1
	var after := walled - still_walled
	print("MEASURE terminus_block_cutaway ", JSON.stringify({"poses": poses, "walled_before_cutaway": walled,
			"walled_by_a_building": still_walled, "walled_after_cutaway": after,
			"min_height_m": BlockCutaway.MIN_HEIGHT_M, "pitch_deg": HIS_PITCH, "distance_m": HIS_DISTANCE}))
	assert_true(poses > 0, "setup: there are poses to judge")
	assert_true(after < 50, "the pre-registered bar: sight line blocked 518 -> under 50, got %d of %d" % [after, poses])


## The cutaway's own rule, on its own: a BUILDING between the camera and the aim point is cut, COVER never is, and a
## building that is not in the way is left alone. `segment_hits_box` is the one definition both the measurement above
## and `BlockCutaway` use, so they cannot disagree about what "in the way" means.
func test_only_buildings_are_cut_and_only_when_they_are_in_the_way() -> void:
	var tall := Vector3(20.0, 24.0, 20.0)
	var low := Vector3(20.0, 2.5, 20.0)
	var camera_at := Vector3(0.0, 18.0, 60.0)
	var aim := Vector3(0.0, BlockCutaway.AIM_HEIGHT_M, 0.0)
	# A building straddling the sight line, halfway along it.
	assert_true(RtsCamera.segment_hits_box(camera_at, aim, Vector3(0.0, tall.y / 2.0, 30.0), tall / 2.0, 0.0),
			"a building between the camera and what it is aimed at is in the way")
	# The same footprint, cover height: the sight line passes over it, so it was never in the way to begin with.
	assert_true(not RtsCamera.segment_hits_box(camera_at, aim, Vector3(0.0, low.y / 2.0, 30.0), low / 2.0, 0.0),
			"cover the sight line passes over is not in the way")
	assert_true(low.y < BlockCutaway.MIN_HEIGHT_M and tall.y >= BlockCutaway.MIN_HEIGHT_M,
			"and only the taller of the two would ever be cut at all")
	# A building beside the line, and one behind the camera: neither is in the way.
	assert_true(not RtsCamera.segment_hits_box(camera_at, aim, Vector3(40.0, tall.y / 2.0, 30.0), tall / 2.0, 0.0),
			"a building beside the sight line is left alone")
	assert_true(not RtsCamera.segment_hits_box(camera_at, aim, Vector3(0.0, tall.y / 2.0, 90.0), tall / 2.0, 0.0),
			"and one BEHIND the camera is left alone: the test is the segment, not the ray")


## `BlockCutaway` on the real arena node tree, not on the pure maths. The maths was green while the thing itself cut
## nothing in a real run (`cut: []` on every alley frame), which is the whole reason this test exists: the boxes it
## reads come from CollisionShape3D children of each body, and a wrong node name or a missed shape is invisible to
## `segment_hits_box`.
func test_the_cutaway_finds_the_arenas_buildings_and_hides_the_one_in_the_way() -> void:
	# `Arena._ready` picks its layout from `layout_name` or --arena, NOT from `Arena.active`: setting `active` and
	# instantiating gets you the DEFAULT arena, which has no city blocks at all (the first version of this test
	# measured "0 buildings" on the foundry and blamed the cutaway).
	var arena := preload("res://game/arena/arena.tscn").instantiate()
	arena.layout_name = TERMINUS
	add_to_tree(arena)
	await wait_physics_frames(2)
	assert_eq(String(Arena.active.get("name", "")), TERMINUS, "setup: the arena really built the Terminus")
	var obstacles := arena.get_node_or_null("Obstacles") as Node3D
	assert_true(obstacles != null and obstacles.get_child_count() > 0,
			"setup: the Terminus builds obstacle bodies (%s)" % [obstacles.get_child_count() if obstacles != null else -1])
	var camera := Camera3D.new()
	add_to_tree(camera)
	var cutaway := BlockCutaway.new()
	cutaway.camera = camera
	cutaway.obstacles_root = obstacles
	add_to_tree(cutaway)
	# `_gather` runs in `_process`, not on ready: read `_solids` before a process frame has happened and it is empty.
	# (It was, and the first version of this test called that a cutaway failure.)
	await tree.process_frame
	await tree.process_frame
	var solids: Array = cutaway._solids
	print("MEASURE block_cutaway_gather ", JSON.stringify({"bodies": obstacles.get_child_count(), "buildings": solids.size()}))
	assert_true(solids.size() >= 8, "it finds the Terminus's city blocks as buildings (%d of %d bodies)" % [
			solids.size(), obstacles.get_child_count()])
	# Stand in a street with a building between the camera and the aim point, at his pose, and look.
	var data: Dictionary = Arena.active
	var found := false
	for at: Vector3 in _street_points(data):
		for step in 8:
			var yaw := TAU * float(step) / 8.0
			var clear := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, HIS_PITCH, data)
			var eye := RtsCamera.pose_at(at, yaw, float(clear["distance"]), float(clear["pitch_deg"]))
			if not RtsCamera.sight_blocked(eye.origin, at + Vector3.UP * BlockCutaway.AIM_HEIGHT_M, data, BlockCutaway.MIN_HEIGHT_M):
				continue
			camera.global_transform = eye
			await tree.process_frame
			await tree.process_frame
			var cut := cutaway.cut_blocks()
			print("MEASURE block_cutaway_one_pose ", JSON.stringify({"at": [at.x, at.z], "yaw_deg": snappedf(rad_to_deg(yaw), 1.0),
					"cut": cut, "aim": str(cutaway.aim_point())}))
			assert_true(cut.size() > 0, "a building on the sight line is cut (%s)" % [cut])
			for solid: Dictionary in solids:
				var body: Node3D = solid["body"]
				var visual: Node3D = solid["visual"]
				if cut.has(String(body.name)):
					assert_true(not visual.visible, "%s is the one in the way, so it is not drawn" % body.name)
				else:
					assert_true(visual.visible, "%s is not in the way, so it is still drawn" % body.name)
			found = true
			break
		if found:
			break
	assert_true(found, "setup: some street on the Terminus has a building on the sight line at his pose")


# ---- Round 11: the airship. *"if the camera and airship intersected, we push the camera up above the airship (that
# way there's more likelihood of seeing the cool airship for an in-game effect)"* ------------------------------------

## A hull-sized box around the point the camera asked for: 57 x 22 m, belly 7.4 m, deck 22.8 m (the cruise heights).
func _hull_around(point: Vector3, yaw := 0.3) -> Dictionary:
	return AirshipFlight.hull_box(Vector2(point.x, point.z), yaw, SyndicateAdAirship.ALTITUDE)


func test_the_camera_is_lifted_over_the_airship_not_pulled_in() -> void:
	var data := {"half_size": 140.0, "obstacles": []}
	var at := Vector3(10.0, 0.0, 5.0)
	var asked := RtsCamera.pose_at(at, 0.0, HIS_DISTANCE, HIS_PITCH).origin
	var hull := _hull_around(asked)
	assert_true(RtsCamera.hull_over(asked, [hull]) > 0.0, "setup: his camera (%.1f m up) is inside the hull" % asked.y)
	var clear := RtsCamera.clear_pose(at, 0.0, HIS_DISTANCE, HIS_PITCH, data, [hull])
	var got := RtsCamera.pose_at(at, 0.0, float(clear["distance"]), float(clear["pitch_deg"])).origin
	assert_near(float(clear["distance"]), HIS_DISTANCE, 0.001, "the boom keeps its length -- up, never in")
	assert_true(got.y >= float(hull["top"]) + RtsCamera.SOLID_CLEAR_M - 0.01,
			"the camera ends above the deck (%.1f m over a %.1f m deck)" % [got.y, float(hull["top"])])
	assert_true(got.y <= float(hull["top"]) + RtsCamera.SOLID_CLEAR_M + 1.5, "and no higher than that takes (%.1f m)" % got.y)
	assert_eq(RtsCamera.hull_over(got, [hull]), -1.0, "so it is outside the hull")
	# ...and the hull is now BELOW the camera, in front of it: that is the point of the lift.
	var to_hull := (Vector3(asked.x, float(hull["top"]), asked.z) - got)
	assert_true(to_hull.y < 0.0, "the deck is below the lifted camera, so the hull is in his frame")
	assert_true(not bool(clear["hull_passing"]), "and it did not give up")


func test_no_occluders_means_exactly_the_building_rule() -> void:
	var data := _layout(TERMINUS)
	for at: Vector3 in _street_points(data).slice(0, 60):
		for step in 4:
			var yaw := TAU * float(step) / 4.0
			var old := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, HIS_PITCH, data)
			var new := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, HIS_PITCH, data, [])
			assert_true(is_equal_approx(float(old["pitch_deg"]), float(new["pitch_deg"]))
					and is_equal_approx(float(old["distance"]), float(new["distance"])), "unchanged at %s yaw %d" % [at, step])


func test_a_hull_no_tilt_can_clear_is_let_pass_rather_than_yanking_the_boom() -> void:
	## "Lift, don't shorten": a camera jerked in during a fight is worse than a moment of hull, and the hull moves on.
	var data := {"half_size": 140.0, "obstacles": []}
	var at := Vector3.ZERO
	var asked := RtsCamera.pose_at(at, 0.0, HIS_DISTANCE, HIS_PITCH).origin
	var tower := _hull_around(asked)
	tower["top"] = 80.0  # taller than any tilt of a 49 m boom can clear
	var clear := RtsCamera.clear_pose(at, 0.0, HIS_DISTANCE, HIS_PITCH, data, [tower])
	assert_near(float(clear["distance"]), HIS_DISTANCE, 0.001, "the boom is not pulled in for a hull")
	assert_true(bool(clear["hull_passing"]), "it says it let the hull pass")


func test_a_passing_airship_lifts_the_camera_once_and_does_not_pump() -> void:
	## It MOVES: a hull sliding through the frame must raise the camera once and let it down once, not make it bob.
	## Fly the real flight on the yard for three minutes past a camera parked on its orbit, at 60 frames a second
	## through the same damping the live camera uses, and count how often the lift changes direction.
	var layout: Dictionary = Arena.load_layout("yard")["layout"]
	var flight := AirshipFlight.new(layout)
	# The camera sits 45.75 m south of its focus at yaw PI; park it on the orbit (radius 62 round the middle).
	var focus := Vector3(0.0, 0.0, -AirshipPilot.ORBIT_RADIUS + SyndicateAdAirship.camera_run())
	var yaw := PI
	var lift := 0.0
	var held := 0.0
	var direction := 0
	var reversals := 0
	var episodes := 0
	var inside := 0
	var frames := 0
	var delta := 1.0 / 60.0
	for tick in int(SimClock.TICK_RATE * 180.0):
		flight.step()
		var box := AirshipFlight.hull_box(flight.pilot.position, flight.pilot.heading,
				flight.altitude + float(SyndicateAdAirship.float_offsets(float(tick) / SimClock.TICK_RATE)["rise"]))
		for frame in 2:
			frames += 1
			var base := RtsCamera.clear_pose(focus, yaw, HIS_DISTANCE, HIS_PITCH, layout)
			var over := RtsCamera.clear_pose(focus, yaw, HIS_DISTANCE, HIS_PITCH, layout, [box], RtsCamera.HULL_LEAD_M)
			var wanted := maxf(0.0, float(over["pitch_deg"]) - float(base["pitch_deg"]))
			var eased := RtsCamera.ease_hull_lift(lift, wanted, held, delta)
			var moved := float(eased[0]) - lift
			lift = float(eased[0])
			held = float(eased[1])
			if absf(moved) > 0.002:
				var now := 1 if moved > 0.0 else -1
				if direction == 0 and now > 0:
					episodes += 1
				elif direction != 0 and now != direction:
					reversals += 1
					if now > 0:
						episodes += 1
				direction = now
			elif lift < 0.01:
				direction = 0
			var shown := RtsCamera.clear_pose(focus, yaw, HIS_DISTANCE, minf(HIS_PITCH + lift, RtsCamera.MAX_PITCH_DEG), layout)
			if RtsCamera.hull_over(RtsCamera.pose_at(focus, yaw, float(shown["distance"]), float(shown["pitch_deg"])).origin, [box]) > 0.0:
				inside += 1
	assert_true(episodes >= 1, "setup: the airship passed through his camera at least once in three minutes (%d)" % episodes)
	# One rise and one fall per pass is a reversal of one; anything more is the camera bobbing.
	assert_true(reversals <= episodes * 2, "the lift does not pump: %d direction changes over %d passes" % [reversals, episodes])
	assert_true(inside <= frames / 200, "and the camera is almost never inside the hull (%d of %d frames)" % [inside, frames])
