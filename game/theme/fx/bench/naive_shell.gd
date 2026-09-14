extends Node3D
## The FX lab's "before" case for projectiles: what you'd write without the tricks. Every shell
## builds its own mesh, its own material, and carries its own OmniLight3D.


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1, 0.85, 0.35)
	var capsule := CapsuleMesh.new()
	capsule.radius = 0.12
	capsule.height = 0.9
	capsule.material = material
	var mesh := MeshInstance3D.new()
	mesh.mesh = capsule
	mesh.rotation.x = PI / 2.0
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.8, 0.4)
	light.light_energy = 2.5
	light.omni_range = 9.0
	add_child(light)
