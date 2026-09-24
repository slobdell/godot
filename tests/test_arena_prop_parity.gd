extends TestCase
## R3 (round 10): prop collision parity. What a hull can touch has a collider. For every kit prop, the drawn geometry
## a hull can reach -- everything below the tallest hull's roof -- lies inside the prop's STATIC FOOTPRINT in
## `ArenaKit.PROPS`, or the prop is declared decoration (`collides: false`) and placed where no lane runs.
##
## The lead (2026-09-20): "vehicles are going straight through and overlapping with some of the assets (like the
## lights)." This measures feel's meshes as drawn (the theme's own slot scenes and yards), so the test re-answers
## itself whenever the art changes.

## Metres of slack before a drawn edge counts as over its box: a fifth of the navmesh cell (0.5 m), below what the
## bake or a hull's contact resolves. Measured at the time it was set: the city block's shopfront trim 0.06 m proud,
## the floodlight's hazard bands 0.01 m. Anything past this is a real overhang.
const TOLERANCE_M := 0.10
## A mesh flatter than this is a light pool or decal on the floor: a hull drives over it.
const FLAT_M := 0.12
## Where the props are placed to be photographed by the measurement: far outside every arena, and far apart.
const ORIGIN := Vector3(2000.0, 0.0, 2000.0)
const SPACING := 80.0


## The roof of the tallest hull, READ from `Units`: geometry above it cannot be touched by any hull.
static func reach_height() -> float:
	var tallest := 0.0
	for unit_id: String in Units.ids():
		tallest = maxf(tallest, float(Units.profile(unit_id)["hull_size"][1]))
	return tallest


## {kind: {overhang_m, worst: Vector3 (local), vertices}} for every kit prop kind, measured from the drawn meshes.
func _measure() -> Dictionary:
	var holder := Node3D.new()
	add_to_tree(holder)
	var placed := {}
	var i := 0
	for kind: String in ArenaKit.PROPS:
		var packed := GameTheme.scene("prop." + kind)
		if packed == null:
			continue
		var node := packed.instantiate() as Node3D
		var at := ORIGIN + Vector3(SPACING * i, 0.0, 0.0)
		i += 1
		holder.add_child(node)
		node.global_position = at
		var prop := {"type": kind, "position": [at.x, at.z], "rotation_deg": 0.0}
		if node.has_method("setup"):
			node.call("setup", prop)
		placed[kind] = {"node": node, "at": at}
	for frame in 4:
		await tree.process_frame
	var roof := reach_height()
	var out := {}
	for kind: String in placed:
		var at: Vector3 = placed[kind]["at"]
		var node: Node3D = placed[kind]["node"]
		var vertices := PackedVector3Array()
		for mesh_node in node.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh_node as MeshInstance3D
			if mi.mesh != null and mi.visible:
				vertices.append_array(_world_vertices(mi.mesh, mi.global_transform))
		for mm_node in tree.root.find_children("*", "MultiMeshInstance3D", true, false):
			var mmi := mm_node as MultiMeshInstance3D
			if mmi.multimesh == null or mmi.multimesh.mesh == null or not mmi.visible:
				continue
			for xform: Transform3D in _instances(mmi):
				if Vector2(xform.origin.x - at.x, xform.origin.z - at.z).length() > SPACING / 2.0:
					continue
				vertices.append_array(_world_vertices(mmi.multimesh.mesh, mmi.global_transform * xform))
		var size := ArenaKit.size_of({"type": kind})
		var worst := 0.0
		var worst_at := Vector3.ZERO
		var counted := 0
		var reach := Vector2.ZERO
		for v in vertices:
			if v.y > roof:
				continue
			counted += 1
			var local := v - at
			reach = Vector2(maxf(reach.x, absf(local.x)), maxf(reach.y, absf(local.z)))
			var over := maxf(absf(local.x) - size.x / 2.0, absf(local.z) - size.z / 2.0)
			if over > worst:
				worst = over
				worst_at = local
		out[kind] = {"overhang_m": worst, "worst": worst_at, "vertices": counted, "box": size, "drawn": reach * 2.0}
	holder.queue_free()
	await tree.process_frame
	return out


