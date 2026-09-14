class_name ShieldEffect
extends MeshInstance3D
## A vehicle's energy shield shell, driven by `set_shield(ratio)` from the hull slot (gameplay G6).
## Hidden except while an event plays, so an idle shield costs nothing:
##   ratio drops      → hit shimmer (0.45 s)
##   ratio hits 0     → shield-down crackle (0.9 s), then the shell stays off
##   ratio rises      → recharge sweep while it keeps rising (and 0.6 s after)
## The effect is per instance (instance uniforms), all shields share one material.

const SHADER := preload("res://game/theme/fx/shaders/shield.gdshader")
const HIT_SECONDS := 0.45
const DOWN_SECONDS := 0.9
const RECHARGE_LINGER := 0.6

static var _material: ShaderMaterial

var ratio := 1.0
var _hit := 0.0
var _down := 0.0
var _recharge_left := 0.0
var _sweep := 0.0
## Flames chip shields every tick; don't retrigger the hit sound faster than this.
var _hit_sound_cooldown := 0.0


func _init(size := Vector3(2.9, 2.2, 4.3)) -> void:
	name = "Shield"
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = SHADER
	var sphere := SphereMesh.new()
	sphere.radius = 0.5
	sphere.height = 1.0
	sphere.radial_segments = 24
	sphere.rings = 12
	sphere.material = _material
	mesh = sphere
	scale = size
	position = Vector3(0, size.y * 0.32, 0)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visible = false
	set_process(false)


func set_tint(color: Color) -> void:
	set_instance_shader_parameter("tint", Vector3(color.r, color.g, color.b).lerp(Vector3.ONE, 0.25))


func set_shield(new_ratio: float) -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	if new_ratio < ratio - 0.0001:
		_hit = 1.0
		var fx := FxWorld.existing()
		if new_ratio <= 0.0:
			_down = 1.0
			if fx != null and is_inside_tree():
				fx.sfx.play_at("shield_down", global_position)
		elif fx != null and is_inside_tree() and _hit_sound_cooldown <= 0.0:
			fx.sfx.play_at("shield_hit", global_position)
			_hit_sound_cooldown = 0.12
	elif new_ratio > ratio + 0.0001:
		_recharge_left = RECHARGE_LINGER
	ratio = new_ratio
	set_instance_shader_parameter("strength", ratio)
	if _hit > 0.0 or _down > 0.0 or _recharge_left > 0.0:
		visible = true
		set_process(true)


## Seconds of each event left (for tests): {hit, down, recharge}.
func state() -> Dictionary:
	return {"hit": _hit, "down": _down, "recharge": _recharge_left, "visible": visible}


func _process(delta: float) -> void:
	_hit_sound_cooldown = maxf(0.0, _hit_sound_cooldown - delta)
	_hit = maxf(0.0, _hit - delta / HIT_SECONDS)
	_down = maxf(0.0, _down - delta / DOWN_SECONDS)
	_recharge_left = maxf(0.0, _recharge_left - delta)
	_sweep = fmod(_sweep + delta * 0.9, 1.0) if _recharge_left > 0.0 else 0.0
	set_instance_shader_parameter("hit", _hit * _hit)
	set_instance_shader_parameter("down", _down)
	set_instance_shader_parameter("recharge", maxf(_sweep, 0.001) if _recharge_left > 0.0 else 0.0)
	if _hit <= 0.0 and _down <= 0.0 and _recharge_left <= 0.0:
		visible = false
		set_process(false)
