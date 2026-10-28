extends TestCase
## Round 43 (camera K5.2): the corner workload's geometry. CameraCorner.lanes finds, on any cover map, a lane along a
## building's long face past its far end with a hiding spot behind it the lane cannot see until the corner; lead_past
## measures how far his lead crew is past the wall's end; faces_building is "still just angled toward the building".

const NORTH := Vector2(0, -1)


## One 10 x 30 m warehouse at the origin, its long side north-south (half (5, 15) with axis +x: local z is the length).
func _warehouse(extra: Array = []) -> CoverMap:
	return CoverMap.from_features([{"position": Vector2.ZERO, "size": Vector2(10, 30), "axis": Vector2.RIGHT, "height": 6.0,
			"type": "warehouse"}] + extra)


func _lane(lanes: Array, along: Vector2, normal: Vector2) -> Dictionary:
	for l: Dictionary in lanes:
		if (l["along"] as Vector2).distance_to(along) < 0.01 and (l["normal"] as Vector2).distance_to(normal) < 0.01:
			return l
	return {}


func test_his_case_driving_north_with_the_building_to_the_east_hides_the_squad_to_the_right() -> void:
	var lanes := CameraCorner.lanes(_warehouse())
	assert_eq(lanes.size(), 4, "two ways down two long faces (%s)" % [lanes])
	var his := _lane(lanes, NORTH, Vector2(-1, 0))  # the lane on the west face, the hidden side east
	assert_true(not his.is_empty(), "his lane exists")
	assert_eq(his["side"], "right", "driving north (up the screen), east is to the right: clockwise, as he said")
	assert_near((his["start"] as Vector2).x, -14.0, 0.01, "the lane runs the first of LANE_OFFSETS_M off the face")
	assert_true((his["start"] as Vector2).y > 15.0 and (his["end"] as Vector2).y < -15.0, "from before the near end to past the far one")
	assert_true((his["hide"] as Vector2).x > 5.0, "the squad hides behind the building, on its east face")
	var other := _lane(lanes, NORTH, Vector2(1, 0))
	assert_eq(other["side"], "left", "down the east face the hidden side is west: left")


func test_a_short_or_low_feature_hides_no_corner_and_a_blocked_lane_is_dropped() -> void:
	var container := CoverMap.from_features([{"position": Vector2.ZERO, "size": Vector2(2.4, 6), "height": 2.6}])
	assert_eq(CameraCorner.lanes(container).size(), 0, "a container is shorter than MIN_WALL_M")
	var low := CoverMap.from_features([{"position": Vector2.ZERO, "size": Vector2(10, 30), "height": 1.0}])
	assert_eq(CameraCorner.lanes(low).size(), 0, "a low wall hides no hull")
	var blocked := _warehouse([{"position": Vector2(-14, 25), "size": Vector2(6, 6), "height": 3.0}])
	var lanes := CameraCorner.lanes(blocked)
	assert_true(_lane(lanes, NORTH, Vector2(-1, 0)).is_empty(), "a crate across the west lane drops it")
	assert_true(not _lane(lanes, NORTH, Vector2(1, 0)).is_empty(), "the east lane still stands")


func test_the_corner_opens_when_the_lead_crew_passes_the_far_end_and_the_view_faces_the_building() -> void:
	var map := _warehouse()
	var his := _lane(CameraCorner.lanes(map), NORTH, Vector2(-1, 0))
	var column := [Vector3(-14, 0, 0), Vector3(-14, 0, 9), Vector3(-14, 0, 18)]
	assert_near(CameraCorner.lead_past(his, column), -15.0, 0.01, "the lead at the building's middle: 15 m short")
	column[0] = Vector3(-14, 0, -20)
	assert_near(CameraCorner.lead_past(his, column), 5.0, 0.01, "the lead 5 m past the corner")
	var east := RtsCamera.yaw_facing(Vector3(1, 0, 0))
	assert_true(CameraCorner.faces_building(map, his, east, Vector3(-14, 0, 0)), "looking east from beside it: the wall")
	assert_true(not CameraCorner.faces_building(map, his, 0.0, Vector3(-14, 0, 0)), "looking north up the lane: open road")
	assert_true(not CameraCorner.faces_building(map, his, east, Vector3(-14, 0, -30)), "looking east past the corner: open")


func test_never_reads_twenty_seconds_and_no_opening_reads_null() -> void:
	assert_eq(CameraCorner._gap(3.0, 5.5), 2.5, "a gap")
	assert_eq(CameraCorner._gap(3.0, -1.0), CameraCorner.NEVER_S, "never on screen")
	assert_eq(CameraCorner._gap(-1.0, 5.0), null, "the corner never opened")


# ---- K5.3: the corner pull ----------------------------------------------------------------------------------------

