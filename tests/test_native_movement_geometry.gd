extends TestCase
## Round 23 (native, N2b): movement.gd's three pure-geometry seams (C23.1: `_chord_compute`'s sampling loop,
## `_outline_ok`, `_arc_hit`) held to the LIVE GDScript functions, bit for bit, on every check: each pose is asked of
## the real Movement twice, once through the native seam and once with `BrainSwitches.native` off (the GDScript loop over
## the engine's own closest-point query). So a brains edit to that geometry that the C++ does not follow fails here
## instead of being silently bypassed (the orchestrator's condition for shipping native_move ON). Random poses, hulls of
## four sizes, hull frames, both turns, three radii, caps, the given and the lazy start form. The match-hash proofs
## (native-proof, ai-ab-match AB_SWITCH=native_move) cover the seams in a fight.

const MATCH := preload("res://game/match/match.tscn")
const OUTLINE: Array[Vector2] = Movement.KTURN_OUTLINE
const POSES := 400
const UNITS: Array[String] = ["scout", "tank", "gang_tank", "artillery"]


## One answer from the live function, through the seam (`native`) or the GDScript path.
func _ask(native: bool, mover: Movement, what: String, args: Array) -> Variant:
	var saved := BrainSwitches.native
	var saved_move := BrainSwitches.native_move
	BrainSwitches.native = native
	BrainSwitches.native_move = true
	# The lazy start form memoises its points: both arms start from an empty memo.
	mover._lazy_start = PackedFloat32Array()
	mover._lazy_start.resize(OUTLINE.size())
	mover._lazy_start.fill(-1.0)
	var answer: Variant = mover.callv(what, args)
	BrainSwitches.native = saved
	BrainSwitches.native_move = saved_move
	return answer


func test_the_seams_answer_as_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the movement geometry equality is not exercised in this run")
		return
	var arena := await ArenaFixture.build(self, "sumps")
	var map: RID = arena.get_world_3d().navigation_map
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var movers: Array[Movement] = []
	for i in UNITS.size():
		var tank := game_match.spawn_tank("Geo%d" % i, 0, Match.Team.GREEN, UNITS[i])
		tank.global_position = Vector3(10.0 * i, 0.0, 0.0)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		await wait_physics_frames(1)
		movers.append(Movement.of(tank))
	await wait_physics_frames(2)
	assert_true(Pathing.is_ready(movers[0].ctl.tank), "the arena's navmesh is ready for the movers")
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
		var mover: Movement = movers[n % movers.size()]
		var at := Vector3(rng.randf_range(-150.0, 150.0), 0.0, rng.randf_range(-150.0, 150.0))
		var heading := Vector3(Vector2.from_angle(rng.randf_range(0.0, TAU)).x, 0.0, Vector2.from_angle(rng.randf_range(0.0, TAU)).y).normalized()
		if heading == Vector3.ZERO:
			heading = Vector3.FORWARD
		var frame: Array = frames[n % frames.size()]
		var to := at + Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))
		var c_gd: bool = _ask(false, mover, "_chord_compute", [at, to])
		var c_nat: bool = _ask(true, mover, "_chord_compute", [at, to])
		if not c_gd:
			chord_off += 1
		if c_gd != c_nat:
			chord_mismatches += 1
			if first == "":
				first = "chord pose %d: native %s gd %s" % [n, c_nat, c_gd]
		# The lazy start pose (kturn_lazy): the seam takes it only when the mover's lazy map and frame are this call's.
		mover._lazy_map = map
		mover._lazy_frame = frame
		mover._lazy_at = at + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0))
		mover._lazy_heading = TankMotion.turn_heading(heading, rng.randf_range(-0.5, 0.5))
		var start := PackedFloat32Array()
		if n % 2 == 0:
			start = _ask(false, mover, "_outline_offs", [map, frame, mover._lazy_at, mover._lazy_heading])
		var o_gd: bool = _ask(false, mover, "_outline_ok", [map, frame, at, heading, start])
		var o_nat: bool = _ask(true, mover, "_outline_ok", [map, frame, at, heading, start])
		if not o_gd:
			outline_bad += 1
		if o_gd != o_nat:
			outline_mismatches += 1
			if first == "":
				first = "outline pose %d: native %s gd %s (start %s)" % [n, o_nat, o_gd, start]
		var turn := -1.0 if n % 2 == 0 else 1.0
		# wheel_radius() memoises by unit: the radius is set the way it caches it.
		mover._wheel_radius_unit = mover.ctl.tank.unit_id
		mover._wheel_radius_value = [6.0, 12.0, 4.0][n % 3] as float
		var cap := INF if n % 4 < 2 else rng.randf_range(2.0, 12.0)
		var target := at + Vector3(rng.randf_range(-40.0, 40.0), 0.0, rng.randf_range(-40.0, 40.0))
		var a_gd: float = _ask(false, mover, "_arc_hit", [map, frame, at, heading, turn, target, start, cap])
		var a_nat: float = _ask(true, mover, "_arc_hit", [map, frame, at, heading, turn, target, start, cap])
		if a_gd != INF:
			arc_hits += 1
		if var_to_bytes(a_gd) != var_to_bytes(a_nat):
			arc_mismatches += 1
			if first == "":
				first = "arc pose %d: native %s gd %s (turn %s cap %s)" % [n, a_nat, a_gd, turn, cap]
	print("MEASURE native movement geometry (live functions) %d poses: chord %d mismatches (%d off mesh), outline %d (%d not clear), arc %d (%d hits)" % [
			POSES, chord_mismatches, chord_off, outline_mismatches, outline_bad, arc_mismatches, arc_hits])
	assert_true(chord_off > POSES / 10 and outline_bad > POSES / 10 and arc_hits > POSES / 10, "the poses exercise both answers of each")
	assert_eq(chord_mismatches + outline_mismatches + arc_mismatches, 0, "every answer equal; first mismatch: %s" % first)
	game_match.queue_free()
	arena.free()
	await drain_navigation()
