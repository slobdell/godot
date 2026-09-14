class_name AssetNormalizer
extends RefCounted
## Fits an arbitrary model scene to a visual slot contract (AssetContracts):
##   1. keeps only the meshes you ask for (include/exclude name globs),
##   2. rotates source axes so forward is −Z and up is +Y,
##   3. scales (contain / stretch / length) and moves the origin to the slot's anchor,
##   4. bakes every transform into vertices and merges surfaces that share a material
##      (one draw call per material),
##   5. decimates to the triangle budget (Godot's meshoptimizer LODs),
##   6. caps texture size, turns off material features the Compatibility renderer lacks,
##      and optionally makes named materials emissive (neon strips from albedo).
## The result is one Node3D with one MeshInstance3D, ready for GLTFDocument export.
## Emission settings and textures on source materials are carried through untouched.

## Source axis names → vectors. glTF's convention is +Y up, models facing +Z.
## Surfaces this small are decimated only if nothing else is left to reduce.
const SMALL_SURFACE_TRIS := 64

const AXES := {
	"+x": Vector3.RIGHT, "-x": Vector3.LEFT, "+y": Vector3.UP, "-y": Vector3.DOWN,
	"+z": Vector3.BACK, "-z": Vector3.FORWARD,
}


## options:
##   forward ("+z")  the source model's forward axis     up ("+y")  the source model's up axis
##   include []      node-name globs to keep (any ancestor may match)     exclude []  globs to drop
##   scale (0)       fixed uniform scale instead of the slot's fit (keep a hull and turret consistent)
##   emissive {}     material-name glob → energy: emission = albedo color/texture (neon from paint)
##   tris (0)        override the slot's triangle budget
##   repeat (1,1,1)  tile the selection N×M×K times along x/y/z before fitting (a wall from barrier segments)
##   emission_maps {} material-name glob → Texture2D: an emission map delivered beside the GLB (Meshy PBR)
## Returns {scene: Node3D, notes: PackedStringArray, scale: Vector3, source: report}.
static func normalize(source: Node, slot: String, options: Dictionary = {}) -> Dictionary:
	var contract := AssetContracts.get_contract(slot)
	var notes := PackedStringArray()
	if contract.is_empty():
		notes.append("unknown slot '%s'" % slot)
		return {"scene": null, "notes": notes}
	var orient := orientation_basis(options.get("forward", "+z"), options.get("up", "+y"))
	var parts := []  # [MeshInstance3D, oriented transform]
	for entry in AssetInspector.mesh_instances(source):
		if _selected(entry[0], source, options.get("include", []), options.get("exclude", [])):
			parts.append([entry[0], Transform3D(orient, Vector3.ZERO) * (entry[1] as Transform3D)])
	if parts.is_empty():
		notes.append("no meshes selected")
		return {"scene": null, "notes": notes}

	var repeat: Vector3i = options.get("repeat", Vector3i.ONE)
	if repeat != Vector3i.ONE:
		parts = _tile(parts, repeat)
		notes.append("tiled the model %d × %d × %d" % [repeat.x, repeat.y, repeat.z])
	var oriented := _bounds(parts)
	var fit := _fit_transform(oriented, contract, float(options.get("scale", 0.0)), notes)
	var groups := _merge_by_material(parts, fit["transform"], notes)
	var budget := int(options.get("tris", 0)) if int(options.get("tris", 0)) > 0 else int(contract["tris"])
	var mesh := _build_mesh(groups, budget, notes)
	_prepare_materials(mesh, int(contract["textures"]), options.get("emissive", {}), notes, options.get("emission_maps", {}))

	var root := Node3D.new()
	root.name = String(contract["file"]).to_pascal_case()
	var instance := MeshInstance3D.new()
	instance.name = "Mesh"
	instance.mesh = mesh
	root.add_child(instance)
	instance.owner = root
	return {"scene": root, "notes": notes, "scale": fit["scale"]}


## Rotation taking the source's forward/up axes to Godot's −Z/+Y.
static func orientation_basis(forward: String, up: String) -> Basis:
	var f: Vector3 = AXES.get(forward, Vector3.BACK)
	var u: Vector3 = AXES.get(up, Vector3.UP)
	if absf(f.dot(u)) > 0.5:
		push_error("forward (%s) and up (%s) must be different axes" % [forward, up])
		return Basis()
	var right := f.cross(u)
	# Columns map Godot's X/Y/Z onto the source axes; the inverse maps source into Godot.
	return Basis(right, u, -f).transposed()