func _column(lead_z: float) -> Array:
	return [Vector3(-14, 0, lead_z), Vector3(-14, 0, lead_z + 9), Vector3(-14, 0, lead_z + 18)]


func _centre(points: Array) -> Vector3:
	var sum := Vector3.ZERO
	for p: Vector3 in points:
		sum += p
	return sum / float(points.size())


func test_the_look_is_the_open_side_once_past_the_end_and_only_where_it_is_open() -> void:
	var map := _warehouse()
	var north := Vector3(0, 0, -1)
	var near := _column(-10.0)  # the lead 5 m short of the far end (z -15)
	assert_true(CameraCorner.pull(map, _centre(near), near, north)["look"] == null, "short of the corner: nothing yet")
	var lead_past := _column(-20.0)  # the lead 5 m past, the squad's centre (z -11) still beside the wall
	assert_true(CameraCorner.pull(map, _centre(lead_past), lead_past, north)["look"] == null, "the lead alone past: not yet")
	var at := _column(-30.0)  # the centre (z -21) 6 m past
	var p := CameraCorner.pull(map, _centre(at), at, north)
	assert_true(p["look"] is Vector3 and (p["look"] as Vector3).distance_to(Vector3(1, 0, 0)) < 0.01,
			"past it: along the open side's normal, east, his words (%s)" % [p])
	var gone := _column(-55.0)  # the centre 31 m past
	assert_true(CameraCorner.pull(map, _centre(gone), gone, north)["look"] == null, "well clear of it: not rounding it")
	assert_true(CameraCorner.pull(map, _centre(at), at, Vector3(1, 0, 0))["look"] == null, "driving AT the wall: not along it")
	var far := [Vector3(-60, 0, -20)]
	assert_true(CameraCorner.pull(map, far[0], far, north)["look"] == null, "a road beyond PULL_FAR_M is not beside it")
	# Bar K5's D2 miss: the next block stands across the open side (Locks' close blocks): no look.
	var blocked := _warehouse([{"position": Vector2(5, -24), "size": Vector2(6, 14), "axis": Vector2.RIGHT, "height": 6.0}])
	assert_true(CameraCorner.pull(blocked, _centre(at), at, north)["look"] == null, "a wall across the open side: no look")


func test_the_look_holds_until_his_next_order_a_turn_or_a_contact() -> void:
	var map := _warehouse()
	var north := Vector3(0, 0, -1)
	var at := _column(-30.0)
	var move := {"id": 7, "verb": "move"}
	var hold := CameraCorner.step({}, CameraCorner.pull(map, _centre(at), at, north), move, north, 0)
	assert_true(hold.get("look") is Vector3, "a quiet move past the corner takes the look")
	var gone := _column(-60.0)
	var later := CameraCorner.step(hold, CameraCorner.pull(map, _centre(gone), gone, north), move, north, 0)
	assert_eq(later, hold, "held after the corner, no easing back (one reversal fewer a corner)")
	assert_eq(CameraCorner.step(hold, {}, {"id": 8, "verb": "move"}, north, 0), {}, "his next order lets go")
	var turned := Vector3(1, 0, -0.5).normalized()  # 63 deg off north
	assert_eq(CameraCorner.step(hold, {}, move, turned, 0), {}, "the squad turning > 45 deg lets go")
	assert_eq(CameraCorner.step(hold, {}, move, Vector3(0.3, 0, -1).normalized(), 0), hold, "a 17 deg wiggle keeps it")
	assert_eq(CameraCorner.step(hold, {}, move, north, 1), {}, "a contact: K4 takes over")
	for verb in ["attack", "hold", ""]:
		assert_eq(CameraCorner.step({}, CameraCorner.pull(map, _centre(at), at, north), {"id": 7, "verb": verb}, north, 0), {},
				"not a quiet move (%s): no look" % verb)
	assert_true(CameraCorner.step({}, CameraCorner.pull(map, _centre(at), at, north), {"id": 9, "verb": "attack_move"}, north, 0)
			.get("look") is Vector3, "an attack-move with nothing known is a quiet move too")


func _state(from: Vector3, own: Array, enemies: Array = []) -> Dictionary:
	return {"from": from, "heading": Vector3(0, 0, -1), "speed": 8.0, "enemies": enemies, "middle": Vector3(-14, 0, -120),
			"own": own}


