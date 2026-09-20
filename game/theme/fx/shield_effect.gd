class_name ShieldEffect
extends MeshInstance3D
## A vehicle's energy shield shell, driven by `set_shield(ratio)` from the hull slot (gameplay G6).
## Hidden except while an event plays, so an idle shield costs nothing:
##   ratio drops      → hit shimmer (0.45 s)
##   ratio hits 0     → shield-down crackle (0.9 s), then the shell stays off
##   ratio rises      → recharge sweep while it keeps rising (and 0.6 s after)
## Each shield owns its material (plain uniforms, one shader): instance uniforms reserve 16 of the renderer's 4,096
## slots per instance and ran out at 30 a side (render X2, round 5).

const SHADER := preload("res://game/theme/fx/shaders/shield.gdshader")
const HIT_SECONDS := 0.45
const DOWN_SECONDS := 0.9
const RECHARGE_LINGER := 0.6
const RIPPLE_SECONDS := 0.5

var _material := ShaderMaterial.new()

var ratio := 1.0
## The first update is where the shield starts, not an event: a unit without one (every gang vehicle, max_shield 0)
## sends 0 from its first frame, and read against the full ratio above it crackled "shield down" at every spawn.
var _started := false
var _hit := 0.0
var _down := 0.0
var _recharge_left := 0.0
var _sweep := 0.0
## 0 = no ripple, else the ripple's progress (grows to 1).
var _ripple := 0.0
## Flames chip shields every tick; don't retrigger the hit sound faster than this.
var _hit_sound_cooldown := 0.0


func _init(size := Vector3(2.9, 2.2, 4.3)) -> void:
	name = "Shield"
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
	_material.set_shader_parameter("tint", Vector3(color.r, color.g, color.b).lerp(Vector3.ONE, 0.25))


func set_shield(new_ratio: float) -> void:
	new_ratio = clampf(new_ratio, 0.0, 1.0)
	if not _started:
		_started = true
		ratio = new_ratio
		_material.set_shader_parameter("strength", ratio)
		return
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
	_material.set_shader_parameter("strength", ratio)
	if _hit > 0.0 or _down > 0.0 or _recharge_left > 0.0:
		visible = true
		set_process(true)


## A round struck the shield at `world_point` (feel X4): a ring spreads across the shell from there.
func hit_at(world_point: Vector3) -> void:
	var local := (global_transform.affine_inverse() * world_point)
	_material.set_shader_parameter("ripple_from", local.normalized() if local.length() > 0.001 else Vector3.BACK)
	_ripple = 0.001
	_hit = maxf(_hit, 0.6)
	visible = true
	set_process(true)


## Seconds of each event left (for tests): {hit, down, recharge, ripple}.
func state() -> Dictionary:
	return {"hit": _hit, "down": _down, "recharge": _recharge_left, "ripple": _ripple, "visible": visible}


func _process(delta: float) -> void:
	_hit_sound_cooldown = maxf(0.0, _hit_sound_cooldown - delta)
	_hit = maxf(0.0, _hit - delta / HIT_SECONDS)
	_down = maxf(0.0, _down - delta / DOWN_SECONDS)
	_recharge_left = maxf(0.0, _recharge_left - delta)
	_sweep = fmod(_sweep + delta * 0.9, 1.0) if _recharge_left > 0.0 else 0.0
	if _ripple > 0.0:
		_ripple += delta / RIPPLE_SECONDS
		if _ripple >= 1.0:
			_ripple = 0.0
	_material.set_shader_parameter("ripple", _ripple)
	_material.set_shader_parameter("hit", _hit * _hit)
	_material.set_shader_parameter("down", _down)
	_material.set_shader_parameter("recharge", maxf(_sweep, 0.001) if _recharge_left > 0.0 else 0.0)
	if _hit <= 0.0 and _down <= 0.0 and _recharge_left <= 0.0 and _ripple <= 0.0:
		visible = false
		set_process(false)
