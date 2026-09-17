extends TestCase
## Round-5 (ai inherits doctrine): how a leader reads terrain on arena's kit-built maps. Round 4 counted obstacles within
## 45 m, tuned on foundry's 19 boxes; on a kit map one container wall is several boxes, so the yard, boneyard and
## boulevard read "dense" almost everywhere and doctrine would pick the same formation on every map (arena, 2026-09-17).
## Now touching boxes (within PIECE_GAP) are one piece of cover, and low cover (a 0.9 m barricade) isn't terrain at all.

var _saved: Dictionary = Arena.active


func teardown() -> void:
	Arena.active = _saved
	ElementSituation.forget_terrain()
	super()


func _use(arena_name: String) -> void:
	var loaded := Arena.load_layout(arena_name)
	assert_true(loaded.has("layout"), "arena %s loads" % arena_name)
	Arena.active = loaded.get("layout", {})
	ElementSituation.forget_terrain()


## Share of a 10 m grid over the arena that reads "dense".
func _dense_share() -> float:
	var half := float(Arena.active.get("half_size", 120.0))
	var dense := 0
	var total := 0
	var x := -half + 5.0
	while x < half:
		var z := -half + 5.0
		while z < half:
			total += 1
			dense += 1 if ElementSituation.terrain_at(Vector3(x, 0, z)) == "dense" else 0
			z += 10.0
		x += 10.0
	return float(dense) / maxf(total, 1)


func _old_rule(center: Vector3) -> String:
	var near := 0
	for obstacle: Dictionary in Arena.active.get("obstacles", []):
		if Vector2(obstacle["position"][0] - center.x, obstacle["position"][1] - center.z).length() <= ElementSituation.TERRAIN_RADIUS:
			near += 1
	return "dense" if near >= ElementSituation.DENSE_FEATURES else ("lanes" if near >= ElementSituation.LANES_FEATURES else "open")


func test_foundry_reads_exactly_as_it_did() -> void:
	_use("foundry")
	var differences := 0
	for x in range(-115, 116, 10):
		for z in range(-115, 116, 10):
			var at := Vector3(x, 0, z)
			differences += 1 if ElementSituation.terrain_at(at) != _old_rule(at) else 0
	assert_eq(differences, 0, "foundry has no touching or low boxes, so its terrain (and the sim baseline) is unchanged")


func test_touching_containers_are_one_piece_of_cover_and_a_barricade_is_none() -> void:
	var obstacles := [
		{"type": "container_20", "position": [0.0, 0.0], "rotation_deg": 0.0, "size": [6.06, 2.59, 2.44]},
		{"type": "container_20", "position": [6.5, 0.0], "rotation_deg": 0.0, "size": [6.06, 2.59, 2.44]},
		{"type": "container_20", "position": [11.5, 0.0], "rotation_deg": 90.0, "size": [6.06, 2.59, 2.44]},
		{"type": "container_20", "position": [40.0, 0.0], "rotation_deg": 0.0, "size": [6.06, 2.59, 2.44]},
		{"type": "barricade", "position": [0.0, 10.0], "rotation_deg": 0.0, "size": [6.0, 0.9, 0.8]},
	]
	var pieces := ElementSituation.cover_pieces(obstacles)
	assert_eq(pieces.size(), 2, "a wall of three touching containers and a lone container: two pieces, no barricade")


func test_the_kit_maps_have_different_character() -> void:
	_use("boulevard")
	var boulevard := _dense_share()
	_use("yard")
	var yard := _dense_share()
	print("MEASURE terrain dense share: boulevard %.0f%%, yard %.0f%%" % [100.0 * boulevard, 100.0 * yard])
	assert_true(boulevard < 0.7, "the boulevard is not dense wall to wall (%.0f%%)" % (100.0 * boulevard))
	assert_true(yard - boulevard > 0.2, "the yard reads denser than the boulevard (%.0f%% vs %.0f%%)" % [100.0 * yard, 100.0 * boulevard])
