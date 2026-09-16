extends TestCase
## Rules R5: a full army per side (Doctrine.MAX_UNITS, one per spawn slot) spawns without overlapping, and
## Match.finished carries the fields the army stream's progression needs (contract C3). The sizes come from
## the caps, not from a number typed here: they grow when armies do.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


## The biggest army the rules allow: Doctrine.MAX_UNITS vehicles, in squads of MAX_SQUAD_UNITS.
func _full_army() -> Dictionary:
	var roster := ["tank", "ifv", "scout", "artillery", "lancer"]
	var army := {"name": "Full", "squads": []}
	for i in Doctrine.MAX_UNITS:
		var squad_index := i / Doctrine.MAX_SQUAD_UNITS
		if squad_index >= army["squads"].size():
			army["squads"].append({"name": "S%d" % squad_index, "formation": "wedge", "verb": "hold", "units": []})
		army["squads"][squad_index]["units"].append({"unit": roster[i % roster.size()]})
	return army


func test_a_full_army_a_side_spawns_clear_of_itself() -> void:
	assert_true(Match.SPAWN_SLOTS >= Doctrine.MAX_UNITS, "the spawn grid has a slot for every unit an army can field")
	assert_true(Doctrine.MAX_UNITS <= Doctrine.MAX_SQUADS * Doctrine.MAX_SQUAD_UNITS,
			"and an army that big fits in the squads the rules allow")
	var game_match := _setup()
	game_match.seed_spawns(9, 6.0)  # the match runner's jitter
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		assert_eq(game_match.load_doctrine(team, _full_army()), "", "a full army loads for team %d" % team)
	var tanks := game_match.tanks_by_name().values()
	assert_eq(tanks.size(), 2 * Doctrine.MAX_UNITS, "setup: a full army on both sides")
	await wait_physics_frames(1)
	var boxes := {}
	for tank: Tank in tanks:
		assert_true(absf(tank.global_position.x) < Match.DRIVABLE_LIMIT and absf(tank.global_position.z) < Match.DRIVABLE_LIMIT,
				"%s spawns inside the arena (%s)" % [tank.name, tank.global_position])
		var size: Array = Units.stat(tank.unit_id, "hull_size")  # spawn yaw is 0 or 180°: boxes are axis-aligned
		boxes[tank] = Rect2(tank.global_position.x - size[0] / 2.0, tank.global_position.z - size[2] / 2.0, size[0], size[2])
	var overlaps: Array = []
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			if (boxes[tanks[i]] as Rect2).grow(0.5).intersects(boxes[tanks[j]]):
				overlaps.append("%s/%s" % [tanks[i].name, tanks[j].name])
	assert_eq(overlaps, [], "no two hulls spawn within half a meter of each other")
	var space := (tanks[0] as Tank).get_world_3d().direct_space_state
	var blocked: Array = []
	for tank: Tank in tanks:
		var probe := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		var size: Array = Units.stat(tank.unit_id, "hull_size")
		shape.size = Vector3(size[0] + 1.0, 1.0, size[2] + 1.0)
		probe.shape = shape
		probe.transform = Transform3D(Basis.IDENTITY, tank.global_position + Vector3.UP * 1.5)  # above the ground slab
		probe.collision_mask = Perception.WORLD_MASK
		if not space.intersect_shape(probe, 1).is_empty():
			blocked.append(String(tank.name))
	assert_eq(blocked, [], "no unit spawns inside a wall or crate")


func test_the_first_five_slots_are_round_ones_front_row() -> void:
	for slot in 5:
		var spot := Match.spawn_position(Match.Team.GREEN, slot)
		assert_eq(spot.z, Match.BASE_Z, "slot %d stands in the front row" % slot)
	assert_true(Match.spawn_position(Match.Team.GREEN, 9).z > Match.BASE_Z, "slot 9 starts the second row, behind the first")
	assert_eq(Match.spawn_position(Match.Team.RUST, 13), -Match.spawn_position(Match.Team.GREEN, 13), "Rust's grid mirrors Green's")


func test_the_result_carries_what_progression_needs() -> void:
	var game_match := _setup()
	game_match.budget = 1500
	var green := {"name": "G", "squads": [{"name": "A", "units": [{"unit": "tank"}, {"unit": "scout"}]}]}
	var rust := {"name": "R", "squads": [{"name": "B", "units": [{"unit": "ifv"}, {"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, green), "", "setup: green")
	assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: rust")
	game_match.elimination = true
	var results: Array = []
	game_match.finished.connect(func(result: Dictionary) -> void: results.append(result))
	await wait_physics_frames(2)
	var cannon := Weapons.profile("cannon")
	for victim_name in ["Rust_B_1", "Rust_B_2"]:
		var victim := game_match.tanks.get_node(victim_name) as Tank
		victim.shield = 0.0
		game_match._land_hit(victim, 100000.0, cannon, Vector3.FORWARD, Match.Team.GREEN, "Green_A_1", "", true)
	(game_match.tanks.get_node("Green_A_2") as Tank).apply_damage(100000)  # lost to something else
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 2)
	assert_eq(results.size(), 1, "the match finishes once")
	if results.is_empty():
		return
	var result: Dictionary = results[0]
	assert_eq(result["winner"], "Green", "the side with units left wins")
	assert_eq(result["reason"], "elimination", "by elimination")
	assert_eq(result["units_lost"], {"green": 1, "rust": 2}, "units lost per side")
	assert_eq(result["units_left"], {"green": 1, "rust": 0}, "units left per side")
	assert_eq(result["kills_by_unit"]["green"], {"ifv": 1, "scout": 1}, "what Green destroyed, by unit type")
	assert_eq(result["losses_by_unit"]["green"], {"scout": 1}, "what Green lost, by unit type")
	assert_eq(result["budget"], 1500, "the match budget")
	assert_eq(result["army_cost"], {"green": 310, "rust": 260}, "each army's cost")
	assert_true(result["duration_seconds"] > 0.0, "and how long it took")
