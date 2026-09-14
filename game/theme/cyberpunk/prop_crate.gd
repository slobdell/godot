extends "res://game/theme/cyberpunk/cyber_prop.gd"
## `prop.crate` (4.5 × 3 × 4.5, ground center): a scrap-container stack. A rusted shipping block
## with a smaller crate on top; amber hazard neon (never a team color) on the edges and a glowing
## top panel so it reads as a lit square from the tactical camera; a failing beacon on top.
## Stays inside the collision footprint; merged into one draw per material.


func _ready() -> void:
	var rust := CyberMaterials.surface(Color(0.24, 0.12, 0.07), 0.55, 0.5)
	var dark := CyberMaterials.surface(Color(0.1, 0.1, 0.12), 0.35, 0.7)
	CyberMaterials.box(self, Vector3(4.5, 2.0, 4.5), Vector3(0, 1.0, 0), rust)
	CyberMaterials.box(self, Vector3(3.4, 0.98, 3.4), Vector3(-0.35, 2.49, 0.35), dark)
	# Ribs on the container sides.
	for i in 5:
		CyberMaterials.box(self, Vector3(0.12, 1.8, 4.56), Vector3(-1.8 + i * 0.9, 1.0, 0), rust)
	var amber := CyberMaterials.neon(CyberMaterials.ORANGE, 3.5, 0.08)
	# Edge strips wide enough to survive the top-down view (~3 px/m).
	for sz in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(4.5, 0.12, 0.35), Vector3(0, 2.02, sz * 2.075), amber, false)
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(0.35, 0.12, 3.8), Vector3(sx * 2.075, 2.02, 0), amber, false)
	CyberMaterials.top_quad(self, Vector2(3.4, 3.4), Vector3(-0.35, 2.99, 0.35),
			CyberMaterials.panel(CyberMaterials.YELLOW, 1.0, 1.8))
	var violet := CyberMaterials.neon(CyberMaterials.PURPLE, 3.0, 0.25)
	CyberMaterials.box(self, Vector3(0.08, 0.9, 0.08), Vector3(1.36, 2.5, 2.06), violet, false)
	CyberMaterials.box(self, Vector3(0.08, 0.9, 0.08), Vector3(-2.06, 2.5, 2.06), violet, false)
	# Hazard beacon: a failing red light.
	CyberMaterials.box(self, Vector3(0.4, 0.3, 0.4), Vector3(1.2, 2.85, -1.2),
			CyberMaterials.neon(CyberMaterials.RED, 6.0, 0.9), false)
	StaticBatcher.merge(self)
	for corner in [Vector3(2.3, 0, 2.3), Vector3(-2.3, 0, -2.3)]:
		add_streak(corner, CyberMaterials.ORANGE, 7.0, 1.4, 0.45)
	add_streak(Vector3(1.2, 0, -1.2), CyberMaterials.RED, 6.0, 1.0, 0.35)
