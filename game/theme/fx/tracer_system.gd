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

## How each kind of round draws (feel X2/X3), by K2 fire model: tracer tail and width (m), brightness, the ground
## splat under it (m, brightness at ground level), and the light it asks the pool for. "default" is round 2's look.
const STYLES := {
	"default": {"tail": 6.0, "width": 0.45, "intensity": 1.0, "splat_width": 3.2, "splat_length": 9.0, "splat_intensity": 0.55,
			"light_energy": 2.5, "light_range": 9.0, "priority": LightPool.PRIORITY_TRACER},
	# The tank shell: a fat white-hot slug you can follow, dragging a long pool of light along the floor.
	"shell": {"tail": 11.0, "width": 1.1, "intensity": 1.8, "splat_width": 6.0, "splat_length": 16.0, "splat_intensity": 1.0,
			"light_energy": 6.0, "light_range": 15.0, "priority": LightPool.PRIORITY_SHELL},
	"burst": {"tail": 5.0, "width": 0.32, "intensity": 1.3, "splat_width": 2.2, "splat_length": 6.5, "splat_intensity": 0.5,
			"light_energy": 1.8, "light_range": 6.0, "priority": LightPool.PRIORITY_TRACER},
	"stream": {"tail": 3.4, "width": 0.2, "intensity": 1.1, "splat_width": 1.5, "splat_length": 4.5, "splat_intensity": 0.35,
			"light_energy": 1.2, "light_range": 4.5, "priority": LightPool.PRIORITY_TRACER - 0.3},
	"arc": {"tail": 6.0, "width": 0.7, "intensity": 1.4, "splat_width": 4.0, "splat_length": 8.0, "splat_intensity": 0.7,
			"light_energy": 3.0, "light_range": 10.0, "priority": LightPool.PRIORITY_TRACER + 0.5},
}

## A splat fades out as its projectile climbs above this height (m).
var splat_fade_height := 6.0
var splats_enabled := true
var lights_enabled := true

## Registered projectile visuals → [tint color, style Dictionary].
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


func add(source: Node3D, color: Color, style := "default") -> void:
	_sources[source] = [color, STYLES.get(style, STYLES["default"])]


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
		var entry: Array = _sources[key]
		var color: Color = entry[0]
		var style: Dictionary = entry[1]
		var xform := source.global_transform.orthonormalized()
		tracers.set_instance_transform(n, xform)
		tracers.set_instance_color(n, color)
		tracers.set_instance_custom_data(n, Color(style["tail"], style["width"], style["intensity"], 0.0))
		var head := xform.origin
		var height_fade := clampf(1.0 - head.y / splat_fade_height, 0.0, 1.0)
		var forward := -xform.basis.z
		var yaw := atan2(-forward.x, -forward.z)
		var splat_basis := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(style["splat_width"], 1.0, style["splat_length"]))
		splats.set_instance_transform(n, Transform3D(splat_basis, Vector3(head.x, 0.05, head.z)))
		splats.set_instance_color(n, color)
		splats.set_instance_custom_data(n, Color(height_fade * float(style["splat_intensity"]) if splats_enabled else 0.0, 0, 0, 0))
		if lights_enabled:
			pool.request(head, color, style["light_energy"], style["light_range"], style["priority"])
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
