extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## `weapon.laser` (turret pivot; emitter along −Z, muzzle ~3.2 m ahead): a slim emitter wrapped in
## team neon coils ending in a focusing lens. `set_heat(ratio)` (every frame) pushes the coils from
## team color to orange-white; `set_firing(true)` on the pulse tick flashes the whole emitter.

const FLASH_SECONDS := 0.12

var _flash := 0.0


func build(b: ColorMeshBuilder) -> void:
	var along := Basis(Vector3.RIGHT, PI / 2.0)
	b.cylinder(0.1, 0.08, 2.6, Transform3D(along, Vector3(0, 0.05, -1.9)), STEEL.darkened(0.45), 8)
	b.box(Vector3(0.36, 0.3, 0.8), Vector3(0, 0.05, -0.75), paint_dark())
	for k in 5:
		b.cylinder(0.15, 0.15, 0.08, Transform3D(along, Vector3(0, 0.05, -1.25 - k * 0.32)), team_color, 8, true, 1.0)
	b.cylinder(0.16, 0.12, 0.2, Transform3D(along, Vector3(0, 0.05, -3.15)), STEEL.darkened(0.2), 8)
	b.glow_box(Vector3(0.12, 0.12, 0.04), Vector3(0, 0.05, -3.27), Color(0.9, 0.85, 1.0), 1.0)
	# Cooling fins on top.
	for k in 3:
		b.box(Vector3(0.3, 0.05, 0.12), Vector3(0, 0.26, -0.5 - k * 0.22), STEEL.darkened(0.3))


func set_heat(ratio: float) -> void:
	if not is_equal_approx(ratio, heat):
		super.set_heat(ratio)


func _apply_glow() -> void:
	ColorMeshBuilder.set_glow_state(mesh_instance, heat, _flash)


func set_firing(firing: bool) -> void:
	if firing:
		_flash = 1.0
		set_process(true)


func _process(delta: float) -> void:
	_flash = maxf(0.0, _flash - delta / FLASH_SECONDS)
	_apply_glow()
	if _flash <= 0.0:
		set_process(false)
