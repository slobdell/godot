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
