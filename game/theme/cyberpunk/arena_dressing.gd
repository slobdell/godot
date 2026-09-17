extends "res://game/theme/cyberpunk/cyber_prop.gd"
## Cyberpunk arena dressing: a chunked textured floor (asphalt, concrete, hazard paint, drains) lit by painted
## floodlight pools (FLOODLIGHTS, art X2), blast-barrier perimeter walls with neon light bars, and the gladiator
## venue around them (art X5, the lead's approved Meshy kit, theme arena_kit): grandstands full of a cheering crowd
## (CrowdSystem) along the long sides, vehicle gates on the short sides, floodlight towers throwing fake volumetric
## beams at the corners, and static glow pools under the light bars (painted light, not real lights). Round 3 (assets
## X2): giant ad screens tower over the short walls either side of the gates, on two broadcast channels; neon signs crown
## the grandstands and gang-tagged container stacks barricade the gates (stretch).
## Ground 320×320 at y=0; perimeter walls at ±121 by default (slot contract: arena.dressing). `setup(layout)` (rules'
## C5 arena layouts) fits the walls, venue, floodlights, hazard band and center ring to the layout. Visual only, no
## collision.

## The default perimeter (walls just outside a 120 m layout's half size).
const HALF := 121.0
const WALL_HEIGHT := 3.0
const WALL_THICK := 2.0
const TOWER_INSET := 112.0
## Painted floodlight pools on the floor: [x, z, radius, intensity]. The corner towers throw theirs toward the
## center; the side pools stand in for the stands' lamps (X5). Emission only: no light passes (fx_tricks.md).
const FLOODLIGHTS := [
	Vector4(-80, -80, 75, 1.05), Vector4(80, -80, 75, 1.05), Vector4(-80, 80, 75, 1.05), Vector4(80, 80, 75, 1.05),
	Vector4(0, -62, 60, 0.6), Vector4(0, 62, 60, 0.6), Vector4(-62, 0, 60, 0.6), Vector4(62, 0, 60, 0.6),
]

## The generated arena kit (tools/assets/build_arena_kit.sh). Missing scenes fall back to the procedural pieces.
const KIT := "res://game/theme/arena_kit/generated/%s.tscn"
const AD_SCREEN := preload("res://game/theme/arena_kit/prop_ad_screen.tscn")
const CONTAINER_20 := preload("res://game/theme/arena_kit/prop_container_20.tscn")
## Screens either side of each gate, this far along the wall from its middle.
const SCREEN_OFFSET := 46.0
const STANDS_ROWS := 5

var ground: ChunkedGround
var crowd: CrowdSystem
## Walls, towers, stands, gates and the crowd: rebuilt when a layout changes the arena's size.
var structures: Node3D
## The perimeter's half size in use (walls at ±half).
var half := HALF
var _flood_maps := {}
## The last layout setup() received (its floodlight props light the floor).
var _layout := {}


func _ready() -> void:
	ground = ChunkedGround.new()
	ground.name = "Ground"
	_apply_ground_quality()
	var fx := FxWorld.get_instance()
	if fx != null:
		fx.quality_changed.connect(_apply_ground_quality)
	add_child(ground)
	_build_structures()


## C5: fit the dressing to an arena layout {half_size, control_point?, …} (rules' Arena calls this after building it).
func setup(layout: Dictionary) -> void:
	_layout = layout
	_flood_maps.clear()
	var wanted := float(layout.get("half_size", HALF - 1.0)) + 1.0
	var ring := float((layout["control_point"] as Dictionary).get("radius", 16.0)) if layout.get("control_point") is Dictionary else 0.0
	for variant in [[false, false], [true, false], [false, true]]:
		var material := CyberMaterials.ground(variant[0], variant[1])
		material.set_shader_parameter("band_inner", wanted - 13.0)
		material.set_shader_parameter("ring_radius", ring)
		material.set_shader_parameter("ring_width", 1.4 if ring > 0.0 else 0.0)
	if not is_equal_approx(wanted, half):
		half = wanted
		_build_structures()
	_apply_ground_quality()


