extends MeshInstance3D
## `fx.fog_of_war` for the cyberpunk theme (contract from gameplay G1: `setup(data)` with
## {"texture": Texture2D, "origin": Vector2 world xz of the texture's top-left, "size": float m}):
## the same ground sheet as the default, styled as a sensor boundary (fog_of_war.gdshader).

const SHADER := preload("res://game/theme/fx/shaders/fog_of_war.gdshader")

var _material := ShaderMaterial.new()


func _ready() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shader = SHADER
	material_override = _material


func setup(data: Dictionary) -> void:
	var size: float = data["size"]
	var origin: Vector2 = data["origin"]
	var plane := PlaneMesh.new()
	plane.size = Vector2(size, size)
	mesh = plane
	# PlaneMesh UV (0,0) is at (-x, -z): the texture's top-left at `origin`. Above the floor art
	# (splats at 0.05, glows at 0.06), below vehicles.
	position = Vector3(origin.x + size / 2.0, 0.08, origin.y + size / 2.0)
	_material.set_shader_parameter("visibility", data["texture"])
	_material.set_shader_parameter("size_m", size)
