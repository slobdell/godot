extends TestCase
## Round 24 (native, N3b `move.path`): the route-following tail of `Movement._next_waypoint` as one native call
## (NativeRoute.tail -> TankNative.follow_route) against the LIVE function. On poses where no re-plan fires (the
## cadence not due, the goal where it was planned to, the hull within OFF_PATH_REPATH of its route, no stall) the
## live `_next_waypoint` IS that tail, so each pose is asked of the real Movement through GDScript and natively from the
## same state: the steering point, the new `_path_index` and the chord memo it leaves must be equal bit for bit. Real
## routes on the Sumps (Pathing.query + the mover's own corner inflation), tracked and wheeled hulls, headings that
## face the route and away from it, reachable and not. (After CP1 the seam inside `_next_waypoint` is asked too.)

const MATCH := preload("res://game/match/match.tscn")
const UNITS: Array[String] = ["tank", "ifv", "gang_tank", "scout", "artillery"]
const POSES := 500


func _snapshot(m: Movement) -> Array:
	return [m._path_index, m._chord_frame, m._chord_from, m._chord_to, m._chord_answer, m._repath_left]


func _restore(m: Movement, s: Array) -> void:
	m._path_index = s[0]
	m._chord_frame = s[1]
	m._chord_from = s[2]
	m._chord_to = s[3]
	m._chord_answer = s[4]
	m._repath_left = s[5]


func test_the_route_tail_answers_as_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the route equality is not exercised in this run")
		return
	var constants: PackedFloat64Array = NativeBridge.impl.route_constants()
	assert_eq(constants, PackedFloat64Array([Movement.PATH_LOOKAHEAD, Movement.WHEELS_LOOKAHEAD_RADII,
			Movement.CARROT_ALIGNED_COS, Movement.WHEELS_LOOKAHEAD_MAX_RADII, Movement.CARROT_PULLBACK[0],
			Movement.CARROT_PULLBACK[1], Movement.WAYPOINT_MIN_M]), "route_native.cpp's constants are movement.gd's")
	assert_eq(Movement.CARROT_PULLBACK.size(), 2, "two pull-back shares (route_native.cpp loops over two)")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var movers: Array[Movement] = []
	for i in UNITS.size():
		var tank := game_match.spawn_tank("Route%d" % i, 0, Match.Team.GREEN, UNITS[i])
		tank.global_position = Vector3(12.0 * i, 0.0, 0.0)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		await wait_physics_frames(1)
		movers.append(Movement.of(tank))
	await wait_physics_frames(2)
	assert_true(Pathing.is_ready(movers[0].ctl.tank), "the navmesh is ready")
	var rng := RandomNumberGenerator.new()
	rng.seed = 2404
	var saved := [BrainSwitches.native, BrainSwitches.native_path]
	var mismatches := 0
	var first := ""
	var asked := 0
	var away := 0
	var chords := 0
	var frame := Engine.get_physics_frames()
	for n in POSES:
		var mover: Movement = movers[n % movers.size()]
		var tank := mover.ctl.tank
		var from := Vector3(rng.randf_range(-140.0, 140.0), 0.0, rng.randf_range(-140.0, 140.0))
		var goal := Vector3(rng.randf_range(-140.0, 140.0), 0.0, rng.randf_range(-140.0, 140.0))
		var route := Pathing.query(tank, from, goal)
		var points: PackedVector3Array = route["points"]
		if points.size() < 2:
			continue
		mover._path = mover._inflate_corners(points)
		if mover._path.size() < 2:
			continue
		# A pose near a random leg of the route (within 4 m: never OFF_PATH_REPATH off it), a random heading.
		var leg := rng.randi_range(0, mover._path.size() - 2)
		var a := mover._path[leg]
		var b := mover._path[leg + 1]
		var t := rng.randf()
		tank.global_position = Vector3(lerpf(a.x, b.x, t) + rng.randf_range(-3.0, 3.0), 0.0, lerpf(a.z, b.z, t) + rng.randf_range(-3.0, 3.0))
		var angle := rng.randf_range(0.0, TAU)
		tank.global_basis = Basis(Vector3.UP, angle)
		mover._path_index = clampi(leg + 1 + rng.randi_range(-1, 1), 1, mover._path.size() - 1)
		if mover._off_path(tank.global_position) > Movement.OFF_PATH_REPATH:
			continue
		mover._reachable = rng.randf() < 0.7
		mover._path_goal = goal
		mover._goal_velocity = Vector2.ZERO
		mover.stalled_ticks = 0
		mover._repath_left = 1000.0
		# The memo: empty, this frame's for other points, or last frame's.
		match n % 3:
			0:
				mover._chord_frame = -1
			1:
				mover._chord_frame = frame
				mover._chord_from = tank.global_position
				mover._chord_to = goal
				mover._chord_answer = rng.randf() < 0.5
			2:
				mover._chord_frame = frame - 1
		var start := _snapshot(mover)
		BrainSwitches.native = false
		var live := mover._next_waypoint(goal, 0.0)
		var live_state := _snapshot(mover)
		_restore(mover, start)
		BrainSwitches.native = true
		BrainSwitches.native_path = true
		var native := NativeRoute.tail(mover, goal)
		var native_state := _snapshot(mover)
		_restore(mover, start)
		# ...and through the seam inside the live function (native on, the drive seam off so _next_waypoint runs).
		var saved_drive := BrainSwitches.native_drive
		BrainSwitches.native_drive = false
		var seamed := mover._next_waypoint(goal, 0.0)
		BrainSwitches.native_drive = saved_drive
		var seamed_state := _snapshot(mover)
		_restore(mover, start)
		if seamed != native or seamed_state != native_state:
			mismatches += 1
			if first == "":
				first = "pose %d through the seam: %s %s v %s %s" % [n, seamed, seamed_state, native, native_state]
		asked += 1
		var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
		var toward := Vector2(mover._path[mover._path_index].x - tank.global_position.x, mover._path[mover._path_index].z - tank.global_position.z)
		away += 1 if forward.normalized().dot(toward.normalized()) < 0.0 else 0
		chords += 1 if live_state[1] == frame and start[1] != frame else 0
		if live != native or live_state != native_state:
			mismatches += 1
			if first == "":
				first = "pose %d (%s): live %s %s, native %s %s" % [n, tank.unit_id, live, live_state, native, native_state]
	BrainSwitches.native = saved[0]
	BrainSwitches.native_path = saved[1]
	print("native route: %d poses asked, %d facing away, %d computed a chord, %d mismatches" % [asked, away, chords, mismatches])
	assert_eq(mismatches, 0, "the native route tail answers as the live _next_waypoint: %s" % first)
	assert_true(asked >= POSES / 3 and away >= 20 and chords >= 20, "the branches are exercised (%d asked, %d away, %d chords)" % [asked, away, chords])
