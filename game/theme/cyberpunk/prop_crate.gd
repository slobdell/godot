extends Node3D
## `prop.crate` (4.5 × 3 × 4.5, ground center): a scrap-container stack. A rusted shipping block
## with a smaller crate on top, neon edge strips, a flickering hazard beacon, and a painted
## glow pool at its feet. Stays inside the collision footprint.

const SIZE := Vector3(4.5, 3.0, 4.5)


func _ready() -> void:
	var rust := CyberMaterials.surface(Color(0.2, 0.1, 0.06), 0.55, 0.5)
	var dark := CyberMaterials.surface(Color(0.07, 0.07, 0.08), 0.35, 0.7)
	CyberMaterials.box(self, Vector3(4.5, 2.0, 4.5), Vector3(0, 1.0, 0), rust)
	CyberMaterials.box(self, Vector3(3.2, 1.0, 3.0), Vector3(-0.4, 2.5, 0.3), dark)
	# Ribs on the container sides.
	for i in 5:
		var x := -1.8 + i * 0.9
		CyberMaterials.box(self, Vector3(0.12, 1.8, 4.56), Vector3(x, 1.0, 0), rust)
	var magenta := CyberMaterials.neon(CyberMaterials.MAGENTA, 4.0, 0.08)
	var cyan := CyberMaterials.neon(CyberMaterials.CYAN, 3.5, 0.2)
	for sz in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(4.5, 0.1, 0.1), Vector3(0, 2.02, sz * 2.26), magenta, false)
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(self, Vector3(0.1, 0.1, 4.5), Vector3(sx * 2.26, 2.02, 0), magenta, false)
	CyberMaterials.box(self, Vector3(0.08, 0.9, 0.08), Vector3(1.19, 2.5, 1.81), cyan, false)
	CyberMaterials.box(self, Vector3(0.08, 0.9, 0.08), Vector3(-2.01, 2.5, 1.81), cyan, false)
	# Hazard beacon: a failing yellow light.
	CyberMaterials.box(self, Vector3(0.35, 0.3, 0.35), Vector3(0.8, 3.0 - 0.15 - 0.01, -0.9),
			CyberMaterials.neon(CyberMaterials.YELLOW, 6.0, 0.9), false)
	StaticBatcher.merge(self)