func _build_structures() -> void:
	if structures != null:
		clear_streaks()
		structures.free()
	crowd = null
	structures = Node3D.new()
	structures.name = "Structures"
	add_child(structures)
	_build_perimeter()
	var inset := half - (HALF - TOWER_INSET)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_build_tower(Vector3(sx * inset, 0.0, sz * inset))
	_build_venue()
	# Render X5: repeated kit models (stands, towers, gates) draw as one MultiMesh per mesh.
	StaticInstancer.instance_repeats(structures)


## Stands and their crowd along the north and south walls, gates in the middle of the east and west walls.
func _build_venue() -> void:
	var stands_scene := _kit("kit_stands")
	if stands_scene != null:
		var probe := stands_scene.instantiate() as Node3D
		var size := _bounds(probe).size
		probe.free()
		var modules := int((2.0 * half) / size.x)
		var rows := []
		var signs := []
		for side in [1.0, -1.0]:  # the model's seats face -Z: the south stands as they are, the north ones turned
			for i in modules:
				var x := -half + size.x * (i + 0.5) + (2.0 * half - size.x * modules) / 2.0
				var z: float = side * (half + WALL_THICK / 2.0 + size.z / 2.0 + 0.3)
				var xform := Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(x, 0.0, z))
				var stands := stands_scene.instantiate() as Node3D
				stands.name = "Stands"
				stands.transform = xform
				structures.add_child(stands, true)
				if i % 3 == 1:  # a neon sign on every third module's top rail, facing the arena
					signs.append({"transform": xform * Transform3D(Basis(), Vector3(0.0, size.y * 0.92 + 1.0, -size.z / 2.0 + 1.5)),
							"cell": signs.size(), "color": NeonSigns.COLORS[signs.size() % NeonSigns.COLORS.size()]})
				# Seat rows climb from the front tier (~30% of the height) to the top (~80%), facing the arena.
				for r in STANDS_ROWS:
					var f := float(r) / (STANDS_ROWS - 1)
					var local_z := -size.z / 2.0 + size.z * lerpf(0.16, 0.7, f)
					var local_y := size.y * lerpf(0.32, 0.8, f)
					rows.append([xform * Vector3(-size.x / 2.0 + 1.0, local_y, local_z), xform * Vector3(size.x / 2.0 - 1.0, local_y, local_z)])
		if not signs.is_empty():
			structures.add_child(NeonSigns.build(signs))
		crowd = CrowdSystem.new()
		structures.add_child(crowd)
		crowd.seat_rows(rows)
	var gate_scene := _kit("kit_gate")
	if gate_scene != null:
		for side in [1.0, -1.0]:  # gates face -Z: turned to face the center from the east (+X) and west walls
			var gate := gate_scene.instantiate() as Node3D
			gate.name = "Gate"
			var depth := _bounds(gate).size.z
			gate.transform = Transform3D(Basis(Vector3.UP, side * PI / 2.0), Vector3(side * (half + WALL_THICK / 2.0 + depth / 2.0), 0.0, 0.0))
			structures.add_child(gate, true)
	for side in [1.0, -1.0]:  # scrap barricades: gang-tagged container stacks flanking each gate, outside the wall
		for along in [1.0, -1.0]:
			var barricade := CONTAINER_20.instantiate() as Node3D
			barricade.name = "Barricade"
			barricade.transform = Transform3D(Basis(Vector3.UP, along * 0.35 + PI / 2.0), Vector3(side * (half + WALL_THICK / 2.0 + 5.5), 0.0, along * 17.0))
			barricade.call("setup", {"stack": 2, "faction": "gangs", "doors": "open" if along < 0.0 else "closed"})
			structures.add_child(barricade, true)
	for side in [1.0, -1.0]:  # outside the east (+X) and west walls, turned so their -Z face looks at the center
		for along in [1.0, -1.0]:
			var screen := AD_SCREEN.instantiate() as Node3D
			screen.name = "AdScreen"
			screen.set("channel_name", "arena" if along * side > 0.0 else "odds")
			screen.transform = Transform3D(Basis(Vector3.UP, side * PI / 2.0),
					Vector3(side * (half + WALL_THICK / 2.0 + 4.0), 0.0, along * minf(SCREEN_OFFSET, half * 0.45)))
			structures.add_child(screen, true)


