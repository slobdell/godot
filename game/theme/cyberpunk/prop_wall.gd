extends Node3D
## `prop.wall` (18 long on X × 3 tall × 1.5 thick, ground center): a blast barrier. Concrete
## segments with a steel rim, cyan light bars on both faces, hazard chevrons at the ends, and a
## holographic ad floating above (visual only, above the collision box).


func _ready() -> void:
	var concrete := CyberMaterials.surface(Color(0.1, 0.1, 0.11), 0.75, 0.05)
	var steel := CyberMaterials.surface(Color(0.14, 0.12, 0.11), 0.4, 0.7)
	# Three slabs with small gaps read as barrier segments.
	for i in 3:
		var x := -6.0 + i * 6.0
		CyberMaterials.box(self, Vector3(5.9, 2.6, 1.5), Vector3(x, 1.3, 0), concrete)
	CyberMaterials.box(self, Vector3(18.0, 0.4, 1.3), Vector3(0, 2.8, 0), steel)
	var bar := CyberMaterials.neon(CyberMaterials.CYAN, 4.0, 0.05)
	var low := CyberMaterials.neon(CyberMaterials.PURPLE, 2.5, 0.25)
	for sz in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(16.0, 0.14, 0.06), Vector3(0, 2.35, sz * 0.78), bar, false)
		CyberMaterials.box(self, Vector3(16.0, 0.06, 0.06), Vector3(0, 0.35, sz * 0.78), low, false)
		for sx in [-1.0, 1.0]:
			for k in 3:
				var chevron := CyberMaterials.box(self, Vector3(0.12, 0.9, 0.05),
						Vector3(sx * (8.2 - k * 0.35), 1.3, sz * 0.78), CyberMaterials.neon(CyberMaterials.YELLOW, 2.5, 0.0), false)
				chevron.rotation.z = sx * 0.6
	var holo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(7.0, 2.6)
	quad.material = CyberMaterials.hologram(CyberMaterials.MAGENTA, CyberMaterials.CYAN, 1.0)
	holo.mesh = quad
	holo.position = Vector3(0, 4.9, 0)
	holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holo)
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(0.12, 1.4, 0.12), Vector3(sx * 3.4, 3.5, 0), steel)
	StaticBatcher.merge(self)
