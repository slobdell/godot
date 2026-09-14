class_name UnderglowSystem
extends Node3D
## Team-colored underglow for every vehicle in one MultiMesh (the splat shader lying on the floor),
## so you can find your squad in the dark, even from the tactical camera. Vehicles register their
## hull visual; hidden vehicles (dead, fogged) stop glowing. Each also asks the LightPool for a
## low-priority light, so spare pooled lights go to the vehicles nearest the camera.

const WORLD_AABB := AABB(Vector3(-200, -5, -200), Vector3(400, 20, 400))

var size := Vector2(5.2, 6.2)
var intensity := 1.1
var light_energy := 1.4
var light_range := 7.0
var lights_enabled := true

var _sources: Dictionary = {}  # Node3D -> Color
var _mesh := MultiMeshInstance3D.new()


func _init() -> void:
	name = "Underglow"
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	var material := ShaderMaterial.new()
	material.shader = TracerSystem.SPLAT_SHADER
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 32
	multimesh.visible_instance_count = 0
	_mesh.name = "UnderglowMesh"
	_mesh.multimesh = multimesh
	_mesh.custom_aabb = WORLD_AABB
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


func add(source: Node3D, color: Color) -> void:
	_sources[source] = color


func remove(source: Node3D) -> void:
	_sources.erase(source)


func active_count() -> int:
	return _mesh.multimesh.visible_instance_count


func update(pool: LightPool) -> void:
	var multimesh := _mesh.multimesh
	if _sources.size() > multimesh.instance_count:
		multimesh.instance_count = (_sources.size() / 32 + 1) * 32
	var n := 0
	for key in _sources:
		if not is_instance_valid(key) or not (key as Node3D).is_visible_in_tree():
			continue
		var source := key as Node3D
		var color: Color = _sources[key]
		var xform := source.global_transform
		var yaw_basis := Basis(Vector3.UP, xform.basis.get_euler().y) * Basis.from_scale(Vector3(size.x, 1.0, size.y))
		multimesh.set_instance_transform(n, Transform3D(yaw_basis, Vector3(xform.origin.x, 0.04, xform.origin.z)))
		multimesh.set_instance_color(n, color)
		multimesh.set_instance_custom_data(n, Color(intensity, 0, 0, 0))
		if lights_enabled:
			pool.request(xform.origin + Vector3(0, 1.2, 0), color, light_energy, light_range, LightPool.PRIORITY_VEHICLE)
		n += 1
	multimesh.visible_instance_count = n
