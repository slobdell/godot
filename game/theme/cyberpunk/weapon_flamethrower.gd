extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## `weapon.flamethrower` (turret pivot; nozzle along −Z; a ~20 m flame): a stubby nozzle fed by a
## fuel canister with a team neon band, and while firing an additive turbulent flame cone, a ground
## glow, and a pooled light that lights the surroundings (priority: beam). set_heat() warms the nozzle.

const FLAME_SHADER := preload("res://game/theme/fx/shaders/flame_cone.gdshader")
const GROUND_GLOW_SHADER := preload("res://game/theme/fx/shaders/ground_glow.gdshader")

var firing := false
var flame := MeshInstance3D.new()
var ground_glow := MeshInstance3D.new()
var _length := 20.0
var _roar: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	flame.name = "Flame"
	flame.visible = false
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	ground_glow.name = "GroundGlow"
	ground_glow.visible = false
	ground_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var glow_material := ShaderMaterial.new()
	glow_material.shader = GROUND_GLOW_SHADER
	plane.material = glow_material
	ground_glow.mesh = plane
	add_child(ground_glow)
	setup({})


func build(b: ColorMeshBuilder) -> void:
	var along := Basis(Vector3.RIGHT, PI / 2.0)
	b.cylinder(0.28, 0.2, 0.9, Transform3D(along, Vector3(0, 0.05, -1.25)), STEEL.darkened(0.3), 10)
	b.cylinder(0.24, 0.24, 0.12, Transform3D(along, Vector3(0, 0.05, -1.72)), Color(1.0, 0.4, 0.05) * 0.4, 10, true, 1.0)
	# Fuel canister riding on the turret's flank, with a team band.
	b.cylinder(0.22, 0.22, 0.9, Transform3D(along, Vector3(0.55, 0.35, 0.1)), RUST.darkened(0.1), 8)
	b.cylinder(0.235, 0.235, 0.1, Transform3D(along, Vector3(0.55, 0.35, 0.1)), team_color, 8, true)
	b.box(Vector3(0.08, 0.08, 1.1), Vector3(0.35, 0.2, -0.6), STEEL)


func setup(weapon: Dictionary) -> void:
	_length = float(weapon.get("range", 20.0))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.2
	cone.bottom_radius = tan(deg_to_rad(float(weapon.get("cone_deg", 30.0)) / 2.0)) * _length
	cone.height = _length
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 16
	var material := ShaderMaterial.new()
	material.shader = FLAME_SHADER
	cone.material = material
	flame.mesh = cone
	# Cylinder axis is +Y with UV 0 at the top: flip it so the narrow top sits at the muzzle, pointing −Z.
	flame.transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0.0, 0.05, -1.8 - _length / 2.0))
	ground_glow.transform = Transform3D(Basis.from_scale(Vector3(cone.bottom_radius * 1.6, 1, _length * 0.9)),
			Vector3(0, -1.18, -1.8 - _length * 0.45))


func set_firing(value: bool) -> void:
	if value == firing:
		return
	firing = value
	flame.visible = value
	ground_glow.visible = value
	_set_roar(value)


## The flame's roar: one looping voice per flamethrower, created the first time it fires.
func _set_roar(on: bool) -> void:
	var fx := FxWorld.existing()
	if fx == null or fx.sfx.muted or not fx.sfx.streams.has("flame_loop"):
		return
	if _roar == null:
		_roar = AudioStreamPlayer3D.new()
		_roar.stream = fx.sfx.streams["flame_loop"]
		_roar.unit_size = 45.0
		_roar.max_distance = 500.0
		_roar.volume_db = -6.0
		_roar.position = Vector3(0, 0, -4.0)
		add_child(_roar)
	if on:
		_roar.play()
	else:
		_roar.stop()


func _process(_delta: float) -> void:
	if not firing or not is_visible_in_tree():
		return
	var fx := FxWorld.existing()
	if fx != null:
		var middle := global_transform * Vector3(0, 0.3, -1.8 - _length * 0.35)
		fx.lights.request(middle, Color(1.0, 0.5, 0.15), 4.0, _length * 0.8, LightPool.PRIORITY_BEAM)


func set_heat(ratio: float) -> void:
	if not is_equal_approx(ratio, heat):
		super.set_heat(ratio)
