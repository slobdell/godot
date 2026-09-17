extends TestCase
## Rules R6 (contract C5): arenas are data. Layouts in arenas/*.json validate as point-symmetric, build collision
## and a mirrored navmesh, feed spawns to Match, and describe their cover for the AI (Arena.cover_features).

const ARENA := preload("res://game/arena/arena.tscn")


func _arena(layout_name: String) -> Arena:
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = layout_name
	add_to_tree(arena)
	for frame in SimClock.TICK_RATE:
		if Pathing.is_ready(arena):
			break
		await tree.physics_frame
	assert_true(Pathing.is_ready(arena), "setup: %s's navigation synced within 1 s" % layout_name)
	return arena


func _sample() -> Dictionary:
	return Arena.load_layout("foundry")["layout"].duplicate(true)


func test_every_shipped_layout_is_valid() -> void:
	var names := Arena.layout_names()
	assert_true(names.has("foundry") and names.has("scrapyard"), "the two round-2 layouts ship (%s)" % [names])
	for layout_name in names:
		var loaded := Arena.load_layout(layout_name)
		assert_true(loaded.has("layout"), "%s validates: %s" % [layout_name, loaded.get("error", "")])
	assert_true(String(Arena.load_layout("atlantis").get("error", "")).contains("foundry"), "an unknown name lists the real ones")


func test_asymmetric_layouts_are_refused() -> void:
	var lopsided := _sample()
	lopsided["obstacles"][1]["position"][0] += 3.0
	assert_true(String(Arena.validate(lopsided)).contains("point-symmetric"), "a moved obstacle breaks symmetry: %s" % Arena.validate(lopsided))
	var turned := _sample()
	for obstacle: Dictionary in turned["obstacles"]:
		if obstacle["type"] == "wall" and obstacle["position"][0] != 0.0:
			obstacle["rotation_deg"] = 30.0
			break
	assert_true(String(Arena.validate(turned)).contains("point-symmetric"), "so does a rotated one")
	var unfair_spawns := _sample()
	unfair_spawns["spawns"]["rust"][0] = [5.0, -90.0]
	assert_true(String(Arena.validate(unfair_spawns)).contains("spawns"), "and uneven spawns")
	var few := _sample()
	few["spawns"]["green"] = few["spawns"]["green"].slice(0, 10)
	few["spawns"]["rust"] = few["spawns"]["rust"].slice(0, 10)
	assert_true(String(Arena.validate(few)).contains("full army"), "a layout must fit 25 units a side")
	var mystery := _sample()
	mystery["obstacles"].append({"type": "fire_pit", "position": [0.0, 0.0]})
	assert_true(String(Arena.validate(mystery)).contains("size"), "a new obstacle type must say how big it is")
	mystery["obstacles"][-1]["size"] = [6.0, 0.5, 6.0]
	assert_eq(Arena.validate(mystery), "", "then it's fine (it maps to visual slot prop.fire_pit)")


func test_foundry_is_round_ones_arena() -> void:
	var arena: Arena = await _arena("foundry")
	assert_eq(arena.obstacles_root.get_child_count(), 19, "19 obstacles, as in round 1's arena.tscn")
	var space := arena.get_world_3d().direct_space_state
	var blocked := func(from: Vector3, to: Vector3) -> bool:
		return not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Perception.WORLD_MASK)).is_empty()
	assert_true(blocked.call(Vector3(28, 1.3, -50), Vector3(28, 1.3, -70)), "CoverNorth still stands at (28, -60)")
	assert_true(blocked.call(Vector3(-5, 1.3, 0), Vector3(5, 1.3, 0)), "and the center crate at the middle")
	assert_true(not blocked.call(Vector3(-100, 1.3, 40), Vector3(-100, 1.3, -40)), "the west lane is open")


