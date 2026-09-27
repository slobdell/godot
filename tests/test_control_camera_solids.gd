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
	var drawn := RtsCamera.drawn_layout(data)
	var touched := 0
	for at: Vector3 in _street_points(data):
		for step in 8:
			# Against what is DRAWN (round 12), as the live camera asks: the yard's ad screens and floodlights are
			# drawn 16-21 m tall, and at his pose the camera (17.6 m up) is still never inside one there.
			var clear := RtsCamera.clear_pose(at, TAU * float(step) / 8.0, HIS_DISTANCE, HIS_PITCH, drawn)
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
	var pose := RtsCamera.pose_at(at, 0.0, float(clear["distance"]), float(clear["pitch_deg"]))
	var got := pose.origin
	assert_true(Vector2(got.x - at.x, got.z - at.z).length() >= Vector2(asked.x - at.x, asked.z - at.z).length() - 0.01,
			"up and BACK, never in: the camera ends no nearer the fight across the ground")
	assert_true(got.y >= float(hull["top"]) + RtsCamera.SOLID_CLEAR_M - 0.01,
			"the camera ends above the deck (%.1f m over a %.1f m deck)" % [got.y, float(hull["top"])])
	assert_true(got.y <= float(hull["top"]) + RtsCamera.SOLID_CLEAR_M + 1.5, "and no higher than that takes (%.1f m)" % got.y)
	assert_eq(RtsCamera.hull_over(got, [hull]), -1.0, "so it is outside the hull")
	assert_true(not bool(clear["hull_passing"]), "and it did not give up")
	# ...and the point of it: the hull is IN HIS FRAME below the camera. Sample the hull's box and project it through
	# a camera at this pose; the tilt-about-the-focus version of this rule left the hull behind the camera.
	var in_frame := _hull_in_frame(pose, hull)
	assert_true(in_frame > 0.1, "the hull fills part of his frame after the lift (%.0f %% of its samples in view)" % (in_frame * 100.0))


## The share of points sampled over a hull box's surface that a camera at `pose` (his FOV, 16:9) has in view.
func _hull_in_frame(pose: Transform3D, box: Dictionary) -> float:
	var half_v := deg_to_rad(RtsCamera.FOV_DEG / 2.0)
	var half_h := atan(tan(half_v) * 16.0 / 9.0)
	var yaw := float(box["yaw"])
	var across := Vector3(cos(yaw), 0.0, -sin(yaw))
	var aft := Vector3(sin(yaw), 0.0, cos(yaw))
	var centre := Vector3((box["centre"] as Vector2).x, 0.0, (box["centre"] as Vector2).y)
	var half: Vector2 = box["half"]
	var seen := 0
	var total := 0
	for i in 11:
		for j in 5:
			for k in 3:
				var point := centre + across * lerpf(-half.x, half.x, j / 4.0) + aft * lerpf(-half.y, half.y, i / 10.0) \
						+ Vector3.UP * lerpf(float(box["bottom"]), float(box["top"]), k / 2.0)
				var local := pose.affine_inverse() * point
				total += 1
				if local.z < -0.5 and absf(atan2(local.y, -local.z)) <= half_v and absf(atan2(local.x, -local.z)) <= half_h:
					seen += 1
	return float(seen) / total


