extends TestCase
## Asset pipeline (assets/pipeline): synthetic "downloaded" models with the usual problems (wrong
## scale, wrong forward axis, too many triangles, huge textures) come out meeting the slot
## contracts, and the checker catches models that don't. Owner: assets stream.

const WRAPPER := preload("res://assets/runtime/generated_visual.gd")
const TMP := "user://asset_pipeline_tests"


## A tank-ish model the way generators and packs deliver it: 10× too big and facing +X.
func _tank_model(scale := 10.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Downloaded"
	_add_box(root, "Body", Vector3(3.6, 1.0, 2.4) * scale, Vector3(0, 0.5, 0) * scale, "paint")
	_add_box(root, "Turret", Vector3(1.7, 0.55, 1.4) * scale, Vector3(0, 1.3, 0) * scale, "paint")
	_add_box(root, "Gun", Vector3(2.5, 0.2, 0.2) * scale, Vector3(2.0, 1.3, 0) * scale, "metal")
	return root


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material_name: String, material: StandardMaterial3D = null) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	if material == null:
		material = StandardMaterial3D.new()
		material.resource_name = material_name
	box.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = box
	instance.position = position
	parent.add_child(instance)
	return instance


func _free_later(node: Node) -> Node:
	add_to_tree(node)
	return node


func test_orientation_basis_turns_the_source_forward_axis_into_minus_z() -> void:
	var basis := AssetNormalizer.orientation_basis("+x", "+y")
	assert_true((basis * Vector3.RIGHT).is_equal_approx(Vector3.FORWARD), "a model facing +X ends up facing -Z")
	assert_true((basis * Vector3.UP).is_equal_approx(Vector3.UP), "up stays up")
	var z_up := AssetNormalizer.orientation_basis("-y", "+z")
	assert_true((z_up * Vector3.BACK).is_equal_approx(Vector3.UP), "a Z-up model is stood upright")
	assert_true((z_up * Vector3.DOWN).is_equal_approx(Vector3.FORWARD), "and its -Y forward faces -Z")


func test_a_raw_oversized_sideways_hull_fails_the_contract() -> void:
	var model := _free_later(_tank_model(10.0))
	var result := AssetChecker.check_report(AssetInspector.inspect(model), "tank.hull")
	var text := "\n".join(result["errors"])
	assert_true(text.contains("exceeds"), "a 10× model is reported as too big: %s" % text)
	assert_true(text.contains("forward axis"), "a model facing +X is reported as wrongly oriented: %s" % text)


func test_normalizing_a_hull_fits_the_slot_and_keeps_only_hull_meshes() -> void:
	var model := _free_later(_tank_model(10.0))
	var result := AssetNormalizer.normalize(model, "tank.hull", {"forward": "+x", "exclude": ["turret", "gun"]})
	var scene: Node3D = _free_later(result["scene"])
	var report := AssetInspector.inspect(scene)
	var check := AssetChecker.check_report(report, "tank.hull")
	assert_eq(check["errors"], PackedStringArray(), "the normalized hull meets the tank.hull contract")
	var aabb: AABB = report["aabb"]
	assert_near(aabb.size.z, 3.6, 0.01, "the hull's long axis runs along Z at the slot's 3.6 m length")
	assert_near(aabb.size.x, 2.4, 0.01, "and it is 2.4 m wide")
	assert_near(aabb.position.y, 0.0, 0.001, "it sits on the ground")
	assert_eq(report["tris"], 12, "only the body box (12 triangles) was kept; turret and gun were excluded")


func test_turret_and_gun_from_the_same_model_share_the_hull_scale() -> void:
	var model := _free_later(_tank_model(10.0))
	var hull := AssetNormalizer.normalize(model, "tank.hull", {"forward": "+x", "exclude": ["turret", "gun"]})
	_free_later(hull["scene"])
	var scale: float = (hull["scale"] as Vector3).x
	var turret := AssetNormalizer.normalize(model, "tank.turret", {"forward": "+x", "include": ["turret"], "scale": scale})
	var turret_scene: Node3D = _free_later(turret["scene"])
	var aabb: AABB = AssetInspector.inspect(turret_scene)["aabb"]
	assert_near(aabb.size.z, 17.0 * scale, 0.01, "the turret keeps the hull's scale, so the parts stay in proportion")
	assert_near(aabb.position.y, -0.275, 0.001, "the turret's bottom sits on the hull deck")


