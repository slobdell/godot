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
