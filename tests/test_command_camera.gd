extends TestCase
## C4: the camera follows orders. RtsCamera.frame(points) shows a set of ground points; after an order
## to somewhere off screen the camera tracks the squad and its destination until arrival, a manual pan,
## or another selection; it moves gently (speed-limited) and never fights the player.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func test_frame_pose_fits_the_points_and_zooms_only_as_far_as_needed() -> void:
	var aspect := 16.0 / 9.0
	var tight := [Vector3(0, 0, 50), Vector3(6, 0, 52)]
	var wide := [Vector3(-50, 0, 60), Vector3(55, 0, -40)]
	var tight_pose := RtsCamera.frame_pose(tight, 0.0, aspect)
	var wide_pose := RtsCamera.frame_pose(wide, 0.0, aspect)
	assert_true(float(tight_pose[1]) >= RtsCamera.FRAME_MIN_ZOOM and float(tight_pose[1]) < 0.4,
			"a tight squad frames close up (%.2f)" % tight_pose[1])
	assert_true(float(wide_pose[1]) > float(tight_pose[1]) + 0.2, "far-apart points need a higher view (%.2f)" % wide_pose[1])
	for pose in [tight_pose, wide_pose]:
		var points: Array = tight if pose == tight_pose else wide
		assert_true(RtsCamera.shows_all(points, pose[0], 0.0, pose[1], aspect), "every point is on screen at the framed pose")
	var turned := RtsCamera.frame_pose(wide, PI / 2.0, aspect)
	assert_true(RtsCamera.shows_all(wide, turned[0], PI / 2.0, turned[1], aspect), "framing works from any yaw")


func _setup() -> Array:
	tree.root.size = Vector2i(1280, 720)
	var arena := ARENA.instantiate()
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, Doctrine.load_file("res://doctrines/player_default.json")["doctrine"]), "",
			"setup: player doctrine")
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	RtsCamera.fov = 55.0  # round 5's lens: these tests are about screen geometry, written for it (the default is the lead's 35° telephoto)
	rig.camera = camera
	rig.edge_pan = false
	add_to_tree(rig)
	# Aimed at squad Alpha's middle (round 6: the army now starts in formation, a wedge that stands 8 m deep behind its
	# leader; aimed 10 m ahead of the leader, the wedge's rear pair sat on the bottom edge of the screen).
	var middle := Vector3.ZERO
	for unit_name in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		middle += (game_match.tanks.get_node(unit_name) as Tank).global_position
	middle /= 3.0
	rig.focus = Vector3(middle.x, 0, middle.z - 4.0)
	rig.zoom = 0.3
	# Round 6 X3: pitch is its own axis, and the lead's default (25°, FOV 60°) shows most of the arena at once. These
	# tests are about which points are on screen and when the camera tracks, written against round 5's tilt at this
	# zoom (42°), so they pin it instead of inheriting whatever the default look is.
	rig.pitch = 42.0
	rig.snap()
	var map := TacticalMap.new()
	map.game_match = game_match
	map.camera = camera
	map.rig = rig
	add_to_tree(map)
	var radar := Radar.new()
	radar.game_match = game_match
	radar.map = map
	map.add_child(radar)
	await wait_physics_frames(2)
	return [game_match, map, rig, radar]


## Run the camera's per-frame update `seconds` long without waiting for real frames.
func _settle(rig: RtsCamera, seconds: float, step := 1.0 / 30.0) -> void:
	for i in int(seconds / step):
		rig._process(step)


func test_an_order_off_screen_frames_the_squad_and_its_destination() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var alpha: Array = map.squad_points("Alpha")
	var goal: Vector3 = alpha[0] + Vector3(55, 0, -5)
	assert_true(not map.all_on_screen([goal]), "setup: the destination is off screen")
	map.order_drag(goal, goal)
	assert_eq(rig.tracking_mode(), RtsCamera.Track.ORDER, "an off-screen order starts tracking")
	var before := rig._shown_focus
	rig._process(1.0 / 60.0)
	assert_true(rig._shown_focus.distance_to(before) <= RtsCamera.TRACK_SPEED / 60.0 + 0.01,
			"one frame moves the view no faster than the speed limit (%.2f m)" % rig._shown_focus.distance_to(before))
	_settle(rig, 6.0)
	var points := map.order_points("Alpha")
	assert_eq(points.size(), 4, "tracking watches Alpha's three vehicles and the destination")
	assert_true(map.all_on_screen(points), "after it settles, the squad AND where it's going are on screen")
	assert_true(rig.zoom <= RtsCamera.TRACK_MAX_ZOOM + 0.001, "without climbing past the tracking ceiling (%.2f)" % rig.zoom)


