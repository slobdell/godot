extends TestCase
## G1: sight radius + line of sight, team vision as the union, and the visibility field UIs draw.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _field(game_match: Match) -> VisibilityField:
	var field := VisibilityField.new()
	field.game_match = game_match
	field.team = Match.Team.GREEN
	game_match.add_child(field)
	return field


func test_the_field_is_lit_in_the_open_and_dark_behind_cover() -> void:
	var game_match := _setup()
	var viewer := game_match.spawn_tank("Viewer", 0, Match.Team.GREEN)
	viewer.global_position = Vector3(-24, 0, 30)  # 18 m north... south of Crate1Mirror at (-24, 12)
	await wait_physics_frames(2)
	var field := _field(game_match)
	field.refresh_all()
	assert_eq(field.state_at(Vector3(-40, 0, 30)), VisibilityField.State.VISIBLE, "open ground 16 m away is visible")
	assert_eq(field.state_at(Vector3(-24, 0, 0)), VisibilityField.State.NEVER, "the ground right behind the crate is in its shadow")
	assert_eq(field.state_at(Vector3(-24, 0, 30 + 80)), VisibilityField.State.NEVER, "beyond the 75 m sight radius is dark")
	var cell := field.world_to_cell(Vector3(-40, 0, 30))
	assert_eq(field.image.get_pixel(cell.x, cell.y).r8, 255, "the image marks visible cells at full brightness")


func test_ground_you_have_left_is_remembered_as_seen() -> void:
	var game_match := _setup()
	var viewer := game_match.spawn_tank("Viewer", 0, Match.Team.GREEN)
	viewer.global_position = Vector3(-100, 0, 60)
	await wait_physics_frames(2)
	var field := _field(game_match)
	field.refresh_all()
	var spot := Vector3(-100, 0, 40)
	assert_eq(field.state_at(spot), VisibilityField.State.VISIBLE, "setup: visible from here")
	viewer.global_position = Vector3(100, 0, -60)
	await wait_physics_frames(2)
	field.refresh_all()
	assert_eq(field.state_at(spot), VisibilityField.State.SEEN, "after driving away it's remembered, not visible")
	var cell := field.world_to_cell(spot)
	assert_eq(field.image.get_pixel(cell.x, cell.y).r8, VisibilityField.SEEN_VALUE, "and drawn dimmer")


func test_team_vision_is_the_union_of_its_tanks() -> void:
	var game_match := _setup()
	var west := game_match.spawn_tank("West", 0, Match.Team.GREEN)
	var east := game_match.spawn_tank("East", 0, Match.Team.GREEN)
	west.global_position = Vector3(-100, 0, 60)
	east.global_position = Vector3(100, 0, 60)
	await wait_physics_frames(2)
	var field := _field(game_match)
	field.refresh_all()
	assert_eq(field.state_at(Vector3(-100, 0, 50)), VisibilityField.State.VISIBLE, "what the west tank sees")
	assert_eq(field.state_at(Vector3(100, 0, 50)), VisibilityField.State.VISIBLE, "and what the east tank sees")
	assert_eq(field.fans.size(), 2, "one view fan per living tank")


func test_intel_respects_each_tanks_sight_radius() -> void:
	var game_match := _setup()
	var short_sighted := game_match.spawn_tank("Short", 0, Match.Team.GREEN)
	var enemy := game_match.spawn_tank("Enemy", 0, Match.Team.RUST)
	short_sighted.sight_radius = 30.0
	short_sighted.global_position = Vector3(-100, 0, 30)
	enemy.global_position = Vector3(-100, 0, -20)  # 50 m, clear lane
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 2)
	assert_true(not game_match.is_visible_to(Match.Team.GREEN, enemy), "50 m is beyond a 30 m sight radius")
	short_sighted.sight_radius = 75.0
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 2)
	assert_true(game_match.is_visible_to(Match.Team.GREEN, enemy), "and inside a 75 m one")
	assert_true(game_match.is_visible_to(Match.Team.GREEN, short_sighted), "a team always sees its own tanks")


func test_a_full_refresh_is_cheap_enough() -> void:
	var game_match := _setup()
	for i in 5:
		var tank := game_match.spawn_tank("Viewer_%d" % i, 0, Match.Team.GREEN)
		tank.global_position = Vector3(-60 + i * 30, 0, 40)
	await wait_physics_frames(2)
	var field := _field(game_match)
	var started := Time.get_ticks_usec()
	field.refresh_all()
	var ms := (Time.get_ticks_usec() - started) / 1000.0
	print("MEASURE g1_visibility_refresh 5 viewers %.1f ms (spread over %d ticks in play)" % [ms, VisibilityField.REFRESH_TICKS])
	assert_true(ms < 200.0, "a full 5-tank refresh stays well under a frame budget spread over %d ticks (%.1f ms)" % [VisibilityField.REFRESH_TICKS, ms])


func test_the_field_sizes_to_the_loaded_arena_not_to_the_bound() -> void:
	# X3 (round 7): Match.ARENA_HALF_SIZE became a BOUND (140) rather than a size, so anything that sizes itself
	# from it now covers the largest arena that could ever load instead of the one that did. For the fog field that
	# is not a correctness bug -- brains never read it -- it is a silent cost: a 120 m map would carry a 280 x 280
	# grid, 36% more cells filled and uploaded every refresh, every one of the extra cells outside the walls.
	#
	# This is the test that would have failed before the change, and it is written against the RATIO rather than
	# against 120 or 140, so it keeps meaning the same thing the next time either number moves.
	var saved := Arena.active
	var loaded := Arena.load_layout("foundry")
	assert_true(loaded.has("layout"), "foundry loads")
	Arena.active = loaded["layout"]
	var half := float(Arena.active["half_size"])
	assert_true(half < Match.ARENA_HALF_SIZE, "the fixture is a layout SMALLER than the bound (%.0f < %.0f)"
			% [half, Match.ARENA_HALF_SIZE])

	var game_match := _setup()
	var field := _field(game_match)
	await wait_physics_frames(1)
	assert_eq(field.cells, ceili(half * 2.0 / VisibilityField.CELL_SIZE),
			"the grid spans the LOADED arena, not the bound")
	assert_near(field.origin.x, -half, 0.01, "and cell (0,0) starts at the layout's own edge...")
	assert_near(field.origin.y, -half, 0.01, "...on both axes")
	# The corners must still map inside the grid, or the saving would have come out of the playable area.
	var corner := field.world_to_cell(Vector3(half - 1.0, 0.0, half - 1.0))
	assert_true(corner.x >= 0 and corner.x < field.cells and corner.y >= 0 and corner.y < field.cells,
			"a point just inside the far corner is still a cell in the grid (%s of %d)" % [corner, field.cells])
	Arena.active = saved
