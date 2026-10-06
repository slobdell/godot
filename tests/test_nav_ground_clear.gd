extends TestCase
## Round 19 (brains B3, switch `ground_clear`): SlotGround's open-ground answer equals the full grounding. Random points
## over each map (the drivable square, so walls, blocks, edges and open floor all come up), three clearances (the
## smallest hull, a middle one and the largest the catalogue has), the full path (switch off) against the fast one
## (switch on), point by point: every answer identical, and the fast path taken often enough to be worth having.

const POINTS := 400
## Turning envelopes (m): the scout's, a tank's, the largest hull's (SlotGround.envelope_of over the catalogue).
const ENVELOPES := [1.77, 4.06, 7.19]


func _equal_on(arena_name: String) -> void:
	var arena: Arena = await ArenaFixture.build(self, arena_name)
	var was := BrainSwitches.ground_clear
	var rng := RandomNumberGenerator.new()
	rng.seed = 1919
	var fast_hits := 0
	var cases := 0
	for i in POINTS:
		var point := Vector3(rng.randf_range(-Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), 0.0,
				rng.randf_range(-Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))
		for envelope: float in ENVELOPES:
			BrainSwitches.ground_clear = false
			var full := SlotGround._standable_for(arena, point, envelope)
			BrainSwitches.ground_clear = true
			var fast := SlotGround._standable_for(arena, point, envelope)
			cases += 1
			if fast == point and SlotGround._in_clear_cell(arena.get_world_3d().navigation_map, point):
				fast_hits += 1
			if fast != full:
				assert_eq(fast, full, "%s: point %s, envelope %.2f: the open-ground answer differs" % [arena_name, point, envelope])
				BrainSwitches.ground_clear = was
				return
	BrainSwitches.ground_clear = was
	# No timing here: the two paths share the frame's navmesh memo and random points touch every cell once (the fast
	# path's worst case). Its price is read inside one match: make ai-ab-match AB_SWITCH=ground_clear.
	print("MEASURE nav_ground_clear %s: %d cases identical, %d answered as open ground" % [arena_name, cases, fast_hits])
	assert_true(fast_hits > 0, "%s: some points are open ground (%d)" % [arena_name, fast_hits])


func test_equal_on_yard() -> void:
	await _equal_on("yard")


func test_equal_on_pit() -> void:
	await _equal_on("pit")


func test_equal_on_terminus() -> void:
	await _equal_on("terminus")


func test_equal_on_crossing() -> void:
	await _equal_on("crossing")


func test_equal_on_sumps() -> void:
	await _equal_on("sumps")


func test_equal_on_locks() -> void:
	await _equal_on("locks")


func test_equal_on_parade() -> void:
	await _equal_on("parade")


func test_equal_on_gorge() -> void:
	await _equal_on("gorge")


func test_equal_on_archipelago() -> void:
	await _equal_on("archipelago")


func test_equal_on_cut() -> void:
	await _equal_on("cut")


func test_equal_on_docks() -> void:
	await _equal_on("docks")


func test_equal_on_yard_open() -> void:
	await _equal_on("yard_open")
