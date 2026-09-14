class_name AssetSplitter
extends RefCounted
## Splits a whole generated unit (one mesh, as AI generators deliver it) into the parts gameplay
## animates separately. Meshy's Smart Topology models are single meshes made of many disconnected
## islands (plates, wheels, barrel, turret), so:
##   1. split_islands(): each connected island becomes its own MeshInstance3D;
##   2. label_tank():   islands are renamed hull_N / turret_N / cannon_N by geometry, so the normal
##                      --include / --exclude globs pick a slot's parts.
## Tank labelling, in the Godot frame (forward −Z, up +Y) after the source axis remap:
##   hull body  = the island with the largest bounding volume; its top is the deck
##   cannon     = the most elongated island along the forward axis, at least 25% of the unit's length,
##                sitting on or above the deck
##   turret     = the largest island on the deck (not the cannon), plus every deck-level island inside its
##                footprint that touches it or the cannon's breech (mantlet, cupola, hatches)
##   hull       = everything else (treads, wheels, plates, exhausts, ram)

## Vertices closer than this (in source units, relative to model size) are the same point when welding.
const WELD_FRACTION := 0.0005


## Replaces every mesh with one child per connected island. Returns the island count.
static func split_islands(root: Node) -> int:
	var count := 0
	for entry in AssetInspector.mesh_instances(root):
		var instance: MeshInstance3D = entry[0]
		if instance.mesh == null:
			continue
		var holder := Node3D.new()
		holder.name = instance.name
		holder.transform = instance.transform
		var pieces := 0
		for surface in instance.mesh.get_surface_count():
			var material := instance.get_surface_override_material(surface)
			if material == null:
				material = instance.mesh.surface_get_material(surface)
			for arrays in _islands(instance.mesh.surface_get_arrays(surface), instance.mesh.get_aabb().size.length()):
				var mesh := ArrayMesh.new()
				mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
				mesh.surface_set_material(0, material)
				var piece := MeshInstance3D.new()
				piece.name = "island_%d" % pieces
				piece.mesh = mesh
				holder.add_child(piece)
				pieces += 1
		instance.replace_by(holder)
		instance.free()
		count += pieces
	return count


## Renames islands hull_N / turret_N / cannon_N. Returns {hull, turret, cannon} island counts.
static func label_tank(root: Node, forward: String, up: String) -> Dictionary:
	var orient := Transform3D(AssetNormalizer.orientation_basis(forward, up), Vector3.ZERO)
	var parts := []  # {node, aabb (Godot frame)}
	var whole := AABB()
	for entry in AssetInspector.mesh_instances(root):
		var holder := Node3D.new()
		var copy := MeshInstance3D.new()
		copy.mesh = (entry[0] as MeshInstance3D).mesh
		copy.transform = orient * (entry[1] as Transform3D)
		holder.add_child(copy)
		var aabb: AABB = AssetInspector.inspect(holder)["aabb"]
		holder.free()
		parts.append({"node": entry[0], "aabb": aabb})
		whole = aabb if whole.size == Vector3.ZERO else whole.merge(aabb)
	if parts.size() < 3:
		return {"hull": parts.size(), "turret": 0, "cannon": 0}

	var body: Dictionary = parts[0]
	for part in parts:
		if _volume(part["aabb"]) > _volume(body["aabb"]):
			body = part
	var tolerance := whole.size.y * 0.04
	var deck: float = (body["aabb"] as AABB).end.y
	var on_deck := func(part: Dictionary) -> bool:
		return part != body and (part["aabb"] as AABB).position.y >= deck - tolerance

	var cannon := {}
	var best := 0.0
	for part in parts:
		var size: Vector3 = (part["aabb"] as AABB).size
		var elongation := size.z / maxf(maxf(size.x, size.y), 1e-6)
		if size.z >= whole.size.z * 0.25 and on_deck.call(part) and elongation > best:
			best = elongation
			cannon = part

	var seed := {}
	for part in parts:
		if part != cannon and on_deck.call(part) and (seed.is_empty() or _volume(part["aabb"]) > _volume(seed["aabb"])):
			seed = part
	var turret := []
	if not seed.is_empty():
		turret.append(seed)
		var reach := whole.size.length() * 0.01
		# Growth stays inside the turret's own footprint: touching-chains of roof rivets and spikes must not
		# walk the "turret" along the whole hull roof (seen on the first Meshy dozer).
		var footprint := (seed["aabb"] as AABB).grow(maxf((seed["aabb"] as AABB).size.x, (seed["aabb"] as AABB).size.z) * 0.2)
		var grown := true
		while grown:  # grow the turret through touching deck-level islands (mantlet, cupola, hatches)
			grown = false
			for part in parts:
				if part == cannon or turret.has(part) or not on_deck.call(part):
					continue
				var center := (part["aabb"] as AABB).get_center()
				if center.y < (seed["aabb"] as AABB).position.y + (seed["aabb"] as AABB).size.y * 0.25:
					continue  # flat on the deck (rivets, straps) even if it passes under the turret
				if center.x < footprint.position.x or center.x > footprint.end.x or center.z < footprint.position.z or center.z > footprint.end.z:
					continue
				for member in turret + ([cannon] if not cannon.is_empty() else []):
					if (part["aabb"] as AABB).grow(reach).intersects(member["aabb"]):
						turret.append(part)
						grown = true
						break

	var counts := {"hull": 0, "turret": 0, "cannon": 0}
	for part in parts:
		var label := "cannon" if part == cannon else ("turret" if turret.has(part) else "hull")
		(part["node"] as Node).name = "%s_%d" % [label, counts[label]]
		counts[label] += 1
	return counts


static func _volume(aabb: AABB) -> float:
	return aabb.size.x * aabb.size.y * aabb.size.z


## Connected components of one surface (triangles sharing welded vertex positions), compacted.
static func _islands(arrays: Array, model_size: float) -> Array:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array(range(vertices.size()))
	var cell := maxf(model_size * WELD_FRACTION, 1e-6)
	var welded := {}
	var point := PackedInt32Array()
	point.resize(vertices.size())
	for i in vertices.size():
		var key := Vector3i((vertices[i] / cell).round())
		if not welded.has(key):
			welded[key] = welded.size()
		point[i] = welded[key]
	var parent := PackedInt32Array()
	parent.resize(welded.size())
	for i in parent.size():
		parent[i] = i
	for tri in range(0, indices.size() - 2, 3):
		var a := _root(parent, point[indices[tri]])
		for k in [1, 2]:
			var b := _root(parent, point[indices[tri + k]])
			if a != b:
				parent[b] = a
	var groups := {}  # root → PackedInt32Array of triangle start offsets
	var order := []
	for tri in range(0, indices.size() - 2, 3):
		var group := _root(parent, point[indices[tri]])
		if not groups.has(group):
			groups[group] = PackedInt32Array()
			order.append(group)
		groups[group].append(tri)
	var result := []
	for group in order:
		var sub := arrays.duplicate()
		var sub_indices := PackedInt32Array()
		for tri in groups[group]:
			sub_indices.append_array([indices[tri], indices[tri + 1], indices[tri + 2]])
		sub[Mesh.ARRAY_INDEX] = sub_indices
		for channel in [Mesh.ARRAY_BONES, Mesh.ARRAY_WEIGHTS]:
			sub[channel] = null
		result.append(AssetNormalizer._compact(sub))
	return result


static func _root(parent: PackedInt32Array, node: int) -> int:
	while parent[node] != node:
		node = parent[node]
	return node