func test_cannon_muzzle_lands_where_gameplay_fires_from() -> void:
	var model := _free_later(_tank_model(10.0))
	var result := AssetNormalizer.normalize(model, "weapon.cannon", {"forward": "+x", "include": ["gun"]})
	var scene: Node3D = _free_later(result["scene"])
	var report := AssetInspector.inspect(scene)
	var aabb: AABB = report["aabb"]
	assert_near(aabb.position.z, -3.2, 0.01, "the muzzle is 3.2 m ahead of the turret pivot")
	assert_near(aabb.end.z, -0.7, 0.01, "the breech tucks into the turret")
	assert_eq(AssetChecker.check_report(report, "weapon.cannon")["errors"], PackedStringArray(), "the cannon meets its contract")


func test_props_stretch_to_their_collision_footprint() -> void:
	var root: Node3D = _free_later(Node3D.new())
	_add_box(root, "Container", Vector3(2.0, 2.6, 6.0), Vector3(5, 10, 5), "rust")
	var result := AssetNormalizer.normalize(root, "prop.wall", {"forward": "+x"})
	var report := AssetInspector.inspect(_free_later(result["scene"]))
	var aabb: AABB = report["aabb"]
	assert_true(aabb.size.is_equal_approx(Vector3(18, 3, 1.5)), "the wall visual matches its 18 × 3 × 1.5 m collision box (got %s)" % aabb.size)
	assert_eq(AssetChecker.check_report(report, "prop.wall")["errors"], PackedStringArray(), "the wall meets its contract")


func test_dense_models_are_decimated_to_the_budget() -> void:
	var root: Node3D = _free_later(Node3D.new())
	var sphere := SphereMesh.new()
	sphere.radial_segments = 128
	sphere.rings = 64
	var instance := MeshInstance3D.new()
	instance.mesh = sphere
	root.add_child(instance)
	var before := AssetInspector.inspect(root)
	assert_true(before["tris"] > 2000, "the source is over the cannon budget (%d tris)" % before["tris"])
	assert_true(AssetChecker.check_report(before, "prop.crate")["errors"][0].contains("budget"), "the checker flags the budget first")
	var result := AssetNormalizer.normalize(root, "prop.crate")
	var after := AssetInspector.inspect(_free_later(result["scene"]))
	assert_true(after["tris"] <= 2000 and after["tris"] > 200, "decimated under the 2000 budget without collapsing (%d tris)" % after["tris"])


func test_emissive_maps_survive_normalize_export_and_reload() -> void:
	var root: Node3D = _free_later(Node3D.new())
	var neon := StandardMaterial3D.new()
	neon.resource_name = "neon_strip"
	neon.emission_enabled = true
	neon.emission = Color(0.0, 0.95, 1.0)
	neon.emission_energy_multiplier = 3.0
	var image := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	neon.emission_texture = ImageTexture.create_from_image(image)
	_add_box(root, "Strip", Vector3(4, 0.2, 0.2), Vector3.ZERO, "", neon)
	_add_box(root, "Paint", Vector3(4, 3, 4), Vector3(0, 1.5, 0), "paint")
	var result := AssetNormalizer.normalize(root, "prop.crate", {"emissive": {"paint": 1.5}})
	var path := "%s/emissive.glb" % TMP
	assert_eq(AssetIO.save_glb(result["scene"], path), OK, "the normalized model exports to GLB")
	_free_later(result["scene"])
	var reloaded: Node3D = _free_later(AssetIO.load_glb(path))
	var materials := {}
	for material in AssetInspector.inspect(reloaded)["materials"]:
		materials[material["name"]] = material
	assert_true(materials.has("neon_strip") and materials["neon_strip"]["emissive"], "the neon strip is still emissive after the GLB round trip")
	var has_emission_map := false
	for texture in materials.get("neon_strip", {}).get("textures", []):
		has_emission_map = has_emission_map or texture[0] == "emission_texture"
	assert_true(has_emission_map, "its emission map survived too")
	assert_true(materials.has("paint") and materials["paint"]["emissive"], "a material named by --emissive glows from its albedo")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_a_separate_emission_map_is_wired_into_matching_materials() -> void:
	var root: Node3D = _free_later(Node3D.new())
	_add_box(root, "Hull", Vector3(4.5, 3, 4.5), Vector3.ZERO, "Main")
	_add_box(root, "Tracks", Vector3(4.5, 1, 4.5), Vector3.ZERO, "Tracks")
	var emission := ImageTexture.create_from_image(Image.create(64, 64, false, Image.FORMAT_RGBA8))
	var result := AssetNormalizer.normalize(root, "prop.crate", {"emission_maps": {"main": emission}})
	var materials := {}
	for material in AssetInspector.inspect(_free_later(result["scene"]))["materials"]:
		materials[material["name"]] = material
	assert_true(materials["Main"]["emissive"], "the generator's emission map lights the material it was made for")
	assert_true(not materials["Tracks"]["emissive"], "other materials stay dark")


