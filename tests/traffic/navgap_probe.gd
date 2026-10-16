extends SceneTree
## Round 32 (traffic, C32.6): the default arena's navmesh gap. In the default arena at (-25.7, 7.3), where
## test_control_queued_task's Green_Alpha_3 stops, the navmesh start was read snapping 8.2 m to (-17.5, 7.3) (brains'
## reach probe, round 31). Bake hole (standable ground left out) or an obstacle footprint the hull was pushed onto?
## This bakes the arena as the game does and prints, as one JSON line, the bake's inputs, the closest-point answers at
## the spot and a grid round it, every navmesh polygon (both regions) and every navigation_source collision box inside
## the window, so tests/traffic/navgap_plot.py can draw them.
##
##   godot --headless --path . --script res://tests/traffic/navgap_probe.gd -- [--arena=<name>] [--x=-25.7 --z=7.3]
##   NAVGAP {...}

const ARENA := preload("res://game/arena/arena.tscn")
const WINDOW_M := 16.0


func _initialize() -> void:
	_run.call_deferred()


func _arg(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	# --after=<layout>: first load that arena, wait for its navmesh, free it, then load this one (the reach probe's order:
	# its default-arena cases ran after terminus and sumps in one process), and report the closest point each frame
	# until it settles: does the map answer from the freed arena's regions first?
	var before := _arg("after", "")
	if before != "":
		var first := ARENA.instantiate()
		first.set("layout_name", before)
		root.add_child(first)
		for frame in 60:
			await physics_frame
		if _arg("sync_free", "") != "":
			first.free()
		else:
			first.queue_free()
		if _arg("settle", "") != "":
			await process_frame  # the freed arena leaves the tree before the next one bakes
		var second := ARENA.instantiate()
		root.add_child(second)
		var map0 := (second as Node3D).get_world_3d().navigation_map
		var probe := Vector3(float(_arg("x", "-25.7")), 0.0, float(_arg("z", "7.3")))
		for frame in int(_arg("frames", "12")):
			var c := NavigationServer3D.map_get_closest_point(map0, probe)
			print("NAVGAP_AFTER frame %d regions %d owner_valid %s closest (%.1f, %.1f) gap %.1f" % [frame,
					NavigationServer3D.map_get_regions(map0).size(),
					NavigationServer3D.map_get_closest_point_owner(map0, Vector3.ZERO).is_valid(), c.x, c.z,
					Vector2(c.x, c.z).distance_to(Vector2(probe.x, probe.z))])
			await physics_frame
		quit()
		return
	var arena := ARENA.instantiate()
	var layout := _arg("arena", "")
	if layout != "":
		arena.set("layout_name", layout)
	root.add_child(arena)
	var spot := Vector3(float(_arg("x", "-25.7")), 0.0, float(_arg("z", "7.3")))
	for frame in 10:
		await physics_frame
	var world: World3D = (arena as Node3D).get_world_3d()
	var map := world.navigation_map
	for frame in 300:
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_regions(map).size() >= 2:
			break
		await physics_frame
	await physics_frame
	var lo := Vector2(spot.x - WINDOW_M, spot.z - WINDOW_M)
	var hi := Vector2(spot.x + WINDOW_M, spot.z + WINDOW_M)
	var out := {"arena": arena.get("layout_name") if layout != "" else "default", "spot": [spot.x, spot.z]}
	var region: NavigationRegion3D = arena.get("navigation")
	var nav_mesh := region.navigation_mesh
	out["bake"] = {"cell_size": nav_mesh.cell_size, "cell_height": nav_mesh.cell_height,
			"agent_radius": nav_mesh.agent_radius, "agent_height": nav_mesh.agent_height,
			"agent_max_climb": nav_mesh.agent_max_climb, "agent_max_slope": nav_mesh.agent_max_slope,
			"border_size": nav_mesh.border_size, "parsed_geometry_type": nav_mesh.geometry_parsed_geometry_type,
			"source_mode": nav_mesh.geometry_source_geometry_mode, "group": String(nav_mesh.geometry_source_group_name),
			"collision_mask": nav_mesh.geometry_collision_mask, "region_min_size": nav_mesh.region_min_size,
			"filter_baking_aabb": [nav_mesh.filter_baking_aabb.position.x, nav_mesh.filter_baking_aabb.position.z,
					nav_mesh.filter_baking_aabb.end.x, nav_mesh.filter_baking_aabb.end.z],
			"map_cell_size": NavigationServer3D.map_get_cell_size(map),
			"map_edge_connection_margin": NavigationServer3D.map_get_edge_connection_margin(map)}
	var closest := NavigationServer3D.map_get_closest_point(map, spot)
	out["closest"] = [closest.x, closest.y, closest.z, Vector2(closest.x, closest.z).distance_to(Vector2(spot.x, spot.z))]
	var grid := []
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var p := spot + Vector3(dx, 0.0, dz)
			var c := NavigationServer3D.map_get_closest_point(map, p)
			grid.append([p.x, p.z, Vector2(c.x, c.z).distance_to(Vector2(p.x, p.z))])
	out["grid"] = grid
	var polys := []
	for r: RID in NavigationServer3D.map_get_regions(map):
		var xf := NavigationServer3D.region_get_transform(r)
		var mesh: NavigationMesh = null
		for node: Node in [region, arena.get_node_or_null("NavigationMirror")]:
			if node != null and (node as NavigationRegion3D).get_rid() == r:
				mesh = (node as NavigationRegion3D).navigation_mesh
		if mesh == null:
			continue
		var verts := mesh.get_vertices()
		for i in mesh.get_polygon_count():
			var ring := []
			var inside := false
			for vi: int in mesh.get_polygon(i):
				var v := xf * verts[vi]
				ring.append([v.x, v.z])
				inside = inside or (v.x >= lo.x and v.x <= hi.x and v.z >= lo.y and v.z <= hi.y)
			if inside:
				polys.append(ring)
	out["polys"] = polys
	var boxes := []
	for node: Node in get_nodes_in_group(nav_mesh.geometry_source_group_name):
		for shape_node: Node in node.find_children("*", "CollisionShape3D", true, false) + [node]:
			if not shape_node is CollisionShape3D or (shape_node as CollisionShape3D).disabled:
				continue
			var box := (shape_node as CollisionShape3D).shape as BoxShape3D
			if box == null:
				continue
			var xf := (shape_node as Node3D).global_transform
			var h := box.size * 0.5
			var ring := []
			for corner: Vector3 in [Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z)]:
				var v := xf * corner
				ring.append([v.x, v.z])
			var centre := xf.origin
			if centre.x >= lo.x - 20.0 and centre.x <= hi.x + 20.0 and centre.z >= lo.y - 20.0 and centre.z <= hi.y + 20.0:
				boxes.append({"name": String(shape_node.get_path()), "ring": ring, "size": [box.size.x, box.size.y, box.size.z],
						"y": centre.y})
	out["boxes"] = boxes
	print("NAVGAP " + JSON.stringify(out))
	quit()
