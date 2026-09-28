class_name GarageTurntable
extends SubViewportContainer
## A 3D preview of one unit, turning slowly. Swipe/drag across it to spin it by hand.
##
## Round 14 (G2; round 13's tour: "the tank in the garage isn't the tank I fought with"): the preview IS a match
## vehicle -- a `Tank` from tank.tscn with `simulate` off and processing disabled -- so `Tank.apply_unit` fits the art
## to the unit's `hull_size` (`_apply_hull_size`, the turret mount, DozerPart._fit_to_hull and the gun cuts) exactly as
## the match does. Until then the turntable filled the three visual slots itself and applied none of that: the
## Condemned's 8.62 m dozer-bus drew as a short turreted tank. The slots (contract C6: "unit.<id>.hull" / ".turret" /
## ".weapon", else the shared tank's) are the Tank's own. The camera frames whatever size that is.

const SPIN_DEG_PER_SEC := 20.0
## Radians of spin per pixel dragged.
const DRAG_SPIN := 0.01
## The camera's direction from the vehicle (the pre-round-14 pose, normalised) and the room left around it.
const CAMERA_DIRECTION := Vector3(6.0, 4.2, 7.5)
const FRAME_MARGIN := 1.12
const TANK_SCENE := preload("res://game/tank/tank.tscn")

var unit_id := ""

var _viewport: SubViewport
var _pivot: Node3D
var _floor: CylinderMesh
var _tank: Tank
var _hull: VisualSlot
var _turret: VisualSlot
var _weapon: VisualSlot
var _camera: Camera3D
var _dragged_recently := 0.0


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(_viewport)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.08)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.6, 0.7)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
	key_light.light_energy = 1.1
	_viewport.add_child(key_light)
	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(-4.0, 3.0, -4.0)
	rim_light.light_color = GameTheme.ui.get("commander", Color(1.0, 0.85, 0.25))
	rim_light.light_energy = 1.5
	rim_light.omni_range = 12.0
	_viewport.add_child(rim_light)

	var floor_mesh := MeshInstance3D.new()
	_floor = CylinderMesh.new()
	_floor.top_radius = 3.2
	_floor.bottom_radius = 3.2
	_floor.height = 0.08
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.14, 0.17)
	_floor.material = floor_material
	floor_mesh.mesh = _floor
	floor_mesh.position.y = -0.04
	_viewport.add_child(floor_mesh)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_viewport.add_child(_camera)
	_pivot.rotation.y = deg_to_rad(-30.0)
	# Deferred: the stretched SubViewport takes its new size after this signal.
	resized.connect(func() -> void: _frame.call_deferred())


func _ready() -> void:
	_frame()


## Show `entry` (an army unit: {"unit": id}) painted `color`. `weapon_id` is the unit's catalog weapon; the Tank reads
## the same one from `Units` (catalog v2), so it is kept for callers and not needed here.
func show_unit(entry: Dictionary, color: Color, _weapon_id := "") -> void:
	unit_id = String(entry.get("unit", "tank"))
	if _tank != null:
		# Hidden now, freed at the frame's end: its parts' deferred fits still run on a node in the tree.
		_tank.visible = false
		_tank.name = "Leaving"
		_tank.queue_free()
	_tank = TANK_SCENE.instantiate() as Tank
	_tank.name = "Vehicle"
	_tank.unit_id = unit_id
	_tank.simulate = false
	# A preview, not a combatant: no ticking, no smoothing toward snapshots. `_ready` (apply_unit, the fit) and the
	# art's deferred fit still run.
	_tank.process_mode = Node.PROCESS_MODE_DISABLED
	_pivot.add_child(_tank)
	_tank.nameplate.visible = false
	_hull = _tank.get_node("HullVisual") as VisualSlot
	_turret = _tank.get_node("Turret/TurretVisual") as VisualSlot
	_weapon = _tank.get_node("Turret/WeaponVisual") as VisualSlot
	_tank.set_team_accent(color)
	_frame()


## The hull's size in metres as the match would draw it (hull_size): the tank's -Z length in z, from the hull model's
## meshes only (a shield shell is bigger than the hull; a gun cut from the hull overhangs it). As
## tests/test_theme_unit_scale.gd measures a match vehicle.
func drawn_hull_size() -> Vector3:
	if _tank == null:
		return Vector3.ZERO
	var hull: Node = _hull
	var models := hull.find_children("Model", "Node3D", true, false)
	if not models.is_empty():
		hull = models[0]
	var result := AABB()
	var first := true
	for child in hull.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null or not instance.is_visible_in_tree() or instance.mesh.get_surface_count() == 0:
			continue
		if child.get_path().get_concatenated_names().contains("GunPivot"):
			continue
		var box := (_tank.global_transform.affine_inverse() * instance.global_transform) * instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result.size


