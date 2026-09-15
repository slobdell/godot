extends TestCase
## TacticalQuery: position picking over a CoverMap (game/ai/tactical_query.gd). Pure, no scene.


func _map() -> CoverMap:
	# An 18 m wall along x at z = 0 (faces at z = ±0.75).
	return CoverMap.from_features([{"position": Vector2.ZERO, "size": [18.0, 1.5], "rotation": 0.0}])


func test_cover_is_behind_the_wall_from_the_threat() -> void:
	var map := _map()
	var request := {"position": Vector3(14, 0, 8), "threats": [{"position": Vector3(0, 0, -50), "weight": 1.0}]}
	var found := TacticalQuery.find_cover(map, request)
	assert_true(not found.is_empty(), "there is cover")
	if found.is_empty():
		return
	var best: Vector3 = found[0]["point"]
	assert_true(best.z > 0.0, "the hiding place is on the far side of the wall from the threat (%s)" % best)
	assert_true(not map.clear_line(Vector3(0, 0, -50), best), "and the threat can't see it")
	assert_true(best.distance_to(request["position"]) <= TacticalQuery.SEARCH_RADIUS, "within reach")


func test_no_threats_means_no_cover_query() -> void:
	assert_true(TacticalQuery.find_cover(_map(), {"position": Vector3(0, 0, 8), "threats": []}).is_empty(), "nothing to hide from")


func test_cover_respects_the_squad_leash_and_friends() -> void:
	var map := _map()
	var request := {"position": Vector3(0, 0, 8), "threats": [{"position": Vector3(0, 0, -50), "weight": 1.0}],
			"anchor": Vector3(-6, 0, 6), "anchor_radius": 6.0, "friends": [Vector3(-9, 0, 4)]}
	for spot in TacticalQuery.find_cover(map, request, 10):
		var point: Vector3 = spot["point"]
		assert_true(point.distance_to(Vector3(-6, 0, 6)) <= 6.0, "inside the leash (%s)" % point)
		assert_true(point.distance_to(Vector3(-9, 0, 4)) >= TacticalQuery.FRIEND_SPACING, "not on top of a friend (%s)" % point)


func test_cover_fire_hides_from_the_target_and_peeks_at_it_front_first() -> void:
	var map := _map()
	var target := Vector3(-10, 0, -45)
	var request := {"position": Vector3(12, 0, 10), "target": target, "threats": [{"position": target, "weight": 1.0}],
			"range": [20.0, 45.0, 70.0]}
	var found := TacticalQuery.find_cover_fire(map, request)
	assert_true(not found.is_empty(), "a hide/peek pair exists near the wall's end")
	if found.is_empty():
		return
	var hide: Vector3 = found["hide"]
	var peek: Vector3 = found["peek"]
	assert_true(not map.clear_line(hide, target), "the target can't see the hide spot (%s)" % hide)
	assert_true(map.clear_line(peek, target), "the peek spot sees the target (%s)" % peek)
	var to_peek := Vector2(peek.x - hide.x, peek.z - hide.z)
	var to_target := Vector2(target.x - hide.x, target.z - hide.z)
	assert_true(absf(rad_to_deg(to_peek.angle_to(to_target))) <= 60.01, "driving out to peek keeps the front mostly toward the target")
	assert_true(not map.path_blocked(Vector2(hide.x, hide.z), Vector2(peek.x, peek.z), 1.0), "the hide-peek drive is clear")
	assert_true(hide.distance_to(peek) <= TacticalQuery.PEEK_MAX + 0.01, "the peek is a short hop (%.1f m)" % hide.distance_to(peek))


func test_no_cover_fire_in_the_open() -> void:
	var map := CoverMap.from_features([])
	var request := {"position": Vector3(0, 0, 10), "target": Vector3(0, 0, -40), "range": [20.0, 45.0, 70.0]}
	assert_true(TacticalQuery.find_cover_fire(map, request).is_empty(), "no obstacles, no hiding place")


func test_queries_are_deterministic() -> void:
	var request := {"position": Vector3(12, 0, 10), "target": Vector3(-10, 0, -45),
			"threats": [{"position": Vector3(-10, 0, -45), "weight": 1.0}, {"position": Vector3(20, 0, -40), "weight": 0.5}],
			"friends": [Vector3(4, 0, 6)], "range": [20.0, 45.0, 70.0]}
	var first := [TacticalQuery.find_cover(_map(), request), TacticalQuery.find_cover_fire(_map(), request)]
	var shared := _map()
	for i in 3:
		assert_eq([TacticalQuery.find_cover(shared, request), TacticalQuery.find_cover_fire(shared, request)], first,
				"same map and request, same answer (run %d, warm memo)" % i)
