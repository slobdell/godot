extends SceneTree
## A4 procedural cyberpunk kit: arena props built from primitives with emissive neon, run through
## the same normalize → GLB → wrapper → manifest pipeline as downloaded or generated models.
## Fallback and filler art that needs no account or download; look & feel decides what fills slots.
##
##   godot --headless --path . --script res://assets/pipeline/procedural_kit.gd [-- --theme=neon_kit]
##   make assets-procedural
##
## Materials are named so the generated wrapper can drive them:
##   neon_team*  → team-colored neon (set_team_color)     paint*  → team tint
##   neon_*, lamp, sign, hazard  → fixed emissive colors (the arena's own lights)
## Everything is seeded, so re-running produces identical GLBs.

const THEME := "neon_kit"
const SEED := 20260914

## Palette from look_and_feel.md (mavlink-hud): cyan #00F3FF, pink #FF0099, purple #D900FF, green #39FF14.
const CYAN := Color(0.0, 0.953, 1.0)
const PINK := Color(1.0, 0.0, 0.6)
const PURPLE := Color(0.851, 0.0, 1.0)
const AMBER := Color(1.0, 0.62, 0.05)

var _materials := {}
var _rng := RandomNumberGenerator.new()


func _initialize() -> void:
	var theme := THEME
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--theme="):
			theme = arg.trim_prefix("--theme=")
	_rng.seed = SEED
	var builders := {
		"prop.crate": _neon_crate_stack,
		"prop.wall": _blast_barrier_wall,
		"kit.container": _container,
		"kit.barrier": _jersey_barrier,
		"kit.light_pole": _light_pole,
		"kit.billboard": _billboard,
		"kit.scrap_pile": _scrap_pile,
	}
	var materials := {"tint": ["paint*"], "team_emissive": ["neon_team*"], "heat": []}
	var manifest := AssetIO.read_manifest(theme)
	manifest["theme"] = theme
	var failed := false
	for slot in builders:
		var model: Node3D = builders[slot].call()
		var result := AssetNormalizer.normalize(model, slot, {"forward": "-z"})
		model.free()
		var scene: Node3D = result["scene"]
		var glb_path := "%s/%s.glb" % [AssetIO.generated_dir(theme), AssetContracts.get_contract(slot)["file"]]
		var error := AssetIO.save_glb(scene, glb_path)
		var report := AssetInspector.inspect(scene)
		scene.free()
		var check := AssetChecker.check_report(report, slot)
		manifest["slots"][slot] = {
			"glb": glb_path.get_file(), "scene": AssetIO.write_wrapper(theme, slot, materials).get_file(),
			"source": "res://assets/pipeline/procedural_kit.gd (seed %d)" % SEED,
			"license": "project-owned (procedurally generated)", "credit": "Tank Squad assets stream",
			"options": {"materials": materials}, "tris": report["tris"], "notes": Array(result["notes"]),
		}
		print("%-15s %5d tris  %.1f × %.1f × %.1f m  %s%s" % [slot, report["tris"], report["aabb"].size.x,
				report["aabb"].size.y, report["aabb"].size.z, "OK" if check["errors"].is_empty() else "CONTRACT: " + "; ".join(check["errors"]),
				"" if error == OK else " (write failed)"])
		failed = failed or error != OK or not check["errors"].is_empty()
	AssetIO.write_manifest(theme, manifest)
	quit(1 if failed else 0)


# ---- props ------------------------------------------------------------------------------------

## prop.crate (4.5 × 3 × 4.5): two stacked cargo pods with team neon edges and a hazard beacon.
func _neon_crate_stack() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(4.4, 1.9, 4.4), Vector3(0, 0.95, 0), "paint_hull")
	_box(root, Vector3(3.2, 1.05, 3.4), Vector3(0.3, 2.43, -0.2), "rust_metal", Vector3(0, 12, 0))
	_ribs(root, Vector3(4.4, 1.9, 4.4), Vector3(0, 0.95, 0), 7)
	for x in [-2.22, 2.22]:
		for z in [-2.22, 2.22]:
			_box(root, Vector3(0.08, 1.9, 0.08), Vector3(x, 0.95, z), "neon_team")
	_box(root, Vector3(4.5, 0.08, 0.08), Vector3(0, 1.9, 2.22), "neon_team")
	_box(root, Vector3(4.5, 0.08, 0.08), Vector3(0, 1.9, -2.22), "neon_team")
	_cylinder(root, 0.18, 0.25, Vector3(1.2, 3.08, 0.6), "hazard")
	return root