## The unit's box (hull_size), standing on the floor at the turntable's centre.
func _box() -> AABB:
	var size_list: Variant = Units.stat(unit_id, "hull_size") if Units.exists(unit_id) else [2.4, 1.6, 3.6]
	var size := Vector3(size_list[0], size_list[1], size_list[2])
	return AABB(Vector3(-size.x / 2.0, 0.0, -size.z / 2.0), size)


## Frame the unit whole at any spin: the camera starts where the box's bounding sphere fits the narrower of the view's
## two angles, then comes in along CAMERA_DIRECTION while every corner still fits at every spin; the floor disc grows.
func _frame() -> void:
	if _camera == null:
		return
	var box := _box()
	var centre := box.get_center()
	var radius := box.size.length() / 2.0
	# Before layout the container can be 0 wide: frame for a wide panel until it has a size (resized re-frames).
	var aspect := clampf(size.x / size.y, 0.5, 4.0) if size.x > 1.0 and size.y > 1.0 else 16.0 / 9.0
	var half_v := deg_to_rad(_camera.fov / 2.0)
	var half_h := atan(tan(half_v) * aspect)
	var distance := radius * FRAME_MARGIN / sin(minf(half_v, half_h))
	_camera.position = centre + CAMERA_DIRECTION.normalized() * distance
	_camera.look_at_from_position(_camera.position, centre)
	# The sphere is cautious (a 14 m rig drew at a third of the panel in round 14's first tour): come in until the box's
	# corners, at every spin, just stay inside the view with a small inset. Needs the view's real size.
	if _viewport.size.x > 1 and _viewport.size.y > 1:
		for _step in 30:
			var nearer := distance * 0.96
			_camera.position = centre + CAMERA_DIRECTION.normalized() * nearer
			if not _fits(box, 0.04):
				_camera.position = centre + CAMERA_DIRECTION.normalized() * distance
				break
			distance = nearer
	_camera.near = maxf(0.05, distance - radius * 2.0)
	_camera.far = distance + radius * 4.0 + 10.0
	var footprint := Vector2(box.size.x, box.size.z).length() / 2.0
	_floor.top_radius = maxf(3.2, footprint + 0.6)
	_floor.bottom_radius = _floor.top_radius


## True when the box's corners stay `inset` (a fraction of the view) inside it at every spin, 15 degrees apart.
func _fits(box: AABB, inset: float) -> bool:
	var view := Vector2(_viewport.size)
	var rect := Rect2(view * inset, view * (1.0 - inset * 2.0))
	for step in 12:
		var yaw := deg_to_rad(15.0 * step)
		for i in 8:
			var corner := Basis(Vector3.UP, yaw) * box.get_endpoint(i)
			if _camera.is_position_behind(corner) or not rect.has_point(_camera.unproject_position(corner)):
				return false
	return true


## How many of the unit's 8 box corners fall outside the view (or behind the camera) with the turntable at `yaw`.
func corners_outside_view(yaw: float) -> int:
	var box := _box()
	var rect := Rect2(Vector2.ZERO, Vector2(_viewport.size))
	var outside := 0
	for i in 8:
		var corner := Basis(Vector3.UP, yaw) * box.get_endpoint(i)
		if _camera.is_position_behind(corner) or not rect.has_point(_camera.unproject_position(corner)):
			outside += 1
	return outside


## Slot contract C6: "unit.<id>.<part>" when the theme has it, else the tank's.
static func slot_for(unit: String, part: String) -> String:
	var own := "unit.%s.%s" % [unit, part]
	return own if GameTheme.slots.has(own) else "tank." + part


func _process(delta: float) -> void:
	_dragged_recently = maxf(_dragged_recently - delta, 0.0)
	if _dragged_recently <= 0.0 and is_visible_in_tree():
		_pivot.rotate_y(deg_to_rad(SPIN_DEG_PER_SEC) * delta)


func _gui_input(event: InputEvent) -> void:
	# Touch arrives as emulated mouse events (Godot's default), so one handler serves both.
	var motion := event as InputEventMouseMotion
	if motion != null and motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_pivot.rotate_y(motion.relative.x * DRAG_SPIN)
		_dragged_recently = 1.5
		accept_event()


func spin_degrees() -> float:
	return rad_to_deg(_pivot.rotation.y)