## FX lab: hide the venue (stands, crowd, gates) to measure what it costs.
func set_venue_visible(shown: bool) -> void:
	for child in structures.get_children():
		if child.name.begins_with("Stands") or child.name.begins_with("Gate") or child.name.begins_with("AdScreen") \
				or child.name == "NeonSigns" or child == crowd or child.name.begins_with("Instanced_"):
			(child as Node3D).visible = shown


func _kit(file: String) -> PackedScene:
	var path := KIT % file
	return load(path) as PackedScene if ResourceLoader.exists(path) else null


static func _bounds(node: Node3D) -> AABB:
	var result := AABB()
	var first := true
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		if instance.mesh == null:
			continue
		var box := instance.mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result


## The floodlight pools baked into a small light map for the ground shader (RGB = light / FLOOD_SCALE over ±FLOOD_HALF m):
## one texture fetch per pixel instead of a loop over lamps in every light pass. Render (round 5): in color, so the
## venue's cool towers and the layout's sodium floodlights read as different light, and the floor has a sense of place.
const FLOOD_HALF := 160.0
const FLOOD_SCALE := 2.0
const FLOOD_MAP_SIZE := 64
## The venue towers' cool metal-halide white, and a layout floodlight's warm sodium.
const TOWER_LIGHT := Color(0.86, 0.92, 1.0)
const SODIUM_LIGHT := Color(1.0, 0.72, 0.4)
## A layout floodlight's pool: this far ahead of the tower (m), this radius, this bright.
const LAYOUT_POOL := Vector3(16.0, 34.0, 1.1)


## `lamps`: Vector4(x, z, radius, intensity) for white light, or [Vector4, Color].
static func flood_map(lamps: Array) -> ImageTexture:
	var image := Image.create(FLOOD_MAP_SIZE, FLOOD_MAP_SIZE, false, Image.FORMAT_RGB8)
	for y in FLOOD_MAP_SIZE:
		for x in FLOOD_MAP_SIZE:
			var world := (Vector2(x, y) + Vector2(0.5, 0.5)) / FLOOD_MAP_SIZE * 2.0 * FLOOD_HALF - Vector2(FLOOD_HALF, FLOOD_HALF)
			var light := Color(0, 0, 0)
			for entry in lamps:
				var lamp: Vector4 = entry[0] if entry is Array else entry
				var tint: Color = entry[1] if entry is Array else Color.WHITE
				var falloff := 1.0 - clampf(world.distance_to(Vector2(lamp.x, lamp.y)) / lamp.z, 0.0, 1.0)
				light += tint * (falloff * falloff * (3.0 - 2.0 * falloff) * lamp.w)
			image.set_pixel(x, y, Color(clampf(light.r / FLOOD_SCALE, 0.0, 1.0), clampf(light.g / FLOOD_SCALE, 0.0, 1.0),
					clampf(light.b / FLOOD_SCALE, 0.0, 1.0)))
	return ImageTexture.create_from_image(image)


## Pools thrown by a layout's own floodlight towers (M2 `props` of type floodlight; their lamps face the prop's -Z).
static func layout_lamps(layout: Dictionary) -> Array:
	var result := []
	for prop: Dictionary in layout.get("props", []):
		if String(prop.get("type", "")) != "floodlight":
			continue
		var at := Vector2(float(prop["position"][0]), float(prop["position"][1]))
		var ahead := Vector2(0.0, -1.0).rotated(-deg_to_rad(float(prop.get("rotation_deg", 0.0))))
		var center := at + ahead * LAYOUT_POOL.x
		result.append([Vector4(center.x, center.y, LAYOUT_POOL.y, LAYOUT_POOL.z), SODIUM_LIGHT])
	return result