## prop.wall (18 × 3 × 1.5): concrete blast barrier segments with a light bar and holo-ad panels.
func _blast_barrier_wall() -> Node3D:
	var root := Node3D.new()
	for i in 6:
		var x := -7.5 + i * 3.0
		_prism(root, [Vector2(-0.75, 0), Vector2(0.75, 0), Vector2(0.45, 0.6), Vector2(0.3, 3.0), Vector2(-0.3, 3.0), Vector2(-0.45, 0.6)],
				2.9, Vector3(x, 0, 0), "concrete")
		_box(root, Vector3(2.9, 0.1, 0.06), Vector3(x, 2.2, 0.36), "neon_team" if i % 2 == 0 else "neon_pink")
		_box(root, Vector3(2.9, 0.1, 0.06), Vector3(x, 2.2, -0.36), "neon_team" if i % 2 == 0 else "neon_pink")
	_panel(root, Vector2(2.6, 1.0), Vector3(-4.5, 1.5, 0.56), "sign", Vector3(-11, 0, 0))
	_panel(root, Vector2(2.6, 1.0), Vector3(4.5, 1.5, -0.56), "sign", Vector3(-11, 180, 0))
	return root


## kit.container: a 20 ft shipping container, corrugated, neon strip along the roof edges.
func _container() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(2.4, 2.5, 6.0), Vector3(0, 1.25, 0), "paint_container")
	_ribs(root, Vector3(2.4, 2.5, 6.0), Vector3(0, 1.25, 0), 12)
	_box(root, Vector3(2.44, 0.12, 6.06), Vector3(0, 2.52, 0), "rust_metal")
	for x in [-1.21, 1.21]:
		_box(root, Vector3(0.06, 0.06, 6.0), Vector3(x, 2.5, 0), "neon_cyan")
	_box(root, Vector3(2.2, 2.3, 0.05), Vector3(0, 1.2, 3.02), "rust_metal")
	_box(root, Vector3(0.05, 2.2, 0.08), Vector3(0, 1.2, 3.06), "neon_pink")
	return root


## kit.barrier: a jersey barrier with an underglow strip on both faces.
func _jersey_barrier() -> Node3D:
	var root := Node3D.new()
	_prism(root, [Vector2(-0.4, 0), Vector2(0.4, 0), Vector2(0.26, 0.3), Vector2(0.12, 1.05), Vector2(-0.12, 1.05), Vector2(-0.26, 0.3)],
			3.0, Vector3.ZERO, "concrete")
	_box(root, Vector3(2.9, 0.05, 0.04), Vector3(0, 0.2, 0.34), "neon_team")
	_box(root, Vector3(2.9, 0.05, 0.04), Vector3(0, 0.2, -0.34), "neon_team")
	_box(root, Vector3(0.5, 0.18, 0.02), Vector3(-0.9, 0.62, 0.21), "hazard", Vector3(-21, 0, 0))
	return root


## kit.light_pole: an 8 m street light with a hooded lamp and a pink ring light at eye level.
func _light_pole() -> Node3D:
	var root := Node3D.new()
	_box(root, Vector3(0.7, 0.3, 0.7), Vector3(0, 0.15, 0), "concrete")
	_cylinder(root, 0.11, 7.6, Vector3(0, 3.95, 0), "rust_metal")
	_box(root, Vector3(0.12, 0.12, 2.6), Vector3(0, 7.6, -1.2), "rust_metal")
	_box(root, Vector3(0.5, 0.2, 0.9), Vector3(0, 7.5, -2.3), "rust_metal")
	_box(root, Vector3(0.36, 0.05, 0.7), Vector3(0, 7.38, -2.3), "lamp")
	_cylinder(root, 0.16, 0.12, Vector3(0, 2.4, 0), "neon_pink")
	_box(root, Vector3(0.05, 4.6, 0.05), Vector3(0, 4.9, -0.13), "neon_team")
	_box(root, Vector3(0.52, 0.04, 0.04), Vector3(0, 7.62, -2.77), "lamp")
	return root


