extends TestCase
## S1 (round 16): the shipping VisibilityField draws exactly what the pre-S1 field drew. Both run on the SAME match,
## side by side, ticked by the engine as the skirmish ticks them; every tick their images must be byte-identical and
## their fans equal, and every few ticks every cell's state_at must agree. The reference is the old file verbatim
## (`tests/scale/visfield_reference.gd`). Viewers drive, stand still (the memo's path), cross the map's walls and pits,
## and one dies mid-run.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const REFERENCE := preload("res://tests/scale/visfield_reference.gd")
const TICKS := 75
const STATE_EVERY := 15


func _setup(layout: String) -> Match:
	var arena: Node = ARENA.instantiate()
	arena.layout_name = layout
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _states(field: Node) -> PackedByteArray:
	var out := PackedByteArray()
	out.resize(field.cells * field.cells)
	for y in field.cells:
		for x in field.cells:
			out[y * field.cells + x] = int(field.state_at(field.cell_to_world(Vector2i(x, y))))
	return out


func _run_side_by_side(layout: String) -> void:
	var game_match := _setup(layout)
	var roster: Array = Array(Units.roster("law")) + Array(Units.roster(Units.DEFAULT_FACTION))
	var viewers: Array[Tank] = []
	for i in 7:
		viewers.append(game_match.spawn_tank("V%d" % i, 0, Match.Team.GREEN, roster[(i * 3) % roster.size()]))
	await wait_physics_frames(2)
	var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE))
	var reference: Node = REFERENCE.new()
	reference.game_match = game_match
	game_match.add_child(reference)
	var shipping := VisibilityField.new()
	shipping.game_match = game_match
	game_match.add_child(shipping)
	reference.refresh_all()
	shipping.refresh_all()
	var refreshes := [0]
	shipping.updated.connect(func() -> void: refreshes[0] += 1)
	var mismatches := 0
	for t in TICKS:
		# Drivers sweep the map (through walls, pits and the open); viewers 4-6 stand still (the memo).
		for i in 4:
			var phase := float(t) / TICKS * TAU + i * 1.7
			viewers[i].global_position = Vector3(cos(phase) * half * (0.25 + 0.15 * i), 0.0,
					sin(phase * 1.3) * half * 0.6)
		if t == TICKS / 2:
			viewers[5].apply_damage(100000)
		await wait_physics_frames(1)
		if shipping.image.get_data() != reference.image.get_data():
			mismatches += 1
			if mismatches == 1:
				fail_once(layout, t, "image")
		if shipping.fans != reference.fans:
			mismatches += 1
			fail_once(layout, t, "fans")
		if t % STATE_EVERY == 0 or t == TICKS - 1:
			if _states(shipping) != _states(reference):
				mismatches += 1
				fail_once(layout, t, "state_at")
	assert_eq(mismatches, 0, "%s: the shipping field matches the pre-S1 field on every tick" % layout)
	assert_true(refreshes[0] >= 2, "%s: the run covered whole refreshes (%d)" % [layout, refreshes[0]])
	assert_true(shipping.reused_looks > 0, "%s: the memo's path ran (%d looks reused)" % [layout, shipping.reused_looks])
	assert_true(not viewers[5].is_alive(), "%s: setup: the killed viewer is dead" % layout)
	var lit := 0
	for value in shipping.image.get_data():
		if value == 255:
			lit += 1
	assert_true(lit > 500, "%s: the comparison is of a lit field, not two empty ones (%d lit cells)" % [layout, lit])
	print("VISFIELD_PARITY %s ticks=%d refreshes=%d reused=%d lit=%d hash=%s" % [layout, TICKS, refreshes[0], shipping.reused_looks, lit,
			str(hash(shipping.image.get_data()))])


func fail_once(layout: String, t: int, what: String) -> void:
	assert_true(false, "%s: %s differs from the reference at tick %d" % [layout, what, t])


func test_the_field_matches_the_reference_on_the_sumps() -> void:
	await _run_side_by_side("sumps")


func test_the_field_matches_the_reference_on_the_terminus() -> void:
	await _run_side_by_side("terminus")
