extends TestCase
## Round 23 (native, N1b): CoverMap's line of sight (clear_line, clear_line_coarse: the quantised key, the memo, the
## grid traversal, the slab test; path_blocked with a grown box) in C++ gives the GDScript's answers over seeded
## arenas and segments, and the memo computes the same number of times. Skipped (said) without the library.

const ARENAS := 12
const QUERIES := 400


func _random_features(rng: RandomNumberGenerator, n: int, spread: float) -> Array:
	var list: Array = []
	for i in n:
		list.append({"position": Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)),
				"size": Vector2(rng.randf_range(1.0, 14.0), rng.randf_range(1.0, 14.0)),
				"rotation_deg": [0.0, 90.0, rng.randf_range(0.0, 360.0), 45.0][i % 4],
				"height": [3.0, 3.0, 0.8, 5.0][i % 4]})
	return list


func test_line_of_sight_is_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the cover equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 23
	var mismatches := 0
	var first := ""
	var compared := 0
	var blocked_any := 0
	var computed_gd := 0
	var computed_native := 0
	for arena in ARENAS:
		var features := _random_features(rng, [0, 3, 12, 40][arena % 4], [20.0, 60.0, 140.0][arena % 3])
		var gd_map := CoverMap.from_features(features)
		var native_map := CoverMap.from_features(features)
		assert_true(native_map._native != null, "a map built with the library has its native twin")
		var queries: Array = []
		for q in QUERIES:
			var spread: float = [20.0, 60.0, 140.0][arena % 3] + 10.0
			var a := Vector3(rng.randf_range(-spread, spread), rng.randf_range(0.0, 2.0), rng.randf_range(-spread, spread))
			var b := Vector3(rng.randf_range(-spread, spread), rng.randf_range(0.0, 2.0), rng.randf_range(-spread, spread))
			match q % 6:
				1:  # a short segment near a feature
					if not features.is_empty():
						var f: Dictionary = features[q % features.size()]
						var c: Vector2 = f["position"]
						a = Vector3(c.x + rng.randf_range(-12.0, 12.0), 0.0, c.y + rng.randf_range(-12.0, 12.0))
						b = Vector3(c.x + rng.randf_range(-12.0, 12.0), 0.0, c.y + rng.randf_range(-12.0, 12.0))
				2:  # axis-aligned (the zero-direction slab branch)
					b = Vector3(b.x, 0.0, a.z)
				3:  # the same query twice: the memo
					if not queries.is_empty():
						var prev: Array = queries[queries.size() - 1]
						a = prev[0]
						b = prev[1]
				4:  # a reversed pair: the same key
					if not queries.is_empty():
						var prev2: Array = queries[queries.size() - 1]
						a = prev2[1]
						b = prev2[0]
			queries.append([a, b])
		for which in 2:
			var map: CoverMap = gd_map if which == 0 else native_map
			BrainSwitches.native = which == 1
			var before := CoverMap.los_computed
			var answers := PackedByteArray()
			for pair: Array in queries:
				var a: Vector3 = pair[0]
				var b: Vector3 = pair[1]
				answers.append(1 if map.clear_line(a, b) else 0)
				if which == 1:  # the native object itself, so a seam silently not taken cannot pass as "equal"
					answers[answers.size() - 1] = answers[answers.size() - 1] if (native_map._native.clear_line(a, b) & 1) == answers[answers.size() - 1] else 2
				answers.append(1 if map.clear_line_coarse(a, b) else 0)
				answers.append(1 if map.path_blocked(Vector2(a.x, a.z), Vector2(b.x, b.z), 2.6) else 0)
				answers.append(1 if map.path_blocked(Vector2(a.x, a.z), Vector2(b.x, b.z), 0.0) else 0)
			if which == 0:
				computed_gd += CoverMap.los_computed - before
				map.set_meta("answers", answers)
			else:
				computed_native += CoverMap.los_computed - before
				var reference: PackedByteArray = gd_map.get_meta("answers")
				for i in answers.size():
					compared += 1
					if reference[i] == 0:
						blocked_any += 1
					if answers[i] != reference[i]:
						mismatches += 1
						if first == "":
							first = "arena %d query %d kind %d: native %d vs gdscript %d (%s)" % [arena, i / 4, i % 4, answers[i], reference[i], queries[i / 4]]
	BrainSwitches.native = NativeBridge.available
	print("MEASURE native cover %d answers compared (%d blocked), %d mismatches; computed gd %d native %d" % [compared, blocked_any, mismatches, computed_gd, computed_native])
	assert_true(blocked_any > compared / 10, "the arenas block enough lines to mean something (%d of %d)" % [blocked_any, compared])
	assert_eq(mismatches, 0, "every answer equal; first mismatch: %s" % first)
	assert_eq(computed_native, computed_gd, "the memo computes the same number of times")
