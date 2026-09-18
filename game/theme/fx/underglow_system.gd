class_name UnderglowSystem
extends Node3D
## Team-colored underglow for every vehicle in one MultiMesh (the splat shader lying on the floor), and a blob shadow
## under each in a second one, so you can find your squad in the dark, even from the tactical camera. Vehicles
## register their hull visual; hidden vehicles (dead, fogged) stop glowing.
##
## Render X3 (round 5): the lead saw "blue lights, not tanks". The glow is now a small, dim hint under the hull, it no
## longer borrows pooled lights (16 vehicle lights were most of the frame's real lights), and the blob shadow replaces
## the moon's dynamic shadows (+4.6 ms GPU at 30 a side).

const BLOB_SHADOW_SHADER := preload("res://game/theme/fx/shaders/blob_shadow.gdshader")
const WORLD_AABB := AABB(Vector3(-200, -5, -200), Vector3(400, 20, 400))

var size := Vector2(3.4, 4.4)
var intensity := 0.35
var light_energy := 1.4
var light_range := 7.0
## Off: vehicles don't take pooled lights (the tier's light floor drops these requests anyway).
var lights_enabled := false
## The shadow ellipse against the glow's footprint, and how dark its middle is (0..1).
var shadow_scale := Vector2(0.88, 0.88)
var shadow_darkness := 0.55

var _sources: Dictionary = {}  # Node3D -> Color
var _mesh := MultiMeshInstance3D.new()
var _shadows := MultiMeshInstance3D.new()


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
	FxMultiMesh.resize(multimesh, 32)
	multimesh.visible_instance_count = 0
	# Placed every rendered frame from FxWorld.visual_transform (`update` runs in _process), so the MultiMesh must not be
	# interpolated as well: it would lag the vehicles by a tick and it logs "MultiMesh interpolation is being triggered
	# from outside physics process" every few seconds at 30 Hz. The flag only exists on the server.
	RenderingServer.multimesh_set_physics_interpolated(multimesh.get_rid(), false)
	_mesh.name = "UnderglowMesh"
	_mesh.multimesh = multimesh
	FxMultiMesh.never_interpolated(_mesh)
	_mesh.custom_aabb = WORLD_AABB
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	var shadow_mesh := ArrayMesh.new()
	shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	var shadow_material := ShaderMaterial.new()
	shadow_material.shader = BLOB_SHADOW_SHADER
	# Under the glow: shadows first, the team hint on top of them.
	shadow_material.render_priority = -1
	shadow_mesh.surface_set_material(0, shadow_material)
	var shadow_multimesh := MultiMesh.new()
	shadow_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	# Darkness rides in the instance COLOR: a MultiMesh with custom data but no colors fed the shader garbage in the
	# Compatibility renderer, which is what drew the blob as a flat dark rectangle (the lead saw it under every vehicle).
	shadow_multimesh.use_colors = true
	shadow_multimesh.mesh = shadow_mesh
	FxMultiMesh.resize(shadow_multimesh, 32)
	shadow_multimesh.visible_instance_count = 0
	RenderingServer.multimesh_set_physics_interpolated(shadow_multimesh.get_rid(), false)
	_shadows.name = "BlobShadows"
	_shadows.multimesh = shadow_multimesh
	FxMultiMesh.never_interpolated(_shadows)
	_shadows.custom_aabb = WORLD_AABB
	_shadows.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_shadows)


func add(source: Node3D, color: Color) -> void:
	_sources[source] = color


func remove(source: Node3D) -> void:
	_sources.erase(source)


func active_count() -> int:
	return _mesh.multimesh.visible_instance_count


func shadow_count() -> int:
	return _shadows.multimesh.visible_instance_count


func update(pool: LightPool) -> void:
	var multimesh := _mesh.multimesh
	var shadows := _shadows.multimesh
	if _sources.size() > multimesh.instance_count:
		FxMultiMesh.resize(multimesh, (_sources.size() / 32 + 1) * 32)
		FxMultiMesh.resize(shadows, multimesh.instance_count)
	var n := 0
	for key in _sources:
		if not is_instance_valid(key) or not (key as Node3D).is_visible_in_tree():
			continue
		var source := key as Node3D
		var color: Color = _sources[key]
		var xform := FxWorld.visual_transform(source)
		var yaw_basis := Basis(Vector3.UP, xform.basis.get_euler().y) * Basis.from_scale(Vector3(size.x, 1.0, size.y))
		multimesh.set_instance_transform(n, Transform3D(yaw_basis, Vector3(xform.origin.x, 0.04, xform.origin.z)))
		multimesh.set_instance_color(n, color)
		multimesh.set_instance_custom_data(n, Color(intensity, 0, 0, 0))
		var shadow_basis := Basis(Vector3.UP, xform.basis.get_euler().y) * Basis.from_scale(Vector3(size.x * shadow_scale.x, 1.0, size.y * shadow_scale.y))
		shadows.set_instance_transform(n, Transform3D(shadow_basis, Vector3(xform.origin.x, 0.03, xform.origin.z)))
		shadows.set_instance_color(n, Color(shadow_darkness, shadow_darkness, shadow_darkness, 1.0))
		if lights_enabled:
			pool.request(xform.origin + Vector3(0, 1.2, 0), color, light_energy, light_range, LightPool.PRIORITY_VEHICLE)
		n += 1
	multimesh.visible_instance_count = n
	shadows.visible_instance_count = n
