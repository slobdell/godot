extends "res://game/theme/default/tinted_visual.gd"
## Default laser emitter (added by gameplay G7 as a placeholder; look & feel owns the real one):
## a slim tinted barrel with an emitter tip that glows hotter as the tank's heat rises.

@onready var tip: MeshInstance3D = $Tip

var _tip_material: StandardMaterial3D


func _ready() -> void:
	_tip_material = (tip.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	tip.material_override = _tip_material


func set_heat(ratio: float) -> void:
	if _tip_material != null:
		_tip_material.albedo_color = Color(0.3, 0.9, 1.0).lerp(Color(1.0, 0.25, 0.1), clampf(ratio, 0.0, 1.0))
