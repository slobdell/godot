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


func test_a_block_gets_the_neon_colour_its_layout_ASKED_for() -> void:
	## Round 9 (show found it): `neon_color` honoured only strings beginning with "#", so every colour NAME fell
	## through to a random pick from the SIGNAGE palette. `arenas/terminus.json` asks for "cyan" on four blocks and
	## "magenta" on four, and all eight were drawing amber, warm white, red or violet -- stable only because the
	## pick is seeded, which is why it survived a round. Red is a SIGNAL in this game and the near-white is not in
	## the palette at all, so the bug put the two colours art_direction.md rules out for architecture onto the
	## lead's city map.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	assert_eq(CityBlock.neon_color("cyan", rng), Color("cyan"), "a named colour is honoured")
	assert_eq(CityBlock.neon_color("magenta", rng), Color("magenta"), "both of the names the Terminus uses")
	assert_eq(CityBlock.neon_color("#00F3FF", rng), Color("#00F3FF"), "and an HTML code still is")
	# Every colour the Terminus actually asks for resolves -- read from the layout, not from this test's memory.
	var layout: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://arenas/terminus.json"))
	var asked := 0
	for prop: Dictionary in (layout as Dictionary).get("props", []):
		if String(prop.get("type", "")) != "block" or not prop.has("neon"):
			continue
		asked += 1
		var wanted := String(prop["neon"])
		assert_true(CityBlock.neon_color(wanted, rng) != CityBlock.UNRESOLVED, "the Terminus's '%s' resolves" % wanted)
		assert_true(not NeonSigns.COLORS.has(CityBlock.neon_color(wanted, rng)),
				"'%s' is the layout's colour, not a signage-palette pick" % wanted)
	assert_true(asked >= 8, "the Terminus still asks for a colour on its blocks (%d)" % asked)


func test_an_unknown_colour_name_is_deterministic_rather_than_a_dice_roll() -> void:
	## The failure mode that hid the bug: answering a name someone typed on purpose with a seeded random pick looks
	## exactly like a deliberate choice. An unresolvable name now gives the SAME colour whatever the rng is doing.
	var first := RandomNumberGenerator.new()
	first.seed = 1
	var second := RandomNumberGenerator.new()
	second.seed = 99999
	second.randi()
	assert_eq(CityBlock.neon_color("not-a-colour", first), CityBlock.neon_color("not-a-colour", second),
			"an unknown name does not depend on the rng")
	# And it stays DETECTABLE, so `Arena.validate()` can reject a typo once when the layout is read. The detection
	# is a predicate rather than a warning because the warning fired per block per build -- and because the test
	# runner's ErrorCollector ignores `_error_type`, so a push_warning fails any test that exercises the path.
	assert_true(not CityBlock.resolves("not-a-colour"), "and an unknown name is reported as unresolvable")
	assert_true(CityBlock.resolves("cyan") and CityBlock.resolves("#00F3FF"), "while real colours resolve")
	assert_true(CityBlock.resolves(null), "and asking for nothing is legal -- it means 'pick me a signage colour'")
	# And a block that asks for NOTHING still gets variety, which is the behaviour that was always intended.
	var a := RandomNumberGenerator.new()
	a.seed = 3
	var b := RandomNumberGenerator.new()
	b.seed = 3
	assert_eq(CityBlock.neon_color(null, a), CityBlock.neon_color(null, b), "no colour asked: seeded, so replayable")
	assert_true(NeonSigns.COLORS.has(CityBlock.neon_color(null, a)), "and it comes from the signage palette")


func test_a_tier_count_the_builder_cannot_honour_is_reported_rather_than_clamped() -> void:
	## Same shape as the unknown-colour bug above, found while measuring the Terminus roofs: `setup` does
	## `clampi(tiers, 1, 3)`, so a layout asking for 4 silently gets 3 and the author's intent is lost with nothing
	## said anywhere. `arenas/terminus.json` really does ask for 4 on two blocks, and those two buildings are
	## shorter and their roofs flatter than the layout asks for.
	##
	## The clamp itself stays -- the builder must draw SOMETHING for any input -- but "can this be honoured?" becomes
	## a question that can be asked, exactly like `resolves()` for colours. It is deliberately NOT wired into
	## `Arena.validate()`: `Arena` is read by `Match`, so a layout failing to LOAD over a `game/theme/` concern would
	## invert the rule that art must never change the simulation (the same reasoning the `show` key carries).
	assert_true(CityBlock.honours_tiers(1) and CityBlock.honours_tiers(3), "the supported range is honoured")
	assert_true(not CityBlock.honours_tiers(4), "and 4 is not: it would be clamped to 3 with nothing said")
	assert_true(not CityBlock.honours_tiers(0), "nor is 0")
	assert_true(CityBlock.honours_tiers(null), "while asking for nothing is legal -- the block seeds its own")

