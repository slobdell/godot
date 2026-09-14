class_name TracerSystem
extends Node3D
## Every projectile in flight drawn as one tracer MultiMesh plus one ground-splat MultiMesh
## (two draw calls total). Projectile visuals (the `fx.shell` slot) register themselves; each
## frame this copies their transforms into the buffers and asks the LightPool for a light
## for each (only the best few get one).

const TRACER_SHADER := preload("res://game/theme/fx/shaders/tracer.gdshader")
const SPLAT_SHADER := preload("res://game/theme/fx/shaders/splat.gdshader")

## Buffers grow in steps of this many instances (rarely: a big firefight has ~40 shells in flight).
const GROW := 32
## Everything a tracer can reach, so the MultiMesh is never frustum-culled by accident.
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))

var tail_length := 6.0
var width := 0.45
var splat_width := 3.2
var splat_length := 9.0
## Splat brightness at ground level.
var splat_intensity := 0.55
## A splat fades out as its projectile climbs above this height (m).
var splat_fade_height := 6.0
var light_energy := 2.5
var light_range := 9.0
var splats_enabled := true
var lights_enabled := true

## Registered projectile visuals → tint color.
var _sources: Dictionary = {}
var _tracers := MultiMeshInstance3D.new()
var _splats := MultiMeshInstance3D.new()


func _init() -> void:
	name = "Tracers"
	_tracers.name = "TracerMesh"
	_tracers.multimesh = _make_multimesh(_quad(), TRACER_SHADER)
	_splats.name = "SplatMesh"
	_splats.multimesh = _make_multimesh(_plane(), SPLAT_SHADER)
	for instance in [_tracers, _splats]:
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		instance.custom_aabb = WORLD_AABB
		add_child(instance)


func add(source: Node3D, color: Color) -> void:
	_sources[source] = color


func remove(source: Node3D) -> void:
	_sources.erase(source)


func active_count() -> int:
	return _tracers.multimesh.visible_instance_count


## Copy this frame's projectiles into the buffers. Called by FxWorld once per frame.
func update(pool: LightPool) -> void:
	var tracers := _tracers.multimesh
	var splats := _splats.multimesh
	if _sources.size() > tracers.instance_count:
		var size := (_sources.size() / GROW + 1) * GROW
		tracers.instance_count = size
		splats.instance_count = size
	var n := 0
	for key in _sources:
		if not is_instance_valid(key) or not (key as Node3D).is_visible_in_tree():
			continue
		var source := key as Node3D
		var color: Color = _sources[key]
		var xform := source.global_transform.orthonormalized()
		tracers.set_instance_transform(n, xform)
		tracers.set_instance_color(n, color)
		tracers.set_instance_custom_data(n, Color(tail_length, width, 1.0, 0.0))
		var head := xform.origin
		var height_fade := clampf(1.0 - head.y / splat_fade_height, 0.0, 1.0)
		var forward := -xform.basis.z
		var yaw := atan2(-forward.x, -forward.z)
		var splat_basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(splat_width, 1.0, splat_length))
		splats.set_instance_transform(n, Transform3D(splat_basis, Vector3(head.x, 0.05, head.z)))
		splats.set_instance_color(n, color)
		splats.set_instance_custom_data(n, Color(height_fade * splat_intensity if splats_enabled else 0.0, 0, 0, 0))
		if lights_enabled:
			pool.request(head, color, light_energy, light_range, LightPool.PRIORITY_TRACER)
		n += 1
	tracers.visible_instance_count = n
	splats.visible_instance_count = n if splats_enabled else 0


static func _make_multimesh(mesh: Mesh, shader: Shader) -> MultiMesh:
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = GROW
	multimesh.visible_instance_count = 0
	return multimesh


static func _quad() -> Mesh:
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	return _baked(quad)


static func _plane() -> Mesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	return _baked(plane)


## Primitive meshes can't hold a surface material via surface_set_material; bake to an ArrayMesh.
static func _baked(primitive: PrimitiveMesh) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
	return mesh
