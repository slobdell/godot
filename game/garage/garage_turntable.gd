class_name GarageTurntable
extends SubViewportContainer
## A 3D preview of one unit, built from the same visual slots the match uses (so look & feel and
## assets art shows up here for free), turning slowly. Swipe/drag across it to spin it by hand.
##
## Slot choice per unit class: "<unit>.hull" / "<unit>.turret" when the theme has them, else the
## tank's; the main hardpoint's weapon goes on the turret as "weapon.<id>" (slot contract in
## _agents/slot_contracts.md: turret ring at y ≈ 1.22, z ≈ +0.2).

const SPIN_DEG_PER_SEC := 20.0
const TURRET_OFFSET := Vector3(0.0, 1.22, 0.2)
## Radians of spin per pixel dragged.
const DRAG_SPIN := 0.01

var unit_id := ""

var _viewport: SubViewport
var _pivot: Node3D
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
	var disc := CylinderMesh.new()
	disc.top_radius = 3.2
	disc.bottom_radius = 3.2
	disc.height = 0.08
	var floor_material := StandardMaterial3D.new()
	floor_material.albedo_color = Color(0.13, 0.14, 0.17)
	disc.material = floor_material
	floor_mesh.mesh = disc
	floor_mesh.position.y = -0.04
	_viewport.add_child(floor_mesh)

	_pivot = Node3D.new()
	_viewport.add_child(_pivot)
	_hull = VisualSlot.new()
	_pivot.add_child(_hull)
	var turret_mount := Node3D.new()
	turret_mount.position = TURRET_OFFSET
	_pivot.add_child(turret_mount)
	_turret = VisualSlot.new()
	turret_mount.add_child(_turret)
	_weapon = VisualSlot.new()
	turret_mount.add_child(_weapon)

	_camera = Camera3D.new()
	_camera.fov = 40.0
	_viewport.add_child(_camera)
	_camera.position = Vector3(6.0, 4.2, 7.5)
	_pivot.rotation.y = deg_to_rad(-30.0)


func _ready() -> void:
	_camera.look_at(Vector3(0.0, 0.9, 0.0))


## Show `tank` (a Loadout unit dictionary) painted `color`.
func show_unit(tank: Dictionary, color: Color) -> void:
	unit_id = String(tank.get("unit", "tank"))
	_hull.fill(_slot_for(unit_id, "hull"))
	_turret.fill(_slot_for(unit_id, "turret"))
	# Catalog v2 (rules R1): a unit type's weapon is fixed in Units.PROFILES.
	var main_weapon := String(tank.get("weapon", Units.profile(String(tank.get("unit", ""))).get("weapon", "")))
	if main_weapon != "" and GameTheme.slots.has("weapon." + main_weapon):
		_weapon.fill("weapon." + main_weapon)
		_weapon.invoke("setup", [Weapons.profile(main_weapon)])
	elif _weapon.visual != null:
		_weapon.visual.free()
		_weapon.visual = null
	for slot in [_hull, _turret, _weapon]:
		slot.invoke("set_team_color", [color])


static func _slot_for(unit: String, part: String) -> String:
	var own := "%s.%s" % [unit, part]
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
