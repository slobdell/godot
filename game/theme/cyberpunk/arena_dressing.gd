extends "res://game/theme/cyberpunk/cyber_prop.gd"
## Cyberpunk arena dressing: a chunked textured floor (asphalt, concrete, hazard paint, drains) lit by painted
## floodlight pools (FLOODLIGHTS, art X2), blast-barrier perimeter walls with neon
## light bars, corner floodlight towers throwing fake volumetric beams, and static glow pools
## under the light bars (painted light, not real lights). Ground 320×320 at y=0; perimeter walls
## at ±121 (slot contract: arena.dressing).

const HALF := 121.0
const WALL_HEIGHT := 3.0
const WALL_THICK := 2.0
const TOWER_INSET := 112.0
## Painted floodlight pools on the floor: [x, z, radius, intensity]. The corner towers throw theirs toward the
## center; the side pools stand in for the stands' lamps (X5). Emission only: no light passes (fx_tricks.md).
const FLOODLIGHTS := [
	Vector4(-80, -80, 75, 0.75), Vector4(80, -80, 75, 0.75), Vector4(-80, 80, 75, 0.75), Vector4(80, 80, 75, 0.75),
	Vector4(0, -62, 60, 0.55), Vector4(0, 62, 60, 0.55), Vector4(-62, 0, 60, 0.55), Vector4(62, 0, 60, 0.55),
]

var ground: ChunkedGround
var _flood_maps := {}


func _ready() -> void:
	ground = ChunkedGround.new()
	ground.name = "Ground"
	_apply_ground_quality()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.quality_changed.connect(_apply_ground_quality)
	add_child(ground)
	_build_perimeter()
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_build_tower(Vector3(sx * TOWER_INSET, 0.0, sz * TOWER_INSET))


## The floodlight pools baked into a small light map for the ground shader (R = intensity / FLOOD_SCALE over
## ±FLOOD_HALF m): one texture fetch per pixel instead of a loop over lamps in every light pass.
const FLOOD_HALF := 160.0
const FLOOD_SCALE := 2.0
const FLOOD_MAP_SIZE := 64


static func flood_map(lamps: Array) -> ImageTexture:
	var image := Image.create(FLOOD_MAP_SIZE, FLOOD_MAP_SIZE, false, Image.FORMAT_L8)
	for y in FLOOD_MAP_SIZE:
		for x in FLOOD_MAP_SIZE:
			var world := (Vector2(x, y) + Vector2(0.5, 0.5)) / FLOOD_MAP_SIZE * 2.0 * FLOOD_HALF - Vector2(FLOOD_HALF, FLOOD_HALF)
			var light := 0.0
			for lamp: Vector4 in lamps:
				var falloff := 1.0 - clampf(world.distance_to(Vector2(lamp.x, lamp.y)) / lamp.z, 0.0, 1.0)
				light += falloff * falloff * (3.0 - 2.0 * falloff) * lamp.w
			var v := clampf(light / FLOOD_SCALE, 0.0, 1.0)
			image.set_pixel(x, y, Color(v, v, v))
	return ImageTexture.create_from_image(image)


func set_chunked(chunked: bool) -> void:
	ground.chunked = chunked
	ground.build()


## The floor shader follows the FX tier: full on high, lite on low and medium.
func _apply_ground_quality() -> void:
	set_ground_style("lite" if FxQuality.tier() < FxQuality.Tier.HIGH else "textured")


## FX lab comparisons: "textured" (the high-tier floor), "lite" (low/medium), "wet" (round 1's procedural asphalt),
## "flat" (plain material).
func set_ground_style(style: String) -> void:
	var material: Material = ground.material
	match style:
		"lite", "textured":
			material = CyberMaterials.ground(style == "lite")
			if not _flood_maps.has("map"):
				_flood_maps["map"] = flood_map(FLOODLIGHTS)
			(material as ShaderMaterial).set_shader_parameter("flood_map", _flood_maps["map"])
		"wet":
			material = ShaderMaterial.new()
			(material as ShaderMaterial).shader = preload("res://game/theme/fx/shaders/wet_ground.gdshader")
		"flat":
			material = StandardMaterial3D.new()
			(material as StandardMaterial3D).albedo_color = Color(0.2, 0.2, 0.22)
		_:
			push_warning("unknown ground style '%s'" % style)
	if material != ground.material:
		ground.material = material
		ground.build()


