extends TestCase
## Round 42 (camera K4.2): the danger rule's weighted sum (RtsCamera.danger_look), its guards, and the rig's turn.

const NORTH := Vector3(0, 0, -1)
const SOUTH := Vector3(0, 0, 1)
const EAST := Vector3(1, 0, 0)


func _state(from: Vector3, heading: Variant, speed: float, enemies: Array) -> Dictionary:
	return {"from": from, "heading": heading, "speed": speed, "enemies": enemies, "middle": Vector3.ZERO}


func _enemy(at: Vector3, fired_s := DangerFeed.NEVER, hit_s := DangerFeed.NEVER, seen := true, age_s := 0.0) -> Dictionary:
	return {"name": "e", "at": at, "seen": seen, "age_s": age_s, "fired_s": fired_s, "hit_s": hit_s}


func _deg(look: Variant) -> float:
	return rad_to_deg(RtsCamera.yaw_facing(look as Vector3))  # 0 north, -90 east


func test_a_quiet_drive_north_looks_north() -> void:
	var out := RtsCamera.danger_look(_state(Vector3(0, 0, 100), NORTH, 8.0, []))
	assert_near(_deg(out["look"]), 0.0, 0.5, "heading and the arena's middle agree")


func test_an_ambush_from_the_east_pulls_the_view_east_while_it_fires() -> void:
	var from := Vector3(0, 0, 60)
	var quiet := RtsCamera.danger_look(_state(from, NORTH, 8.0, [_enemy(from + EAST * 40.0)]))
	var firing := RtsCamera.danger_look(_state(from, NORTH, 8.0, [_enemy(from + EAST * 40.0, 0.2)]))
	var hit := RtsCamera.danger_look(_state(from, NORTH, 8.0, [_enemy(from + EAST * 40.0, 0.2, 0.2)]))
	assert_true(_deg(firing["look"]) < _deg(quiet["look"]), "firing at us pulls further east (%.0f v %.0f)" % [_deg(firing["look"]), _deg(quiet["look"])])
	assert_true(_deg(hit["look"]) < -45.0, "a gun that hits us from the east takes the view past 45 deg east (%.0f)" % _deg(hit["look"]))
	# The shooter is then on screen: the wedge at his 35 deg lens shows ~+-29 deg; the rule faces it within that.
	assert_true(absf(_deg(hit["look"]) - (-90.0)) < 45.0, "and nearer the shooter than the heading")


func test_his_retreat_to_his_own_edge_looks_back_at_the_fight() -> void:
	var from := Vector3(0, 0, 110)  # his own (south) edge
	var fight := [_enemy(Vector3(0, 0, 30), 1.0), _enemy(Vector3(10, 0, 25))]
	var out := RtsCamera.danger_look(_state(from, SOUTH, 10.0, fight))
	assert_near(_deg(out["look"]), 0.0, 10.0, "driving south at full speed, the view looks north at the fight")
	var forgotten := RtsCamera.danger_look(_state(from, SOUTH, 10.0, []))
	assert_near(_deg(forgotten["look"]), 0.0, 10.0, "with the fight forgotten, the arena's middle still outweighs the heading")


func test_threats_on_opposite_sides_cancel_and_keep_the_yaw() -> void:
	var from := Vector3(0, 0, 0)
	var both := [_enemy(Vector3(40, 0, 0), 0.1), _enemy(Vector3(-40, 0, 0), 0.1)]
	var out := RtsCamera.danger_look(_state(from, null, 0.0, both))
	assert_eq(out["look"], null, "east and west equally: no direction worth turning to (strength %.2f)" % out["strength"])


func test_a_remembered_enemy_fades_and_the_middle_lets_go_near_it() -> void:
	var from := Vector3(60, 0, 60)
	var fresh := RtsCamera.danger_look(_state(from, null, 0.0, [_enemy(Vector3(60, 0, 100), DangerFeed.NEVER, DangerFeed.NEVER, false, 0.5)]))
	var old := RtsCamera.danger_look(_state(from, null, 0.0, [_enemy(Vector3(60, 0, 100), DangerFeed.NEVER, DangerFeed.NEVER, false, 5.5)]))
	assert_true((fresh["pulls"]["enemies"] as Vector3).length() > (old["pulls"]["enemies"] as Vector3).length() * 3.0,
			"a contact last seen 5.5 s ago weighs far less than one seen 0.5 s ago")
	var centre := RtsCamera.danger_look(_state(Vector3(5, 0, 5), null, 0.0, []))
	assert_eq(centre["look"], null, "standing on the middle with nothing known: nothing to look at")


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


