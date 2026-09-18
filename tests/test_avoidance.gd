extends TestCase
## X3 (nav, round 6): ORCA local avoidance, as pure math (no scene). Two units meeting head-on each give way to their
## own side — reciprocally, never both the same way — and a parked unit makes the mover do all the avoiding.

const DT := 1.0 / 30.0
const R := 1.8


func _solve(me: String, rows: Array, position: Vector2, velocity: Vector2, preferred: Vector2) -> Vector2:
	Avoidance.load_rows(rows)
	return Avoidance.solve(me, position, velocity, preferred, 9.0, R, DT)


func test_nobody_near_keeps_the_wish() -> void:
	var wish := Vector2(0, 6)
	assert_eq(_solve("A", [["A", 0, 0, 0, 6, R, false], ["Far", 40, 0, 0, 0, R, false]], Vector2.ZERO, wish, wish), wish,
			"nothing within reach: the preferred velocity is the answer")


func test_head_on_both_give_way_to_opposite_sides() -> void:
	var rows := [["A", 0, 0, 0, 6, R, false], ["B", 0.2, 12, 0, -6, R, false]]
	var a := _solve("A", rows, Vector2(0, 0), Vector2(0, 6), Vector2(0, 6))
	var b := _solve("B", rows, Vector2(0.2, 12), Vector2(0, -6), Vector2(0, -6))
	assert_true(absf(a.x) > 0.3 and absf(b.x) > 0.3, "both swerve (A %s, B %s)" % [a, b])
	assert_true(signf(a.x) != signf(b.x), "to opposite sides, so they pass instead of mirroring (A %s, B %s)" % [a, b])
	assert_true(a.y > 2.0 and b.y < -2.0, "and both keep going (A %s, B %s)" % [a, b])


func test_reciprocal_shares_are_half_of_the_still_case() -> void:
	# The same encounter, but B is parked: A must do all of it.
	var moving := _solve("A", [["A", 0, 0, 0, 6, R, false], ["B", 0.5, 10, 0, 0, R, false]], Vector2.ZERO,
			Vector2(0, 6), Vector2(0, 6))
	var parked := _solve("A", [["A", 0, 0, 0, 6, R, false], ["B", 0.5, 10, 0, 0, R, true]], Vector2.ZERO,
			Vector2(0, 6), Vector2(0, 6))
	assert_true(Vector2(0, 6).distance_to(parked) > Vector2(0, 6).distance_to(moving) + 0.2,
			"a parked unit leaves all the avoiding to the mover (moving %s, parked %s)" % [moving, parked])


func test_the_answer_is_collision_free_over_the_horizon() -> void:
	var rows := [["A", 0, 0, 0, 6, R, false], ["B", 1.0, 9, 0, 0, R, true]]
	var v := _solve("A", rows, Vector2.ZERO, Vector2(0, 6), Vector2(0, 6))
	var closest := INF
	for step in 61:
		var t := step * Avoidance.TIME_HORIZON / 60.0
		closest = minf(closest, (v * t).distance_to(Vector2(1.0, 9)))
	assert_true(closest >= 2.0 * R - 0.05, "driving it for the horizon never closes inside the combined radius (%.2f m, v %s)" % [closest, v])


func test_a_crowd_still_gets_an_answer() -> void:
	var rows := [["A", 0, 0, 0, 0, R, false]]
	for i in 8:
		var angle := TAU * i / 8.0
		rows.append(["N%d" % i, cos(angle) * 4.0, sin(angle) * 4.0, 0, 0, R, true])
	var v := _solve("A", rows, Vector2.ZERO, Vector2.ZERO, Vector2(0, 6))
	assert_true(v.is_finite() and v.length() <= 9.01, "boxed in on every side: a finite velocity within top speed (%s)" % v)


func test_neighbours_are_ordered_by_distance_then_name() -> void:
	Avoidance.load_rows([["A", 0, 0, 0, 0, R, false], ["Zed", 3, 0, 0, 0, R, false], ["Bob", -3, 0, 0, 0, R, false],
			["Near", 0, 2, 0, 0, R, false]])
	var names := Avoidance.neighbours("A", 0, 0).map(func(row: Array) -> String: return row[1])
	assert_eq(names, ["Near", "Bob", "Zed"], "nearest first, equal distances by name")


func test_two_hulls_on_one_spot_part_opposite_ways() -> void:
	var rows := [["A", 0, 0, 0, 0, R, false], ["B", 0, 0, 0, 0, R, false]]
	var a := _solve("A", rows, Vector2.ZERO, Vector2.ZERO, Vector2(0, 6))
	var b := _solve("B", rows, Vector2.ZERO, Vector2.ZERO, Vector2(0, 6))
	assert_true(a.distance_to(b) > 1.0, "coincident hulls choose different velocities (A %s, B %s)" % [a, b])
