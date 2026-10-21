extends TestCase
## Round 37 (native N2, cover's K2/K3): CoverMap.low_screen, CoverMap.low_features_near and Armor.cover_roll in C++
## (CoverNative) give the GDScript's answers exactly, over seeded arenas full of LOW features (barricades under the eye
## height, beside tall ones that must be skipped), hulls of every size and facing, shooters from every side. The native
## object is asked directly as well as through the map's seam, so a seam silently not taken cannot pass as "equal".
## Skipped (said) without the library.

const ARENAS := 10
const QUERIES := 300


func _features(rng: RandomNumberGenerator, n: int, spread: float) -> Array:
	var list: Array = []
	for i in n:
		list.append({"position": Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread)),
				"size": Vector2(rng.randf_range(0.6, 9.0), rng.randf_range(0.6, 4.0)),
				"rotation_deg": [0.0, 90.0, rng.randf_range(0.0, 360.0), 45.0, 30.0][i % 5],
				"height": [0.8, 0.5, 3.0, 1.1, 0.95][i % 5]})
	return list


static func _same(a: Variant, b: Variant) -> bool:
	if typeof(a) != typeof(b):
		return false
	if a is Dictionary:
		if (a as Dictionary).size() != (b as Dictionary).size():
			return false
		for key in a:
			if not (b as Dictionary).has(key) or not _same(a[key], b[key]):
				return false
		return true
	return a == b  # floats, Vector2s and int arrays compared bit for bit


func test_low_cover_is_the_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the low-cover equality is not exercised in this run")
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var mismatches := 0
	var first := ""
	var compared := 0
	var screened := 0
	var near_found := 0
	for arena in ARENAS:
		var spread: float = [12.0, 30.0, 70.0][arena % 3]
		var features := _features(rng, [4, 12, 30, 60][arena % 4], spread)
		var map := CoverMap.from_features(features)
		assert_true(map._native != null, "a map built with the library has its native twin")
		for q in QUERIES:
			var center := Vector2(rng.randf_range(-spread, spread), rng.randf_range(-spread, spread))
			if q % 3 == 1 and not features.is_empty():  # parked just behind a feature: the case the rule is for
				var f: Dictionary = features[q % features.size()]
				center = (f["position"] as Vector2) + Vector2(rng.randf_range(-6.0, 6.0), rng.randf_range(-6.0, 6.0))
			var heading := rng.randf_range(-PI, PI)
			var forward := Vector2(cos(heading), sin(heading))
			var toward := forward if q % 4 == 0 else Vector2(cos(heading + rng.randf_range(-1.2, 1.2)), sin(heading + rng.randf_range(-1.2, 1.2)))
			var hull := Vector3(rng.randf_range(2.0, 3.6), rng.randf_range(1.2, 4.0), rng.randf_range(4.0, 12.0))
			if q % 25 == 0:
				hull.y = 0.0  # the degenerate guard
			var radius := rng.randf_range(1.0, 12.0)
			var pid := rng.randi() - (1 << 31) if q % 2 else q * 7919
			BrainSwitches.native = false
			var gd_screen := map.low_screen(center, forward, toward, hull)
			var gd_near := map.low_features_near(center, radius)
			var gd_roll := Armor.cover_roll(pid)
			BrainSwitches.native = true
			var answers := [[map.low_screen(center, forward, toward, hull), gd_screen, "screen (seam)"],
					[map._native.low_screen(center, forward, toward, hull), gd_screen, "screen (object)"],
					[map.low_features_near(center, radius), gd_near, "near (seam)"],
					[map._native.low_features_near(center, radius), gd_near, "near (object)"],
					[map._native.cover_roll(pid), gd_roll, "roll"]]
			for answer: Array in answers:
				compared += 1
				if not _same(answer[0], answer[1]):
					mismatches += 1
					if first == "":
						first = "arena %d query %d %s: native %s v gdscript %s" % [arena, q, answer[2], answer[0], answer[1]]
			if float(gd_screen["fraction"]) > 0.0:
				screened += 1
			if not gd_near.is_empty():
				near_found += 1
	BrainSwitches.native = NativeBridge.available
	print("MEASURE native low cover %d answers compared, %d mismatches; screened %d, near %d of %d queries" % [compared,
			mismatches, screened, near_found, ARENAS * QUERIES])
	assert_true(screened > ARENAS * QUERIES / 20, "enough queries are screened to mean something (%d)" % screened)
	assert_true(near_found > ARENAS * QUERIES / 10, "enough queries find a low feature near (%d)" % near_found)
	assert_eq(mismatches, 0, "every answer equal; first mismatch: %s" % first)
