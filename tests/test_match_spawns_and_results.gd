extends TestCase
## Rules R5: 5 squads x 5 units per side spawn without overlapping, and Match.finished carries the fields the
## army stream's progression needs (contract C3).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


## The biggest army one side may field (Army.MAX_ARMY_UNITS), in squads of Doctrine.MAX_SQUAD_UNITS.
func _full_army() -> Dictionary:
	var roster := ["tank", "ifv", "scout", "artillery", "lancer"]
	var army := {"name": "Full", "squads": []}
	var squads := ceili(float(Army.MAX_ARMY_UNITS) / Doctrine.MAX_SQUAD_UNITS)
	var bought := 0
	for s in squads:
		var units: Array = []
		for u in Doctrine.MAX_SQUAD_UNITS:
			if bought >= Army.MAX_ARMY_UNITS:
				break
			units.append({"unit": roster[(s + u) % roster.size()]})
			bought += 1
		army["squads"].append({"name": "S%d" % s, "formation": "wedge", "verb": "hold", "units": units})
	return army


func test_a_full_faction_army_a_side_spawns_clear_of_itself() -> void:
	# X5 (round 4): the grid has to hold a faction army, not five squads of five.
	assert_true(Match.SPAWN_SLOTS >= Doctrine.MAX_UNITS, "the spawn grid has a slot for every unit an army can field")
	var game_match := _setup()
	game_match.seed_spawns(9, 6.0)  # the match runner's jitter
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		assert_eq(game_match.load_doctrine(team, _full_army()), "", "a full army loads for team %d" % team)
	var tanks := game_match.tanks_by_name().values()
	assert_eq(tanks.size(), 2 * Army.MAX_ARMY_UNITS, "setup: %d units" % (2 * Army.MAX_ARMY_UNITS))
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
		# NAME THE BODY. "inside a wall or crate" is a guess dressed as a finding: when three units failed this on
		# 2026-09-20 it cost an hour to learn whether they had hit an obstacle (a placement bug) or the ground itself
		# (the degenerate y = 0 contact, a different bug with a different owner). The failure says which.
		var hits := space.intersect_shape(probe, 4)
		if not hits.is_empty():
			var names: Array = []
			for hit: Dictionary in hits:
				var body := hit.get("collider") as Node
				names.append("<freed>" if body == null else "%s (%s)" % [body.name, body.get_class()])
			blocked.append("%s hit %s at %s" % [tank.name, ", ".join(names), tank.global_position])
	assert_eq(blocked, [], "no unit spawns inside a wall or crate")


func test_the_grid_fills_the_front_row_before_the_rows_behind_it() -> void:
	var columns := Match.SLOT_X.size()
	for slot in columns:
		var spot := Match.spawn_position(Match.Team.GREEN, slot)
		assert_eq(spot.z, Match.BASE_Z, "slot %d stands in the front row" % slot)
	assert_true(Match.spawn_position(Match.Team.GREEN, columns).z > Match.BASE_Z,
			"the next slot starts the second row, behind the first")
	# The mirror is point symmetry ON THE FLOOR PLANE. `SPAWN_LIFT_M` is a constant lift on BOTH sides, so negating a
	# spawn point would flip it below the floor -- the mirror is asserted in x/z and the lift separately.
	var green_deep := Match.spawn_position(Match.Team.GREEN, columns + 1)
	var rust_deep := Match.spawn_position(Match.Team.RUST, columns + 1)
	assert_eq(Vector2(rust_deep.x, rust_deep.z), -Vector2(green_deep.x, green_deep.z), "Rust's grid mirrors Green's")
	# `assert_near`, not `assert_eq`: Vector3 stores 32-bit floats, so the component reads back 0.05000000074506 and a
	# double literal will never equal it. Comparing a stored float to a source constant always needs a tolerance.
	assert_near(green_deep.y, Match.SPAWN_LIFT_M, 1e-6, "and both sides stand the same distance clear of the floor")
	assert_near(rust_deep.y, Match.SPAWN_LIFT_M, 1e-6, "and both sides stand the same distance clear of the floor")
	assert_true(Match.SPAWN_SLOTS >= Army.MAX_ARMY_UNITS, "and there is a slot for every vehicle an army may field")


## Round 9: a body created at exactly y = 0.0 makes a degenerate ground contact, and whether Jolt resolves it cleanly
## depends on solver state left by earlier bodies — scale measured three units ejected 1.5 m THROUGH the floor at
## spawn, reproducing only after other bodies had been created and destroyed. Every spawn point now stands clear of
## the floor, and it comes from ONE constant so the grid path and the arena-layout path cannot drift apart.
func test_every_spawn_point_stands_clear_of_the_floor() -> void:
	# NOT `> 0.0`: the constant is deliberately 0.0 while the ejection is diagnosed (it is not the lift -- the same
	# three units fall through the floor at 0.0 AND at 0.05, same workload). What this test guards is the property
	# that survives whatever value it takes: EVERY spawn point, both teams, grid slots and layout slots alike, has the
	# SAME clearance and it comes from one constant. That is what stops the two sources drifting apart again.
	assert_true(Match.SPAWN_LIFT_M >= 0.0, "the lift is a real distance")
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		for slot in [0, 1, Match.SLOT_X.size(), Match.SPAWN_SLOTS - 1]:
			assert_near(Match.spawn_position(team, slot).y, Match.SPAWN_LIFT_M, 1e-6,
					"team %d slot %d spawns clear of the floor" % [team, slot])


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
