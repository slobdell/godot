class_name StaticInstancer
extends RefCounted
## Turns repeated static models into one MultiMesh per mesh (render X5, round 5). StaticBatcher merges the small parts
## of ONE prop into one mesh; this is for the same big model placed many times (20 grandstand modules, 4 floodlight
## towers, 2 gates): the Compatibility renderer draws each MeshInstance3D separately, so 20 stands were 20 draws.
## Only meshes without per-instance material overrides and with at least `min_count` copies are instanced; the
## originals are hidden (their nodes stay, so anything that reads bounds or transforms still can).

## Replace repeated MeshInstance3Ds under `root` with MultiMeshInstance3Ds added to `root`. Returns the draws removed.
static func instance_repeats(root: Node3D, min_count := 2) -> int:
	var groups := {}  # Mesh -> Array[MeshInstance3D]
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance.material_override != null:
			continue
		var overridden := false
		for surface in instance.mesh.get_surface_count():
			if instance.get_surface_override_material(surface) != null:
				overridden = true
				break
		if overridden:
			continue
		(groups.get_or_add(instance.mesh, []) as Array).append(instance)
	var removed := 0
	for mesh: Mesh in groups:
		var copies: Array = groups[mesh]
		if copies.size() < min_count:
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = mesh
		FxMultiMesh.resize(multimesh, copies.size())
		var draw := MultiMeshInstance3D.new()
		draw.name = "Instanced_%s" % (mesh.resource_name if mesh.resource_name != "" else str(removed))
		draw.multimesh = multimesh
		FxMultiMesh.never_interpolated(draw)
		draw.cast_shadow = (copies[0] as MeshInstance3D).cast_shadow
		var bounds := AABB()
		var placed: Array[Transform3D] = []
		for i in copies.size():
			var copy := copies[i] as MeshInstance3D
			var xform := StaticInstancer.relative_transform(copy, root)
			multimesh.set_instance_transform(i, xform)
			placed.append(xform)
			var box := xform * mesh.get_aabb()
			bounds = box if i == 0 else bounds.merge(box)
			copy.visible = false
		draw.custom_aabb = bounds
		# Headless renderers drop MultiMesh instance data; tests and tools read the placements here.
		draw.set_meta("transforms", placed)
		root.add_child(draw)
		removed += copies.size() - 1
	return removed


## `node`'s transform in `root`'s space from the parent chain (works before either is in the tree).
static func relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var result := Transform3D.IDENTITY
	var current: Node = node
	while current != null and current != root:
		if current is Node3D:
			result = (current as Node3D).transform * result
		current = current.get_parent()
	return result
