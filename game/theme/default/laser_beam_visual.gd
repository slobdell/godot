extends Node3D
## Default laser pulse (added by gameplay G7 as a placeholder; look & feel owns the real one):
## a thin unshaded bar from the muzzle to the hit point that fades out in a blink.

const FADE_SECONDS := 0.15

@onready var bar: MeshInstance3D = $Bar

var _age := 0.0
var _material: StandardMaterial3D


func setup(from: Vector3, to: Vector3) -> void:
	var length := from.distance_to(to)
	if length < 0.01:
		return
	global_position = (from + to) / 2.0
	look_at(to, Vector3.UP if absf((to - from).normalized().y) < 0.99 else Vector3.RIGHT)
	bar.scale = Vector3(1.0, 1.0, length)


func _ready() -> void:
	_material = (bar.mesh.surface_get_material(0) as StandardMaterial3D).duplicate()
	bar.material_override = _material


func _process(delta: float) -> void:
	_age += delta
	_material.albedo_color.a = clampf(1.0 - _age / FADE_SECONDS, 0.0, 1.0)
