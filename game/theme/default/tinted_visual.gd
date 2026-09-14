extends Node3D
## Default-theme visual: recolors its meshes marked for tinting. Materials are shared by every
## instance of a scene, so each tinted mesh gets its own copy.

## Meshes to tint (others, like treads, keep their material).
@export var tinted: Array[NodePath] = []
## Lighten the team color by this much (turrets read slightly lighter than hulls).
@export var lighten := 0.0


func set_team_color(color: Color) -> void:
	for path in tinted:
		var mesh_instance := get_node_or_null(path) as MeshInstance3D
		if mesh_instance == null:
			continue
		var material := mesh_instance.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = color.lightened(lighten)
		mesh_instance.material_override = material
