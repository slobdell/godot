class_name NaiveImpact
extends MeshInstance3D
## The FX lab's "before" case for hits: the original Impact, which allocated a SphereMesh and a
## StandardMaterial3D per hit, alpha-blended, animated from script, then freed.

const LIFETIME := 0.45

var big := false

var _age := 0.0
var _material := StandardMaterial3D.new()


func _ready() -> void:
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1.0, 0.6, 0.2, 1.0)
	sphere.material = _material
	mesh = sphere
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_age += delta
	var progress := _age / LIFETIME
	scale = Vector3.ONE * lerpf(0.3, 5.0 if big else 1.8, progress)
	_material.albedo_color.a = 1.0 - progress
	if progress >= 1.0:
		queue_free()
