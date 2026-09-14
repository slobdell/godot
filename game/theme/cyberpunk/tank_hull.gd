extends "res://game/theme/cyberpunk/cyber_vehicle.gd"
## `tank.hull` (2.4 W × 3.6 L × ≤ 1.6 H, ground center, forward −Z; turret ring at y 1.22, z +0.2):
## a Death Race scrap tank. Treads with neon seams, a dark team-tinted hull with bolted rust skirts,
## a ram spike bar, headlights, a team light bar at the rear, and team neon deck stripes. It also
## registers the team underglow (one batched draw for all vehicles).


func _ready() -> void:
	super._ready()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.underglow.add(self, team_color)


func set_team_color(color: Color) -> void:
	super.set_team_color(color)
	var fx := FxWorld.existing()
	if fx != null and is_inside_tree():
		fx.underglow.add(self, color)


func _exit_tree() -> void:
	var fx := FxWorld.existing()
	if fx != null:
		fx.underglow.remove(self)


func build(b: ColorMeshBuilder) -> void:
	var neon := team_color
	for sx in [-1.0, 1.0]:
		# Treads, road wheels hinted by darker bands, neon seam along the outer face.
		b.box(Vector3(0.52, 0.72, 3.6), Vector3(sx * 0.94, 0.36, 0.0), RUBBER)
		for k in 5:
			b.box(Vector3(0.54, 0.5, 0.12), Vector3(sx * 0.94, 0.36, -1.4 + k * 0.7), Color(0.09, 0.09, 0.1))
		b.glow_box(Vector3(0.04, 0.05, 3.1), Vector3(sx * 1.215, 0.5, 0.0), neon * 0.8)
		# Rusty bolted skirt plates.
		b.box(Vector3(0.07, 0.34, 1.3), Vector3(sx * 1.24, 0.7, -0.75), RUST, Vector3(0, 0, sx * 0.08))
		b.box(Vector3(0.07, 0.34, 1.2), Vector3(sx * 1.24, 0.72, 0.62), RUST.darkened(0.2), Vector3(0, 0, sx * 0.06))
		# Deck stripes (visible from above).
		b.glow_box(Vector3(0.12, 0.04, 2.3), Vector3(sx * 0.82, 1.14, 0.25), neon)
		# Exhaust stacks with hot tips (heat mask).
		b.cylinder(0.08, 0.07, 0.55, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(sx * 0.62, 1.2, 1.62)), STEEL.darkened(0.3))
		b.cylinder(0.075, 0.075, 0.06, Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(sx * 0.62, 1.46, 1.72)), Color(1.0, 0.35, 0.05) * 0.5, 8, true, 1.0)
		# Headlights.
		b.glow_box(Vector3(0.32, 0.12, 0.05), Vector3(sx * 0.6, 0.86, -1.73), HEADLIGHT)
	b.box(Vector3(1.4, 0.5, 3.4), Vector3(0, 0.62, 0.0), paint_dark())
	b.box(Vector3(1.95, 0.34, 2.7), Vector3(0, 0.96, 0.15), paint())
	# Sloped glacis and the rear engine deck.
	b.box(Vector3(1.9, 0.12, 0.95), Vector3(0, 0.88, -1.45), paint(), Vector3(-0.38, 0, 0))
	b.box(Vector3(1.6, 0.2, 0.7), Vector3(0, 1.2, 1.2), paint_dark())
	for k in 4:
		b.box(Vector3(1.4, 0.03, 0.08), Vector3(0, 1.31, 0.95 + k * 0.16), STEEL.darkened(0.4))
	# Ram bar with spikes (Mad Max).
	b.box(Vector3(2.1, 0.16, 0.16), Vector3(0, 0.55, -1.78), STEEL)
	for k in 5:
		b.box(Vector3(0.09, 0.09, 0.34), Vector3(-0.9 + k * 0.45, 0.55, -1.95), STEEL.lightened(0.2))
	# Rear team light bar.
	b.glow_box(Vector3(1.5, 0.1, 0.05), Vector3(0, 0.95, 1.74), neon)