static func _selected(instance: Node, root: Node, include: Array, exclude: Array) -> bool:
	var names := PackedStringArray()
	var node := instance
	while node != null and node != root:
		names.append(String(node.name).to_lower())
		node = node.get_parent()
	var matches := func(globs: Array) -> bool:
		for glob in globs:
			for node_name in names:
				if node_name.matchn(String(glob)):
					return true
		return false
	if not include.is_empty() and not matches.call(include):
		return false
	return not matches.call(exclude)


static func _tile(parts: Array, repeat: Vector3i) -> Array:
	var step := _bounds(parts).size
	var tiled := []
	for i in maxi(repeat.x, 1):
		for j in maxi(repeat.y, 1):
			for k in maxi(repeat.z, 1):
				var offset := Transform3D(Basis(), Vector3(step.x * i, step.y * j, step.z * k))
				for part in parts:
					tiled.append([part[0], offset * (part[1] as Transform3D)])
	return tiled


static func _bounds(parts: Array) -> AABB:
	var aabb := AABB()
	var first := true
	for part in parts:
		var mesh: Mesh = (part[0] as MeshInstance3D).mesh
		if mesh == null:
			continue
		for surface in mesh.get_surface_count():
			for vertex in mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = part[1] * vertex
				aabb = AABB(point, Vector3.ZERO) if first else aabb.expand(point)
				first = false
	return aabb


static func _fit_transform(bounds: AABB, contract: Dictionary, fixed_scale: float, notes: PackedStringArray) -> Dictionary:
	var size := bounds.size
	var safe := Vector3(maxf(size.x, 1e-6), maxf(size.y, 1e-6), maxf(size.z, 1e-6))
	var guide: Vector3 = contract["guide"]
	var max_size: Vector3 = contract["max"]
	var scale := Vector3.ONE
	match String(contract["fit"]):
		"contain":
			var s := minf(minf(max_size.x / safe.x, max_size.y / safe.y), max_size.z / safe.z)
			scale = Vector3(s, s, s)
		"stretch":
			scale = guide / safe
			var distortion := maxf(maxf(scale.x, scale.y), scale.z) / minf(minf(scale.x, scale.y), scale.z)
			if distortion > 2.0:
				notes.append("stretched %.1f× out of proportion to fit the collision box" % distortion)
		"length":
			var s := guide.z / safe.z
			s = minf(s, minf(max_size.x / safe.x, max_size.y / safe.y))
			scale = Vector3(s, s, s)
	if fixed_scale > 0.0:
		scale = Vector3(fixed_scale, fixed_scale, fixed_scale)
	var scaled := AABB(bounds.position * scale, bounds.size * scale)
	var center := scaled.get_center()
	var offset := Vector3.ZERO
	match String(contract["anchor"]):
		"ground_center":
			offset = Vector3(-center.x, -scaled.position.y, -center.z)
		"center":
			offset = -center
		"turret":
			offset = Vector3(-center.x, float(contract["turret_bottom"]) - scaled.position.y, -center.z)
		"barrel":
			offset = Vector3(-center.x, float(contract["barrel_y"]) - center.y,
					float(contract["barrel_back"]) - scaled.end.z)
	return {"transform": Transform3D(Basis.from_scale(scale), offset), "scale": scale}


## Bakes transforms and concatenates surfaces per material. Returns [{material, arrays}].
static func _merge_by_material(parts: Array, fit: Transform3D, notes: PackedStringArray) -> Array:
	var groups := {}  # material (or "none") → {material, vertex, normal, tangent, color, uv, uv2, index}
	var order := []
	for part in parts:
		var instance: MeshInstance3D = part[0]
		var mesh := instance.mesh
		if mesh == null:
			continue
		var xform: Transform3D = fit * (part[1] as Transform3D)
		var normal_basis := xform.basis.inverse().transposed()
		var mirrored := xform.basis.determinant() < 0.0
		for surface in mesh.get_surface_count():
			if mesh is ArrayMesh and (mesh as ArrayMesh).surface_get_primitive_type(surface) != Mesh.PRIMITIVE_TRIANGLES:
				notes.append("skipped a non-triangle surface in %s" % instance.name)
				continue
			var material := instance.get_surface_override_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			var key: Variant = material if material != null else "none"
			if not groups.has(key):
				groups[key] = {"material": material, "vertex": PackedVector3Array(), "normal": PackedVector3Array(),
						"tangent": PackedFloat32Array(), "color": PackedColorArray(), "uv": PackedVector2Array(),
						"uv2": PackedVector2Array(), "index": PackedInt32Array(),
						"has_tangent": false, "has_color": false, "has_uv": false, "has_uv2": false}
				order.append(key)
			_append_surface(groups[key], mesh.surface_get_arrays(surface), xform, normal_basis, mirrored)
	var merged := []
	for key in order:
		merged.append(groups[key])
	return merged


