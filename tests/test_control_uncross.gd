extends TestCase
## Round 35 (orders D5, C35.5): a queued leg's places are dealt by the squads' DRIVES, not their straight lines. Planner's
## Locks 5-squad route: squads 3 and 5 jammed ~55 s at the junction near (5, 65) because their navmesh drives off the
## second waypoint crossed although their anchors' straight lines did not. SelectionSquads.uncross_paths swaps two
## squads' places when their paths cross, if the swap uncrosses them and the total drive grows within the length guard.
## Pure: stub paths.


func teardown() -> void:
	SelectionSquads.UNCROSS = true
	super.teardown()


## A stub navmesh: every drive goes up its own lane of a north-south street to the junction line (z 0), then straight
## to its place (a street mouth), as two squads side by side in one street do.
func _via_junction(a: Vector3, b: Vector3) -> PackedVector3Array:
	return PackedVector3Array([a, Vector3(a.x, 0, 0), b])


func _len(a: Vector3, b: Vector3) -> float:
	var path := _via_junction(a, b)
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func _straight(a: Vector3, b: Vector3) -> PackedVector3Array:
	return PackedVector3Array([a, b])


func _straight_len(a: Vector3, b: Vector3) -> float:
	return a.distance_to(b)


func test_crossing_drives_are_swapped() -> void:
	# Two squads come up a street from the south side by side (west one at x -6, east at +6) to the junction; the west
	# one's place is EAST (40, -30), the east one's WEST (-40, -30): their drives cross after the junction.
	var starts := [Vector3(-6, 0, 60), Vector3(6, 0, 60)]
	var anchors: Array[Vector3] = [Vector3(40, 0, -30), Vector3(-40, 0, -30)]
	var dealt := SelectionSquads.uncross_paths(anchors, starts, _via_junction, _len)
	assert_eq(dealt, [Vector3(-40, 0, -30), Vector3(40, 0, -30)] as Array[Vector3], "the west squad goes west, the east one east")


func test_drives_that_do_not_cross_stand() -> void:
	var starts := [Vector3(-6, 0, 60), Vector3(6, 0, 60)]
	var anchors: Array[Vector3] = [Vector3(-40, 0, -30), Vector3(40, 0, -30)]
	assert_eq(SelectionSquads.uncross_paths(anchors, starts, _via_junction, _len), anchors, "nothing to swap")


func test_the_length_guard_refuses_a_long_swap() -> void:
	# Straight drives that cross, where swapping would double the driving: kept (the guard), crossing or not.
	var starts := [Vector3(0, 0, 0), Vector3(100, 0, 10)]
	var anchors: Array[Vector3] = [Vector3(100, 0, 0), Vector3(0, 0, 10.5)]
	var dealt := SelectionSquads.uncross_paths(anchors, starts, _straight, _straight_len)
	assert_eq(dealt, anchors, "a swap that costs far more driving is refused")


func test_five_squads_end_with_no_crossing_drives() -> void:
	var starts := [Vector3(-12, 0, 60), Vector3(-6, 0, 60), Vector3(0, 0, 60), Vector3(6, 0, 60), Vector3(12, 0, 60)]
	var anchors: Array[Vector3] = [Vector3(60, 0, -20), Vector3(-30, 0, -40), Vector3(30, 0, -40), Vector3(-60, 0, -20), Vector3(0, 0, -50)]
	var dealt := SelectionSquads.uncross_paths(anchors, starts, _via_junction, _len)
	for i in dealt.size():
		for j in range(i + 1, dealt.size()):
			assert_true(not SelectionSquads.paths_cross(_via_junction.call(starts[i], dealt[i]), _via_junction.call(starts[j], dealt[j])),
					"squads %d and %d drive apart (%s, %s)" % [i, j, dealt[i], dealt[j]])
	var sorted := dealt.duplicate()
	sorted.sort()
	var given := anchors.duplicate()
	given.sort()
	assert_eq(sorted, given, "the same places, dealt again")


func test_switched_off() -> void:
	SelectionSquads.UNCROSS = false
	var starts := [Vector3(-6, 0, 60), Vector3(6, 0, 60)]
	var anchors: Array[Vector3] = [Vector3(40, 0, -30), Vector3(-40, 0, -30)]
	assert_eq(SelectionSquads.uncross_paths(anchors, starts, _via_junction, _len), anchors, "--uncross=off: as dealt")