func test_in_the_look_it_swings_the_view_toward_the_open_side_and_a_gun_outranks_it() -> void:
	var map := _warehouse()
	var at := _column(-30.0)
	var state := _state(_centre(at), at)
	var quiet := RtsCamera.danger_look(state)
	assert_near(RtsCamera.yaw_facing(quiet["look"]), 0.0, 0.05, "without the pull: up the road (north)")
	state["corner"] = CameraCorner.step({}, CameraCorner.pull(map, state["from"], at, state["heading"]),
			{"id": 1, "verb": "move"}, state["heading"], 0)
	var swung := RtsCamera.danger_look(state)
	var bearing := rad_to_deg(RtsCamera.yaw_facing(swung["look"]))
	assert_true(bearing < -55.0 and bearing > -90.0, "clockwise, most of the way east (yaw %.0f; east is -90)" % bearing)
	assert_true(RtsCamera.corner_leads(swung), "the trace and the recording say corner")
	var gun := {"name": "Gun", "at": Vector3(-40, 0, -30), "seen": true, "age_s": 0.0, "fired_s": 0.5, "hit_s": DangerFeed.NEVER}
	var fired := _state(_centre(at), at, [gun])
	fired["corner"] = state["corner"]
	var shot := RtsCamera.danger_look(fired)
	assert_eq((shot["pulls"]["corner"] as Vector3).length(), 0.0, "a gun firing at him drops the corner pull")
	assert_true(not RtsCamera.corner_leads(shot), "the danger turn outranks it")


func test_the_corner_swing_ships_off_and_reads_no_enemy() -> void:
	var rig := RtsCamera.new()
	assert_true(not rig.corner_on, "OFF until Bar K5 passes")
	rig.free()
	# C43.6: the pull's inputs are the cover map and his units; an enemy cannot reach it.
	var args: Array = []
	for method: Dictionary in (load("res://game/camera/camera_corner.gd") as Script).get_script_method_list():
		if method["name"] == "pull":
			args = method["args"].map(func(a: Dictionary) -> String: return a["name"])
	assert_eq(args, ["map", "from", "own", "heading"], "walls and his units only")


func test_a_lane_beside_the_water_is_dropped() -> void:
	# A canal 4 m wide under the west lanes (x -11 to -18): Locks' quay case, where his crews never reached the corner.
	var water := CameraCorner.water_of({"terrain": [{"kind": "water", "rect": [-14.0, 0.0, 4.0, 300.0]},
			{"kind": "bridge", "rect": [0.0, 0.0, 16.0, 24.0]}]})
	assert_eq(water.size(), 1, "only water counts")
	var lanes := CameraCorner.lanes(_warehouse(), Match.DRIVABLE_LIMIT - 6.0, water)
	assert_eq(lanes.size(), 0, "the west lanes run in it and the east lanes' hiding spot (x -15) lies in it: %s" % [lanes])
	var dry := CameraCorner.lanes(_warehouse(), Match.DRIVABLE_LIMIT - 6.0,
			CameraCorner.water_of({"terrain": [{"kind": "water", "rect": [-40.0, 0.0, 4.0, 300.0]}]}))
	assert_eq(dry.size(), 4, "a canal 22 m off the west lane leaves all four")


func _yaw_run(rig: RtsCamera, feed: DangerFeed, frames: int) -> Array:
	rig.danger = feed.reader()
	rig.yaw = 0.0
	rig._yaw_turning = false
	rig._danger_settled_at = -1e9
	rig.corner_hold = {}
	var out: Array = []
	for i in frames:
		rig._update_yaw_follow(1.0 / 60.0)
		out.append(rig.yaw)
	return out


func test_no_fog_cheat_an_unseen_enemy_changes_no_yaw() -> void:
	# C43.6 (Bar K5's no-fog-cheat line, pinned): his squad drives north past a corner with the swing ON; an enemy his
	# team cannot see parked in the blind spot moves the yaw by not one bit.
	var arena := add_to_tree(load("res://game/arena/arena.tscn").instantiate())
	var m: Match = add_to_tree(load("res://game/match/match.tscn").instantiate())
	var mine := m.spawn_tank("Mine", 0, Match.Team.GREEN)
	mine.place(Vector3(-14, 0, -18), 0.0)
	var hidden := m.spawn_tank("Hidden", 0, Match.Team.RUST)
	hidden.place(Vector3(15, 0, -9), 0.0)
	await wait_physics_frames(1)
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	add_to_tree(camera)
	var rig := RtsCamera.new()
	rig.camera = camera
	rig.edge_pan = false
	add_to_tree(rig)
	rig.corner_on = true
	rig.order_now = func() -> Dictionary: return {"id": 1, "verb": "move"}
	rig.facing = func() -> Variant: return Vector3(0, 0, -1)
	var feed := DangerFeed.new().attach(m, Match.Team.GREEN, func() -> Array[String]: return ["Mine"],
			func(_t: Tank) -> bool: return false, rig.facing)
	var with_it := _yaw_run(rig, feed, 120)
	hidden.free()
	var without := _yaw_run(rig, feed, 120)
	assert_eq(with_it, without, "the yaw sequence is identical with and without the unseen enemy")
	assert_true(arena != null, "an arena (the cover map's source)")