## kit.billboard: a two-legged neon sign with a procedurally drawn "ad" texture.
func _billboard() -> Node3D:
	var root := Node3D.new()
	for x in [-3.0, 3.0]:
		_box(root, Vector3(0.25, 3.0, 0.25), Vector3(x, 1.5, 0), "rust_metal")
	_box(root, Vector3(7.6, 3.0, 0.4), Vector3(0, 4.5, 0), "rust_metal")
	_panel(root, Vector2(7.2, 2.7), Vector3(0, 4.5, 0.21), "sign")
	_box(root, Vector3(7.6, 0.08, 0.08), Vector3(0, 6.04, 0.2), "neon_purple")
	_box(root, Vector3(7.6, 0.08, 0.08), Vector3(0, 2.96, 0.2), "neon_purple")
	return root


## kit.scrap_pile: a seeded heap of plates, drums, and a dead neon tube.
func _scrap_pile() -> Node3D:
	var root := Node3D.new()
	for i in 14:
		var size := Vector3(_rng.randf_range(0.6, 2.2), _rng.randf_range(0.1, 0.6), _rng.randf_range(0.6, 2.0))
		var at := Vector3(_rng.randf_range(-1.8, 1.8), _rng.randf_range(0.1, 1.3) * (1.0 - float(i) / 20.0), _rng.randf_range(-1.8, 1.8))
		_box(root, size, at, "rust_metal" if i % 3 else "paint_scrap", Vector3(_rng.randf_range(-25, 25), _rng.randf_range(0, 180), _rng.randf_range(-25, 25)))
	for i in 3:
		_cylinder(root, 0.3, 0.9, Vector3(_rng.randf_range(-2, 2), 0.45, _rng.randf_range(-2, 2)), "rust_metal", Vector3(0, 0, 90 if i == 1 else 0))
	_box(root, Vector3(1.6, 0.06, 0.06), Vector3(0.4, 0.9, 0.2), "neon_cyan", Vector3(0, 30, 18))
	return root


# ---- primitives -------------------------------------------------------------------------------

func _box(parent: Node3D, size: Vector3, at: Vector3, material: String, rotation_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, material, rotation_deg)


