extends SceneTree
## Round 33 (traffic stretch, the crate-roof islands): bake each arena as the game does, with the bake's
## `region_min_size` set to each value asked for, and list the navmesh's connected components (polygons sharing an
## edge) of the baked half: count, area, height. Round 32's side finding: the 1.75 m agent height lets a 3 m crate's top
## count as standable, and the 0.25 m climb keeps it disconnected, so each crate grows a small roof island a goal could
## snap to. Measurement only.
##
##   godot --headless --path . --script res://tests/traffic/island_probe.gd -- [--arenas=a,b] [--min-sizes=2,6,8,10]
##   ISLANDS {"arena", "min_size", "components", "main_area", "raised": [[area, y], ...], "small": [[area, y], ...]}

const ARENA := preload("res://game/arena/arena.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _components(mesh: NavigationMesh) -> Array:
	var vertices := mesh.get_vertices()
	var count := mesh.get_polygon_count()
	var parent := range(count)
	var find := func(i: int, self_ref: Callable) -> int:
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i
	var by_edge := {}
	for p in count:
		var poly := mesh.get_polygon(p)
		for k in poly.size():
			var a := vertices[poly[k]]
			var b := vertices[poly[(k + 1) % poly.size()]]
			var ka := "%.2f,%.2f,%.2f" % [a.x, a.y, a.z]
			var kb := "%.2f,%.2f,%.2f" % [b.x, b.y, b.z]
			var key := ka + "|" + kb if ka < kb else kb + "|" + ka
			if by_edge.has(key):
				var ra: int = find.call(p, find)
				var rb: int = find.call(int(by_edge[key]), find)
				if ra != rb:
					parent[ra] = rb
			else:
				by_edge[key] = p
	var groups := {}
	for p in count:
		var root: int = find.call(p, find)
		var poly := mesh.get_polygon(p)
		var area := 0.0
		var top := -INF
		for k in range(1, poly.size() - 1):
			var a := vertices[poly[0]]
			var b := vertices[poly[k]]
			var c := vertices[poly[k + 1]]
			area += absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
		for v in poly:
			top = maxf(top, vertices[v].y)
		var g: Array = groups.get_or_add(root, [0.0, -INF])
		g[0] = float(g[0]) + area
		g[1] = maxf(float(g[1]), top)
	return groups.values()


func _run() -> void:
	var arenas := _flag("arenas", ",".join(Arena.ROTATION) + ",foundry").split(",", false)
	var sizes := _flag("min-sizes", "2,6,8,10").split(",", false)
	for arena_name in arenas:
		for size_text in sizes:
			var arena := ARENA.instantiate() as Node3D
			arena.set("layout_name", arena_name)
			var region := arena.get_node("Navigation") as NavigationRegion3D
			region.navigation_mesh = region.navigation_mesh.duplicate()
			region.navigation_mesh.region_min_size = float(size_text)
			root.add_child(arena)
			for i in 120:
				await physics_frame
				if region.navigation_mesh.get_polygon_count() > 0:
					break
			var groups := _components(region.navigation_mesh)
			groups.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
			var raised := []
			var small := []
			for g: Array in groups.slice(1):
				var row := [snappedf(g[0], 0.1), snappedf(g[1], 0.01)]
				if float(g[1]) > 1.0:
					raised.append(row)
				else:
					small.append(row)
			print("ISLANDS " + JSON.stringify({"arena": arena_name, "min_size": float(size_text), "components": groups.size(),
					"main_area": snappedf(float(groups[0][0]), 1.0) if not groups.is_empty() else 0.0,
					"raised": raised, "small": small}))
			arena.queue_free()
			await physics_frame
			await physics_frame
	quit(0)
