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
	await physics_frame
	await physics_frame

	var tanks: Array = game_match.tanks_by_name().values()
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
		print("SPAWN_PROBE_BLOCKED %s unit=%s hull %.2fx%.2f at %s :: %s" % [tank.name, tank.unit_id,
				float(size[0]), float(size[2]), tank.global_position, ", ".join(names)])
	print("SPAWN_PROBE_DONE blocked=%d of %d" % [blocked, tanks.size()])
	quit(0)
