extends "res://game/theme/cyberpunk/cyber_prop.gd"
## A generated prop (the lead's approved Meshy kit, art X6) placed in the cyberpunk arena. The model brings the look;
## this adds what the tactical overview needs (trip-up 46: ~3 px per meter, dark roofs vanish): a neon hazard frame
## on the floor around the cover's footprint, wide enough to bloom from 200 m up, merged into one draw. Plus the
## wet-floor streaks under it. Visual only: the collision box is gameplay's.

@export var model_scene: PackedScene
## The collision footprint (x, z) the frame traces: prop.crate 4.5 × 4.5, prop.wall 18 × 1.5.
@export var footprint := Vector2(4.5, 4.5)
@export var trim_color := Color(1.0, 0.5, 0.1)
@export_range(0.0, 8.0) var trim_energy := 3.0

const TRIM_WIDTH := 0.35


func _ready() -> void:
	if model_scene != null:
		add_child(model_scene.instantiate())
	var trim := Node3D.new()
	trim.name = "Trim"
	add_child(trim)
	var neon := CyberMaterials.neon(trim_color, trim_energy, 0.1)
	var half := footprint / 2.0 + Vector2(TRIM_WIDTH, TRIM_WIDTH) / 2.0
	for sz in [-1.0, 1.0]:
		CyberMaterials.box(trim, Vector3(footprint.x + TRIM_WIDTH * 2.0, 0.06, TRIM_WIDTH), Vector3(0, 0.03, sz * half.y), neon, false)
	for sx in [-1.0, 1.0]:
		CyberMaterials.box(trim, Vector3(TRIM_WIDTH, 0.06, footprint.y), Vector3(sx * half.x, 0.03, 0), neon, false)
	StaticBatcher.merge(trim)
	for corner in [Vector3(half.x, 0, half.y), Vector3(-half.x, 0, -half.y)]:
		add_streak(corner, trim_color, 6.0, 1.2, 0.35)