func test_a_hull_that_meets_the_camera_from_behind_still_ends_up_in_his_frame() -> void:
	## The case that broke the first two versions of this rule: the hull's centre 28 m BEHIND the camera (the Pit's
	## frame). Tilting about the focus or rising straight up both left it behind the lens.
	var data := {"half_size": 140.0, "obstacles": []}
	var at := Vector3.ZERO
	var asked := RtsCamera.pose_at(at, 0.0, HIS_DISTANCE, HIS_PITCH).origin
	# [hull yaw, centre behind the camera, the share of it that must be in view]. Broadside the camera ends right over
	# the middle of a 57 m hull and both ends run off a 60 deg frame (it measures 11 %); zero is the failure.
	for case: Array in [[0.0, 20.0, 0.25], [0.5, 15.0, 0.25], [PI / 2.0, 7.0, 0.08]]:
		var yaw := float(case[0])
		var hull := AirshipFlight.hull_box(Vector2(asked.x, asked.z + float(case[1])), yaw, SyndicateAdAirship.ALTITUDE)
		assert_true(RtsCamera.hull_over(asked, [hull]) > 0.0, "setup: his camera is inside the hull (yaw %.1f)" % yaw)
		var clear := RtsCamera.clear_pose(at, 0.0, HIS_DISTANCE, HIS_PITCH, data, [hull])
		var pose := RtsCamera.pose_at(at, 0.0, float(clear["distance"]), float(clear["pitch_deg"]))
		assert_eq(RtsCamera.hull_over(pose.origin, [hull]), -1.0, "outside the hull (yaw %.1f)" % yaw)
		var share := _hull_in_frame(pose, hull)
		assert_true(share > float(case[2]), "and the hull is in his frame, not behind him: %.0f %% of it in view (yaw %.1f)" % [
				share * 100.0, yaw])


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
	tower["top"] = 400.0  # higher than MAX_PITCH_DEG reaches even backed off the most (85.75 m run: 235.6 m)
	var clear := RtsCamera.clear_pose(at, 0.0, HIS_DISTANCE, HIS_PITCH, data, [tower])
	assert_true(float(clear["distance"]) >= HIS_DISTANCE - 0.001, "the boom is not pulled in for a hull")
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
	var back := 0.0
	var held_back := 0.0
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
			var went := RtsCamera.boom(0.0, float(over["distance"]), float(over["pitch_deg"]))
			var was := RtsCamera.boom(0.0, float(base["distance"]), float(base["pitch_deg"]))
			var wanted := maxf(0.0, went.y - was.y)
			var eased := RtsCamera.ease_hull_lift(lift, wanted, held, delta)
			var eased_back := RtsCamera.ease_hull_lift(back, maxf(0.0, went.z - was.z), held_back, delta)
			back = float(eased_back[0])
			held_back = float(eased_back[1])
			var moved := float(eased[0]) - lift
			lift = float(eased[0])
			held = float(eased[1])
			if absf(moved) > 0.01:
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
			var up := RtsCamera.raise_pose(float(base["distance"]), float(base["pitch_deg"]), lift, back)
			var shown := RtsCamera.clear_pose(focus, yaw, float(up[0]), minf(float(up[1]), RtsCamera.MAX_PITCH_DEG), layout)
			if RtsCamera.hull_over(RtsCamera.pose_at(focus, yaw, float(shown["distance"]), float(shown["pitch_deg"])).origin, [box]) > 0.0:
				inside += 1
	assert_true(episodes >= 1, "setup: the airship passed through his camera at least once in three minutes (%d)" % episodes)
	# One rise and one fall per pass is a reversal of one; anything more is the camera bobbing.
	assert_true(reversals <= episodes * 2, "the lift does not pump: %d direction changes over %d passes" % [reversals, episodes])
	assert_true(inside <= frames / 200, "and the camera is almost never inside the hull (%d of %d frames)" % [inside, frames])


# ---- Round 12 (camera K1): the camera asks the DRAWING, not the collider --------------------------------------
# `verification.md` *A collider is not a silhouette*: a floodlight's collider is 3 m and its drawn mast and lamp head
# 16 m; an ad screen's is 1.4 m and its LED wall 20.7 m; a sign has no collider and a 7.65 m board. The round-9
# measurement (703 of 4328 Terminus poses inside a solid, 0 after `clear_pose`) was against COLLIDERS. This sweep
# asks the same poses against both, per kit type, on every map he can be dealt.

## One sweep of `data`'s street grid at his pose, eight yaws each, the camera posed by `clear_pose` over `pose_data`
## (the colliders are what the camera read before round 12; `RtsCamera.drawn_layout` is what it reads after). Every
## camera is then judged against the colliders AND the drawing: inside a solid, and the sight line to the aim point
## blocked, counted per kit type (a pose blocked by two types counts under both; `any` counts it once).
func _drawn_sweep(data: Dictionary, pose_data: Dictionary, pitch: float) -> Dictionary:
	var drawn := RtsCamera.drawn_layout(data)
	var counts := {"poses": 0}
	for key: String in ["inside_collider", "inside_drawn", "blocked_collider", "blocked_drawn", "blocked_drawn_tall"]:
		counts[key] = {"any": 0}
	for at: Vector3 in _street_points(data):
		for step in 8:
			var yaw := TAU * float(step) / 8.0
			var clear := RtsCamera.clear_pose(at, yaw, HIS_DISTANCE, pitch, pose_data)
			var eye := RtsCamera.pose_at(at, yaw, float(clear["distance"]), float(clear["pitch_deg"])).origin
			var aim := at + Vector3.UP * BlockCutaway.AIM_HEIGHT_M
			counts["poses"] += 1
			_tally(counts["inside_collider"], [RtsCamera.solid_at(eye, data)])
			_tally(counts["inside_drawn"], [RtsCamera.solid_at(eye, drawn)])
			_tally(counts["blocked_collider"], RtsCamera.sight_blockers(eye, aim, data))
			_tally(counts["blocked_drawn"], RtsCamera.sight_blockers(eye, aim, drawn))
			# What the cutaway would have to take away: drawn solids tall enough to be a building to it.
			_tally(counts["blocked_drawn_tall"], RtsCamera.sight_blockers(eye, aim, drawn, BlockCutaway.MIN_HEIGHT_M))
	return counts


func _tally(into: Dictionary, solids: Array) -> void:
	var types := {}
	for solid: Dictionary in solids:
		if not solid.is_empty():
			types[String(solid.get("type", "?"))] = true
	if types.is_empty():
		return
	into["any"] += 1
	for type: String in types:
		into[type] = int(into.get(type, 0)) + 1


## His default tilt, and the tilt where his camera (49 m boom) is at a floodlight's lamp head: 15.1 m up, inside the
## 16.05 m drawn top. At 21 deg it is 17.6 m up and clears it, so the default pose alone cannot show the lamp head.
const DRAWN_PITCHES := [HIS_PITCH, 18.0]