func test_oversized_textures_are_capped_at_1024() -> void:
	var root: Node3D = _free_later(Node3D.new())
	var material := StandardMaterial3D.new()
	material.resource_name = "skin"
	material.albedo_texture = ImageTexture.create_from_image(Image.create(4096, 2048, false, Image.FORMAT_RGBA8))
	_add_box(root, "Box", Vector3(4, 3, 4), Vector3.ZERO, "", material)
	var before := AssetInspector.inspect(root)
	assert_true(AssetChecker.check_report(before, "prop.crate")["errors"].size() > 0, "a 4096 texture breaks the contract")
	var result := AssetNormalizer.normalize(root, "prop.crate")
	var after := AssetInspector.inspect(_free_later(result["scene"]))
	var texture: Array = after["materials"][0]["textures"][0]
	assert_eq([texture[1], texture[2]], [1024, 512], "the albedo map is shrunk to 1024 on its long edge, keeping aspect")


func test_collision_in_a_model_is_rejected() -> void:
	var root: Node3D = _free_later(Node3D.new())
	_add_box(root, "Box", Vector3(4.5, 3, 4.5), Vector3(0, 1.5, 0), "crate")
	var body := StaticBody3D.new()
	body.name = "Box_col"
	root.add_child(body)
	var errors: PackedStringArray = AssetChecker.check_report(AssetInspector.inspect(root), "prop.crate")["errors"]
	assert_true("\n".join(errors).contains("collision"), "visuals that bring their own collision are rejected: %s" % errors)


func test_wrapper_tints_only_named_materials_per_instance() -> void:
	var make := func() -> Node3D:
		var wrapper := Node3D.new()
		wrapper.set_script(WRAPPER)
		wrapper.set("tint_materials", PackedStringArray(["paint*"]))
		wrapper.set("team_emissive_materials", PackedStringArray(["neon"]))
		wrapper.set("heat_materials", PackedStringArray(["barrel"]))
		return wrapper
	var shared_paint := StandardMaterial3D.new()
	shared_paint.resource_name = "paint_body"
	var shared_metal := StandardMaterial3D.new()
	shared_metal.resource_name = "metal"
	var first: Node3D = _free_later(make.call())
	var second: Node3D = _free_later(make.call())
	var first_body := _add_box(first, "Body", Vector3.ONE, Vector3.ZERO, "", shared_paint)
	var first_metal := _add_box(first, "Metal", Vector3.ONE, Vector3.ZERO, "", shared_metal)
	var second_body := _add_box(second, "Body", Vector3.ONE, Vector3.ZERO, "", shared_paint)
	var neon := StandardMaterial3D.new()
	neon.resource_name = "neon"
	var strip := _add_box(first, "Strip", Vector3.ONE, Vector3.ZERO, "", neon)
	var barrel := StandardMaterial3D.new()
	barrel.resource_name = "barrel"
	var gun := _add_box(first, "Gun", Vector3.ONE, Vector3.ZERO, "", barrel)
	first.call("set_team_color", Color.MAGENTA)
	first.call("set_heat", 0.5)
	var body_material := first_body.get_surface_override_material(0) as StandardMaterial3D
	assert_true(body_material != null and body_material.albedo_color == Color.MAGENTA, "the paint material takes the team color")
	assert_eq(first_metal.get_surface_override_material(0), null, "metal parts keep their own material")
	assert_eq(second_body.get_surface_override_material(0), null, "another tank's paint is untouched")
	assert_eq(shared_paint.albedo_color, Color.WHITE, "the shared source material is never edited")
	var strip_material := strip.get_surface_override_material(0) as StandardMaterial3D
	assert_true(strip_material != null and strip_material.emission_enabled and strip_material.emission == Color.MAGENTA, "neon strips glow in the team color")
	var gun_material := gun.get_surface_override_material(0) as StandardMaterial3D
	assert_near(gun_material.emission_energy_multiplier if gun_material != null else 0.0, 2.0, 0.001, "a half-hot barrel glows at half the heat energy")


func test_committed_generated_themes_meet_their_contracts() -> void:
	for theme in AssetIO.generated_themes():
		var result := AssetChecker.check_theme(theme)
		assert_eq(result["errors"], PackedStringArray(), "generated theme '%s' meets every slot contract" % theme)
