class_name HeatHaze
extends Node3D
## Heat haze rising off burning wrecks (feel stretch): one camera-facing quad per fire, nearest the camera first, that
## bends what's behind it. It reads the screen texture (an extra full-screen copy per frame while any haze is on screen),
## so it's tier-gated: high only, at most MAX_QUADS. Fed from FireSites by FxWorld; no nodes per fire.

const SHADER := preload("res://game/theme/fx/shaders/heat_haze.gdshader")
const MAX_QUADS := 8
const WIDTH := 6.0
const HEIGHT := 7.0
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))

var enabled := true
var _mesh := MultiMeshInstance3D.new()
var _material := ShaderMaterial.new()


func _init() -> void:
	name = "HeatHaze"
	_material.shader = SHADER
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	mesh.surface_set_material(0, _material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = MAX_QUADS
	multimesh.visible_instance_count = 0
	_mesh.multimesh = multimesh
	_mesh.name = "HazeMesh"
	_mesh.custom_aabb = WORLD_AABB
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func active_count() -> int:
	return _mesh.multimesh.visible_instance_count


## Place haze over the burning sites nearest `camera_position` (FireSites.sites entries), fading as each burns down.
func update(sites: Array, camera_position: Vector3, now: float) -> void:
	var multimesh := _mesh.multimesh
	if not enabled or not bool(FxQuality.value("haze")) or sites.is_empty():
		multimesh.visible_instance_count = 0
		return
	_material.set_shader_parameter("now", now)
	var ranked: Array = []
	for site: Dictionary in sites:
		ranked.append([(site["position"] as Vector3).distance_squared_to(camera_position), site])
	ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var n := mini(ranked.size(), MAX_QUADS)
	for i in n:
		var site: Dictionary = ranked[i][1]
		var position: Vector3 = site["position"]
		var age := now - float(site["start"])
		var strength := clampf(age / 1.0, 0.0, 1.0) * (1.0 - smoothstep(FireSites.BURN_SECONDS * 0.6, FireSites.BURN_SECONDS, age))
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(WIDTH, HEIGHT, 1.0)), position + Vector3.UP * (HEIGHT * 0.5 + 0.8)))
		multimesh.set_instance_custom_data(i, Color(strength, fmod(position.x * 0.37 + position.z * 0.11, 1.0), 0.0, 0.0))
	multimesh.visible_instance_count = n
