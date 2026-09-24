class_name TurretFit
extends RefCounted
## Round 11 (fleet T1; the lead: "The turret on the Law's IFV is not spinning"). It WAS spinning -- inside its hull.
## This measures, from the meshes as the game draws them, how much of what turns with a unit's turret is drawn ABOVE
## the hull that does not turn. Pure measurement, no list of units: `make turret-probe` prints it and
## tests/test_theme_unit_scale.gd asserts on it for the whole roster.
##
## "What turns" is everything the turret yaw carries: the turret part, the weapon part, and a gun cut out of the hull
## (FactionArt.GUN_CUTS, under a GunPivot). "The hull" is every other drawn mesh under HullVisual. The hull is reduced
## to a HEIGHT FIELD: the highest hull point in each CELL_M square of the tank's x/z plane. A turning point counts as
## visible when it is above the hull's height field at its own x/z (or where there is no hull at all), within
## SEATED_M -- a turret ring sitting ON the roof is seated, not buried.

const CELL_M := 0.2
const SEATED_M := 0.05


## Every drawn vertex (and triangle centroid, so a large flat face still marks its cells) under `node`, in `tank`'s
## frame. `turning`: true keeps only meshes the turret carries, false only the hull's own.
static func points(tank: Node3D, node: Node, turning: bool) -> PackedVector3Array:
	var out := PackedVector3Array()
	var to_tank := tank.global_transform.affine_inverse()
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance is ShieldEffect:
			continue
		if _under_gun_pivot(instance, node) != turning and node.name == "HullVisual":
			continue
		var xform := to_tank * instance.global_transform
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			# Only the vertices a triangle USES: a gun cut (FactionArt.split_mesh) keeps the whole vertex array on both
			# halves and splits the indices, so the hull half still carries every vertex of the gun.
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if indices.is_empty():
				indices.resize(verts.size())
				for i in verts.size():
					indices[i] = i
			for t in range(0, indices.size() - 2, 3):
				var a := verts[indices[t]]
				var b := verts[indices[t + 1]]
				var c := verts[indices[t + 2]]
				out.append_array([xform * a, xform * b, xform * c, xform * ((a + b + c) / 3.0)])
	return out


static func _under_gun_pivot(instance: Node, stop: Node) -> bool:
	var up := instance.get_parent()
	while up != null and up != stop:
		if String(up.name) == "GunPivot":
			return true
		up = up.get_parent()
	return false


## The hull's drawn points and the turret's drawn points, in the tank frame: {"hull": ..., "turning": ...}.
static func split(tank: Node3D) -> Dictionary:
	var turning := PackedVector3Array()
	turning.append_array(points(tank, tank.get_node("Turret/TurretVisual"), true))
	turning.append_array(points(tank, tank.get_node("Turret/WeaponVisual"), true))
	turning.append_array(points(tank, tank.get_node("HullVisual"), true))
	return {"hull": points(tank, tank.get_node("HullVisual"), false), "turning": turning}


static func _cell(p: Vector3) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL_M)), int(floor(p.z / CELL_M)))


## {"points": n, "above": fraction of turning points drawn above the hull, "lowest": the lowest turning point's height
## above (+) or below (-) the hull under it, m}. points 0 = nothing turns (a fixed mount, or no turret art).
static func measure(tank: Node3D) -> Dictionary:
	var parts := split(tank)
	var roof := {}
	for p: Vector3 in parts["hull"]:
		var cell := _cell(p)
		roof[cell] = maxf(float(roof.get(cell, -INF)), p.y)
	var turning: PackedVector3Array = parts["turning"]
	var above := 0
	var lowest := INF
	for p in turning:
		var under := float(roof.get(_cell(p), -INF))
		if p.y >= under - SEATED_M:
			above += 1
		if under > -INF:
			lowest = minf(lowest, p.y - under)
	return {"points": turning.size(), "above": float(above) / maxf(turning.size(), 1.0),
			"lowest": lowest if lowest < INF else 0.0}