static func _append_surface(group: Dictionary, arrays: Array, xform: Transform3D, normal_basis: Basis, mirrored: bool) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var count := vertices.size()
	var base: int = group["vertex"].size()
	for vertex in vertices:
		group["vertex"].append(xform * vertex)
	var normals = arrays[Mesh.ARRAY_NORMAL]
	for i in count:
		group["normal"].append((normal_basis * normals[i]).normalized() if normals != null and normals.size() == count else Vector3.UP)
	var tangents = arrays[Mesh.ARRAY_TANGENT]
	var has_tangents: bool = tangents != null and tangents.size() == count * 4
	group["has_tangent"] = group["has_tangent"] or has_tangents
	for i in count:
		if has_tangents:
			var t := (xform.basis * Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])).normalized()
			group["tangent"].append_array([t.x, t.y, t.z, -tangents[i * 4 + 3] if mirrored else tangents[i * 4 + 3]])
		else:
			group["tangent"].append_array([1.0, 0.0, 0.0, 1.0])
	_append_optional(group, "color", "has_color", arrays[Mesh.ARRAY_COLOR], count, Color.WHITE)
	_append_optional(group, "uv", "has_uv", arrays[Mesh.ARRAY_TEX_UV], count, Vector2.ZERO)
	_append_optional(group, "uv2", "has_uv2", arrays[Mesh.ARRAY_TEX_UV2], count, Vector2.ZERO)
	var indices = arrays[Mesh.ARRAY_INDEX]
	if indices == null or indices.size() == 0:
		indices = PackedInt32Array(range(count))
	for tri in range(0, indices.size() - 2, 3):
		if mirrored:  # a mirrored transform flips winding; swap to keep faces pointing out
			group["index"].append_array([base + indices[tri], base + indices[tri + 2], base + indices[tri + 1]])
		else:
			group["index"].append_array([base + indices[tri], base + indices[tri + 1], base + indices[tri + 2]])


static func _append_optional(group: Dictionary, key: String, flag: String, source, count: int, fallback) -> void:
	if source != null and source.size() == count:
		group[flag] = true
		group[key].append_array(source)
	else:
		for i in count:
			group[key].append(fallback)


static func _group_arrays(group: Dictionary) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = group["vertex"]
	arrays[Mesh.ARRAY_NORMAL] = group["normal"]
	if group["has_tangent"]:
		arrays[Mesh.ARRAY_TANGENT] = group["tangent"]
	if group["has_color"]:
		arrays[Mesh.ARRAY_COLOR] = group["color"]
	if group["has_uv"]:
		arrays[Mesh.ARRAY_TEX_UV] = group["uv"]
	if group["has_uv2"]:
		arrays[Mesh.ARRAY_TEX_UV2] = group["uv2"]
	arrays[Mesh.ARRAY_INDEX] = group["index"]
	return arrays