func test_every_shipping_map_measured_against_what_is_drawn() -> void:
	## K1's table: the camera as posed from the COLLIDERS (the game before round 12) and as posed from the DRAWING,
	## each judged against both. Printed per map and tilt; the assertions are the round-9 invariant and the setup.
	for name: String in Arena.ROTATION:
		var data := _layout(name)
		var drawn := RtsCamera.drawn_layout(data)
		for pitch: float in DRAWN_PITCHES:
			for arm: String in ["collider", "drawn"]:
				var counts := _drawn_sweep(data, data if arm == "collider" else drawn, pitch)
				print("MEASURE camera_drawn_solids ", JSON.stringify({"map": name, "posed_from": arm, "counts": counts,
						"pitch_deg": pitch, "distance_m": HIS_DISTANCE}))
				assert_true(int(counts["poses"]) > 1000, "setup: %s has open ground to stand on (%d poses)" % [name, counts["poses"]])
				assert_eq(int(counts["inside_collider"]["any"]), 0,
						"%s at %.0f deg, posed from the %s: round 9 holds, the camera is outside every collider" % [name, pitch, arm])
				if arm == "drawn":
					# K2's bar: posed as the live camera now poses itself, it is inside nothing drawn.
					assert_eq(int(counts["inside_drawn"]["any"]), 0,
							"%s at %.0f deg: the camera is outside everything DRAWN (%s)" % [name, pitch, counts["inside_drawn"]])


func test_the_camera_reads_the_drawing_and_the_colliders_are_untouched() -> void:
	## C12.3: the collider never grows to fix a picture. The drawn list is a separate list; `Arena.active` is the
	## gameplay's and must come out of this exactly as it went in.
	var data := _layout(TERMINUS)
	var before := JSON.stringify(data)
	var drawn := RtsCamera.drawn_layout(data)
	assert_eq(JSON.stringify(data), before, "building the drawn list leaves the layout's colliders as they were")
	var grown := {}
	for entry: Dictionary in drawn["obstacles"]:
		if bool(entry.get("drawn", false)):
			grown[String(entry["type"])] = Arena.obstacle_size(entry)
	for type: String in ["floodlight", "ad_screen", "sign"]:
		assert_true(grown.has(type), "the Terminus's %s is on the drawn list" % type)
		if grown.has(type):
			assert_true(is_equal_approx((grown[type] as Vector3).y, float(AirshipFlight.DRAWN[type][1])),
					"%s stands %.2f m, the drawn height (the collider says %.2f)" % [type, (grown[type] as Vector3).y,
					float(ArenaKit.PROPS[type]["size"][1])])
	# The default is what the live camera reads: point it at the Terminus and it asks the drawing.
	var was := Arena.active
	Arena.active = data
	var seen := RtsCamera.seen()
	assert_eq((seen["obstacles"] as Array).size(), (drawn["obstacles"] as Array).size(), "`seen()` is the drawn list of Arena.active")
	assert_true(is_same(RtsCamera.seen(), seen), "and it is built once per arena, not once per frame")
	var flood: Dictionary = (data["obstacles"] as Array).filter(func(o: Dictionary) -> bool: return o["type"] == "floodlight")[0]
	var lamp := Vector3(float(flood["position"][0]), 15.0, float(flood["position"][1]))
	assert_true(RtsCamera.roof_over(lamp) > 15.0, "by default a point in the lamp head is inside the floodlight")
	assert_eq(RtsCamera.roof_over(lamp, data), -1.0, "and the colliders, asked explicitly, still say it is open air")
	Arena.active = was


func test_the_drawn_list_covers_what_the_kit_meshes_draw() -> void:
	## The camera reads `AirshipFlight.DRAWN` (C12.2); this holds the camera's use of it against the meshes
	## themselves (`AirshipTruth`, which shares no geometry with the table), so a kit change is found out here too.
	var layout := {"name": "t", "half_size": 60.0, "obstacles": [], "props": [
			{"type": "floodlight", "position": [0.0, 0.0]}, {"type": "sign", "position": [20.0, 0.0]},
			{"type": "ad_screen", "position": [-20.0, 0.0], "rotation_deg": 30.0}]}
	var truth := AirshipTruth.drawn_solids(layout)
	var drawn := RtsCamera.drawn_layout(Arena.normalize(layout))
	assert_eq(truth.size(), 3, "setup: three props drawn tall enough to matter")
	for solid: Dictionary in truth:
		var mine: Array = (drawn["obstacles"] as Array).filter(func(o: Dictionary) -> bool: return o["type"] == solid["type"])
		assert_eq(mine.size(), 1, "the camera knows about the %s" % solid["type"])
		if mine.is_empty():
			continue
		var size := Arena.obstacle_size(mine[0])
		assert_true(size.y >= float(solid["top"]) - 0.01, "%s: top %.2f covers the drawn %.2f" % [solid["type"], size.y, solid["top"]])
		assert_true(size.x / 2.0 >= (solid["half"] as Vector2).x - 0.01 and size.z / 2.0 >= (solid["half"] as Vector2).y - 0.01,
				"%s: footprint %v covers the drawn half %v" % [solid["type"], size, solid["half"]])
