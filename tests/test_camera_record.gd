extends TestCase
## Round 43 (camera K5.1, C43.2): the match recording holds where the camera looked. A `cam` row every CENSUS_S and at
## each automatic turn's start, the shown pose and the mode; the rows that were there keep their meaning; a match with
## no camera (headless harnesses, the native recorder's twin test) writes none.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const NORTH := Vector3(0, 0, -1)
const EAST := Vector3(1, 0, 0)


## The controls as the recorder reads them: the rig, and the command signal it listens to.
class FakeControls:
	extends RefCounted
	signal command_issued(command: Dictionary, error: String)
	var rig: RtsCamera


func _rig() -> RtsCamera:
	if tree.root.size.x < 640:
		tree.root.size = Vector2i(1280, 720)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var rig := RtsCamera.new()
	RtsCamera.fov = RtsCamera.FOV_DEG
	rig.camera = camera
	rig.edge_pan = false
	rig.focus = Vector3(0, 0, 40)
	rig.zoom = 0.4
	add_to_tree(rig)
	return rig


func _rows(path: String) -> Array:
	var rows: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		rows.append(JSON.parse_string(line))
	return rows


func _of(rows: Array, kind: String) -> Array:
	return rows.filter(func(r: Dictionary) -> bool: return r["t"] == kind)


func test_the_row_is_the_shown_pose_and_names_who_turns_the_yaw() -> void:
	var rig := _rig()
	rig.danger_on = false
	rig.yaw = 0.0
	rig.snap()
	var row := rig.record_row()
	for key in ["yaw", "want", "pitch", "dist", "target", "mode"]:
		assert_true(row.has(key), "the row has %s" % key)
	assert_near(float(row["yaw"]), 0.0, 0.05, "yaw in degrees, 0 = north")
	assert_near(float(row["pitch"]), RtsCamera.DEFAULT_PITCH_DEG, 3.0, "his pitch (plus any clearance)")
	assert_eq(row["target"], [0.0, 40.0], "the ground point it looks at")
	assert_eq(row["mode"], "follow", "nothing turning it")
	rig.facing = func() -> Variant: return EAST
	rig._update_yaw_follow(1.0 / 60.0)
	assert_eq(rig.turns, 1, "a turn east started")
	assert_eq(rig.turn_mode, "follow", "the heading started it")
	for i in 120:
		rig._update_yaw_follow(1.0 / 60.0)
	assert_eq(rig.turns, 1, "one turn, however many frames it takes")
	assert_near(float(rig.record_row()["want"]), -90.0, RtsCamera.YAW_SETTLE_DEG + 0.1, "east is -90 (positive turns left)")
	rig.rotate_by(0.1)
	assert_eq(rig.record_row()["mode"], "manual", "his hand")


func test_the_recording_carries_cam_rows_and_old_rows_keep_their_meaning() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	m.load_doctrine(Match.Team.GREEN, {"squads": [{"name": "A", "units": [{"unit": "tank"}]}]})
	m.load_doctrine(Match.Team.RUST, {"squads": [{"name": "B", "units": [{"unit": "ifv"}]}]})
	var rig := _rig()
	rig.danger_on = false
	var controls := FakeControls.new()
	controls.rig = rig
	var dir := OS.get_user_data_dir().path_join("test_camera_record")
	var recorder := MatchRecorder.start(m, null, controls, null, dir, "cam", 7)
	recorder.set_physics_process(false)
	await wait_physics_frames(1)
	for t in 3:
		m.tick = t * SimClock.TICK_RATE  # three seconds of match: three census-paced rows
		recorder._physics_process(0.0)
	rig.facing = func() -> Variant: return EAST
	rig._update_yaw_follow(1.0 / 60.0)  # a turn starts between census rows
	m.tick += 1
	recorder._physics_process(0.0)
	m.tick += 1
	recorder._physics_process(0.0)  # nothing new: no row
	var path := recorder.path
	recorder.queue_free()
	await wait_physics_frames(1)
	var rows := _rows(path)
	assert_eq(rows[0]["t"], "match", "the header still comes first")
	var cams := _of(rows, "cam")
	assert_eq(cams.size(), 4, "three paced rows and one turn row (%s)" % [cams])
	for row: Dictionary in cams:
		for key in ["tick", "yaw", "pitch", "dist", "target", "mode"]:
			assert_true(row.has(key), "cam row has %s" % key)
	assert_true(bool(cams[3].get("turn", false)) and cams[3]["mode"] == "follow", "the turn's row names who started it")
	assert_true(not cams[0].has("turn"), "a paced row is not a turn")
	assert_true(_of(rows, "census").size() >= 3, "the census rows are still written beside them")


func test_a_match_without_a_camera_writes_no_cam_rows() -> void:
	add_to_tree(ARENA.instantiate())
	var m: Match = MATCH.instantiate()
	add_to_tree(m)
	var dir := OS.get_user_data_dir().path_join("test_camera_record_none")
	var recorder := MatchRecorder.start(m, null, null, null, dir, "none", 7)
	recorder.set_physics_process(false)
	await wait_physics_frames(1)
	for t in 3:
		m.tick = t * SimClock.TICK_RATE
		recorder._physics_process(0.0)
	var path := recorder.path
	recorder.queue_free()
	await wait_physics_frames(1)
	assert_eq(_of(_rows(path), "cam").size(), 0, "no rig, no cam rows")
