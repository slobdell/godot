class_name OutriggerRig
extends RefCounted
## Artillery outriggers as rigid parts (assets X5): cuts the legs out of a generated hull mesh by region boxes, and
## poses them for a deploy ratio (combat's X5 `deployed` state, called on the hull slot as `set_deployed(ratio)`).
## No skeleton and no new art: the legs keep the model's own geometry and textures, and a stowed leg simply slides in
## under the chassis and lifts its jack. Visual only.

## How far a stowed leg slides in toward the chassis, and how high its jack lifts (meters, hull space).
const SLIDE := 0.45
const LIFT := 0.35

## Cut results by source mesh and boxes: WeakRef(rest mesh), which carries its legs as metadata, so every vehicle of a
## kind shares one cut and it's freed with the last one (a strong static cache leaks at exit).
static var _cache := {}


## Splits `mesh` into the rest and one mesh per leg. `boxes` are regions in fractions of the mesh's bounds (x 0 = -X …
## 1 = +X, y 0 = bottom … 1 = top, z 0 = -Z … 1 = +Z); a triangle whose centroid lies in a box belongs to a leg, and
## each box splits into a front (-Z) and a rear (+Z) leg. Returns {rest: ArrayMesh, legs: [{mesh, side: Vector2(±x, ±z)}]}.
static func cut(mesh: ArrayMesh, boxes: Array[AABB]) -> Dictionary:
	var key := "%d:%s" % [mesh.get_instance_id(), boxes]
	if _cache.has(key):
		var cached := (_cache[key] as WeakRef).get_ref() as ArrayMesh
		if cached != null:
			return {"rest": cached, "legs": cached.get_meta("legs")}
	var bounds := mesh.get_aabb()
	var rest := ArrayMesh.new()
	var buckets := {}  # side → ArrayMesh
	for surface in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			indices.resize(vertices.size())
			for i in vertices.size():
				indices[i] = i
		var groups := {}  # side (Vector2.ZERO = rest) → PackedInt32Array of source indices
		for t in indices.size() / 3:
			var centroid := (vertices[indices[t * 3]] + vertices[indices[t * 3 + 1]] + vertices[indices[t * 3 + 2]]) / 3.0
			var f := (centroid - bounds.position) / bounds.size
			var side := Vector2.ZERO
			for box in boxes:
				if box.has_point(f):
					side = Vector2(signf(f.x - 0.5), signf(f.z - 0.5))
					break
			var group: PackedInt32Array = groups.get(side, PackedInt32Array())
			group.append_array([indices[t * 3], indices[t * 3 + 1], indices[t * 3 + 2]])
			groups[side] = group
		for side: Vector2 in groups:
			var target: ArrayMesh = rest if side == Vector2.ZERO else buckets.get_or_add(side, ArrayMesh.new())
			target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, _subset(arrays, groups[side]))
			target.surface_set_material(target.get_surface_count() - 1, mesh.surface_get_material(surface))
	var legs := []
	for side: Vector2 in buckets:
		legs.append({"mesh": buckets[side], "side": side})
	legs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["side"] < b["side"])
	rest.set_meta("legs", legs)
	_cache[key] = weakref(rest)
	return {"rest": rest, "legs": legs}


## The leg's offset from its generated (deployed) pose: the first half of the ratio slides the beam out, the second
## lowers the jack.
static func offset(side: Vector2, ratio: float) -> Vector3:
	var out := smoothstep(0.0, 1.0, clampf(ratio * 2.0, 0.0, 1.0))
	var down := smoothstep(0.0, 1.0, clampf(ratio * 2.0 - 1.0, 0.0, 1.0))
	return Vector3(-side.x * SLIDE * (1.0 - out), LIFT * (1.0 - down), 0.0)


## The attribute arrays of `arrays` restricted to the vertices `indices` uses, reindexed.
static func _subset(arrays: Array, indices: PackedInt32Array) -> Array:
	var remap := {}
	var order := PackedInt32Array()
	var reindexed := PackedInt32Array()
	for index in indices:
		if not remap.has(index):
			remap[index] = order.size()
			order.append(index)
		reindexed.append(remap[index])
	var result := []
	result.resize(Mesh.ARRAY_MAX)
	for kind in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_COLOR, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var source: Variant = arrays[kind]
		if source == null:
			continue
		var per_vertex := 4 if kind == Mesh.ARRAY_TANGENT else 1
		var picked: Variant = source.duplicate()
		picked.resize(order.size() * per_vertex)
		for i in order.size():
			for k in per_vertex:
				picked[i * per_vertex + k] = source[order[i] * per_vertex + k]
		result[kind] = picked
	result[Mesh.ARRAY_INDEX] = reindexed
	return result