## The instance transforms a yard MultiMesh draws. Read from the yard's own entry table (`KitYard`, `ContainerYard`:
## `_entries`, id -> [kind, Transform3D, data], one draw per kind named after it), NOT from the MultiMesh: a headless
## renderer does not keep instance data, so `get_instance_transform()` answers identity for every instance there and
## the first version of this test measured nothing at all (its positive control caught it).
static func _instances(mmi: MultiMeshInstance3D) -> Array:
	var yard := mmi.get_parent()
	var entries: Variant = yard.get("_entries") if yard != null else null
	var out: Array = []
	if entries is Dictionary:
		for entry: Array in (entries as Dictionary).values():
			if String(entry[0]) == String(mmi.name):
				out.append(entry[1])
		return out
	for k in mmi.multimesh.instance_count:
		out.append(mmi.multimesh.get_instance_transform(k))
	return out


## A mesh's vertices in world space, skipping flat surfaces (floor light pools, decals).
static func _world_vertices(mesh: Mesh, xform: Transform3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null:
			continue
		var surface := PackedVector3Array()
		var low := INF
		var high := -INF
		for v: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
			var w := xform * v
			surface.append(w)
			low = minf(low, w.y)
			high = maxf(high, w.y)
		if high - low >= FLAT_M:
			out.append_array(surface)
	return out


func test_every_prop_a_hull_can_touch_is_inside_its_collider() -> void:
	var measured := await _measure()
	var failures: PackedStringArray = []
	for kind: String in measured:
		var m: Dictionary = measured[kind]
		print("PROP_PARITY %-13s box %.2f x %.2f  drawn below %.2f m: %.2f x %.2f, %.2f m past the box (at local %s, %d vertices)%s" % [
				kind, m["box"].x, m["box"].z, reach_height(), m["drawn"].x, m["drawn"].y, m["overhang_m"], m["worst"], m["vertices"],
				"" if ArenaKit.collides(kind) else "  [decoration]"])
		if not ArenaKit.collides(kind):
			continue  # decoration: judged by where it stands, below
		if m["overhang_m"] > TOLERANCE_M:
			failures.append("%s overhangs its %.2f x %.2f box by %.2f m at local (%.2f, %.2f, %.2f)" % [kind,
					m["box"].x, m["box"].z, m["overhang_m"], m["worst"].x, m["worst"].y, m["worst"].z])
	for kind: String in measured:
		assert_true(int(measured[kind]["vertices"]) > 0, "POSITIVE CONTROL: %s's drawn mesh was found and measured" % kind)
	assert_true(failures.is_empty(), "every colliding prop's reachable geometry is inside its box: %s" % "; ".join(failures))


## Decoration has no collider, so a hull drives through it: it must stand where no hull is sent. Off every declared
## lane (by the lane bar's half-width) where the lane rule is asserted, and out of both spawn zones on every map.
func test_decoration_stands_where_no_hull_is_sent() -> void:
	var the_bar := ArenaLanes.bar()
	var half := float(the_bar["physical_bar_m"]) / 2.0
	var failures: PackedStringArray = []
	for layout_name in Arena.layout_names():
		var data: Dictionary = Arena.load_layout(layout_name)["layout"]
		if Arena.is_fixture(data):
			continue
		# Lanes are judged where the lane rule is asserted; spawn zones on every map.
		var lanes: Array = [] if ArenaLanes.REPORT_ONLY.has(layout_name) else data.get("lanes", [])
		for prop: Dictionary in data.get("props", []):
			if ArenaKit.collides(String(prop["type"])):
				continue
			var p := Vector2(prop["position"][0], prop["position"][1])
			for lane: Dictionary in lanes:
				var pts: Array = lane["points"]
				for k in range(1, pts.size()):
					var a := Vector2(pts[k - 1][0], pts[k - 1][1])
					var b := Vector2(pts[k][0], pts[k][1])
					if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < half:
						failures.append("%s: %s at %s is on %s" % [layout_name, prop["type"], p, lane["name"]])
			for south in [true, false]:
				var zone := Arena.spawn_zone_of(data, south)
				if zone.is_empty():
					continue
				var c: Vector3 = zone["center"]
				var s: Vector2 = zone["size"]
				if absf(p.x - c.x) <= s.x / 2.0 and absf(p.y - c.z) <= s.y / 2.0:
					failures.append("%s: %s at %s is inside a spawn zone" % [layout_name, prop["type"], p])
	assert_true(failures.is_empty(), "decoration stands where no hull is sent: %s" % "; ".join(failures))


## Round 11 (A2): the DRESSING layer too. *"units can still drive right through the spotlight assets in Terminus;
## solid objects should not intersect."* The two tests above iterate `ArenaKit.PROPS` and the layout's props, so they
## never saw `arena.dressing` at all -- and the venue's 21 m floodlight towers were built by the dressing, 9 m inside
## every polygon corner, standing on drivable navmesh with no collider.
##
## For every map he can be dealt (and every other non-fixture layout), build the shipping dressing exactly as a match
## does and measure every drawn mesh -- hidden instancing originals included, since `StaticInstancer` keeps their nodes
## and hides them -- that stands on the floor (its lowest vertex under a hull's roof) and rises off it. Anything with
## such geometry INSIDE the drivable area (`ArenaShape.contains` on the layout's own shape and half_size, by more than
## the tolerance: never a hard-coded coordinate, lesson 3) must lie inside a `StaticBody3D` box in the
## `navigation_source` group, or it is a decoration a hull drives through. Unshadowed meshes are light (beams, pools)
## and are skipped; that exemption is printed so it cannot hide anything silently.
func test_the_venue_dressing_is_solid_or_outside_the_wall() -> void:
	var roof := reach_height()
	var failures: PackedStringArray = []
	var measured := 0
	for layout_name in Arena.layout_names():
		var data: Dictionary = Arena.load_layout(layout_name)["layout"]
		if Arena.is_fixture(data):
			continue
		var kind := String((data.get("shape", {}) as Dictionary).get("kind", ArenaShape.DEFAULT_KIND))
		var bound := float(data.get("half_size", Match.ARENA_HALF_SIZE))
		var dressing := (load("res://game/theme/cyberpunk/arena_dressing.tscn") as PackedScene).instantiate() as Node3D
		add_to_tree(dressing)
		dressing.call("setup", data)
		await tree.process_frame
		var solids: Array = []  # [Transform3D, half extents] of every navigation_source box in the dressing
		for body_node in dressing.find_children("*", "StaticBody3D", true, false):
			if not (body_node as Node).is_in_group("navigation_source"):
				continue
			for shape_node in (body_node as Node).find_children("*", "CollisionShape3D", true, false):
				var cs := shape_node as CollisionShape3D
				if cs.shape is BoxShape3D:
					solids.append([cs.global_transform, (cs.shape as BoxShape3D).size / 2.0])
		var intruders := {}
		for mesh_node in dressing.find_children("*", "MeshInstance3D", true, false):
			var mi := mesh_node as MeshInstance3D
			if mi.mesh == null or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
				continue
			var vertices := _world_vertices(mi.mesh, mi.global_transform)
			var low := INF
			for v in vertices:
				low = minf(low, v.y)
			if vertices.is_empty() or low > roof:
				continue  # off the floor entirely (the airship, signs on a stand's rail)
			measured += 1
			for v in vertices:
				if v.y > roof or not ArenaShape.contains(kind, bound, Vector2(v.x, v.z), TOLERANCE_M):
					continue
				var held := false
				for solid: Array in solids:
					var local: Vector3 = (solid[0] as Transform3D).affine_inverse() * v
					var ext: Vector3 = solid[1]
					if absf(local.x) <= ext.x + TOLERANCE_M and absf(local.z) <= ext.z + TOLERANCE_M:
						held = true
						break
				if not held:
					var path := String(dressing.get_path_to(mi))
					if not intruders.has(path):
						intruders[path] = Vector2(v.x, v.z)
		for path: String in intruders:
			failures.append("%s: %s stands inside the wall at %s with no collider" % [layout_name, path, intruders[path]])
		dressing.free()
	for line in failures:
		print("DRESSING_PARITY " + line)
	assert_true(measured > 50, "POSITIVE CONTROL: the dressing's floor-standing meshes were found (%d)" % measured)
	assert_true(failures.is_empty(), "nothing the venue dressing stands inside the drivable area without a collider: %d found (DRESSING_PARITY lines)" % failures.size())