func test_the_rig_turns_toward_the_danger_only_when_on_and_holds_after_settling() -> void:
	var rig := _rig()
	rig.yaw = 0.0
	rig.facing = func() -> Variant: return NORTH
	var state := _state(Vector3(0, 0, 60), NORTH, 8.0, [_enemy(Vector3(40, 0, 60), 0.1, 0.1)])
	rig.danger = func() -> Dictionary: return state
	rig.danger_on = false
	for i in 60:
		rig._update_yaw_follow(1.0 / 60.0)
	assert_near(rig.yaw, 0.0, 0.001, "off: round 41, the heading only")
	rig.danger_on = true
	for i in 180:
		rig._update_yaw_follow(1.0 / 60.0)
	var wanted := RtsCamera.yaw_facing(RtsCamera.danger_look(state)["look"])
	assert_near(rig.yaw, wanted, deg_to_rad(RtsCamera.YAW_SETTLE_DEG + 0.1), "on: it turns to the danger and settles")
	assert_eq(rig.wrote["yaw"], "danger", "the trace can tell the danger turn from the heading's")
	# A new pull just past the deadband right after settling waits out the hold.
	var settled := rig.yaw
	state["enemies"] = [_enemy(Vector3(40, 0, 20), 0.1, 0.1)]
	rig._update_yaw_follow(1.0 / 60.0)
	assert_near(rig.yaw, settled, 0.0001, "held for DANGER_HOLD_S after a turn: no swinging")


func test_the_readout_shows_the_three_pulls_and_a_cancel() -> void:
	var from := Vector3(0, 0, 60)
	var line := CameraReadout.danger_line(RtsCamera.danger_look(_state(from, NORTH, 8.0, [_enemy(from + EAST * 40.0, 0.2)])))
	assert_true(line.begins_with("DANGER") and line.contains("heading 0.6 @ 0°") and line.contains("enemies") \
			and line.contains("war 1.0 @ -90°") and line.contains("look -"), line)
	var cancel := CameraReadout.danger_line(RtsCamera.danger_look(_state(Vector3.ZERO, null, 0.0,
			[_enemy(Vector3(40, 0, 0), 0.1), _enemy(Vector3(-40, 0, 0), 0.1)])))
	assert_true(cancel.contains("heading -") and cancel.contains("hold (cancel)"), cancel)


func test_the_feed_wired_as_skirmish_mode_does_stays_alive() -> void:
	var read := DangerFeed.new().reader()  # nobody else holds the feed, as in skirmish_mode
	assert_true(read.is_valid(), "the Callable still has its feed")
	var state: Dictionary = read.call()
	assert_true(state.has("enemies") and state["middle"] == Vector3.ZERO, "and reads: %s" % state)
	var bare := _bare_read()
	assert_true(not bare.is_valid(), "the bare method Callable (the bug) does not, once the line that made it is done")


func _bare_read() -> Callable:
	return DangerFeed.new().read


func test_the_danger_frame_keeps_mirrors_and_the_focus_inside_the_wall() -> void:
	var saved := RtsCamera.perimeter_poly
	# A square wall at +-100 (the polygon path, as the hexagon uses).
	RtsCamera.perimeter_poly = PackedVector2Array([Vector2(-100, -100), Vector2(100, -100), Vector2(100, 100), Vector2(-100, 100)])
	var inside := RtsCamera.inside_wall(Vector3(0, 0, 150), 4.0)
	assert_near(inside.z, 96.0, 0.01, "a point past the south wall comes back to 4 m inside it")
	assert_eq(RtsCamera.inside_wall(Vector3(10, 0, 20), 4.0), Vector3(10, 0, 20), "a point inside is left alone")
	# His scout at the south edge (z 90), a contact north at z 10: its mirror (z 170) is outside; the contact is not.
	var frame := [Vector3(0, 0, 90), Vector3(0, 0, 10), Vector3(0, 0, 170)]
	var kept := RtsCamera.danger_frame(frame, 1)
	assert_eq(kept[1], Vector3(0, 0, 10), "the contact stays where it is")
	assert_near((kept[2] as Vector3).z, 96.0, 0.01, "its mirror is pulled inside the wall")
	assert_true(RtsCamera.behind_view(0.0, Vector3(0, 0, 90), Vector3(0, 0, 120)), "a destination south of a north view is behind it")
	assert_true(not RtsCamera.behind_view(0.0, Vector3(0, 0, 90), Vector3(5, 0, 40)), "one north of it is not")
	RtsCamera.perimeter_poly = saved