func _build_perimeter() -> void:
	var concrete := CyberMaterials.surface(Color(0.09, 0.09, 0.1), 0.7, 0.1)
	var rail := CyberMaterials.surface(Color(0.16, 0.12, 0.1), 0.45, 0.6)
	var sides := [
		[Vector3(0, 0, -HALF), Vector3(244, 0, WALL_THICK), CyberMaterials.PURPLE, 1.0],
		[Vector3(0, 0, HALF), Vector3(244, 0, WALL_THICK), CyberMaterials.PURPLE, -1.0],
		[Vector3(HALF, 0, 0), Vector3(WALL_THICK, 0, 244), CyberMaterials.PURPLE, -1.0],
		[Vector3(-HALF, 0, 0), Vector3(WALL_THICK, 0, 244), CyberMaterials.PURPLE, 1.0],
	]
	var glow_pools := MultiMeshInstance3D.new()
	var pools: Array[Transform3D] = []
	var pool_colors: Array[Color] = []
	for side in sides:
		var center: Vector3 = side[0]
		var extent: Vector3 = side[1]
		var neon_color: Color = side[2]
		var inward: float = side[3]
		var segment := Node3D.new()
		segment.name = "Perimeter"
		add_child(segment)
		CyberMaterials.box(segment, Vector3(extent.x, WALL_HEIGHT, extent.z), center + Vector3(0, WALL_HEIGHT / 2.0, 0), concrete)
		CyberMaterials.box(segment, Vector3(maxf(extent.x, 2.6), 0.35, maxf(extent.z, 2.6)),
				center + Vector3(0, WALL_HEIGHT + 0.17, 0), rail)
		# A light bar along the rim top: the arena's glowing outline from the tactical camera.
		var rim_size := Vector2(extent.x, 0.9) if extent.x > extent.z else Vector2(0.9, extent.z)
		CyberMaterials.top_quad(segment, rim_size, center + Vector3(0, WALL_HEIGHT + 0.36, 0),
				CyberMaterials.neon(neon_color, 0.9, 0.03))
		# The light bar runs along the inner face, just under the rim.
		var along_x := extent.x > extent.z
		var bar_size := Vector3(extent.x - 8.0, 0.18, 0.12) if along_x else Vector3(0.12, 0.18, extent.z - 8.0)
		var face := Vector3(0, 0, inward * (WALL_THICK / 2.0 + 0.07)) if along_x else Vector3(inward * (WALL_THICK / 2.0 + 0.07), 0, 0)
		CyberMaterials.box(segment, bar_size, center + face + Vector3(0, WALL_HEIGHT - 0.35, 0),
				CyberMaterials.neon(neon_color, 4.0, 0.05), false)
		CyberMaterials.box(segment, bar_size * Vector3(1, 0.4, 1), center + face + Vector3(0, 0.5, 0),
				CyberMaterials.neon(neon_color, 2.0, 0.3), false)
		StaticBatcher.merge(segment)
		# Painted glow pools on the floor along the bar (one batched draw for all of them).
		var length := extent.x if along_x else extent.z
		var count := int(length / 14.0)
		for i in count:
			var t := -length / 2.0 + (i + 0.5) * length / count
			var offset := Vector3(t, 0.04, inward * 5.0) if along_x else Vector3(inward * 5.0, 0.04, t)
			var pool_basis := Basis.from_scale(Vector3(26.0, 1.0, 12.0) if along_x else Vector3(12.0, 1.0, 26.0))
			pools.append(Transform3D(pool_basis, Vector3(center.x, 0.0, center.z) + offset))
			pool_colors.append(neon_color * 0.22)
			# A reflection streak from the foot of the light bar (just inside the wall).
			var foot := Vector3(t, 0.0, center.z + inward * 1.4) if along_x else Vector3(center.x + inward * 1.4, 0.0, t)
			add_streak(foot, neon_color, 14.0, 5.0, 0.35)
	glow_pools.name = "GlowPools"
	glow_pools.multimesh = _glow_multimesh(pools, pool_colors)
	glow_pools.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow_pools)


func _build_tower(base: Vector3) -> void:
	var steel := CyberMaterials.surface(Color(0.12, 0.11, 0.1), 0.5, 0.7)
	var height := 16.0
	var tower := Node3D.new()
	tower.name = "Tower"
	add_child(tower)
	CyberMaterials.box(tower, Vector3(1.2, height, 1.2), base + Vector3(0, height / 2.0, 0), steel)
	CyberMaterials.box(tower, Vector3(4.0, 0.8, 1.6), base + Vector3(0, height, 0), steel)
	# Lamp faces: hot white neon.
	var toward_center := -base.normalized()
	var lamp_pos := base + Vector3(0, height - 0.3, 0) + toward_center * 0.9
	CyberMaterials.box(tower, Vector3(3.2, 0.4, 0.3), lamp_pos, CyberMaterials.neon(Color(0.85, 0.95, 1.0), 6.0, 0.02), false)
	# Beam: an open cone from the lamp angled down toward the arena.
	var target := base * 0.78
	var beam_length := lamp_pos.distance_to(target)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.6
	cone.bottom_radius = 9.0
	cone.height = beam_length
	cone.cap_top = false
	cone.cap_bottom = false
	cone.radial_segments = 16
	cone.material = CyberMaterials.beam(Color(0.55, 0.8, 1.0), 0.14)
	var beam := MeshInstance3D.new()
	beam.name = "Beam"
	beam.mesh = cone
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tower.add_child(beam)
	# Cylinder axis is +Y with the top (UV 0) up: point -Y from the lamp toward the target.
	var down := (target - lamp_pos).normalized()
	var axis_y := -down
	var axis_x := axis_y.cross(Vector3.FORWARD).normalized()
	if axis_x.length() < 0.1:
		axis_x = Vector3.RIGHT
	var axis_z := axis_x.cross(axis_y).normalized()
	beam.transform = Transform3D(Basis(axis_x, axis_y, axis_z), lamp_pos + down * beam_length / 2.0)
	StaticBatcher.merge(tower)
	# A painted light pool where the beam lands.
	add_streak(Vector3(target.x, 0.0, target.z), Color(0.55, 0.75, 1.0), 26.0, 7.0, 0.35)
	var pool := MultiMeshInstance3D.new()
	pool.name = "BeamPool"
	pool.multimesh = _glow_multimesh([Transform3D(Basis.from_scale(Vector3(22, 1, 22)), Vector3(target.x, 0.04, target.z))],
			[Color(0.35, 0.5, 0.7) * 0.5])
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)


## Static additive glow quads (reuses the projectile splat shader: radial falloff × color).
static func _glow_multimesh(transforms: Array, colors: Array) -> MultiMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.get_mesh_arrays())
	var material := ShaderMaterial.new()
	material.shader = TracerSystem.SPLAT_SHADER
	mesh.surface_set_material(0, material)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()
	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])
		multimesh.set_instance_color(i, colors[i])
		multimesh.set_instance_custom_data(i, Color(1, 0, 0, 0))
	return multimesh
