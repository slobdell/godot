extends "res://game/theme/cyberpunk/cyber_prop.gd"
## `prop.wall` (18 long on X × 3 tall × 1.5 thick, ground center): a blast barrier. Concrete
## segments under a steel rim whose top carries a violet light bar (a glowing line from the
## tactical camera), light bars and yellow chevrons on both faces, and a holographic ad floating
## above (visual only, above the collision box). Violet/amber, never a team color.


func _ready() -> void:
	var concrete := CyberMaterials.surface(Color(0.14, 0.14, 0.16), 0.75, 0.05)
	var steel := CyberMaterials.surface(Color(0.16, 0.14, 0.13), 0.4, 0.7)
	# Three slabs with small gaps read as barrier segments.
	for i in 3:
		CyberMaterials.box(self, Vector3(5.9, 2.6, 1.5), Vector3(-6.0 + i * 6.0, 1.3, 0), concrete)
	CyberMaterials.box(self, Vector3(18.0, 0.4, 1.3), Vector3(0, 2.8, 0), steel)
	CyberMaterials.top_quad(self, Vector2(18.0, 1.5), Vector3(0, 3.01, 0),
			CyberMaterials.panel(CyberMaterials.PURPLE, 12.0, 3.2))
	var bar := CyberMaterials.neon(CyberMaterials.PURPLE, 3.5, 0.05)
	var low := CyberMaterials.neon(CyberMaterials.PURPLE, 1.8, 0.25)
	var chevron_material := CyberMaterials.neon(CyberMaterials.YELLOW, 2.2, 0.0)
	for sz in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(16.0, 0.14, 0.06), Vector3(0, 2.35, sz * 0.78), bar, false)
		CyberMaterials.box(self, Vector3(16.0, 0.06, 0.06), Vector3(0, 0.35, sz * 0.78), low, false)
		for sx in [-1.0, 1.0]:
			for k in 3:
				var chevron := CyberMaterials.box(self, Vector3(0.12, 0.9, 0.05),
						Vector3(sx * (8.2 - k * 0.35), 1.3, sz * 0.78), chevron_material, false)
				chevron.rotation.z = sx * 0.6
	var holo := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(7.0, 2.6)
	quad.material = CyberMaterials.hologram(CyberMaterials.PURPLE, CyberMaterials.GREEN, 1.0)
	holo.mesh = quad
	holo.position = Vector3(0, 4.9, 0)
	holo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(holo)
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(0.12, 1.4, 0.12), Vector3(sx * 3.4, 3.5, 0), steel)
	StaticBatcher.merge(self)
	for sz in [-1.0, 1.0]:
		for x in [-6.0, 0.0, 6.0]:
			add_streak(Vector3(x, 0, sz * 0.9), CyberMaterials.PURPLE, 10.0, 3.2, 0.5)
