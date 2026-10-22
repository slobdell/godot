extends TestCase
## Round 37 (orders O3; his answer 2026-10-20: every vehicle with its own squad, PROVIDED contention is not worse).
## Under SelectionSquads.UNTANGLE_WHOLE two squads whose drives cross swap PLACES and keep their vehicles (and their
## elements), instead of untangle's deal re-dealing vehicles between them. Pure.

const HIS := {"Green_Hunters_1": Vector3(66.1, 0, -72.3), "Green_Hunters_4": Vector3(63.1, 0, -64.2),
		"Green_Hunters_5": Vector3(55.9, 0, -80.1), "Green_Hunters_6": Vector3(47.9, 0, -82.6),
		"Green_Hunters_7": Vector3(43.2, 0, -87.9), "Green_Hunters_8": Vector3(57.0, 0, -71.7)}


func _squad(number: int, units: Array) -> Dictionary:
	var typed: Array[String] = []
	typed.assign(units)
	return {"number": number, "units": typed, "element": null}


func _crossings(squads: Array, anchors: Array[Vector3], at: Dictionary) -> int:
	var count := 0
	for i in squads.size():
		for j in range(i + 1, squads.size()):
			for a: String in squads[i]["units"]:
				for b: String in squads[j]["units"]:
					var pa: Vector3 = at[a]
					var pb: Vector3 = at[b]
					if Geometry2D.segment_intersects_segment(Vector2(pa.x, pa.z), Vector2(anchors[i].x, anchors[i].z),
							Vector2(pb.x, pb.z), Vector2(anchors[j].x, anchors[j].z)) != null:
						count += 1
	return count


func _whole(on: bool) -> void:
	SelectionSquads.UNTANGLE_WHOLE = on


func test_two_squads_sent_across_each_other_swap_places_and_keep_their_vehicles() -> void:
	_whole(true)
	var at := {"a1": Vector3(-40, 0, 0), "a2": Vector3(-30, 0, 0), "b1": Vector3(30, 0, 0), "b2": Vector3(40, 0, 0)}
	var a := _squad(1, ["a1", "a2"])
	var b := _squad(2, ["b1", "b2"])
	a["element"] = "alpha's element"
	var anchors: Array[Vector3] = [Vector3(35, 0, -100), Vector3(-35, 0, -100)]  # each laid on the other's side
	var before := _crossings([a, b], anchors, at)
	var out := SelectionSquads.untangle([a, b], anchors, func(u: String) -> Vector3: return at[u])
	_whole(false)
	assert_true(before > 0, "setup: the drives cross (%d)" % before)
	assert_true(out[0] == a and out[1] == b, "the squads come back as they were: same vehicles, same element")
	assert_eq(anchors[0], Vector3(-35, 0, -100), "squad 1 takes the place on its own side")
	assert_eq(anchors[1], Vector3(35, 0, -100), "and squad 2 the other")
	assert_eq(_crossings([a, b], anchors, at), 0, "no drive crosses")


func test_squads_that_do_not_cross_keep_their_places() -> void:
	_whole(true)
	var at := {"a1": Vector3(-40, 0, 0), "b1": Vector3(40, 0, 0)}
	var anchors: Array[Vector3] = [Vector3(-35, 0, -100), Vector3(35, 0, -100)]
	SelectionSquads.untangle([_squad(1, ["a1"]), _squad(2, ["b1"])], anchors, func(u: String) -> Vector3: return at[u])
	_whole(false)
	assert_eq(anchors[0], Vector3(-35, 0, -100), "untouched")
	assert_eq(anchors[1], Vector3(35, 0, -100), "untouched")


func test_his_interleaved_six_stay_whole_with_the_fewest_crossings() -> void:
	_whole(true)
	var squads := [_squad(1, ["Green_Hunters_1", "Green_Hunters_5", "Green_Hunters_7"]),
			_squad(2, ["Green_Hunters_4", "Green_Hunters_6", "Green_Hunters_8"])]
	var anchors: Array[Vector3] = [Vector3(110, 0, 20), Vector3(82, 0, 27)]
	var swapped: Array[Vector3] = [anchors[1], anchors[0]]
	var least := mini(_crossings(squads, anchors, HIS), _crossings(squads, swapped, HIS))
	var out := SelectionSquads.untangle(squads, anchors, func(u: String) -> Vector3: return HIS[u])
	_whole(false)
	assert_eq((out[0]["units"] as Array), squads[0]["units"], "squad 1 keeps its three")
	assert_eq((out[1]["units"] as Array), squads[1]["units"], "squad 2 keeps its three")
	assert_true(not out[0].has("dealt") and not out[1].has("dealt"), "nobody re-dealt")
	assert_eq(_crossings(squads, anchors, HIS), least, "the places go the way with the fewest crossings (%d)" % least)


func test_permutations_cover_every_order_identity_first() -> void:
	var perms := SelectionSquads._permutations(4)
	assert_eq(perms.size(), 24, "4! orders")
	assert_eq(perms[0], [0, 1, 2, 3], "the order they had first (a tie keeps it)")
	var seen := {}
	for p: Array in perms:
		seen[str(p)] = true
	assert_eq(seen.size(), 24, "all distinct")
