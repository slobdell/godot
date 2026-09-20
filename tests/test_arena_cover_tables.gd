extends TestCase
## A3 (scale, round 9): cover measured over a hull's own length, and the falsifier the catalogue pre-registered.
##
## **The positive control comes first, because a treatment that cannot be distinguished from its control proves
## nothing** (lesson 147). Under the query this replaces -- registering cover at the hull's CENTRE POINT -- yard's
## cover score is 0.99 for a 12 m hull and 0.00 for a 12.5 m one: a step function at 12.19 m, the length of
## `container_40`, reproduced on the resized roster in `make arena-report`. A hull-chord query must make that
## cliff go away. If it survives, the treatment did not engage.
##
## The determinism assertion is here because combat asked for it in a test rather than in a comment: the tables are
## integer prefix sums and the difference of two of them is exact, so the same query has to give bit-identical
## answers whatever order the tables were built in.

const REACH := CoverTables.COVER_REACH_M


## A layout with one long wall across the middle: everything south of it is in cover from a watcher to the north.
func _walled(wall_length: float, half := 60.0) -> Dictionary:
	return {"name": "walled", "half_size": half, "obstacles": [
			{"type": "block", "position": [0.0, 0.0], "rotation_deg": 0.0, "size": [wall_length, 4.0, 2.0]}]}


func test_a_hull_behind_a_long_wall_is_covered_and_one_beside_it_is_not() -> void:
	var tables := CoverTables.build(_walled(60.0))
	assert_true(tables.is_built(), "the tables built")
	var north := Vector3(0.0, 0.0, -40.0)
	var behind := Vector3(0.0, 0.0, 8.0)   # south of the wall, between it and the watcher's opposite side
	var beside := Vector3(50.0, 0.0, 8.0)  # past the wall's end
	var east := Vector3(1.0, 0.0, 0.0)
	assert_true(tables.cover_fraction(north, behind, east, 14.0) > 0.9,
			"a 14 m hull lying along a 60 m wall is covered from the far side (%.2f)"
			% tables.cover_fraction(north, behind, east, 14.0))
	assert_true(tables.cover_fraction(north, beside, east, 14.0) < 0.1,
			"a hull past the wall's end is not (%.2f)" % tables.cover_fraction(north, beside, east, 14.0))


## THE FALSIFIER. The catalogue pre-registered it: the cover a hull gets must stop being a step function of its
## length. A wall 12.19 m long -- `container_40`, the prop that makes yard's cliff -- covers a 12 m hull almost
## entirely under the old query and a 14 m hull not at all. Under the chord query the 14 m hull must come back to
## within 0.1 of its 12 m value, because it is 87% as long and the wall hides most of it either way.
func test_the_12_19_m_step_is_gone() -> void:
	var tables := CoverTables.build(_walled(12.19))
	var north := Vector3(0.0, 0.0, -40.0)
	var behind := Vector3(0.0, 0.0, 6.0)
	var east := Vector3(1.0, 0.0, 0.0)
	var at_12 := tables.cover_fraction(north, behind, east, 12.0)
	var at_14 := tables.cover_fraction(north, behind, east, 14.0)
	assert_true(at_12 > 0.5, "a 12 m hull behind a 12.19 m wall is mostly covered (%.2f)" % at_12)
	assert_true(absf(at_14 - at_12) <= 0.1,
			"and a 14 m hull is within 0.1 of it, not at zero: 12 m %.2f, 14 m %.2f" % [at_12, at_14])
	# Every length between them, monotone-ish and never a cliff: no pair 0.5 m apart may differ by more than 0.2.
	var previous := -1.0
	var length := 2.93
	while length <= 14.0:
		var value := tables.cover_fraction(north, behind, east, length)
		if previous >= 0.0:
			assert_true(absf(value - previous) <= 0.2,
					"cover at %.2f m (%.2f) is not a cliff away from %.2f m (%.2f)" % [length, value, length - 0.5, previous])
		previous = value
		length += 0.5


## Combat calls this per candidate point, per query, per unit, so a silly point must cost nothing and say nothing.
func test_a_hull_off_the_table_returns_zero_and_does_not_complain() -> void:
	var tables := CoverTables.build(_walled(60.0))
	var north := Vector3(0.0, 0.0, -40.0)
	var east := Vector3(1.0, 0.0, 0.0)
	assert_eq(tables.cover_fraction(north, Vector3(5000.0, 0.0, 5000.0), east, 14.0), 0.0, "far outside the arena")
	assert_eq(tables.cover_fraction(north, Vector3(58.0, 0.0, 0.0), east, 14.0), 0.0, "a chord straddling the edge")
	assert_eq(tables.cover_fraction(north, Vector3(0.0, 0.0, 8.0), Vector3.ZERO, 14.0), 0.0, "no heading")
	assert_eq(tables.cover_fraction(north, Vector3(0.0, 0.0, 8.0), east, 0.0), 0.0, "no length")
	assert_eq(CoverTables.new().cover_fraction(north, Vector3.ZERO, east, 14.0), 0.0, "tables that were never built")