## FLOODLIGHTS moved with the arena's size (cool tower light), plus the layout's own floodlights (sodium).
func _scaled_floodlights() -> Array:
	var k := half / HALF
	var lamps: Array = FLOODLIGHTS.map(func(lamp: Vector4) -> Array: return [Vector4(lamp.x * k, lamp.y * k, lamp.z * k, lamp.w), TOWER_LIGHT])
	return lamps + layout_lamps(_layout)


func set_chunked(chunked: bool) -> void:
	ground.chunked = chunked
	ground.build()


## The floor shader follows the FX tier: full detail lit in its own shader on high (render X5: -0.6 ms GPU at 720p), lite
## on low and medium.
func _apply_ground_quality() -> void:
	set_ground_style("lite" if FxQuality.tier() < FxQuality.Tier.HIGH else "unlit")


## FX lab comparisons: "textured" (the high-tier floor), "lite" (low/medium), "wet" (round 1's procedural asphalt),
## "flat" (plain material).
func set_ground_style(style: String) -> void:
	var material: Material = ground.material
	match style:
		"lite", "textured", "unlit":
			material = CyberMaterials.ground(style == "lite", style == "unlit")
			if not _flood_maps.has("map"):
				_flood_maps["map"] = flood_map(_scaled_floodlights())
			(material as ShaderMaterial).set_shader_parameter("flood_map", _flood_maps["map"])
		"wet":
			material = ShaderMaterial.new()
			(material as ShaderMaterial).shader = preload("res://game/theme/fx/shaders/wet_ground.gdshader")
		"flat":
			material = StandardMaterial3D.new()
			(material as StandardMaterial3D).albedo_color = Color(0.2, 0.2, 0.22)
		_:
			push_warning("unknown ground style '%s'" % style)
	# Render X5: the unlit floor takes no light passes, so tiles only cost draw calls: one plane instead.
	var chunked := style != "unlit"
	if material != ground.material or chunked != ground.chunked:
		ground.material = material
		ground.chunked = chunked
		ground.build()


func _build_perimeter() -> void:
	var concrete := CyberMaterials.surface(Color(0.09, 0.09, 0.1), 0.7, 0.1)
	var rail := CyberMaterials.surface(Color(0.16, 0.12, 0.1), 0.45, 0.6)
	var span := 2.0 * half + 2.0
	var sides := [
		[Vector3(0, 0, -half), Vector3(span, 0, WALL_THICK), CyberMaterials.PURPLE, 1.0],
		[Vector3(0, 0, half), Vector3(span, 0, WALL_THICK), CyberMaterials.PURPLE, -1.0],
		[Vector3(half, 0, 0), Vector3(WALL_THICK, 0, span), CyberMaterials.PURPLE, -1.0],
		[Vector3(-half, 0, 0), Vector3(WALL_THICK, 0, span), CyberMaterials.PURPLE, 1.0],
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
		structures.add_child(segment, true)
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
	structures.add_child(glow_pools)


func _build_tower(base: Vector3) -> void:
	var steel := CyberMaterials.surface(Color(0.12, 0.11, 0.1), 0.5, 0.7)
	var height := 16.0
	var tower := Node3D.new()
	tower.name = "Tower"
	structures.add_child(tower, true)
	var toward_center := -base.normalized()
	var kit_tower := _kit("kit_floodlight_tower")
	var lamp_pos: Vector3
	if kit_tower != null:
		# The generated tower (lamp bank on top, facing -Z) turned toward the center.
		var model := kit_tower.instantiate() as Node3D
		height = _bounds(model).size.y
		model.transform = Transform3D(Basis(Vector3.UP, atan2(-toward_center.x, -toward_center.z)), base)
		structures.add_child(model)
		lamp_pos = base + Vector3(0, height * 0.9, 0) + toward_center * 1.5
	else:
		CyberMaterials.box(tower, Vector3(1.2, height, 1.2), base + Vector3(0, height / 2.0, 0), steel)
		CyberMaterials.box(tower, Vector3(4.0, 0.8, 1.6), base + Vector3(0, height, 0), steel)
		# Lamp faces: hot white neon.
		lamp_pos = base + Vector3(0, height - 0.3, 0) + toward_center * 0.9
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
	structures.add_child(pool)


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
