extends TestCase
## Round 23 (native, N2b): movement.gd's three pure-geometry functions (C23.1: `_chord_compute`'s sampling loop,
## `_outline_ok`, `_arc_hit`) as one native call each, held to VERBATIM GDScript copies below over the engine's own
## closest-point query on a baked arena, bit for bit, across random poses, hull frames, turns, caps and the lazy start
## form. The match-hash proofs (native-proof, ai-ab-match AB_SWITCH=native_move) cover the real seams in movement.gd.

const OUTLINE: Array[Vector2] = Movement.KTURN_OUTLINE
const POSES := 400


func _gd_chord(map: RID, from: Vector3, to: Vector3, samples: Array, slack: float) -> bool:
	for share: float in samples:
		var probe := Vector3(lerpf(from.x, to.x, share), 0.0, lerpf(from.z, to.z, share))
		if Movement._flat_distance(NavigationServer3D.map_get_closest_point(map, probe), probe) > slack:
			return false
	return true


func _gd_off(map: RID, frame: Array, at: Vector3, heading: Vector3, i: int) -> float:
	var right := Vector3(-heading.z, 0.0, heading.x)
	var sample: Vector2 = OUTLINE[i]
	var point := at + heading * (sample.x * float(frame[1])) + right * (sample.y * float(frame[0]))
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	return Vector2(closest.x - point.x, closest.z - point.z).length()


func _gd_outline_ok(map: RID, frame: Array, at: Vector3, heading: Vector3, start: PackedFloat32Array, lazy_at: Vector3, lazy_heading: Vector3) -> bool:
	var lazy := PackedFloat32Array()
	lazy.resize(OUTLINE.size())
	lazy.fill(-1.0)
	for i in OUTLINE.size():
		var off := _gd_off(map, frame, at, heading, i)
		if off > float(frame[2]):
			var from_start: float
			if not start.is_empty():
				from_start = start[i]
			else:
				if lazy[i] < 0.0:
					lazy[i] = _gd_off(map, frame, lazy_at, lazy_heading, i)
				from_start = lazy[i]
			if off > from_start + 0.05:
				return false
	return true


func _gd_arc_hit(map: RID, frame: Array, at: Vector3, heading: Vector3, turn: float, target: Vector3, start: PackedFloat32Array,
		cap: float, radius: float, lazy_at: Vector3, lazy_heading: Vector3) -> float:
	var travelled := 0.0
	var limit := TAU * radius * Movement.KTURN_SWEEP_TURNS
	while travelled < limit and travelled < cap:
		var to := Vector3(target.x - at.x, 0.0, target.z - at.z)
		if absf(heading.signed_angle_to(to, Vector3.UP)) <= deg_to_rad(Movement.KTURN_ALIGNED_DEG):
			return INF
		heading = TankMotion.turn_heading(heading, Movement.KTURN_STEP_M * turn / radius)
		at += heading * Movement.KTURN_STEP_M
		travelled += Movement.KTURN_STEP_M
		if not _gd_outline_ok(map, frame, at, heading, start, lazy_at, lazy_heading):
			return travelled
	return INF


func test_chord_outline_and_arc_are_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the movement geometry equality is not exercised in this run")
		return
	var arena := await ArenaFixture.build(self, "sumps")
	var map: RID = arena.get_world_3d().navigation_map
	var nav: Object = ClassDB.instantiate("NavNative")
	var rng := RandomNumberGenerator.new()
	rng.seed = 53
	var frames: Array = [[1.2, 2.4, 1.6], [1.66, 7.0, 1.6], [1.0, 1.9, 1.6], [1.5, 3.2, -0.2]]
	var chord_mismatches := 0
	var outline_mismatches := 0
	var arc_mismatches := 0
	var chord_off := 0
	var outline_bad := 0
	var arc_hits := 0
	var first := ""
	for n in POSES:
		var at := Vector3(rng.randf_range(-150.0, 150.0), 0.0, rng.randf_range(-150.0, 150.0))
		var heading := Vector3(Vector2.from_angle(rng.randf_range(0.0, TAU)).x, 0.0, Vector2.from_angle(rng.randf_range(0.0, TAU)).y).normalized()
		if heading == Vector3.ZERO:
			heading = Vector3.FORWARD
		var frame: Array = frames[n % frames.size()]
		var to := at + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))
		var samples: Array = Movement.CHORD_SAMPLES if n % 3 != 0 else Movement.CHORD_END
		var slack := [0.3, 0.4, -0.1, 1.2][n % 4] as float
		var c_gd := _gd_chord(map, at, to, samples, slack)
		var c_nat: bool = nav.chord_on_mesh(map, at, to, PackedFloat64Array(samples), slack)
		if not c_gd:
			chord_off += 1
		if c_gd != c_nat:
			chord_mismatches += 1
			if first == "":
				first = "chord pose %d: native %s gd %s" % [n, c_nat, c_gd]
		var lazy_at := at + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
		var lazy_heading := TankMotion.turn_heading(heading, rng.randf_range(-0.5, 0.5))
		var start := PackedFloat32Array()
		if n % 2 == 0:
			for i in OUTLINE.size():
				start.append(_gd_off(map, frame, lazy_at, lazy_heading, i))
		var o_gd := _gd_outline_ok(map, frame, at, heading, start, lazy_at, lazy_heading)
		var o_nat: bool = nav.outline_ok(map, float(frame[0]), float(frame[1]), float(frame[2]), at, heading, start, lazy_at, lazy_heading)
		if not o_gd:
			outline_bad += 1
		if o_gd != o_nat:
			outline_mismatches += 1
			if first == "":
				first = "outline pose %d: native %s gd %s (start %s)" % [n, o_nat, o_gd, start]
		var turn := -1.0 if n % 2 == 0 else 1.0
		var radius := [6.0, 12.0, 4.0][n % 3] as float
		var cap := INF if n % 4 < 2 else rng.randf_range(2.0, 12.0)
		var target := at + Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
		var a_gd := _gd_arc_hit(map, frame, at, heading, turn, target, start, cap, radius, lazy_at, lazy_heading)
		var a_nat: float = nav.arc_hit(map, float(frame[0]), float(frame[1]), float(frame[2]), at, heading, turn, target, start, cap, radius, lazy_at, lazy_heading)
		if a_gd != INF:
			arc_hits += 1
		if var_to_bytes(a_gd) != var_to_bytes(a_nat):
			arc_mismatches += 1
			if first == "":
				first = "arc pose %d: native %s gd %s (turn %s radius %s cap %s)" % [n, a_nat, a_gd, turn, radius, cap]
	print("MEASURE native movement geometry %d poses: chord %d mismatches (%d off mesh), outline %d (%d not clear), arc %d (%d hits)" % [
			POSES, chord_mismatches, chord_off, outline_mismatches, outline_bad, arc_mismatches, arc_hits])
	assert_true(chord_off > POSES / 10 and outline_bad > POSES / 10 and arc_hits > POSES / 10, "the poses exercise both answers of each")
	assert_eq(chord_mismatches + outline_mismatches + arc_mismatches, 0, "every answer equal; first mismatch: %s" % first)
	arena.free()
	await drain_navigation()
