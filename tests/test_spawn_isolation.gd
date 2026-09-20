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
	# THE COLLIDER'S OWN GEOMETRY AT PLACEMENT, before any physics step. `_apply_hull_size` sets
	# `_collision.position.y = size.y / 2.0`, which should put the box BOTTOM at the unit origin -- so a unit spawned
	# at y = 0 rests exactly on the ground and nothing straddles it. If instead the bottom is BELOW y = 0 here, the
	# box straddles the floor by half its height at spawn and the solver ejects it up or down depending on engine
	# state, which is the whole failure. Measured for every unit; printed for the ones that end up blocked plus a
	# passing unit of the same class, so the comparison is like-for-like.
	var aabb := {}
	for tank: Tank in tanks:
		var shape_node := tank.get_node_or_null("Collision") as CollisionShape3D
		if shape_node == null:
			continue
		var box := shape_node.shape as BoxShape3D
		if box == null:
			continue
		var centre: Vector3 = shape_node.global_position
		aabb[tank] = {"bottom": centre.y - box.size.y / 2.0, "top": centre.y + box.size.y / 2.0,
				"centre_y": centre.y, "local_y": shape_node.position.y, "box_h": box.size.y,
				"origin_y": tank.global_position.y}

	# THE GROUND'S OWN GEOMETRY. With `motion_mode = MOTION_MODE_FLOATING` and `velocity.y = 0.0` (tank_motion.gd:462,
	# "floating on a flat arena"), nothing falls and nothing snaps to a floor -- so the ONLY thing that can move a
	# unit in y is `move_and_slide`'s depenetration recovery, which means the hull box must already overlap something
	# at spawn. If the ground slab's TOP is above y = 0, then every unit placed at y = 0 with its box bottom at the
	# origin is inside the slab by that much, and recovery pushes it out in whichever direction the deepest contact
	# points -- up on one process history, down on another. That is the number this print exists to get.
	for ground_name: String in ["Ground", "Terrain"]:
		for node: Node in tree.root.get_children():
			var g := node.get_node_or_null(ground_name) as CollisionObject3D
			if g == null:
				continue
			for owner_id: int in g.get_shape_owners():
				for k in g.shape_owner_get_shape_count(owner_id):
					var sh := g.shape_owner_get_shape(owner_id, k)
					var owner_node := g.shape_owner_get_owner(owner_id) as Node3D
					var at: Vector3 = owner_node.global_position if owner_node != null else g.global_position
					if sh is BoxShape3D:
						var bs := sh as BoxShape3D
						print("SPAWN_ISO_GROUND %s/%s box %s centred y=%.4f -> top=%+.4f bottom=%+.4f"
								% [node.name, ground_name, bs.size, at.y, at.y + bs.size.y / 2.0,
								at.y - bs.size.y / 2.0])
					else:
						print("SPAWN_ISO_GROUND %s/%s shape=%s at y=%.4f" % [node.name, ground_name, sh, at.y])

	# WHO WRITES THE Y. `CharacterBody3D.get_position_delta()` reports the motion the last `move_and_slide()` produced,
	# so it separates the two candidates cleanly: if the delta carries the drop, `move_and_slide`'s depenetration
	# recovery moved the body; if the delta is ~0 while the position changed, some line ASSIGNED the position. With
	# `velocity.y = 0.0` and `MOTION_MODE_FLOATING` there is no third option. Sampled per frame for a few frames, so
	# the frame it jumps in is visible rather than inferred from a single before/after pair.
	# The FULL vector, not y alone. squad measured the widest pair abreast -- artillery 2.90 and lancer 2.76, placed
	# 5.02 m apart -- settling to 3.15 m, i.e. ~0.9 m each TOWARD each other in the same step that sank three units.
	# That direction is the puzzle: depenetration pushes bodies APART, so two hulls converging cannot be recovery from
	# each other. Either it is recovery from the GROUND with a lateral component, or something else moves them. So
	# print position, delta, velocity, floor state AND every slide collision's normal and collider per frame -- the
	# normal is what says which surface the solver thought it was escaping.
	var watch: Array = []
	for tank: Tank in tanks:
		# The WHOLE S2 row, not two of its members: if frame 1 is recovery from their OUTER squadmates, the outer
		# units move inward too and the row compresses from both ends. Two units cannot show that; five can.
		if String(tank.name).begins_with("Green_S2_") or ["Green_S5_1", "Rust_S5_1", "Green_S0_1"].has(String(tank.name)):
			watch.append(tank)
	for tank: Tank in watch:
		var a: Dictionary = aabb.get(tank, {})
		# `simulate` and `sync_position` test the remote-smoothing hypothesis: `Tank._process` lerps toward
		# `sync_position` ONLY when `simulate` is false, and `Match.simulate` defaults true (only client_mode sets it
		# false), so this should print true/unused. Printed rather than argued.
		print("SPAWN_ISO_PLACED %-12s unit=%-10s at %s  box_h=%s bottom=%s  simulate=%s sync_position=%s smoothing=%s"
				% [tank.name, tank.unit_id, placed[tank], a.get("box_h", "?"), a.get("bottom", "?"),
				str(tank.simulate), tank.sync_position, tank.remote_smoothing])
	for frame in 4:
		await wait_physics_frames(1)
		for tank: Tank in watch:
			var body := tank as CharacterBody3D
			var contacts: Array = []
			for i in body.get_slide_collision_count():
				var hit := body.get_slide_collision(i)
				var other: Object = hit.get_collider()
				var who := String((other as Node).name) if other is Node else str(other)
				contacts.append("%s n=%s depth=%.4f" % [who, hit.get_normal(), hit.get_depth()])
			print("SPAWN_ISO_WRITER f%d %-12s unit=%-10s at %s delta=%s vel=%s floor=%s contacts[%d] %s"
					% [frame + 1, tank.name, tank.unit_id, tank.global_position, body.get_position_delta(),
					body.velocity, str(body.is_on_floor()), contacts.size(), ", ".join(contacts)])
	# WHO IS ACTUALLY AROUND THEM. S2_2 and S2_3 are the only two units of their squad in the SECOND rank
	# (z = 100.62 = BASE_Z + 8.62 + HULL_CLEAR_M, ArmyLayout's deep_floor); their three squadmates are at z = 90 and
	# barely move. So whatever compresses them is NOT their own squad, and depenetration needs something to recover
	# FROM. This prints every unit placed within 12 m of S2_2, whatever squad it belongs to, with its gap to S2_2 at
	# placement -- if a neighbouring squad's second rank overlaps them, it will be here.
	for tank: Tank in tanks:
		if String(tank.name) != "Green_S2_2":
			continue
		var here: Vector3 = placed[tank]
		var near: Array = []
		for other: Tank in tanks:
			if other == tank:
				continue
			var there: Vector3 = placed[other]
			var d := Vector2(here.x, here.z).distance_to(Vector2(there.x, there.z))
			if d > 12.0:
				continue
			var sa: Array = Units.stat(tank.unit_id, "hull_size")
			var sb: Array = Units.stat(other.unit_id, "hull_size")
			var gap_x: float = absf(here.x - there.x) - (float(sa[0]) + float(sb[0])) / 2.0
			var gap_z: float = absf(here.z - there.z) - (float(sa[2]) + float(sb[2])) / 2.0
			near.append("%s(%s) at %.1f,%.1f d=%.2f gap=%.2f" % [other.name, other.unit_id, there.x, there.z, d,
					maxf(gap_x, gap_z)])
		near.sort()
		print("SPAWN_ISO_NEIGHBOURS of Green_S2_2 at %.1f,%.1f within 12 m: %s" % [here.x, here.z, ", ".join(near)])

	# The pair squad measured, as a distance rather than two positions, so the convergence is one number.
	var pair: Array = watch.filter(func(t: Tank) -> bool:
			return String(t.name) == "Green_S2_2" or String(t.name) == "Green_S2_3")
	if pair.size() == 2:
		var a0: Vector3 = placed[pair[0]]
		var b0: Vector3 = placed[pair[1]]
		print("SPAWN_ISO_PAIR %s/%s placed %.3f m apart -> now %.3f m apart (%.3f m of convergence)"
				% [pair[0].name, pair[1].name, Vector2(a0.x, a0.z).distance_to(Vector2(b0.x, b0.z)),
				Vector2((pair[0] as Tank).global_position.x, (pair[0] as Tank).global_position.z).distance_to(
						Vector2((pair[1] as Tank).global_position.x, (pair[1] as Tank).global_position.z)),
				Vector2(a0.x, a0.z).distance_to(Vector2(b0.x, b0.z))
						- Vector2((pair[0] as Tank).global_position.x, (pair[0] as Tank).global_position.z)
						.distance_to(Vector2((pair[1] as Tank).global_position.x, (pair[1] as Tank).global_position.z))])

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

	# The four AABBs the orchestrator asked for: each blocked unit, plus a PASSING unit of the same class.
	for name: String in blocked:
		for tank: Tank in tanks:
			if String(tank.name) == name and aabb.has(tank):
				_print_aabb("BLOCKED", tank, aabb[tank])
	var shown := {}
	for tank: Tank in tanks:
		if blocked.has(String(tank.name)) or not aabb.has(tank):
			continue
		if shown.has(tank.unit_id):
			continue
		shown[tank.unit_id] = true
		_print_aabb("passing", tank, aabb[tank])

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


