extends TestCase
## Round 23 (native, N2a): NavNative.closest_point gives NavigationServer3D.map_get_closest_point's answer BIT FOR BIT
## on a baked arena (both regions: the half and its pi-mirror), over a lattice of points across the arena and beyond
## it, random points, points on the mesh's own vertices and edges, and points high above and below. The grid walk
## visits a superset of the polygons the engine's strict first-minimum can land on, in the engine's order, with the
## engine's own per-polygon code. Skipped (said) without the library.

const LATTICE_STEP := 7.0
const RANDOM_POINTS := 1500


func test_closest_point_is_the_engines() -> void:
	if not NativeBridge.available:
		print("native: absent, the navmesh equality is not exercised in this run")
		return
	var arena := await ArenaFixture.build(self, "sumps")
	var map: RID = arena.get_world_3d().navigation_map
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	var nav: Object = ClassDB.instantiate("NavNative")
	var regions := NavigationServer3D.map_get_regions(map)
	var points := PackedVector3Array()
	var half := 170.0
	var x := -half
	while x <= half:
		var z := -half
		while z <= half:
			points.append(Vector3(x, 0.0, z))
			z += LATTICE_STEP
		x += LATTICE_STEP
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	for i in RANDOM_POINTS:
		points.append(Vector3(rng.randf_range(-200.0, 200.0), rng.randf_range(-3.0, 6.0), rng.randf_range(-200.0, 200.0)))
	# The mesh's own vertices (ties between polygons sharing them) and mid-edges, from the first region's mesh.
	for rid in regions:
		var owner := instance_from_id(NavigationServer3D.region_get_owner_id(rid)) as NavigationRegion3D
		if owner == null or owner.navigation_mesh == null:
			continue
		var transform := NavigationServer3D.region_get_transform(rid)
		var vertices := owner.navigation_mesh.get_vertices()
		for p in mini(owner.navigation_mesh.get_polygon_count(), 400):
			var indices := owner.navigation_mesh.get_polygon(p)
			var a := transform * vertices[indices[0]]
			var b := transform * vertices[indices[1]]
			points.append(a)
			points.append((a + b) * 0.5)
			points.append(a + Vector3(0.0, 2.0, 0.0))
	var mismatches := 0
	var first := ""
	var scan_mismatches := 0
	for point in points:
		var engine := NavigationServer3D.map_get_closest_point(map, point)
		var ours: Vector3 = nav.closest_point(map, point, iteration)
		if var_to_bytes(ours) != var_to_bytes(engine):
			mismatches += 1
			if first == "":
				first = "point %s: native %s vs engine %s (%.6f m apart)" % [point, ours, engine, ours.distance_to(engine)]
			var full: Vector3 = nav.closest_point_scan(map, point, iteration)
			if var_to_bytes(full) != var_to_bytes(engine):
				scan_mismatches += 1
	var t0 := Time.get_ticks_usec()
	for point in points:
		NavigationServer3D.map_get_closest_point(map, point)
	var engine_usec := Time.get_ticks_usec() - t0
	t0 = Time.get_ticks_usec()
	for point in points:
		nav.closest_point(map, point, iteration)
	var native_usec := Time.get_ticks_usec() - t0
	print("MEASURE native navmesh %d points, %d mismatches (%d even by the full scan); %s; regions %d; engine %.2f us/call, native %.2f us/call (from GDScript, the call included)" % [
			points.size(), mismatches, scan_mismatches, nav.stats(), regions.size(), float(engine_usec) / points.size(), float(native_usec) / points.size()])
	assert_true(nav.polygon_count() > 100, "the index holds the arena's polygons (%d)" % nav.polygon_count())
	assert_eq(nav.region_count(), regions.size(), "and both regions")
	assert_eq(mismatches, 0, "every point equal bit for bit; first mismatch: %s" % first)
	arena.free()
	await drain_navigation()


func test_every_dealt_map_agrees() -> void:
	# Coarser than the Sumps lattice above, on every map the game deals (and foundry): the bridges, water and channels
	# of crossing / archipelago / docks make different meshes, and a mesh is where an index can go wrong.
	if not NativeBridge.available:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 37
	var summary := PackedStringArray()
	var total_mismatches := 0
	for layout_name in [Arena.DEFAULT_LAYOUT] + Arena.ROTATION:
		var arena := await ArenaFixture.build(self, layout_name)
		var map: RID = arena.get_world_3d().navigation_map
		var iteration := NavigationServer3D.map_get_iteration_id(map)
		var nav: Object = ClassDB.instantiate("NavNative")
		var mismatches := 0
		var count := 0
		var x := -180.0
		while x <= 180.0:
			var z := -180.0
			while z <= 180.0:
				var point := Vector3(x + rng.randf_range(-2.0, 2.0), rng.randf_range(-1.0, 3.0), z + rng.randf_range(-2.0, 2.0))
				count += 1
				if var_to_bytes(nav.closest_point(map, point, iteration)) != var_to_bytes(NavigationServer3D.map_get_closest_point(map, point)):
					mismatches += 1
				z += 12.0
			x += 12.0
		summary.append("%s %d/%d polygons %d" % [layout_name, mismatches, count, nav.polygon_count()])
		total_mismatches += mismatches
		arena.free()
		await drain_navigation()
	print("MEASURE native navmesh maps (mismatches/points): %s" % ", ".join(summary))
	assert_eq(total_mismatches, 0, "every dealt map agrees with the engine: %s" % ", ".join(summary))
