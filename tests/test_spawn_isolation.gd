extends TestCase
## Round 9, scale: `test_match_spawns_and_results::test_a_full_faction_army_a_side_spawns_clear_of_itself` PASSES
## ALONE and FAILS when an arena test runs before it in the same process. Measured, not inferred:
##
##   make test FILTER=a_full_faction_army   -> 1 passed, 0 failed
##   make test FILTER=match_spawns          -> 4 passed, 1 failed (test_arena_layouts runs first)
##   make test FILTER=army                  -> passes (test_arena_layouts excluded)
##
## A standalone SceneTree reproduction of the failing test's setup is CLEAN (`make spawn-probe`: blocked=0 of 90,
## worst tick-one motion 0.018 m), and stays clean even when a scrapyard arena is built and freed first -- so the
## leak is NOT stale physics bodies (`free()` takes 38 bodies to 0 immediately) and NOT stale navigation regions
## (the TestCase teardown guard does not fire). The one difference left is the TEST HARNESS path itself, so this
## file reproduces the sequence INSIDE it: the first test is the polluter, the second is the victim, and the second
## prints what the real test cannot.
##
## Both tests are named so they run in this order. If the second fails here, the sequence is reproduced in-harness
## and the printed diagnostics say which state carried over.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


## Exactly what `test_arena_layouts::test_match_spawns_come_from_the_layout` does first.
func test_a_polluter_builds_and_drops_a_scrapyard_arena() -> void:
	var arena: Arena = await ArenaFixture.build(self, "scrapyard")
	assert_true(arena != null, "setup: the scrapyard arena built")
	print("SPAWN_ISO_POLLUTER active=%s obstacles=%d" % [str(Arena.active.get("name", "?")),
			(Arena.active.get("obstacles", []) as Array).size()])


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


## The victim, with the instrumentation the real test lacks.
func test_b_victim_deploys_a_full_army_and_reports_what_it_sees() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(9, 6.0)
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		assert_eq(game_match.load_doctrine(team, _full_army()), "", "a full army loads for team %d" % team)
	var tanks: Array = game_match.tanks_by_name().values()
	var placed := {}
	for tank: Tank in tanks:
		placed[tank] = tank.global_position
	print("SPAWN_ISO_VICTIM active=%s obstacles=%d bodies=%d units=%d" % [str(Arena.active.get("name", "?")),
			(Arena.active.get("obstacles", []) as Array).size(), _bodies(tree.root), tanks.size()])
	# AT PLACEMENT, before any physics step: pure geometry, so this number cannot depend on the solver or on what
	# ran before. The real test takes BOTH its measurements after a physics frame, which is why both of them move
	# with test order. If units are already touching here, that is a deterministic consequence of the CP2 hull
	# sizes and it is the finding -- the sinking is only how the solver happens to resolve it.
	var touching: Array = []
	var closest := INF
	for i in tanks.size():
		for j in range(i + 1, tanks.size()):
			var a := tanks[i] as Tank
			var b := tanks[j] as Tank
			var sa: Array = Units.stat(a.unit_id, "hull_size")
			var sb: Array = Units.stat(b.unit_id, "hull_size")
			var pa: Vector3 = placed[a]
			var pb: Vector3 = placed[b]
			var gap_x: float = absf(pa.x - pb.x) - (float(sa[0]) + float(sb[0])) / 2.0
			var gap_z: float = absf(pa.z - pb.z) - (float(sa[2]) + float(sb[2])) / 2.0
			var gap: float = maxf(gap_x, gap_z)
			closest = minf(closest, gap)
			if gap < 0.0:
				touching.append("%s/%s overlap %.2f m" % [a.name, b.name, -gap])
	print("SPAWN_ISO_PLACEMENT closest pair gap %.3f m; %d overlapping pairs at placement%s"
			% [closest, touching.size(), ("" if touching.is_empty() else ": " + ", ".join(touching.slice(0, 6)))])
	await wait_physics_frames(1)
	var space := (tanks[0] as Tank).get_world_3d().direct_space_state
	var blocked: Array = []
	for tank: Tank in tanks:
		var size: Array = Units.stat(tank.unit_id, "hull_size")
		var probe := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(size[0] + 1.0, 1.0, size[2] + 1.0)
		probe.shape = shape
		probe.transform = Transform3D(Basis.IDENTITY, tank.global_position + Vector3.UP * 1.5)
		probe.collision_mask = Perception.WORLD_MASK
		var hits: Array = space.intersect_shape(probe, 4)
		if hits.is_empty():
			continue
		var names: Array = []
		for hit: Dictionary in hits:
			var body: Object = hit.get("collider")
			if body is Node3D:
				var n3 := body as Node3D
				names.append("%s/%s at %s" % [String(n3.get_parent().name) if n3.get_parent() else "?", n3.name,
						n3.global_position])
		var moved: float = (placed[tank] as Vector3).distance_to(tank.global_position)
		blocked.append(String(tank.name))
		print("SPAWN_ISO_BLOCKED %s unit=%s placed %s -> now %s moved %.3f m :: %s" % [tank.name, tank.unit_id,
				placed[tank], tank.global_position, moved, ", ".join(names)])
	print("SPAWN_ISO_DONE blocked=%d of %d" % [blocked.size(), tanks.size()])

	# WHAT THIS FILE ASSERTS, and it is the half that is scale's: at CP2 hull sizes a full 45-unit army a side is
	# PLACED with real clearance. That is deterministic -- pure geometry, before any physics step -- so it cannot
	# move with test order, and it is the question "did the resize outgrow the assembly?" answered directly.
	assert_eq(touching, [], "no two hulls are placed overlapping at CP2 sizes")
	assert_true(closest > 0.5, "the closest pair of a full army is placed more than half a metre apart (%.3f m)"
			% closest)

	# WHAT IT DOES NOT ASSERT, on purpose (Invariant 0b: a check must not encode a decision nobody has made).
	# `blocked` above is 0 when this test runs alone and 3 when an arena test runs before it in the same process,
	# with IDENTICAL placement coordinates, an identical world (foundry, 19 obstacles, 111 bodies) and nothing
	# leaked. The three are ejected ~1.5 m DOWNWARD through `Arena/Ground`: units are placed at exactly y = 0.0,
	# resting on the ground at zero penetration, which is a degenerate contact whose resolution direction depends on
	# the physics engine's internal state -- and that depends on how many bodies the process created and destroyed
	# earlier. Round 8 recorded the same shape for the sim hash (identical geometry, different body order, different
	# Jolt answer).
	#
	# So the owner's decision is whether to place units a few centimetres ABOVE the ground so the contact is not
	# degenerate (`ArmyLayout.deploy` writes y = 0.0; `Match.spawn_position` returns y = 0.0), or to let them settle
	# for more than one frame before measuring. Both are outside this stream's paths, so this file MEASURES and
	# prints and refuses to encode either.
	if blocked.size() > 0:
		print("SPAWN_ISO_WATCH %d unit(s) ejected below the ground by the tick-one contact resolution. Placement "
				% blocked.size() + "was clean, so this is the degenerate y=0 resting contact, not spacing.")


func _bodies(node: Node) -> int:
	var n := 1 if node is CollisionObject3D else 0
	for child in node.get_children():
		n += _bodies(child)
	return n
