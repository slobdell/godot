extends TestCase
## Round-5 X1 (ai): CoverMap's typed columns and bucketed tactical points must answer exactly what the plain versions
## answered (nearest-first points with ties by index; line-of-sight through every feature), on round 1's arena and on
## a kit-built one with hundreds of boxes.

const ARENAS := ["foundry", "yard"]


func _map_for(arena_name: String) -> CoverMap:
	var loaded := Arena.load_layout(arena_name)
	assert_true(loaded.has("layout"), "arena %s loads" % arena_name)
	var layout: Dictionary = loaded.get("layout", {})
	var list: Array = []
	for obstacle: Dictionary in layout.get("obstacles", []):
		var size := Arena.obstacle_size(obstacle)
		list.append({"position": obstacle["position"], "size": [size.x, size.y, size.z],
				"rotation_deg": float(obstacle.get("rotation_deg", 0.0)), "height": size.y})
	return CoverMap.from_features(list)


## The old points_near: every point on the map.
func _points_near_all(map: CoverMap, center: Vector2, radius: float) -> PackedInt32Array:
	var pairs: Array = []
	for i in map.points.size():
		var d := center.distance_squared_to(map.points[i])
		if d <= radius * radius:
			pairs.append([d, i])
	pairs.sort()
	var result := PackedInt32Array()
	for pair in pairs:
		result.append(pair[1])
	return result


## The old blocked(): every feature, read from its dictionary.
func _blocked_all(map: CoverMap, a: Vector2, b: Vector2) -> bool:
	for feature: Dictionary in map.features:
		if float(feature["height"]) < CoverMap.EYE_HEIGHT:
			continue
		var center: Vector2 = feature["center"]
		var axis: Vector2 = feature["axis"]
		var across := Vector2(-axis.y, axis.x)
		var half: Vector2 = feature["half"]
		var la := Vector2((a - center).dot(axis), (a - center).dot(across))
		var d := Vector2((b - center).dot(axis), (b - center).dot(across)) - la
		var t0 := 0.0
		var t1 := 1.0
		var hit := true
		for k in 2:
			if absf(d[k]) < 1e-9:
				if absf(la[k]) > half[k]:
					hit = false
					break
				continue
			var ta := (-half[k] - la[k]) / d[k]
			var tb := (half[k] - la[k]) / d[k]
			if ta > tb:
				var swap := ta
				ta = tb
				tb = swap
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				hit = false
				break
		if hit:
			return true
	return false


func test_bucketed_points_and_typed_features_answer_exactly_as_before() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for arena_name: String in ARENAS:
		var map := _map_for(arena_name)
		var sight_lines := 0
		for i in 400:
			var center := Vector2(rng.randf_range(-115.0, 115.0), rng.randf_range(-115.0, 115.0))
			var radius := rng.randf_range(4.0, 40.0)
			var fast := map.points_near(center, radius)
			var slow := _points_near_all(map, center, radius)
			if fast != slow:
				assert_eq(fast, slow, "%s: points near %s within %.1f m" % [arena_name, center, radius])
				return
			var other := center + Vector2(rng.randf_range(-90.0, 90.0), rng.randf_range(-90.0, 90.0))
			var blocked := map.blocked(center, other)
			if blocked != _blocked_all(map, center, other):
				assert_eq(blocked, not blocked, "%s: sight line %s -> %s" % [arena_name, center, other])
				return
			sight_lines += 1 if blocked else 0
		print("MEASURE cover_map_equivalence %s: %d points, %d features, %d of 400 lines blocked" % [
				arena_name, map.points.size(), map.features.size(), sight_lines])
		assert_true(sight_lines > 20 and sight_lines < 380, "%s: the sample has blocked and clear lines" % arena_name)
