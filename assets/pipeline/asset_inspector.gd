class_name AssetInspector
extends RefCounted
## Measures a model scene (not in the tree): bounds, triangles, surfaces, materials, textures,
## emissive use, and things that don't belong in a visual (collision, lights, cameras, skeletons).
## Transforms are accumulated by hand, so this works on scenes fresh out of GLTFDocument.

## Texture properties on BaseMaterial3D worth measuring.
const TEXTURE_PROPERTIES := ["albedo_texture", "normal_texture", "orm_texture", "roughness_texture",
		"metallic_texture", "emission_texture", "ao_texture", "heightmap_texture",
		"detail_albedo", "detail_normal"]


## Returns {aabb, tris, surfaces, meshes, materials: [{name, emissive, textures: [[prop, w, h]]}],
## texture_bytes, emissive, extras: [node descriptions that aren't meshes]}.
static func inspect(root: Node) -> Dictionary:
	var report := {
		"aabb": AABB(), "tris": 0, "surfaces": 0, "meshes": 0, "materials": [],
		"texture_bytes": 0, "emissive": false, "extras": [],
	}
	var seen_materials := {}
	var seen_textures := {}
	var first := true
	for entry in mesh_instances(root):
		var instance: MeshInstance3D = entry[0]
		var xform: Transform3D = entry[1]
		var mesh := instance.mesh
		if mesh == null:
			continue
		report["meshes"] += 1
		for surface in mesh.get_surface_count():
			report["surfaces"] += 1
			var arrays := mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			report["tris"] += (indices.size() if indices.size() > 0 else vertices.size()) / 3
			for vertex in vertices:
				var point := xform * vertex
				if first:
					report["aabb"] = AABB(point, Vector3.ZERO)
					first = false
				else:
					report["aabb"] = (report["aabb"] as AABB).expand(point)
			var material := instance.get_surface_override_material(surface)
			if material == null:
				material = mesh.surface_get_material(surface)
			if material == null or seen_materials.has(material):
				continue
			seen_materials[material] = true
			report["materials"].append(_describe_material(material, seen_textures, report))
	for node in _all_nodes(root):
		if node is CollisionObject3D or node is CollisionShape3D:
			report["extras"].append("collision: %s" % node.name)
		elif node is Light3D:
			report["extras"].append("light: %s" % node.name)
		elif node is Camera3D:
			report["extras"].append("camera: %s" % node.name)
		elif node is Skeleton3D:
			report["extras"].append("skeleton: %s" % node.name)
		elif node is AnimationPlayer:
			report["extras"].append("animation: %s" % node.name)
	return report


## Replaces every skinned mesh with a static copy posed at the skeleton's rest pose, so bounds,
## normalization, and export see where the parts actually render. (Visual slots don't play
## skeletal animation; tread animations in packs are dropped.) Returns how many were baked.
static func bake_skins(root: Node) -> int:
	var baked := 0
	var transforms := {}
	for entry in mesh_instances(root):
		transforms[entry[0]] = entry[1]
	for entry in mesh_instances(root):
		var instance: MeshInstance3D = entry[0]
		var skeleton := instance.get_node_or_null(instance.skeleton) as Skeleton3D
		if instance.skin == null or skeleton == null or instance.mesh == null:
			continue
		var skeleton_xform := _transform_to(root, skeleton)
		# Skinned vertices land in skeleton space; express them in the instance's own space.
		var to_local: Transform3D = (entry[1] as Transform3D).affine_inverse() * skeleton_xform
		var bind_poses := []
		for bind in instance.skin.get_bind_count():
			var bone := instance.skin.get_bind_bone(bind)
			if bone < 0:
				bone = skeleton.find_bone(instance.skin.get_bind_name(bind))
			var bone_rest := skeleton.get_bone_global_rest(bone) if bone >= 0 else Transform3D.IDENTITY
			bind_poses.append(to_local * bone_rest * instance.skin.get_bind_pose(bind))
		var static_mesh := ArrayMesh.new()
		for surface in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			_skin_arrays(arrays, bind_poses)
			static_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			static_mesh.surface_set_material(surface, instance.mesh.surface_get_material(surface))
			static_mesh.surface_set_name(surface, (instance.mesh as ArrayMesh).surface_get_name(surface) if instance.mesh is ArrayMesh else "")
		instance.mesh = static_mesh
		instance.skin = null
		instance.skeleton = NodePath()
		baked += 1
	return baked


