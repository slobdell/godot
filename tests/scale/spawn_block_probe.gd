extends SceneTree
## Diagnostic for main's one red test at `b008a277`:
## `test_match_spawns_and_results::test_a_full_faction_army_a_side_spawns_clear_of_itself` reports
## `[Green_S5_1, Rust_S5_1, Rust_S8_1]` spawning inside a wall or crate. The test says WHICH units; it cannot say
## WHERE they are or WHAT they are in, and a fix chosen without that is a guess.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/spawn_block_probe.gd -- [--arena=foundry]
##
## Reproduces the test's exact setup (`Arena.DEFAULT_LAYOUT` is foundry, `seed_spawns(9, 6.0)`, a full
## `Army.MAX_ARMY_UNITS` army a side) and prints, for every unit the test's own probe would flag, its position, its
## hull, and the NAME and AABB of each body it intersects -- so the mechanism is read off the output rather than
## inferred. Prints `SPAWN_PROBE_DONE`; exits 1 only if it could not run.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _init() -> void:
	_run.call_deferred()


## The test's own army: Army.MAX_ARMY_UNITS in squads of Doctrine.MAX_SQUAD_UNITS, same roster and order.
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


func _run() -> void:
	var arena_name := Arena.DEFAULT_LAYOUT
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--arena="):
			arena_name = arg.trim_prefix("--arena=")
	# POSITIVE CONTROL for the test-isolation hypothesis (`--pollute=<layout>`): stand up ANOTHER arena first and
	# never free it, which is what an arena test whose deferred `queue_free` has not been processed leaves behind.
	# If the standalone run is clean and this one reproduces the failure, the cause is a stale arena in the physics
	# space and not the roster, the grid or anyone's tick-one motion.
	var pollute := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pollute="):
			pollute = arg.trim_prefix("--pollute=")
	# `--pollute=X` leaves X in the tree (proves a mechanism). `--pollute-free=X` builds X and then FREES it exactly
	# as `TestCase.teardown()` does, which is what actually happens between two tests -- so this arm is the one that
	# decides whether the real failure is stale bodies surviving a free, or something else entirely.
	var pollute_free := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pollute-free="):
			pollute_free = arg.trim_prefix("--pollute-free=")
	if pollute != "":
		var stale: Node = ARENA.instantiate()
		stale.layout_name = pollute
		root.add_child(stale)
		await physics_frame
		print("SPAWN_PROBE_POLLUTED with '%s' left in the tree; world bodies now %d" % [pollute, _bodies()])
	if pollute_free != "":
		# `--pollute-frames=N`: how many physics frames the doomed arena lives for before it is freed. The real
		# polluter is `test_arena_layouts::test_match_spawns_come_from_the_layout`, four lines whose first is
		# `await ArenaFixture.build(self, "scrapyard")` -- and that fixture awaits frames until the arena's OWN
		# navmesh has baked, up to 5 s. One frame is not the same experiment.
		var frames := 1
		for arg2 in OS.get_cmdline_user_args():
			if arg2.begins_with("--pollute-frames="):
				frames = int(arg2.trim_prefix("--pollute-frames="))
		var doomed: Node = ARENA.instantiate()
		doomed.layout_name = pollute_free
		root.add_child(doomed)
		for f in frames:
			await physics_frame
		var before := _bodies()
		doomed.free()  # exactly TestCase.teardown(): immediate free, no physics frame after it
		print("SPAWN_PROBE_FREED '%s': world bodies %d -> %d immediately after free(), no frame awaited"
				% [pollute_free, before, _bodies()])

	var arena: Node = ARENA.instantiate()
	arena.layout_name = arena_name
	root.add_child(arena)
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(9, 6.0)
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var err := game_match.load_doctrine(team, _full_army())
		if err != "":
			print("SPAWN_PROBE_ERROR load_doctrine team %d: %s" % [team, err])
			quit(1)
			return
	# nav's discriminator, and it is the whole point of the run: a unit that spawns ALREADY intersecting, with no
	# first-tick motion, is indistinguishable in the test's output from one that was nudged into geometry. So the
	# placement coordinate is captured HERE -- `ArmyLayout.deploy()` runs synchronously inside `load_doctrine`, before
	# any physics step -- and compared with the position the probe sees. Equal means PLACEMENT (scale's: the grid and
	# the hull sizes). Different means TICK-ONE MOTION (squad's corridor field or combat's switching seam in
	# tank_brain.gd, the only code left in the 7542df28..HEAD window).
	var placed := {}
	for tank: Tank in game_match.tanks_by_name().values():
		placed[tank] = tank.global_position

	await physics_frame
	await physics_frame

	var tanks: Array = game_match.tanks_by_name().values()
	# half_size does NOT discriminate two layouts (foundry and scrapyard are both 120.0) -- the name and the obstacle
	# count do. A print that cannot tell the two arms apart is not an instrument.
	print("SPAWN_PROBE world_bodies=%d active=%s obstacles=%d half_size=%s" % [_bodies(),
			str(Arena.active.get("name", "?")), (Arena.active.get("obstacles", []) as Array).size(),
			str(Arena.active.get("half_size", "?"))])
	print("SPAWN_PROBE arena=%s units=%d squads=%d slots=%d drivable=%.1f base_z=%.1f" % [arena_name, tanks.size(),
			ceili(float(Army.MAX_ARMY_UNITS) / Doctrine.MAX_SQUAD_UNITS), Match.SPAWN_SLOTS,
			Match.DRIVABLE_LIMIT, Match.BASE_Z])
	# The assembly's real footprint, so "it no longer fits" can be confirmed or ruled out rather than assumed.
	var span := {}
	for tank: Tank in tanks:
		var side := "green" if String(tank.name).begins_with("Green") else "rust"
		var box: Dictionary = span.get(side, {"minz": INF, "maxz": -INF, "minx": INF, "maxx": -INF})
		box["minz"] = minf(box["minz"], tank.global_position.z)
		box["maxz"] = maxf(box["maxz"], tank.global_position.z)
		box["minx"] = minf(box["minx"], tank.global_position.x)
		box["maxx"] = maxf(box["maxx"], tank.global_position.x)
		span[side] = box
	for side: String in span:
		var b: Dictionary = span[side]
		print("SPAWN_PROBE_SPAN %s x %.1f..%.1f (%.1f m) z %.1f..%.1f (%.1f m)" % [side, b["minx"], b["maxx"],
				b["maxx"] - b["minx"], b["minz"], b["maxz"], b["maxz"] - b["minz"]])

	var space := (tanks[0] as Tank).get_world_3d().direct_space_state
	var blocked := 0
	for tank: Tank in tanks:
		var size: Array = Units.stat(tank.unit_id, "hull_size")
		var probe := PhysicsShapeQueryParameters3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(size[0] + 1.0, 1.0, size[2] + 1.0)
		probe.shape = shape
		probe.transform = Transform3D(Basis.IDENTITY, tank.global_position + Vector3.UP * 1.5)
		probe.collision_mask = Perception.WORLD_MASK
		var hits: Array = space.intersect_shape(probe, 8)
		if hits.is_empty():
			continue
		blocked += 1
		var names: Array = []
		for hit: Dictionary in hits:
			var body: Object = hit.get("collider")
			var where := ""
			if body is Node3D:
				var node3d := body as Node3D
				where = " at %s" % node3d.global_position
				var owner_name := String(node3d.get_parent().name) if node3d.get_parent() != null else "?"
				names.append("%s/%s%s" % [owner_name, node3d.name, where])
			else:
				names.append("%s%s" % [str(body), where])
		var at_placement: Vector3 = placed.get(tank, tank.global_position)
		var moved := at_placement.distance_to(tank.global_position)
		var cause := "PLACEMENT (did not move)" if moved < 0.001 else "MOTION (moved %.3f m on tick one)" % moved
		print("SPAWN_PROBE_BLOCKED %s unit=%s hull %.2fx%.2f placed %s -> now %s :: %s :: %s" % [tank.name,
				tank.unit_id, float(size[0]), float(size[2]), at_placement, tank.global_position, cause,
				", ".join(names)])
	# The same discriminator over the WHOLE army, so "nothing moved on tick one" is a measured statement about all 90
	# units rather than an observation about the three that happened to fail.
	var movers := 0
	var worst := 0.0
	var worst_name := ""
	for tank: Tank in tanks:
		var d: float = (placed.get(tank, tank.global_position) as Vector3).distance_to(tank.global_position)
		if d >= 0.001:
			movers += 1
		if d > worst:
			worst = d
			worst_name = String(tank.name)
	print("SPAWN_PROBE_MOTION %d of %d units moved on tick one; worst %.3f m (%s)" % [movers, tanks.size(), worst,
			worst_name if worst_name != "" else "none"])
	print("SPAWN_PROBE_DONE blocked=%d of %d" % [blocked, tanks.size()])
	quit(0)


## Every static body in the tree: the count that distinguishes "one arena" from "one arena plus a stale one".
func _bodies() -> int:
	return _count(root)


func _count(node: Node) -> int:
	var n := 1 if node is StaticBody3D else 0
	for child in node.get_children():
		n += _count(child)
	return n
