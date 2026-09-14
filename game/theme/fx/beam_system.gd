class_name BeamSystem
extends Node3D
## Every laser pulse in one MultiMesh (laser_beam.gdshader), plus one splat MultiMesh that lights
## the floor along each beam. A beam visual `add()`s itself on setup and `remove()`s when freed; the
## shader fades it from its start time. While a beam lives it borrows pooled lights at the hit
## point and the beam's middle, so walls and tanks along it catch real light.

const SHADER := preload("res://game/theme/fx/shaders/laser_beam.gdshader")
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))
const FADE_SECONDS := 0.18

var width := 0.55
var floor_glow := 0.8
var light_energy := 5.0
var lights_enabled := true

var _beams: Dictionary = {}  # source Node -> {from, to, color, start}
var _mesh := MultiMeshInstance3D.new()
var _floor := MultiMeshInstance3D.new()
var _material := ShaderMaterial.new()


func _init() -> void:
	name = "Beams"
	_material.shader = SHADER
	_mesh.name = "BeamMesh"
	_mesh.multimesh = _multimesh(QuadMesh.new(), _material)
	var splat := ShaderMaterial.new()
	splat.shader = TracerSystem.SPLAT_SHADER
	_floor.name = "BeamFloorMesh"
	_floor.multimesh = _multimesh(PlaneMesh.new(), splat)
	for instance in [_mesh, _floor]:
		instance.custom_aabb = WORLD_AABB
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)


func add(source: Object, from: Vector3, to: Vector3, color: Color, now: float) -> void:
	_beams[source] = {"from": from, "to": to, "color": color, "start": now}


func remove(source: Object) -> void:
	_beams.erase(source)


func active_count() -> int:
	return _mesh.multimesh.visible_instance_count


func update(pool: LightPool, now: float) -> void:
	_material.set_shader_parameter("now", now)
	var beams := _mesh.multimesh
	var floors := _floor.multimesh
	if _beams.size() > beams.instance_count:
		beams.instance_count = (_beams.size() / 16 + 1) * 16
		floors.instance_count = beams.instance_count
	var n := 0
	for key in _beams:
		if not is_instance_valid(key):
			continue
		var beam: Dictionary = _beams[key]
		var from: Vector3 = beam["from"]
		var to: Vector3 = beam["to"]
		var color: Color = beam["color"]
		var age: float = (now - float(beam["start"])) / FADE_SECONDS
		if age >= 1.0:
			continue
		var along := to - from
		var length := along.length()
		if length < 0.05:
			continue
		var basis := Basis.looking_at(-along / length, Vector3.UP if absf(along.y / length) < 0.99 else Vector3.RIGHT)
		beams.set_instance_transform(n, Transform3D(basis, from))
		beams.set_instance_color(n, color)
		beams.set_instance_custom_data(n, Color(length, beam["start"], FADE_SECONDS, width))
		var flat := Vector3(along.x, 0.0, along.z)
		var yaw := atan2(-flat.x, -flat.z)
		var middle := from + along * 0.5
		var fade := 1.0 - age
		floors.set_instance_transform(n, Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(3.5, 1.0, flat.length() + 4.0)),
				Vector3(middle.x, 0.05, middle.z)))
		floors.set_instance_color(n, color)
		floors.set_instance_custom_data(n, Color(floor_glow * fade * clampf(1.0 - minf(from.y, to.y) / 6.0, 0.0, 1.0), 0, 0, 0))
		if lights_enabled:
			pool.request(to - along / length * 0.6, color, light_energy * fade, 10.0, LightPool.PRIORITY_BEAM)
			if length > 18.0:
				pool.request(middle, color, light_energy * 0.6 * fade, 12.0, LightPool.PRIORITY_BEAM - 0.1)
		n += 1
	beams.visible_instance_count = n
	floors.visible_instance_count = n


static func _multimesh(primitive: PrimitiveMesh, material: Material) -> MultiMesh:
	primitive.set("size", Vector2.ONE)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, primitive.get_mesh_arrays())
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = 16
	multimesh.visible_instance_count = 0
	return multimesh
