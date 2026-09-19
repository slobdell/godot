class_name UnitPortraits
extends Node
## Round 7 (C1), the lead: "instead of tank icons or scout icons, we should be able to actually re-use the meshy
## renderings we have per vehicle." A portrait is the real vehicle: the first time the HUD asks for a unit type, one
## tank of that type is dressed by the theme (Tank.apply_unit, exactly as in play) in an offscreen SubViewport with its
## own world, photographed from a three-quarter front view sized from its hull, and cached as a texture. One render per
## type, one at a time; until it is ready - and in headless runs, where nothing is drawn - callers keep the role icon.

const SIZE := 192
const TANK_SCENE := preload("res://game/tank/tank.tscn")
## The camera looks down at the hull from this high and this far round from the front (degrees).
const VIEW_PITCH_DEG := 24.0
const VIEW_YAW_DEG := 35.0

static var _textures := {}
static var _pending: Array[String] = []
static var _instance: UnitPortraits
static var _rendering := false


## The portrait for `unit_id`, or null until it has been rendered (it is queued on the first ask).
static func texture(unit_id: String, tree: SceneTree) -> Texture2D:
	if _textures.has(unit_id):
		return _textures[unit_id]
	if DisplayServer.get_name() == "headless" or tree == null:
		return null
	if not _pending.has(unit_id):
		_pending.append(unit_id)
	if _instance == null or not is_instance_valid(_instance):
		_instance = UnitPortraits.new()
		_instance.name = "UnitPortraits"
		tree.root.add_child.call_deferred(_instance)
	return null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	if _rendering or _pending.is_empty():
		return
	_render(_pending.pop_front())


func _render(unit_id: String) -> void:
	_rendering = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.light_energy = 1.6
	viewport.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20, 200, 0)
	fill.light_energy = 0.6
	viewport.add_child(fill)
	var tank := TANK_SCENE.instantiate() as Tank
	tank.unit_id = unit_id
	tank.name = "Portrait_" + unit_id
	viewport.add_child(tank)
	tank.process_mode = Node.PROCESS_MODE_DISABLED
	var hull: Array = Units.stat(unit_id, "hull_size")
	var reach := maxf(float(hull[0]), maxf(float(hull[1]), float(hull[2])))
	var camera := Camera3D.new()
	camera.fov = 30.0
	viewport.add_child(camera)
	var look_at_point := Vector3(0.0, float(hull[1]) * 0.45, 0.0)
	var back := Vector3(0.0, sin(deg_to_rad(VIEW_PITCH_DEG)), -cos(deg_to_rad(VIEW_PITCH_DEG))).rotated(Vector3.UP, deg_to_rad(VIEW_YAW_DEG))
	camera.global_transform = Transform3D(Basis.IDENTITY, look_at_point + back * reach * 2.6).looking_at(look_at_point, Vector3.UP)
	camera.current = true
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image != null and not image.is_empty():
		_textures[unit_id] = ImageTexture.create_from_image(image)
	viewport.queue_free()
	_rendering = false
