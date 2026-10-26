extends TestCase
## Round 41 (camera K1): CameraTrace replays the rig's pose to say who moved the ground under the cursor, in screen px.

const SIZE := Vector2(1920, 1080)


func _layers(focus: Vector3, yaw := 0.0, distance := 49.0, pitch := 21.0) -> Dictionary:
	return {"f": focus, "y": yaw, "d": distance, "pr": pitch, "fov": 35.0, "sd": 0.0, "sp": 0.0, "hd": 0.0, "hp": 0.0,
			"h": 0.0, "v": 0.0, "w": {"focus": "auto_frame", "yaw": "yaw_follow", "zoom": "auto_frame", "pitch": "player"}}


func test_the_replay_projects_like_the_camera() -> void:
	tree.root.size = Vector2i(SIZE)
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.make_current()
	var layers := _layers(Vector3(12, 0, -30), 0.4, 60.0, 25.0)
	layers["h"] = 0.3
	layers["v"] = -0.2
	camera.fov = 35.0
	camera.global_transform = RtsCamera.pose_at(layers["f"], 0.4, 60.0, RtsCamera.tilt_at(25.0, 60.0))
	camera.h_offset = 0.3
	camera.v_offset = -0.2
	await wait_physics_frames(1)
	for point in [Vector3(12, 0, -30), Vector3(0, 0, -50), Vector3(30, 2, -10)]:
		var mine: Variant = CameraTrace.project(layers, SIZE, point)
		var godot := camera.unproject_position(point)
		assert_true(mine is Vector2 and (mine as Vector2).distance_to(godot) < 0.5,
				"%s: replay %s v Camera3D %s (h/v offsets included)" % [point, mine, godot])
		var back: Variant = CameraTrace.ground_at(layers, SIZE, mine as Vector2)
		if point.y == 0.0:
			assert_true(back is Vector3 and (back as Vector3).distance_to(point) < 0.05, "ground_at inverts project at %s" % point)


func test_parts_add_up_and_name_their_writer() -> void:
	var before := _layers(Vector3(0, 0, 0))
	var after := _layers(Vector3(1.5, 0, -0.5), 0.05, 50.0)
	after["v"] = 0.1
	var point := Vector3(3, 0, -8)
	var parts := CameraTrace.parts(before, after, point, SIZE)
	var total := (CameraTrace.project(after, SIZE, point) as Vector2) - (CameraTrace.project(before, SIZE, point) as Vector2)
	var sum := Vector2.ZERO
	for source: String in parts:
		sum += parts[source]
	assert_true(sum.distance_to(total) < 0.01, "the parts sum to the whole move: %s v %s" % [sum, total])
	assert_true(parts.has("auto_frame") and parts.has("yaw_follow") and parts.has("shake"), "each part under its source: %s" % [parts])
	assert_true(not parts.has("player"), "the player did not move it: %s" % [parts])
	var still := CameraTrace.parts(before, before.duplicate(), point, SIZE)
	assert_true(still.is_empty(), "nothing moved, nothing reported")


## A lerp that starts from rest (the rig's exponential smoothing toward a goal that jumped) is a jerk; a critically damped
## glide over the same distance is not.
func test_a_snap_start_is_a_jerk_and_a_glide_is_not() -> void:
	var size := SIZE
	for shape in ["lerp", "glide"]:
		var trace := CameraTrace.new()
		var at := Vector3.ZERO
		var velocity := Vector3.ZERO
		var goal := Vector3(12, 0, 0)
		var prev := _layers(at)
		var dt := 1.0 / 60.0
		for frame in 180:
			if shape == "lerp":
				at = at.lerp(goal, 1.0 - exp(-RtsCamera.SMOOTHING * dt))
			else:
				var omega := 4.0
				var accel := (goal - at) * omega * omega - velocity * 2.0 * omega
				velocity += accel * dt
				at += velocity * dt
			var cur := _layers(at)
			var ground: Variant = CameraTrace.ground_at(prev, size, size * 0.5)
			trace._frame(CameraTrace.parts(prev, cur, ground as Vector3, size), dt)
			trace._clock += dt
			prev = cur
		var auto: Dictionary = trace.summary()["by_source"]["auto_frame"]
		if shape == "lerp":
			assert_true(int(auto["events"]) >= 1, "a lerp from rest is a jerk: %s" % [auto])
		else:
			assert_eq(int(auto["events"]), 0, "a critically damped glide is not a jerk: %s" % [auto])
		assert_true(float(auto["px_per_min"]) > 100.0, "%s: it did move the ground (%s)" % [shape, auto])
		trace.free()
