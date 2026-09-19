extends TestCase
## Round 7 (feel): the city block, the skyline made playable. What you see must be what Arena's one collision box of
## `size` blocks, wherever driving and fire happen.


func test_a_block_fills_its_footprint_at_ground_level_and_steps_in_only_above_eye_height() -> void:
	var size := Vector3(40.0, 30.0, 24.0)
	var tiers := CityBlock.tiers_of(size, 3, 3.0)
	var ground: PackedVector2Array = tiers[0][0]
	var box := Rect2(Vector2(-20.0, -12.0), Vector2(40.0, 24.0))
	for point in ground:
		assert_true(box.grow(0.01).has_point(point), "the shopfronts sit inside the footprint (%s)" % point)
	var bounds := Rect2(ground[0], Vector2.ZERO)
	for point in ground:
		bounds = bounds.expand(point)
	assert_near(bounds.size.x, 40.0, 0.01, "and fill it")
	for i in range(1, tiers.size()):
		var poly: PackedVector2Array = tiers[i][0]
		var smaller := Rect2(poly[0], Vector2.ZERO)
		for point in poly:
			smaller = smaller.expand(point)
		if smaller.size.x < 39.99:
			assert_true(float(tiers[i][1]) >= CityBlock.SHOP_HEIGHT, "a setback starts above the shopfronts (%.1f m)" % tiers[i][1])
	assert_near(float(tiers[tiers.size() - 1][2]), 30.0, 0.01, "the roof is the block's height")


func test_the_block_mesh_stays_inside_its_collision_box_and_draws_twice() -> void:
	var block: CityBlock = add_to_tree(CityBlock.new())
	block.setup({"size": [32, 20, 18], "tiers": 2, "seed": 4})
	var mesh := block.mesh_instance.mesh
	assert_eq(mesh.get_surface_count(), 2, "one surface for the building, one for its neon: two draw calls")
	var aabb := mesh.get_aabb()
	assert_true(aabb.size.x <= 32.0 + 0.2 and aabb.size.z <= 18.0 + 0.2, "within the collision box (the neon stands 6 cm off) %s" % aabb)
	assert_near(aabb.position.y, 0.0, 0.01, "on the ground")
	assert_true(aabb.end.y <= 20.0 + CityBlock.BEVEL + 0.01, "no taller than its box plus the roof's bevel")


func test_corners_are_chamfered_like_the_hud_frames() -> void:
	var outline := CityBlock.outline(20.0, 10.0, 0.0)
	assert_eq(outline.size(), 8, "four sides and four cut corners")
	assert_true(not outline.has(Vector2(10.0, 5.0)), "no sharp corner")
	assert_near(outline[1].distance_to(outline[2]), CityBlock.CHAMFER * sqrt(2.0), 0.01, "each cut is CHAMFER along both sides")
