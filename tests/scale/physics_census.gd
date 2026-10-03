extends SceneTree
## S8 (round 16): what the physics server holds in his match -- bodies by kind, shapes, and how many of each are
## static -- on every shipping arena, with his armies (Law v the Condemned at the default budget). Light; local.
##
##   .tools/.../godot --headless --path . --script res://tests/scale/physics_census.gd

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for layout: String in Arena.shipping_layout_names():
		var arena: Node = ARENA.instantiate()
		arena.layout_name = layout
		root.add_child(arena)
		var game_match: Match = MATCH.instantiate()
		root.add_child(game_match)
		for team in 2:
			game_match.load_doctrine(team, Army.cpu_army("cpu", 92721 + team, Units.BASELINE_BUDGET,
					"law" if team == 0 else "condemned"))
		for i in 3:
			await physics_frame
		var counts := {}
		var shapes := {}
		for node in root.find_children("*", "CollisionObject3D", true, false):
			var kind := node.get_class()
			counts[kind] = int(counts.get(kind, 0)) + 1
			var owned := 0
			for owner_id in (node as CollisionObject3D).get_shape_owners():
				owned += (node as CollisionObject3D).shape_owner_get_shape_count(owner_id)
			shapes[kind] = int(shapes.get(kind, 0)) + owned
		var shape_kinds := {}
		for node in root.find_children("*", "CollisionShape3D", true, false):
			var shape := (node as CollisionShape3D).shape
			var kind := shape.get_class() if shape != null else "none"
			shape_kinds[kind] = int(shape_kinds.get(kind, 0)) + 1
		var multimeshes := root.find_children("*", "MultiMeshInstance3D", true, false).size()
		print("PHYSICS_CENSUS %s bodies=%s shapes=%s shape_kinds=%s multimesh_nodes=%d active_objects=%d"
				% [layout, counts, shapes, shape_kinds, multimeshes,
					Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)])
		game_match.free()
		arena.free()
		for i in 2:
			await physics_frame
	quit()
