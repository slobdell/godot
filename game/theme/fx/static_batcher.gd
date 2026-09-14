class_name StaticBatcher
extends RefCounted
## Merges a static prop's many small MeshInstance3Ds into one mesh with one surface per material.
## The Compatibility renderer doesn't batch 3D draws, so a wall built from 23 boxes costs 23 draw
## calls (twice with shadows); merged it costs one per material. Use for anything that never
## moves relative to its root: props, perimeter segments, towers.

## The FX lab turns this off to measure what merging saves.
static var enabled := true


## Replace every MeshInstance3D under `root` (recursively) with merged meshes: one MeshInstance3D
## per shadow setting, one surface per material. Returns how many draw sources it removed.
static func merge(root: Node3D) -> int:
	if not enabled:
		return 0
	var groups := {}  # [cast_shadow] -> {material: SurfaceTool}
	var sources: Array[MeshInstance3D] = []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null or not instance.visible:
			continue
		sources.append(instance)
		var xform := _relative_transform(instance, root)
		for surface in instance.mesh.get_surface_count():
			var material := instance.material_override if instance.material_override != null \
					else instance.get_surface_override_material(surface)
			if material == null:
				material = instance.mesh.surface_get_material(surface)
			var by_material: Dictionary = groups.get_or_add(instance.cast_shadow, {})
			if not by_material.has(material):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_material[material] = tool
			(by_material[material] as SurfaceTool).append_from(instance.mesh, surface, xform)
	if sources.size() <= 1:
		return 0
	for instance in sources:
		instance.get_parent().remove_child(instance)
		instance.queue_free()
	for shadow in groups:
		var mesh := ArrayMesh.new()
		for material in groups[shadow]:
			(groups[shadow][material] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, material)
		var merged := MeshInstance3D.new()
		merged.name = "Merged"
		merged.mesh = mesh
		merged.cast_shadow = shadow
		root.add_child(merged)
	return sources.size()


static func _relative_transform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := node.transform
	var parent := node.get_parent()
	while parent != null and parent != root:
		if parent is Node3D:
			xform = (parent as Node3D).transform * xform
		parent = parent.get_parent()
	return xform
