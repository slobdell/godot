extends TestCase
## The gladiator venue (art X5): the crowd seats itself along the stands, reacts to spectacle and settles back, draws
## as one MultiMesh within its tier's count; the arena dressing builds stands, gates and the crowd from the kit.


func _crowd(rows: Array) -> CrowdSystem:
	var crowd := CrowdSystem.new()
	add_to_tree(crowd)
	crowd.seat_rows(rows)
	return crowd


func test_the_crowd_fills_its_rows_as_one_multimesh() -> void:
	var crowd := _crowd([[Vector3(-10, 3, 130), Vector3(10, 3, 130)], [Vector3(-10, 5, 134), Vector3(10, 5, 134)]])
	var per_row := int(20.0 / 0.75)
	assert_true(crowd.seats.size() > per_row and crowd.seats.size() <= per_row * 2, "two 20 m rows seat most of %d places (%d)" % [per_row * 2, crowd.seats.size()])
	assert_eq(crowd.find_children("*", "MultiMeshInstance3D", true, false).size(), 1, "the whole crowd is one draw")
	for seat in crowd.seats:
		assert_true(seat.y == 3.0 or seat.y == 5.0, "everyone stands on a row")
	var again := _crowd([[Vector3(-10, 3, 130), Vector3(10, 3, 130)], [Vector3(-10, 5, 134), Vector3(10, 5, 134)]])
	assert_eq(again.seats, crowd.seats, "the same arena seats the same crowd (seeded)")


func test_a_kill_makes_the_crowd_roar_near_it_then_it_settles() -> void:
	var crowd := _crowd([[Vector3(-10, 3, 130), Vector3(10, 3, 130)]])
	var calm := crowd.excitement
	crowd.react(Vector3(0, 0, 100), 0.15)
	var after_hit := crowd.excitement
	crowd.react(Vector3(5, 0, 110), 1.0)
	assert_true(after_hit > calm and crowd.excitement > after_hit, "a hit lifts the crowd a little, a kill a lot")
	crowd._process(0.0)
	var event: Vector4 = crowd.material.get_shader_parameter("event_position")
	assert_near(event.x, 5.0, 0.001, "the stands near the kill get the local pulse")
	assert_near(float(crowd.material.get_shader_parameter("excitement")), crowd.excitement, 0.001, "the shader gets the mood")
	for i in 60:
		crowd._process(0.1)
	assert_near(crowd.excitement, CrowdSystem.CALM, 0.001, "six seconds later it's back to a murmur")


func test_the_tier_sets_how_many_people_are_drawn() -> void:
	var rows := []
	for r in 40:
		rows.append([Vector3(-100, 3, 130 + r), Vector3(100, 3, 130 + r)])
	var crowd := _crowd(rows)
	var previous := FxQuality.tier()
	FxQuality.set_tier(FxQuality.Tier.LOW, "test")
	crowd.apply_quality()
	assert_eq(crowd.drawn_count(), CrowdSystem.PER_TIER[FxQuality.Tier.LOW], "phones draw a thinner crowd")
	FxQuality.set_tier(FxQuality.Tier.HIGH, "test")
	crowd.apply_quality()
	assert_eq(crowd.drawn_count(), mini(crowd.seats.size(), CrowdSystem.PER_TIER[FxQuality.Tier.HIGH]), "desktops draw more")
	FxQuality.set_tier(previous, "test")


func test_the_arena_dressing_builds_the_venue_from_the_kit() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var dressing: Node3D = add_to_tree((load(GameTheme.CYBERPUNK_SLOTS["arena.dressing"]) as PackedScene).instantiate())
	GameTheme.use(previous)
	var structures: Node3D = dressing.get("structures")
	var stands := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Stands"))
	var gates := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Gate"))
	assert_true(stands.size() >= 16, "grandstands line both long walls (%d modules)" % stands.size())
	assert_eq(gates.size(), 2, "a vehicle gate in each short wall")
	var crowd: CrowdSystem = dressing.get("crowd")
	assert_true(crowd != null and crowd.seats.size() > 1000, "the stands are full (%d seats)" % (crowd.seats.size() if crowd else 0))
	for node in stands:
		var z: float = (node as Node3D).position.z
		assert_true(absf(z) > 121.0, "stands sit outside the arena walls (z %.1f)" % z)
	assert_eq(dressing.find_children("*", "CollisionObject3D", true, false).size(), 0, "the venue adds no collision")


func test_the_dressing_fits_an_arena_layout() -> void:
	# C5 (rules R6): Arena calls arena.dressing.setup(layout) after building the obstacles.
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var dressing: Node3D = add_to_tree((load(GameTheme.CYBERPUNK_SLOTS["arena.dressing"]) as PackedScene).instantiate())
	GameTheme.use(previous)
	dressing.call("setup", {"name": "small", "half_size": 80.0, "obstacles": [], "control_point": {"radius": 12.0}})
	var structures: Node3D = dressing.get("structures")
	var walls := structures.get_children().filter(func(n: Node) -> bool: return n.name.begins_with("Perimeter"))
	assert_eq(walls.size(), 4, "four perimeter walls after the rebuild (old ones freed)")
	for node in structures.get_children():
		if node.name.begins_with("Stands"):
			var z: float = (node as Node3D).position.z
			assert_true(absf(z) > 81.0 and absf(z) < 100.0, "stands move in with the 80 m arena's walls (z %.1f)" % z)
	var ground := CyberMaterials.ground(false)
	assert_near(float(ground.get_shader_parameter("band_inner")), 68.0, 0.001, "the hazard band follows the walls")
	assert_near(float(ground.get_shader_parameter("ring_radius")), 12.0, 0.001, "the painted ring marks the control point")
	dressing.call("setup", {"name": "no_point", "half_size": 80.0, "obstacles": []})
	assert_near(float(ground.get_shader_parameter("ring_width")), 0.0, 0.001, "no control point, no ring")
	dressing.call("setup", {"name": "default", "half_size": 120.0, "obstacles": [], "control_point": {"radius": 16.0}})
