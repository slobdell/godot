class_name NightSky
extends MeshInstance3D
## The night sky over the arena (feel X4, round 6), drawn on a dome instead of the Environment's Sky: a Sky resource in
## the Compatibility renderer leaked its radiance textures across the title -> skirmish scene switch (control's
## shell-playtest: "Texture with GL ID ... leaked 5460 bytes"; confirmed by toggling only the sky on builder0). A mesh
## owns no render targets, so there is nothing to leak. One draw call; the Environment keeps its flat background colour.

## Inside the camera's far plane (1200 m) and outside the city ring (640 m).
const RADIUS := 1000.0
const SHADER := preload("res://game/theme/fx/shaders/night_sky.gdshader")


func _init() -> void:
	name = "NightSky"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	var dome := SphereMesh.new()
	dome.radius = RADIUS
	dome.height = RADIUS * 2.0
	dome.radial_segments = 32
	dome.rings = 16
	mesh = dome
	var material := ShaderMaterial.new()
	material.shader = SHADER
	# Round 16 (R3): drawn LAST among opaque things. Sorted front to back it went first (its centre is near the camera)
	# and shaded every pixel of the screen before the arena painted over them; last, with the depth test, it shades
	# only the sky he sees. It writes no depth, so nothing drawn after could tell. 0.33 ms GPU at his window (laptop,
	# sky + skyline + city ground together, frozen within-run A/B `sky_r15`).
	material.render_priority = Material.RENDER_PRIORITY_MAX
	material_override = material
	extra_cull_margin = 16384.0