func test_a_far_order_keeps_the_squad_readable_and_leans_toward_the_goal() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var radar: Radar = setup[3]
	var goal := Vector3(-70, 0, -80)
	radar.tap(radar.world_to_radar(goal))
	assert_eq(rig.tracking_mode(), RtsCamera.Track.ORDER, "a radar tap across the arena starts tracking")
	_settle(rig, 6.0)
	var squad: Array = map.squad_points("Alpha")
	assert_true(map.all_on_screen(squad), "the squad stays on screen")
	assert_true(rig.zoom <= RtsCamera.TRACK_MAX_ZOOM + 0.001, "at a zoom where vehicles still read (%.2f), not the whole arena" % rig.zoom)
	var center: Vector3 = (squad[0] + squad[1] + squad[2]) / 3.0
	# 5 m, not 10: since round 8 the lean stops with the squad above the command card (RtsCamera.VISION_FRAME_BOTTOM),
	# which halved it here (16.2 -> 8.4 m at this fixture's 42 deg / FOV 55) - the lean had been parking squads under the HUD.
	assert_true(Vector2(rig.focus.x - goal.x, rig.focus.z - goal.z).length() < Vector2(center.x - goal.x, center.z - goal.z).length() - 5.0,
			"the view leans ahead of the squad toward where it's going (%s)" % rig.focus)
	rig.pan_screen(Vector2(640, 360), Vector2(640, 380))
	var shown := rig._shown_zoom
	_settle(rig, 1.0)
	assert_near(rig._shown_zoom, shown, 0.01, "letting go of tracking doesn't lurch the zoom")


func test_an_order_to_a_visible_spot_leaves_the_camera_alone() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var alpha := map.squad_points("Alpha")
	var nearby: Vector3 = alpha[0] + Vector3(8, 0, -8)
	assert_true(map.all_on_screen(alpha + [nearby]), "setup: squad and spot are on screen")
	var focus_before := rig.focus
	map.tap(rig.camera.unproject_position(nearby))
	assert_eq(rig.tracking_mode(), RtsCamera.Track.NONE, "no tracking for an order you can already see")
	assert_eq(rig.focus, focus_before, "the camera didn't move")


func test_a_manual_pan_or_another_selection_ends_tracking() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var reasons: Array = []
	rig.tracking_ended.connect(func(reason: String) -> void: reasons.append(reason))
	map.order_drag(Vector3(70, 0, -90), Vector3(70, 0, -90))
	assert_true(rig.is_tracking(), "setup: tracking")
	_settle(rig, 0.5)
	rig.pan_screen(Vector2(640, 360), Vector2(700, 360))
	assert_true(not rig.is_tracking(), "dragging the view hands the camera back to the player")
	assert_eq(reasons, ["manual"], "(reason: manual)")
	map.order_drag(Vector3(-70, 0, -90), Vector3(-70, 0, -90))
	assert_true(rig.is_tracking(), "a new off-screen order tracks again")
	map.select_squad("Bravo")
	assert_true(not rig.is_tracking(), "selecting another squad ends the order tracking")
	map.order_drag(Vector3(-70, 0, -90), Vector3(-70, 0, -90))
	rig.zoom_by(0.1)
	assert_true(not rig.is_tracking(), "a pinch or wheel zoom also ends it")


func test_tracking_ends_when_the_squad_arrives() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var goal := Vector3(-60, 0, -70)
	map.order_drag(goal, goal)
	assert_true(rig.is_tracking(), "setup: tracking")
	for member in ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]:
		(game_match.tanks.get_node(member) as Tank).global_position = goal + Vector3(0, 0.5, 0)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 1)
	rig._process(1.0 / 60.0)
	assert_true(game_match.squads["0/Alpha"].arrived, "setup: Alpha has arrived")
	assert_true(not rig.is_tracking(), "arrival ends the tracking")


func test_follow_selected_is_a_toggle_that_moves_with_the_selection() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	(map._buttons["follow"] as Button).pressed.emit()
	assert_eq(rig.tracking_mode(), RtsCamera.Track.FOLLOW, "Follow tracks the selected squad")
	map.order_drag(Vector3(70, 0, -90), Vector3(70, 0, -90))
	assert_eq(rig.tracking_mode(), RtsCamera.Track.FOLLOW, "orders don't replace an explicit follow")
	map.select_squad("Bravo")
	assert_eq(rig.tracking_mode(), RtsCamera.Track.FOLLOW, "selecting another squad follows that one instead")
	_settle(rig, 6.0)
	assert_true(map.all_on_screen(map.squad_points("Bravo")), "Bravo is framed")
	(map._buttons["follow"] as Button).pressed.emit()
	assert_eq(rig.tracking_mode(), RtsCamera.Track.NONE, "pressing Follow again stops following")


func test_frame_points_on_screen_after_snapping() -> void:
	var setup: Array = await _setup()
	var map: TacticalMap = setup[1]
	var rig: RtsCamera = setup[2]
	var points := [Vector3(-60, 0, 60), Vector3(60, 0, 40), Vector3(0, 0, -60)]
	rig.frame(points, true)
	assert_true(map.all_on_screen(points), "frame(points) puts every point on the real screen")


func teardown() -> void:
	# The hook restores the viewport and nothing else: `_teardown()` frees and drains after it, sealed.
	tree.root.size = Vector2i(1280, 720)