func test_scrapyard_builds_cover_features_and_symmetric_navigation() -> void:
	var arena: Arena = await _arena("scrapyard")
	var features := arena.cover_features()
	assert_eq(features.size(), arena.layout["obstacles"].size(), "one cover feature per obstacle")
	assert_eq(arena.obstacles_root.get_child_count(), features.size(), "and one collision body each")
	var long_wall: Dictionary = features.filter(func(f: Dictionary) -> bool: return f["size"].x > 30.0)[0]
	for key in ["position", "size", "rotation", "height", "type"]:
		assert_true(long_wall.has(key), "a feature has %s" % key)
	assert_near(long_wall["height"], 3.0, 0.01, "walls are 3 m tall")
	var space := arena.get_world_3d().direct_space_state
	var along_wall := PhysicsRayQueryParameters3D.create(Vector3(20, 1.3, 22), Vector3(40, 1.3, 22), Perception.WORLD_MASK)
	assert_true(not space.intersect_ray(along_wall).is_empty(), "a sized, rotated wall blocks where the layout puts it")
	for trip in [[Vector3(0, 0, 100), Vector3(0, 0, -100)], [Vector3(40, 0, 90), Vector3(-20, 0, 10)], [Vector3(-60, 0, 20), Vector3(60, 0, -50)]]:
		var there := _path_length(Pathing.find_path(arena, trip[0], trip[1]))
		var back := _path_length(Pathing.find_path(arena, -trip[0], -trip[1]))
		assert_true(there > 0.0, "trip %s has a path" % [trip])
		assert_near(there, back, 0.05, "trip %s is as long as its 180° mirror" % [trip])


func test_match_spawns_come_from_the_layout() -> void:
	var arena: Arena = await _arena("scrapyard")
	var green: Array = arena.layout["spawns"]["green"]
	assert_eq(Match.spawn_position(Match.Team.GREEN, 4), Vector3(green[4][0], 0.0, green[4][1]), "Green's slot 4 is the layout's")
	assert_eq(Match.spawn_position(Match.Team.RUST, 4), -Match.spawn_position(Match.Team.GREEN, 4), "Rust's mirrors it")


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


func test_hazard_layouts_validate_symmetric_fire_pits() -> void:
	var loaded := Arena.load_layout("furnace")
	assert_true(loaded.has("layout"), "furnace validates: %s" % loaded.get("error", ""))
	var lopsided: Dictionary = loaded["layout"].duplicate(true)
	lopsided["hazards"][0]["radius"] = 12.0
	assert_true(String(Arena.validate(lopsided)).contains("hazard"), "a fire pit without an equal mirror is refused: %s" % Arena.validate(lopsided))
	var bad := _sample()
	bad["hazards"] = [{"type": "fire_pit", "position": [0.0, 0.0], "radius": -1.0, "damage_per_second": 10.0}]
	assert_true(String(Arena.validate(bad)).contains("radius"), "a hazard needs a positive radius")


func test_fire_pits_burn_whoever_stands_in_them() -> void:
	var arena: Arena = await _arena("furnace")
	var game_match: Match = preload("res://game/match/match.tscn").instantiate()
	add_to_tree(game_match)
	var pit: Dictionary = arena.hazards()[0]
	var burning := game_match.spawn_tank("Green_In_1", 0, Match.Team.GREEN, "tank")
	var enemy := game_match.spawn_tank("Rust_In_1", 0, Match.Team.RUST, "ifv")
	var safe := game_match.spawn_tank("Green_Out_1", 0, Match.Team.GREEN, "tank")
	burning.global_position = pit["position"] + Vector3(1.5, 0, 0)
	enemy.global_position = pit["position"] + Vector3(-3.0, 0, 0)
	safe.global_position = pit["position"] + Vector3(float(pit["radius"]) + 6.0, 0, 0)
	await wait_physics_frames(SimClock.TICK_RATE * 3)
	var toughness := func(tank: Tank) -> float: return tank.health + tank.shield
	assert_true(toughness.call(burning) < burning.max_health + burning.max_shield - 60.0,
			"3 s in a %.0f dps pit burns a tank (%.0f left)" % [pit["damage_per_second"], toughness.call(burning)])
	assert_true(toughness.call(enemy) < enemy.max_health + enemy.max_shield, "fire doesn't care about teams")
	assert_eq(toughness.call(safe), safe.max_health + safe.max_shield, "outside the pit: untouched")
	assert_true(game_match.stats["hazard_damage"][Match.Team.GREEN] > 0.0, "hazard damage is recorded by the victim's team")
	assert_eq(game_match.stats["damage"], [0, 0], "and never credited to either team as combat damage")
