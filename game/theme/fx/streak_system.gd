class_name StreakSystem
extends Node3D
## Static wet-floor reflection streaks for every neon source in the arena, in one MultiMesh. Props
## and dressing `add()` a streak at the foot of a light and `remove()` it when they leave the tree.
## The shader orients streaks toward the camera, so nothing updates per frame.

const SHADER := preload("res://game/theme/fx/shaders/streak.gdshader")
const WORLD_AABB := AABB(Vector3(-200, -5, -200), Vector3(400, 20, 400))

var enabled := true:
	set(value):
		enabled = value
		_mesh.visible = value

var _mesh := MultiMeshInstance3D.new()
var _entries: Dictionary = {}  # id -> [position, color, length, width, intensity]
var _next_id := 1
var _dirty := false


func _init() -> void:
	name = "Streaks"
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
	var material := ShaderMaterial.new()
	material.shader = SHADER
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	_mesh.name = "StreakMesh"
	_mesh.multimesh = multimesh
	_mesh.custom_aabb = WORLD_AABB
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)


## A streak under a light at `position` (its height is ignored). Returns an id for remove().
func add(position: Vector3, color: Color, length := 9.0, width := 1.6, intensity := 0.6) -> int:
	var id := _next_id
	_next_id += 1
	_entries[id] = [position, color, length, width, intensity]
	_dirty = true
	return id


func remove(id: int) -> void:
	if _entries.erase(id):
		_dirty = true


func count() -> int:
	return _entries.size()


func _process(_delta: float) -> void:
	if _dirty:
		_rebuild()


func _rebuild() -> void:
	_dirty = false
	var multimesh := _mesh.multimesh
	multimesh.instance_count = _entries.size()
	var i := 0
	for id in _entries:
		var entry: Array = _entries[id]
		var foot: Vector3 = entry[0]
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(foot.x, 0.0, foot.z)))
		multimesh.set_instance_color(i, entry[1])
		multimesh.set_instance_custom_data(i, Color(entry[2], entry[3], entry[4], float(id % 97) / 97.0))
		i += 1
