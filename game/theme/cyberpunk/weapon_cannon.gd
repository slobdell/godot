extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## `weapon.cannon` (turret pivot; barrel along −Z, muzzle ~3.2 m ahead): a long barrel with a
## thermal sleeve, team neon rings, and a muzzle brake. set_heat() makes the rings and muzzle glow
## orange-white after firing.


func build(b: ColorMeshBuilder) -> void:
	var along := Basis(Vector3.RIGHT, PI / 2.0)  # cylinder +Y → -Z... any axis along Z works for a round barrel
	b.cylinder(0.12, 0.1, 2.3, Transform3D(along, Vector3(0, 0.05, -2.0)), STEEL.darkened(0.35), 10)
	b.cylinder(0.17, 0.17, 0.7, Transform3D(along, Vector3(0, 0.05, -1.15)), paint_dark(), 10)
	for z in [-1.7, -2.45]:
		b.cylinder(0.135, 0.135, 0.07, Transform3D(along, Vector3(0, 0.05, z)), team_color, 10, true, 1.0)
	b.box(Vector3(0.34, 0.2, 0.36), Vector3(0, 0.05, -3.05), STEEL.darkened(0.2))
	b.glow_box(Vector3(0.2, 0.08, 0.05), Vector3(0, 0.05, -3.24), team_color * 0.6, 1.0)
