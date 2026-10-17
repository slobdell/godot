extends TestCase
## Round 33 (traffic stretch, round 32's side finding): the bake left a navmesh island on top of each 3 m crate in the
## default arena (foundry: five, 1-2.5 m2 at 3.5 m; the 1.75 m agent height counts the top as standable, the 0.25 m climb
## keeps it disconnected), so a goal point inside a crate could snap to a roof nobody can reach. The bake's
## region_min_size 8 (64 cells, 16 m2) drops isolated regions that small; on all 13 arenas it removes exactly those
## islands (tests/traffic/island_probe.gd: the next-smallest island anywhere is a 72 m2 ground pocket on crossing).

const ARENA := preload("res://game/arena/arena.tscn")


## Connected components of the baked half (polygons sharing an edge): [[area, top y], ...].
static func _islands(mesh: NavigationMesh) -> Array:
	var vertices := mesh.get_vertices()
	var count := mesh.get_polygon_count()
	var parent: Array = range(count)
	var find := func(i: int) -> int:
		while parent[i] != i:
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
				var ra: int = find.call(p)
				var rb: int = find.call(int(by_edge[key]))
				if ra != rb:
					parent[ra] = rb
			else:
				by_edge[key] = p
	var groups := {}
	for p in count:
		var poly := mesh.get_polygon(p)
		var g: Array = groups.get_or_add(find.call(p), [0.0, -INF])
		for k in range(1, poly.size() - 1):
			var a := vertices[poly[0]]
			var b := vertices[poly[k]]
			var c := vertices[poly[k + 1]]
			g[0] = float(g[0]) + absf((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) * 0.5
		for v in poly:
			g[1] = maxf(float(g[1]), vertices[v].y)
	return groups.values()


func test_the_default_arena_bakes_no_crate_roof_islands() -> void:
	var arena := ARENA.instantiate() as Node3D
	arena.set("layout_name", "foundry")
	add_to_tree(arena)
	var region := arena.get_node("Navigation") as NavigationRegion3D
	for i in 120:
		await tree.physics_frame
		if region.navigation_mesh.get_polygon_count() > 0:
			break
	assert_true(region.navigation_mesh.region_min_size >= 4.0, "the bake drops isolated regions under 4 m2 at least")
	var raised := []
	for g: Array in _islands(region.navigation_mesh):
		if float(g[1]) > 1.0 and float(g[0]) < 16.0:
			raised.append(g)
	assert_eq(raised, [], "no small island above the ground (a crate roof)")