## One unit's collider geometry at placement, in the terms the hypothesis is about: is the box bottom at the origin?
func _print_aabb(label: String, tank: Tank, a: Dictionary) -> void:
	print("SPAWN_ISO_AABB %-8s %-12s unit=%-10s origin_y=%.4f local_y=%.4f box_h=%.4f -> bottom=%+.4f top=%+.4f %s"
			% [label, tank.name, tank.unit_id, a["origin_y"], a["local_y"], a["box_h"], a["bottom"], a["top"],
			("BOTTOM BELOW GROUND" if float(a["bottom"]) < -0.0005 else "bottom at/above ground")])


## IS THE GUARD CRYING WOLF? `TestCase.teardown()` counts navigation regions immediately after `free()`, and it is
## synchronous, so it cannot await. But `NavigationServer3D` applies changes when it syncs, not when a node is freed --
## ArenaFixture's docstring says exactly that: *"the previous test's arena is freed a frame or two before
## NavigationServer3D drops its regions"*. **A frame or two.** So a count taken in teardown may be measuring a PENDING
## removal, not a leak, and a guard that fails on a transient is the same defect as the spawn test it was written to
## explain. This measures the drain: regions right after `free()`, then after each of three frames.
##
## If the count reaches 0 within a frame or two, the guard must measure later (or tolerate pending regions) and the
## three tests it flagged are NOT leaking. If it stays up, they are, and the guard stands.
func test_c_do_navigation_regions_drain_after_an_arena_is_freed() -> void:
	var map := (tree.root as Viewport).world_3d.navigation_map
	var before := NavigationServer3D.map_get_regions(map).size()
	var arena: Arena = await ArenaFixture.build(self, "foundry")
	var with_arena := NavigationServer3D.map_get_regions(map).size()
	arena.free()
	var counts: Array = [NavigationServer3D.map_get_regions(map).size()]
	for f in 3:
		await wait_physics_frames(1)
		counts.append(NavigationServer3D.map_get_regions(map).size())
	print("SPAWN_ISO_REGIONS before=%d with_arena=%d then after free: %s (frames 0,1,2,3)"
			% [before, with_arena, str(counts)])
	assert_true(true, "diagnostic only: the numbers decide whether the teardown guard is sound")