static func _build_mesh(groups: Array, budget: int, notes: PackedStringArray) -> ArrayMesh:
	var total := 0
	for group in groups:
		total += group["index"].size() / 3
	var importer := ImporterMesh.new()
	for group in groups:
		var material: Material = group["material"]
		importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, _group_arrays(group), [], {}, material,
				material.resource_name if material != null else "")
	var mesh := ArrayMesh.new()
	if total <= budget:
		for surface in importer.get_surface_count():
			_commit(mesh, importer, surface, importer.get_surface_arrays(surface))
		return mesh
	# Over budget: generate meshoptimizer LODs, then step down the LOD of the surface with the most
	# triangles until the model fits. Small surfaces (signs, decals, neon strips) are only touched as
	# a last resort, because one LOD step collapses a 2-triangle quad into its frame.
	importer.generate_lods(25.0, 60.0, [])
	var count := importer.get_surface_count()
	var levels := []
	var protected := []
	for surface in count:
		levels.append(-1)
		protected.append(_lod_indices(importer, surface, -1).size() / 3 <= maxi(SMALL_SURFACE_TRIS, int(total * 0.1)))
	var current := total
	while current > budget:
		var pick := -1
		var pick_tris := 0
		for pass_protected in [false, true]:
			for surface in count:
				if protected[surface] != pass_protected or levels[surface] + 1 >= importer.get_surface_lod_count(surface):
					continue
				var tris := _lod_indices(importer, surface, levels[surface]).size() / 3
				if tris > pick_tris:
					pick = surface
					pick_tris = tris
			if pick >= 0:
				break
		if pick < 0:
			break
		levels[pick] += 1
		current += _lod_indices(importer, pick, levels[pick]).size() / 3 - pick_tris
	for surface in count:
		var arrays := importer.get_surface_arrays(surface)
		arrays[Mesh.ARRAY_INDEX] = _lod_indices(importer, surface, levels[surface])
		_commit(mesh, importer, surface, arrays)
	notes.append("decimated %d → %d triangles (budget %d)" % [total, current, budget])
	if current > budget:
		notes.append("still over budget after the coarsest LOD")
	return mesh


static func _lod_indices(importer: ImporterMesh, surface: int, level: int) -> PackedInt32Array:
	var count := importer.get_surface_lod_count(surface)
	if level < 0 or count == 0:
		return importer.get_surface_arrays(surface)[Mesh.ARRAY_INDEX]
	return importer.get_surface_lod_indices(surface, mini(level, count - 1))


static func _commit(mesh: ArrayMesh, importer: ImporterMesh, surface: int, arrays: Array) -> void:
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var index := mesh.get_surface_count() - 1
	mesh.surface_set_material(index, importer.get_surface_material(surface))
	mesh.surface_set_name(index, importer.get_surface_name(surface))


## Copies each material, caps its textures, strips unsupported features, applies emissive rules.
static func _prepare_materials(mesh: ArrayMesh, max_texture: int, emissive: Dictionary, notes: PackedStringArray,
		emission_maps: Dictionary = {}) -> void:
	var resized := {}
	for surface in mesh.get_surface_count():
		var source := mesh.surface_get_material(surface)
		if source == null:
			var fallback := StandardMaterial3D.new()
			fallback.resource_name = "default"
			mesh.surface_set_material(surface, fallback)
			continue
		var material := source.duplicate() as Material
		if material is BaseMaterial3D:
			var base := material as BaseMaterial3D
			for glob in emission_maps:
				if base.resource_name.matchn(String(glob)):
					base.emission_enabled = true
					base.emission = Color.WHITE
					base.emission_texture = emission_maps[glob]
					notes.append("material '%s' uses the supplied emission map" % base.resource_name)
			for property in AssetInspector.TEXTURE_PROPERTIES:
				var texture := base.get(property) as Texture2D
				if texture != null and maxi(texture.get_width(), texture.get_height()) > max_texture:
					if not resized.has(texture):
						resized[texture] = _shrink(texture, max_texture)
						notes.append("texture %s %d×%d → %d×%d" % [property, texture.get_width(), texture.get_height(),
								resized[texture].get_width(), resized[texture].get_height()])
					base.set(property, resized[texture])
			for feature in ["subsurf_scatter_enabled", "refraction_enabled", "clearcoat_enabled", "anisotropy_enabled"]:
				if base.get(feature):
					base.set(feature, false)
					notes.append("material '%s': turned off %s (Compatibility renderer)" % [base.resource_name, feature])
			for glob in emissive:
				if base.resource_name.matchn(String(glob)):
					base.emission_enabled = true
					base.emission = base.albedo_color
					base.emission_texture = base.albedo_texture
					base.emission_energy_multiplier = float(emissive[glob])
					notes.append("material '%s' made emissive ×%.1f" % [base.resource_name, float(emissive[glob])])
		mesh.surface_set_material(surface, material)


static func _shrink(texture: Texture2D, max_edge: int) -> ImageTexture:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	var factor := float(max_edge) / maxi(image.get_width(), image.get_height())
	image.resize(maxi(1, int(image.get_width() * factor)), maxi(1, int(image.get_height() * factor)), Image.INTERPOLATE_LANCZOS)
	var result := ImageTexture.create_from_image(image)
	result.resource_name = texture.resource_name
	return result