static func _skin_arrays(arrays: Array, bind_poses: Array) -> void:
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals = arrays[Mesh.ARRAY_NORMAL]
	var bones = arrays[Mesh.ARRAY_BONES]
	var weights = arrays[Mesh.ARRAY_WEIGHTS]
	if bones == null or weights == null or vertices.size() == 0:
		return
	var per_vertex: int = bones.size() / vertices.size()
	for i in vertices.size():
		var position := Vector3.ZERO
		var normal := Vector3.ZERO
		var total := 0.0
		for k in per_vertex:
			var weight: float = weights[i * per_vertex + k]
			var bind: int = bones[i * per_vertex + k]
			if weight <= 0.0 or bind >= bind_poses.size():
				continue
			var pose: Transform3D = bind_poses[bind]
			position += (pose * vertices[i]) * weight
			if normals != null:
				normal += (pose.basis * normals[i]) * weight
			total += weight
		if total > 0.0:
			vertices[i] = position / total
			if normals != null:
				normals[i] = normal.normalized()
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_BONES] = null
	arrays[Mesh.ARRAY_WEIGHTS] = null
	arrays[Mesh.ARRAY_TANGENT] = null


static func _transform_to(root: Node, node: Node) -> Transform3D:
	var xform := Transform3D.IDENTITY
	while node != null and node != root:
		if node is Node3D:
			xform = (node as Node3D).transform * xform
		node = node.get_parent()
	return xform


## [[MeshInstance3D, transform relative to root], ...] for every mesh under root (root included).
static func mesh_instances(root: Node) -> Array:
	var found := []
	_collect(root, Transform3D.IDENTITY, found, true)
	return found


static func summary(report: Dictionary) -> String:
	var aabb: AABB = report["aabb"]
	var lines := PackedStringArray()
	lines.append("size (w×h×l): %.2f × %.2f × %.2f m" % [aabb.size.x, aabb.size.y, aabb.size.z])
	lines.append("bounds: min %s  max %s" % [_v(aabb.position), _v(aabb.end)])
	lines.append("triangles: %d in %d surfaces / %d meshes" % [report["tris"], report["surfaces"], report["meshes"]])
	lines.append("texture memory: %.1f KB uncompressed (with mipmaps)" % (report["texture_bytes"] / 1024.0))
	for material in report["materials"]:
		var textures := PackedStringArray()
		for texture in material["textures"]:
			textures.append("%s %d×%d" % texture)
		lines.append("material '%s'%s%s" % [material["name"], " EMISSIVE" if material["emissive"] else "",
				(": " + ", ".join(textures)) if textures.size() > 0 else ""])
	for extra in report["extras"]:
		lines.append("extra node: %s" % extra)
	return "\n".join(lines)


static func _describe_material(material: Material, seen_textures: Dictionary, report: Dictionary) -> Dictionary:
	var description := {"name": material.resource_name, "emissive": false, "textures": [],
			"type": material.get_class()}
	if material is BaseMaterial3D:
		var base := material as BaseMaterial3D
		description["emissive"] = base.emission_enabled and (base.emission.get_luminance() > 0.0 or base.emission_texture != null)
		for property in TEXTURE_PROPERTIES:
			var texture := base.get(property) as Texture2D
			if texture == null:
				continue
			description["textures"].append([property, texture.get_width(), texture.get_height()])
			if not seen_textures.has(texture):
				seen_textures[texture] = true
				# RGBA8 with a full mip chain is ~4/3 of the base level.
				report["texture_bytes"] += int(texture.get_width() * texture.get_height() * 4 * 4.0 / 3.0)
	report["emissive"] = report["emissive"] or description["emissive"]
	return description


static func _collect(node: Node, parent_xform: Transform3D, found: Array, is_root: bool) -> void:
	var xform := parent_xform
	if node is Node3D and not is_root:
		xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		found.append([node, xform])
	for child in node.get_children():
		_collect(child, xform, found, false)


static func _all_nodes(root: Node) -> Array:
	var nodes := [root]
	var index := 0
	while index < nodes.size():
		nodes.append_array(nodes[index].get_children())
		index += 1
	return nodes


static func _v(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]
