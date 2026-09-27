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


## Round 11 follow-up (the lead, twice: the War Rig's gun "disconnected and floating"). `measure` compares each
## turning point with the hull in its OWN x/z cell and skips a point with no hull beneath it, which is blind in the
## two states where a gun most obviously hangs in the air: traversed off the hull's footprint, and swung out on a
## bent trailer. `seat_gap` answers the question a player actually asks -- *is there daylight under it?* -- by
## measuring every turning point against the NEAREST hull surface within `REACH_CELLS`, so a gun hanging past the
## edge is measured against the edge rather than excused. Positive is air under the lowest point.
const REACH_CELLS := 3


## The CUT GUN on its own (the GunPivot subtree inside HullVisual), against the hull directly beneath its own
## footprint. `seat_gap` above takes the minimum over EVERY turning part, so one part tucked inside the hull hides a
## different part hanging in the air -- which is exactly what happened to the War Rig: the probe read -0.148 m
## ("sunk") for a gun the render showed floating. A player looks at one part at a time, so the instrument must too.
## {"has_gun", "lowest": the gun's lowest y, "under": the hull's top beneath its footprint, "air": lowest - under}.
static func gun_seat(tank: Node3D) -> Dictionary:
	var hull := tank.get_node_or_null("HullVisual")
	if hull == null:
		return {"has_gun": false}
	var gun := PackedVector3Array()
	for pivot in hull.find_children("GunPivot", "Node3D", true, false):
		gun.append_array(points(tank, pivot as Node3D, true))
	if gun.is_empty():
		return {"has_gun": false}
	var roof := {}
	for p: Vector3 in points(tank, hull, false):
		var cell := _cell(p)
		roof[cell] = maxf(float(roof.get(cell, -INF)), p.y)
	# PER POINT, not globally. The first version of this accumulated ONE `under` (the highest hull anywhere near any
	# gun point) and subtracted it from ONE `lowest` (the gun's lowest point anywhere), which compares the bottom of
	# the gun against the top of the tanker's crown several metres away. On the War Rig that read -0.175 m ("sunk
	# 17 cm into the hull") for a gun the render showed hanging in clear air, because the crown is a narrow ridge and
	# the gun's low parts hang out where the cylinder has already curved away beneath them. A clearance is a local
	# quantity: each point against the hull under THAT point.
	var air := INF
	var at := Vector3.ZERO
	var under_at := 0.0
	var floating := 0
	var measured := 0
	# DIRECTLY beneath: the same CELL_M column, never a neighbourhood. Widening the search to +/- 3 cells (1.2 m)
	# was the second wrong version of this: on a cylinder it finds the tanker's CROWN 30 cm to the side of a point
	# that has nothing under it at all, so a gun sitting above a curved tank always reads as seated. On the War Rig
	# that held the answer at -0.148 m through three attempted fixes while the render showed daylight. A point with
	# nothing in its own column is not seated on anything -- it is the daylight, and it gets counted as such.
	for p in gun:
		var under := float(roof.get(_cell(p), -INF))
		if under == -INF:
			floating += 1  # nothing beneath it at all: hanging past the hull entirely
			continue
		measured += 1
		if p.y - under < air:
			air = p.y - under
			at = p
			under_at = under
	var total := maxi(measured + floating, 1)
	if measured == 0:
		return {"has_gun": true, "air": 0.0, "measured": 0, "floating": floating, "over_nothing": 1.0,
				"no_hull_under": true}
	return {"has_gun": true, "air": air, "lowest": at.y, "under": under_at, "at": at,
			"measured": measured, "floating": floating, "over_nothing": float(floating) / float(total)}


static func seat_gap(tank: Node3D) -> Dictionary:
	var parts := split(tank)
	var roof := {}
	for p: Vector3 in parts["hull"]:
		var cell := _cell(p)
		roof[cell] = maxf(float(roof.get(cell, -INF)), p.y)
	var lowest := INF
	var at := Vector3.ZERO
	var measured := 0
	for p in parts["turning"]:
		var under := -INF
		for dx in range(-REACH_CELLS, REACH_CELLS + 1):
			for dz in range(-REACH_CELLS, REACH_CELLS + 1):
				var near: float = float(roof.get(_cell(p) + Vector2i(dx, dz), -INF))
				under = maxf(under, near)
		if under == -INF:
			continue
		measured += 1
		if p.y - under < lowest:
			lowest = p.y - under
			at = p
	return {"points": parts["turning"].size(), "measured": measured,
			"gap": lowest if lowest < INF else 0.0, "at": at}


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
