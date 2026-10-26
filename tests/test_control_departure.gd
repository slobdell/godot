extends TestCase
## Round 41 (orders O2, `--group-depart=queue`): DepartureQueue's pure reads. The front squad ranks first; a squad's
## corridor is the first CORRIDOR_M of its route (at most half of it); a crew within CORRIDOR_HALF_M of it blocks.


func test_squads_rank_front_first_along_the_approach() -> void:
	var centres := [Vector3(0, 0, 0), Vector3(0, 0, -30), Vector3(10, 0, -15)]
	assert_eq(DepartureQueue.rank(centres, Vector3(0, 0, -1)), [1, 2, 0], "the squad nearest the way he sent them goes first")
	assert_eq(DepartureQueue.rank(centres, Vector3(0, 0, 1)), [0, 2, 1], "reversed approach, reversed rank")
	assert_eq(DepartureQueue.rank([Vector3(5, 0, 0), Vector3(-5, 0, 0)], Vector3(0, 0, -1)), [0, 1], "abreast: dealt order")


func test_the_corridor_is_the_first_stretch_of_the_route() -> void:
	var route := PackedVector3Array([Vector3(0, 0, 0), Vector3(20, 0, 0), Vector3(20, 0, 100)])
	var corridor := DepartureQueue.corridor_of(route)
	assert_eq(corridor.size(), 3, "it follows the route round its corner")
	assert_true(corridor[2].distance_to(Vector2(20, DepartureQueue.CORRIDOR_M - 20.0)) < 0.01, "and stops CORRIDOR_M along it")
	var short := DepartureQueue.corridor_of(PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -20)]))
	assert_true(short[short.size() - 1].distance_to(Vector2(0, -10)) < 0.01, "at most half a short route")
	assert_eq(DepartureQueue.corridor_of(PackedVector3Array([Vector3.ZERO])).size(), 0, "no route, no corridor")


func test_crews_in_the_corridor_block_and_crews_beside_it_do_not() -> void:
	var corridor := PackedVector2Array([Vector2(0, 0), Vector2(0, -30)])
	var crews := {"in_road": Vector2(3, -12), "beside": Vector2(12, -12), "beyond": Vector2(0, -45), "edge": Vector2(-7, -20)}
	assert_eq(DepartureQueue.blockers(corridor, crews), ["edge", "in_road"], "within CORRIDOR_HALF_M of the road, sorted")
	assert_eq(DepartureQueue.blockers(corridor, {}), [], "an empty road is clear")


func test_the_longest_drive_ranks_first_and_route_length_is_flat() -> void:
	assert_eq(DepartureQueue.rank_by_drive([120.0, 240.0, 120.0, 90.0]), [1, 0, 2, 3], "longest first, ties in dealt order")
	var route := PackedVector3Array([Vector3(0, 0, 0), Vector3(3, 5, 4), Vector3(3, 0, 14)])
	assert_true(absf(DepartureQueue.route_length(route) - 15.0) < 0.001, "flat metres along the route")


func test_v3_the_merge_is_where_the_roads_meet_before_the_halt_area() -> void:
	# Mine comes in from the side and joins the other's road at (0, -60); both run on to z = -140.
	var other := PackedVector2Array([Vector2(0, 0), Vector2(0, -140)])
	var mine := PackedVector2Array([Vector2(40, -20), Vector2(0, -60), Vector2(0, -140)])
	var merge := DepartureQueue.merge_of(mine, other)
	assert_true(not merge.is_empty(), "the roads meet")
	assert_true(absf(float(merge["at_m"]) - 55.0) < 3.0, "about 55-60 m along the other's road (%s)" % merge)
	assert_true(float(merge["mine_m"]) < 57.0, "before mine reaches the join (%s)" % merge)
	var apart := PackedVector2Array([Vector2(60, 0), Vector2(60, -140)])
	assert_true(DepartureQueue.merge_of(apart, other).is_empty(), "parallel streets 60 m apart never merge")
	# Roads that only meet in the halt area (their last MERGE_SKIP_END_M) do not count.
	var late := PackedVector2Array([Vector2(30, 0), Vector2(5, -135), Vector2(0, -140)])
	assert_true(DepartureQueue.merge_of(late, other).is_empty(), "meeting only at the halt is not a merge")


func test_v3_a_squad_goes_when_the_other_tail_will_be_through_the_merge_first() -> void:
	var road := PackedVector2Array([Vector2(0, 0), Vector2(0, -140)])
	# The merge is 60 m along the other's road; mine is 40 m from it, so it goes once the other's tail is <= 30 m short.
	assert_true(not DepartureQueue.merge_clear(road, 60.0, 40.0, [Vector2(0, -10), Vector2(0, -40)]), "tail 50 m short: wait")
	assert_true(DepartureQueue.merge_clear(road, 60.0, 40.0, [Vector2(0, -35), Vector2(0, -70)]), "tail 25 m short: go")
	assert_true(DepartureQueue.merge_clear(road, 60.0, 40.0, []), "nobody left on that road: go")
	assert_true(absf(DepartureQueue.arc_of(road, Vector2(5, -33)) - 33.0) < 0.01, "arc length of a point beside the road")