## Integer prefix sums, exact differences: the same question gives bit-identical answers, and two tables built from
## the same layout agree bit for bit. The sim baseline moves at CP2 anyway, so this is the one chance to prove the
## query is not what moves it later (combat's request).
func test_the_query_is_exact_and_repeatable() -> void:
	var layout := _walled(30.0)
	var a := CoverTables.build(layout)
	var b := CoverTables.build(layout)
	var viewer := Vector3(-30.0, 0.0, -30.0)
	for length: float in [2.93, 5.55, 8.62, 14.0]:
		for x in [-20.0, -6.0, 0.0, 6.0, 20.0]:
			for heading: Vector3 in [Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 1).normalized()]:
				var at := Vector3(x, 0.0, 6.0)
				var first := a.cover_fraction(viewer, at, heading, length)
				assert_eq(a.cover_fraction(viewer, at, heading, length), first, "the same query, twice")
				assert_eq(b.cover_fraction(viewer, at, heading, length), first, "and a second build of the tables")


## The cost of the approximation, in the two terms combat's threshold sits on. The point of reporting them apart is
## that they move in opposite directions with hull length, so the query is LEAST precise on the shortest hull.
func test_the_quantisation_error_is_worst_on_the_shortest_hull() -> void:
	var rat_rod := CoverTables.worst_case_error(2.93)
	var rig := CoverTables.worst_case_error(14.0)
	assert_near(float(rat_rod["angular"]), float(rig["angular"]), 1e-9,
			"the angular term is a constant fraction of any hull length")
	assert_true(float(rat_rod["grid"]) > float(rig["grid"]) * 4.0,
			"the grid term is a constant in metres, so it dominates the short hull (%.3f vs %.3f)"
			% [rat_rod["grid"], rig["grid"]])
	assert_true(float(rig["total"]) < 0.25, "and the rig's worst case is still under a quarter of its length (%.3f)"
			% rig["total"])


## Directions are quantised without trig, because trig does not agree across builds (trip-up 52). Checked at the
## boundaries, both ways round, so a sign error cannot hide in the middle of an octant.
func test_directions_quantise_to_eight_without_trig() -> void:
	assert_eq(CoverTables.direction_index(Vector2(1.0, 0.0)), 0, "+X")
	assert_eq(CoverTables.direction_index(Vector2(1.0, 1.0)), 1, "+X+Z")
	assert_eq(CoverTables.direction_index(Vector2(0.0, 1.0)), 2, "+Z")
	assert_eq(CoverTables.direction_index(Vector2(-1.0, 1.0)), 3, "-X+Z")
	assert_eq(CoverTables.direction_index(Vector2(-1.0, 0.0)), 4, "-X")
	assert_eq(CoverTables.direction_index(Vector2(-1.0, -1.0)), 5, "-X-Z")
	assert_eq(CoverTables.direction_index(Vector2(0.0, -1.0)), 6, "-Z")
	assert_eq(CoverTables.direction_index(Vector2(1.0, -1.0)), 7, "+X-Z")
	assert_eq(CoverTables.direction_index(Vector2.ZERO), -1, "a zero direction is refused, not guessed")
	# Just either side of the 22.5 deg boundary between +X and +X+Z.
	assert_eq(CoverTables.direction_index(Vector2(1.0, 0.40)), 0, "just inside the axis octant")
	assert_eq(CoverTables.direction_index(Vector2(1.0, 0.43)), 1, "just inside the diagonal octant")


## THE POSITIVE CONTROL, kept in the suite rather than run once. Lesson 147: a treatment that cannot be
## distinguished from its control proves nothing, and the way to know is to run the control. This reimplements the
## OLD rule in four lines -- a prop counts as cover only if its longest horizontal side is at least the hull's
## length, which is what `arena_report.hull_cover_reach` does and what `TacticalQuery` consumed -- and asserts that
## it DOES cliff on the same fixture where the chord query does not. When the point sample is deleted next round,
## this stays: it is the record of what was replaced.
func _old_rule_covered(prop_length: float, hull_length: float) -> bool:
	return prop_length >= hull_length