## A one-sided quad facing +Z with the full texture on it (BoxMesh splits UVs across six faces).
func _panel(parent: Node3D, size: Vector2, at: Vector3, material: String, rotation_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	return _add(parent, mesh, at, material, rotation_deg)


func _cylinder(parent: Node3D, radius: float, height: float, at: Vector3, material: String, rotation_deg := Vector3.ZERO) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _add(parent, mesh, at, material, rotation_deg)


## Vertical ribs on the long sides of a box (corrugated metal read at a distance).
func _ribs(parent: Node3D, size: Vector3, center: Vector3, count: int) -> void:
	for side in [-1.0, 1.0]:
		for i in count:
			var z := -size.z / 2.0 + size.z * (i + 0.5) / count
			_box(parent, Vector3(0.05, size.y * 0.86, size.z / count * 0.35), center + Vector3(side * (size.x / 2.0 + 0.02), 0, z), "rust_metal")


## Extrudes a closed 2D profile (x across, y up) along X, centered on `at`. Flat-shaded.
func _prism(parent: Node3D, profile: Array, length: float, at: Vector3, material: String) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := length / 2.0
	var count := profile.size()
	for i in count:  # side quads
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[(i + 1) % count]
		var quad := [Vector3(-half, a.y, a.x), Vector3(-half, b.y, b.x), Vector3(half, b.y, b.x), Vector3(half, a.y, a.x)]
		_quad(tool, quad)
	for cap in [-1.0, 1.0]:  # end caps (fan)
		for i in range(1, count - 1):
			var points := [profile[0], profile[i], profile[i + 1]]
			var tri := []
			for p in points:
				tri.append(Vector3(cap * half, p.y, p.x))
			if cap < 0:
				tri.reverse()
			for v in tri:
				tool.set_uv(Vector2(v.z, v.y))
				tool.add_vertex(v)
	tool.generate_normals()
	var mesh := tool.commit()
	return _add(parent, mesh, at, material, Vector3.ZERO)


func _quad(tool: SurfaceTool, quad: Array) -> void:
	for index in [0, 2, 1, 0, 3, 2]:
		var v: Vector3 = quad[index]
		tool.set_uv(Vector2(v.x, v.y))
		tool.add_vertex(v)


func _add(parent: Node3D, mesh: Mesh, at: Vector3, material: String, rotation_deg: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation_deg
	if mesh is PrimitiveMesh:
		(mesh as PrimitiveMesh).material = _material(material)
	else:
		(mesh as ArrayMesh).surface_set_material(0, _material(material))
	parent.add_child(instance)
	return instance


func _material(material_name: String) -> StandardMaterial3D:
	if _materials.has(material_name):
		return _materials[material_name]
	var material := StandardMaterial3D.new()
	material.resource_name = material_name
	match material_name:
		"paint_hull", "paint_container", "paint_scrap":
			material.albedo_color = Color(0.24, 0.25, 0.29)
			material.albedo_texture = _grime_texture(Color(0.72, 0.72, 0.75), 11)
			material.metallic = 0.5
			material.roughness = 0.55
		"rust_metal":
			material.albedo_color = Color(0.36, 0.2, 0.12)
			material.albedo_texture = _grime_texture(Color(0.9, 0.75, 0.6), 23)
			material.metallic = 0.6
			material.roughness = 0.8
		"concrete":
			material.albedo_color = Color(0.3, 0.3, 0.31)
			material.albedo_texture = _grime_texture(Color(0.85, 0.85, 0.85), 37)
			material.roughness = 0.95
		"sign":
			material.albedo_texture = _sign_texture()
			material.emission_enabled = true
			material.emission_texture = material.albedo_texture
			material.emission_energy_multiplier = 2.5
		"lamp":
			_glow(material, Color(1.0, 0.93, 0.8), 6.0)
		"hazard":
			_glow(material, AMBER, 4.0)
		"neon_team":
			_glow(material, CYAN, 4.0)
		"neon_cyan":
			_glow(material, CYAN, 4.0)
		"neon_pink":
			_glow(material, PINK, 4.0)
		"neon_purple":
			_glow(material, PURPLE, 4.0)
	_materials[material_name] = material
	return material


func _glow(material: StandardMaterial3D, color: Color, energy: float) -> void:
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy


## 128² grayscale grime (multiplied with albedo_color): cheap surface breakup that reads at RTS zoom.
func _grime_texture(tint: Color, noise_seed: int) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = noise_seed
	noise.frequency = 0.05
	noise.fractal_octaves = 3
	var image := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var value := 0.72 + 0.28 * noise.get_noise_2d(x, y)
			image.set_pixel(x, y, Color(tint.r * value, tint.g * value, tint.b * value))
	return ImageTexture.create_from_image(image)


## 256×96 neon "advert": four bold glyph-like characters and a slogan bar in pink/cyan on near-black,
## with scanlines. Strokes are 7 px so they still read from the tactical camera.
func _sign_texture() -> ImageTexture:
	var image := Image.create(256, 96, false, Image.FORMAT_RGB8)
	image.fill(Color(0.03, 0.01, 0.06))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var bounds := Rect2i(0, 0, 256, 96)
	for character in 4:
		var origin := Vector2i(14 + character * 48, 12)
		var color := PINK if character % 2 == 0 else CYAN
		image.fill_rect(Rect2i(origin.x, origin.y + rng.randi_range(0, 8), 38, 7), color)  # top bar
		image.fill_rect(Rect2i(origin.x + rng.randi_range(4, 26), origin.y, 7, 50), color)  # stem
		image.fill_rect(Rect2i(origin.x + rng.randi_range(0, 10), origin.y + rng.randi_range(22, 40), rng.randi_range(18, 36), 7), color)
		if rng.randf() < 0.6:
			image.fill_rect(Rect2i(origin.x + rng.randi_range(0, 30), origin.y + 18, 7, rng.randi_range(12, 30)).intersection(bounds), color)
	image.fill_rect(Rect2i(14, 72, 186, 10), CYAN)
	image.fill_rect(Rect2i(210, 72, 32, 10), PINK)
	for y in range(1, 96, 4):
		image.fill_rect(Rect2i(0, y, 256, 1), Color(0.0, 0.0, 0.0))
	image.fill_rect(Rect2i(0, 0, 256, 3), PURPLE)
	image.fill_rect(Rect2i(0, 93, 256, 3), PURPLE)
	return ImageTexture.create_from_image(image)
