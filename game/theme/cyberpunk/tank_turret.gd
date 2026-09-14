extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## `tank.turret` (~1.4 × 1.7 × 0.55, pivot at the turret ring, rotates about +Y): an angular armored
## turret with a mantlet, a sensor pod, a whip antenna with a red tip, and a team neon crest stripe
## across the roof so the turret heading reads from above.


func build(b: ColorMeshBuilder) -> void:
	var neon := team_color
	b.box(Vector3(1.3, 0.44, 1.5), Vector3(0, 0.12, 0.05), paint())
	b.box(Vector3(1.0, 0.16, 1.1), Vector3(0, 0.4, 0.15), paint_dark())
	# Angled cheeks.
	for sx in [-1.0, 1.0]:
		b.box(Vector3(0.12, 0.4, 1.1), Vector3(sx * 0.68, 0.12, -0.25), paint_dark(), Vector3(0, sx * 0.35, 0))
	b.box(Vector3(0.62, 0.36, 0.3), Vector3(0, 0.1, -0.78), STEEL.darkened(0.25))
	# Sensor pod with a team eye.
	b.box(Vector3(0.28, 0.2, 0.34), Vector3(0.48, 0.55, -0.15), STEEL.darkened(0.3))
	b.glow_box(Vector3(0.18, 0.08, 0.03), Vector3(0.48, 0.56, -0.33), neon)
	# Crest: a stripe pointing along the barrel (reads as heading from the tactical view).
	b.glow_box(Vector3(0.14, 0.03, 1.2), Vector3(-0.22, 0.49, 0.1), neon)
	# Antenna.
	b.box(Vector3(0.025, 1.1, 0.025), Vector3(-0.5, 0.95, 0.55), STEEL)
	b.glow_box(Vector3(0.06, 0.06, 0.06), Vector3(-0.5, 1.5, 0.55), Color(1.0, 0.1, 0.15))
	# Rear stowage.
	b.box(Vector3(1.1, 0.28, 0.25), Vector3(0, 0.05, 0.9), RUST.darkened(0.3))
