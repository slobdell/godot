extends TestCase
## CoverMap: the arena's cover as pure 2D geometry (game/ai/cover_map.gd). No scene except where noted.

const ARENA := preload("res://game/arena/arena.tscn")


func _wall_map() -> CoverMap:
	# An 18 m by 1.5 m wall along x at the origin, and a crate rotated 45° at (30, 0).
	return CoverMap.from_features([
		{"position": Vector3(0, 0, 0), "size": [18.0, 3.0, 1.5], "rotation": 0.0},
		{"position": Vector2(30, 0), "size": Vector2(4.5, 4.5), "rotation_deg": 45.0},
	])


func test_a_wall_blocks_sight_across_it_but_not_around_it() -> void:
	var map := _wall_map()
	assert_true(not map.clear_line(Vector3(0, 0, -10), Vector3(0, 0, 10)), "straight through the wall: blocked")
	assert_true(not map.clear_line(Vector3(8, 0, -10), Vector3(-8, 0, 10)), "diagonally through the wall: blocked")
	assert_true(map.clear_line(Vector3(11, 0, -10), Vector3(11, 0, 10)), "past the wall's end: clear")
	assert_true(map.clear_line(Vector3(-20, 0, -3), Vector3(20, 0, -3)), "alongside the wall: clear")


func test_a_rotated_crate_blocks_by_its_real_footprint() -> void:
	var map := _wall_map()
	# The crate's corners point along the axes (a diamond): its half-diagonal is 3.18 m.
	assert_true(not map.clear_line(Vector3(33.0, 0, -10), Vector3(33.0, 0, 10)), "3 m east of center, inside the diamond's reach")
	assert_true(map.clear_line(Vector3(33.4, 0, -10), Vector3(33.4, 0, 10)), "just past the diamond's tip: clear")
	assert_true(map.clear_line(Vector3(34.7, 0, -1.0), Vector3(29.7, 0, 4.0)), "a line through the unrotated box's corner misses the diamond: clear")


func test_low_cover_does_not_block_sight() -> void:
	var map := CoverMap.from_features([{"position": Vector2.ZERO, "size": [10.0, 2.0], "height": 1.0}])
	assert_true(map.clear_line(Vector3(0, 0, -10), Vector3(0, 0, 10)), "a 1 m barrier is below eye height")


func test_line_of_sight_is_symmetric_and_repeatable() -> void:
	var map := _wall_map()
	for i in 40:
		var a := Vector3(-30 + i * 1.7, 0, -12 + (i % 7) * 0.9)
		var b := Vector3(25 - i * 1.3, 0, 11 - (i % 5) * 1.1)
		var first := map.clear_line(a, b)
		assert_eq(map.clear_line(b, a), first, "the same answer from either end (%s, %s)" % [a, b])
		assert_eq(CoverMap.from_features([
			{"position": Vector3(0, 0, 0), "size": [18.0, 3.0, 1.5], "rotation": 0.0},
			{"position": Vector2(30, 0), "size": Vector2(4.5, 4.5), "rotation_deg": 45.0},
		]).clear_line(a, b), first, "a fresh map (empty memo) agrees")


func test_tactical_points_ring_features_and_stand_clear_of_them() -> void:
	var map := _wall_map()
	assert_true(map.points.size() > 20, "points ring both features (%d)" % map.points.size())
	for point in map.points:
		assert_true(not map.inside_any(point, CoverMap.STAND_CLEARANCE - 0.01), "a tank fits at %s" % point)
	var near := map.points_near(Vector2(0, 5), 6.0)
	assert_true(near.size() > 0, "points just south of the wall")
	for i in range(1, near.size()):
		assert_true(map.points[near[i - 1]].distance_to(Vector2(0, 5)) <= map.points[near[i]].distance_to(Vector2(0, 5)), "nearest first")


func test_it_reads_the_real_arena_obstacles() -> void:
	var arena: Node3D = add_to_tree(ARENA.instantiate())
	var map := CoverMap.from_arena(arena)
	assert_eq(map.features.size(), 19, "8 walls and 11 crates")
	# WallWestA at (-36, -20) runs 18 m along x: a gun north of it can't see south through it.
	assert_true(not map.clear_line(Vector3(-36, 0, -40), Vector3(-36, 0, -5)), "WallWestA blocks north-south sight")
	assert_true(map.clear_line(Vector3(-24, 0, -40), Vector3(-24, 0, -5)), "east of its end, sight is clear")
	# The rotated walls (WallWestB at (-72, 24)) run along z.
	assert_true(not map.clear_line(Vector3(-82, 0, 24), Vector3(-62, 0, 24)), "WallWestB blocks east-west sight")
	assert_true(CoverMap.of(arena) == CoverMap.of(arena), "one cached map per arena")


func test_it_agrees_with_physics_line_of_sight_on_the_real_arena() -> void:
	var arena: Node3D = add_to_tree(ARENA.instantiate())
	var map := CoverMap.from_arena(arena)
	var match_scene: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	var viewer := match_scene.spawn_tank("Green_Viewer", 0, Match.Team.GREEN)
	var target := match_scene.spawn_tank("Rust_Target", 0, Match.Team.RUST)
	await wait_physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var disagreements := 0
	var samples := 0
	for i in 150:
		var a := Vector3(rng.randf_range(-110, 110), 0, rng.randf_range(-110, 110))
		var b := a + Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(-60, 60))
		b = Vector3(clampf(b.x, -110, 110), 0, clampf(b.z, -110, 110))  # the perimeter walls aren't cover features
		if map.inside_any(Vector2(a.x, a.z), 2.0) or map.inside_any(Vector2(b.x, b.z), 2.0):
			continue
		viewer.global_position = a
		target.global_position = b
		samples += 1
		if map.clear_line(a, b) != Perception.has_line_of_sight(viewer, target):
			disagreements += 1
			print("  disagree: %s -> %s map %s" % [a, b, map.clear_line(a, b)])
	print("MEASURE ai_cover_map_vs_physics %d of %d sight lines disagree" % [disagreements, samples])
	assert_true(samples > 100, "enough sample lines (%d)" % samples)
	assert_true(disagreements <= samples / 50, "the 2D map matches physics raycasts (%d of %d disagree, quantization only)" % [disagreements, samples])
