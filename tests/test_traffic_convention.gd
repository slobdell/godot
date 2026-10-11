extends TestCase
## Round 26 (traffic CP1b, C26.4): the friendly convention, pure (Traffic.shape over a table loaded by hand). Forward is
## -Z and a hull's right is +X when it faces -Z (trip-up 2). Rows: [name, team, x, z, vx, vz, heading_x, heading_z,
## radius, moving].

const R := 3.0


func _reset() -> void:
	Traffic.set_off("keepright", false)
	Traffic.set_off("crossing", false)


func _head_on(b_team := 0, b_moving := true, b_x := 0.0, gap := 40.0) -> void:
	Traffic.load_rows([
		["A", 0, 0.0, gap * 0.5, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", b_team, b_x, -gap * 0.5, 0.0, 10.0, 0.0, 1.0, R, b_moving],
	])


func test_head_on_friendlies_both_keep_right_and_mirror_each_other() -> void:
	_reset()
	_head_on()
	var a := Traffic.shape("A", Vector2(0.0, -10.0))
	var b := Traffic.shape("B", Vector2(0.0, 10.0))
	assert_true(a.x > 0.5, "A (facing -Z) turns to its right, +X: %s" % a)
	assert_true(b.x < -0.5, "B (facing +Z) turns to its right, -X: %s" % b)
	assert_near(a.x, -b.x, 0.0001, "both take the same half")
	assert_near(a.length(), 10.0, 0.001, "the speed is kept: only the direction turns")
	assert_true(a.y < 0.0 and b.y > 0.0, "both keep going where they were going")


func test_head_on_slightly_offset_the_wrong_way_still_keeps_right() -> void:
	_reset()
	_head_on(0, true, 2.0)  # B starts 2 m to A's right
	var a := Traffic.shape("A", Vector2(0.0, -10.0))
	var b := Traffic.shape("B", Vector2(0.0, 10.0))
	assert_true(a.x > 0.0 and b.x < 0.0, "the rule, not the geometry, picks the side: %s %s" % [a, b])


func test_never_against_an_enemy_or_a_parked_friend() -> void:
	_reset()
	_head_on(1)
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "an enemy: unchanged (it may block)")
	_head_on(0, false)
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "a parked friend: ORCA and the give-way")


func test_head_on_far_off_or_already_clear_changes_nothing() -> void:
	_reset()
	_head_on(0, true, 0.0, 120.0)
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "6 s away: not yet")
	_head_on(0, true, -12.0)
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "already passing left to left, clear")


func test_a_crossing_tie_gives_priority_to_the_right() -> void:
	_reset()
	# A comes south (-Z) to the origin, B east (+X) to it, both 20 m out at 10 m/s: a tie. B has A on its right
	# (B faces +X, its right is +Z, A is at +Z): B yields; A has B on its left: A holds.
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", 0, -20.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true],
	])
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "A holds its line")
	var b := Traffic.shape("B", Vector2(10.0, 0.0))
	assert_true(b.length() < 8.0, "B slows: %s" % b)
	assert_true(b.x > 0.0 and absf(b.y) < 0.001, "and keeps its heading")


func test_at_a_crossing_the_later_crew_yields() -> void:
	_reset()
	# A is 27 m out (2.7 s), B 20 m (2.0 s): past the tie, inside the overlap. A (later) yields though B is on its left.
	Traffic.load_rows([
		["A", 0, 0.0, 27.0, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", 0, -20.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true],
	])
	assert_true(Traffic.shape("A", Vector2(0.0, -10.0)).length() < 9.0, "the later crew slows")
	assert_eq(Traffic.shape("B", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "the earlier one holds")


func test_a_crossing_with_room_in_time_changes_nothing() -> void:
	_reset()
	Traffic.load_rows([
		["A", 0, 0.0, 40.0, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", 0, -5.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true],
	])
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "B is long gone when A gets there")


func test_following_is_not_a_crossing() -> void:
	_reset()
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", 0, 3.0, 0.0, 1.0, -10.0, 0.1, -1.0, R, true],
	])
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "same way: ORCA and the give-way")


func test_switched_off_nothing_changes() -> void:
	_head_on()
	Traffic.set_off("keepright", true)
	assert_eq(Traffic.shape("A", Vector2(0.0, -10.0)), Vector2(0.0, -10.0), "--traffic-off=keepright")
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", 0, -20.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true],
	])
	Traffic.set_off("crossing", true)
	assert_eq(Traffic.shape("B", Vector2(10.0, 0.0)), Vector2(10.0, 0.0), "--traffic-off=crossing")
	_reset()


func test_a_crossing_verdict_is_the_pairs_and_both_crews_read_it() -> void:
	_reset()
	Traffic.load_rows([
		["A", 0, 0.0, 20.0, 0.0, -10.0, 0.0, -1.0, R, true],
		["B", 0, -20.0, 0.0, 10.0, 0.0, 1.0, 0.0, R, true],
	])
	var b := Traffic.shape("B", Vector2(10.0, 0.0))
	var a := Traffic.shape("A", Vector2(0.0, -10.0))
	assert_true(b.length() < 8.0 and is_equal_approx(a.length(), 10.0), "one yields, the other holds: %s %s" % [a, b])
	assert_eq(Traffic.shape("B", Vector2(10.0, 0.0)), b, "asked again on the same tick: the same answer")