func test_the_old_centre_point_rule_cliffs_on_the_same_fixture() -> void:
	var wall := 12.19
	assert_true(_old_rule_covered(wall, 12.0), "the old rule covers a 12 m hull behind a 12.19 m prop")
	assert_true(not _old_rule_covered(wall, 12.5), "and covers a 12.5 m hull not at all: a step, not a gradient")
	# The same two lengths through the new query, on the same geometry: no step.
	var tables := CoverTables.build(_walled(wall))
	var north := Vector3(0.0, 0.0, -40.0)
	var behind := Vector3(0.0, 0.0, 6.0)
	var east := Vector3(1.0, 0.0, 0.0)
	var at_12 := tables.cover_fraction(north, behind, east, 12.0)
	var at_12_5 := tables.cover_fraction(north, behind, east, 12.5)
	assert_true(absf(at_12_5 - at_12) < 0.1,
			"the chord query steps by %.2f where the old rule stepped by 1.00 (%.2f -> %.2f)"
			% [absf(at_12_5 - at_12), at_12, at_12_5])


## And on a map the lead has played, not only on a fixture. **yard is where the cliff was found**: under the old
## centre-point rule 0.99 of the field is within reach of a prop long enough for a 12.19 m hull and **0.00** for a
## 12.5 m one, reproduced on the resized roster by `make arena-report` (laptop, pure Python, machine-independent).
## Here the same field is swept with the chord query and the cover a hull gets must be FLAT in its length.
##
## Measured on the laptop at this commit, mean occluded chord fraction over the contested field, watcher on the far
## side, hull lengths 2.93 / 6 / 8.62 / 12 / 12.19 / 12.5 / 14 m:
##   yard      0.32  0.29  0.29  0.29  0.29  0.29  0.29
##   pit       0.31  0.38  0.34  0.36  0.36  0.36  0.36
##   terminus  0.76  0.76  0.77  0.77  0.77  0.77  0.77
## The bars below are set from those numbers rather than guessed (lesson 3), with room for a cell of grid noise.
func test_no_shipped_map_cliffs_between_twelve_and_fourteen_metres() -> void:
	for name: String in Arena.ROTATION:
		var loaded := Arena.load_layout(name)
		assert_true(not loaded.has("error"), "%s loads (%s)" % [name, loaded.get("error", "")])
		var tables := CoverTables.build(loaded["layout"])
		assert_true(tables.is_built(), "%s's tables built (%d cells a side)" % [name, tables.cell_count()])
		var east := Vector3(1.0, 0.0, 0.0)
		var shares := {}
		for length: float in [12.0, 12.19, 12.5, 14.0]:
			var covered := 0.0
			var points := 0
			var z := -80.0
			while z <= 80.0:
				var x := -80.0
				while x <= 80.0:
					points += 1
					# A watcher on the far side of the field, which is the shot that matters.
					var viewer := Vector3(x, 0.0, -110.0 if z > 0.0 else 110.0)
					covered += tables.cover_fraction(viewer, Vector3(x, 0.0, z), east, length)
					x += 8.0
				z += 8.0
			shares[length] = covered / float(points)
		assert_true(float(shares[12.0]) > 0.15, "%s: a 12 m hull can hide (%.2f of its chord on average)"
				% [name, shares[12.0]])
		for length: float in [12.19, 12.5, 14.0]:
			assert_true(absf(float(shares[length]) - float(shares[12.0])) <= 0.1,
					"%s: a %.2f m hull gets %.2f where a 12 m hull gets %.2f -- the old rule put the 12.5 m one at 0.00"
					% [name, length, shares[length], shares[12.0]])


## The sweeps walk lines that enter the grid through its edges, and a line family that MISSES cells leaves zeros in
## the prefix that look exactly like "nothing is in the way". Nothing about a wrong answer would be visible, so the
## coverage is asserted rather than reasoned about: with every cell blocked, every cell must read as covered from
## every direction and at every heading. One missed line and the fraction drops below 1.0.
func test_every_line_family_reaches_every_cell() -> void:
	var half := 20.0
	var solid := {"name": "solid", "half_size": half, "obstacles": [
			{"type": "block", "position": [0.0, 0.0], "rotation_deg": 0.0, "size": [2.0 * half, 4.0, 2.0 * half]}]}
	var tables := CoverTables.build(solid)
	assert_true(tables.is_built(), "the tables built")
	var headings := [Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1), Vector3(-1, 0, 1)]
	var viewers := [Vector3(100, 0, 0), Vector3(100, 0, 100), Vector3(0, 0, 100), Vector3(-100, 0, 100),
			Vector3(-100, 0, 0), Vector3(-100, 0, -100), Vector3(0, 0, -100), Vector3(100, 0, -100)]
	var z := -half + 6.0
	while z <= half - 6.0:
		var x := -half + 6.0
		while x <= half - 6.0:
			for viewer: Vector3 in viewers:
				for heading: Vector3 in headings:
					assert_eq(tables.cover_fraction(viewer, Vector3(x, 0.0, z), heading, 8.0), 1.0,
							"solid ground at %.0f,%.0f is covered from %s along %s" % [x, z, viewer, heading])
			x += 4.0
		z += 4.0
