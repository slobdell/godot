extends TestCase
## Mapkit (round 47): his two extras from the looks page, pipes B (the ground pipeline) and crane A (the yard gantry).
## A pipeline is `low` under the muzzles; a gantry is four `hard` legs, one of which draws the beam to its partner.

func test_the_types() -> void:
	assert_eq(ArenaKit.cover_of("pipeline"), "low", "a pipe run is low cover")
	assert_true(ArenaKit.size_of({"type": "pipeline"}).y < 1.05, "under the lowest muzzle")
	assert_eq(ArenaKit.cover_of("gantry_leg"), "hard", "a crane leg is a hard post")
	assert_true(ArenaKit.size_of({"type": "gantry_leg"}).y > 6.18, "taller than the tallest hull (6.18 m, arena_kit.gd)")


func test_a_crane_is_four_legs_and_one_beam_and_a_run_is_one_multimesh() -> void:
	var holder := Node3D.new()
	add_to_tree(holder)
	var leg := GameTheme.scene("prop.gantry_leg")
	var pipe := GameTheme.scene("prop.pipeline")
	assert_true(leg != null and pipe != null, "both are dressed")
	for corner in [Vector3(-11, 0, -6), Vector3(11, 0, -6), Vector3(-11, 0, 6), Vector3(11, 0, 6)]:
		var node := leg.instantiate() as Node3D
		holder.add_child(node)
		node.global_position = corner + Vector3(0, 0, 40)
		node.call("setup", {"type": "gantry_leg", "span": [22.0, 0.0]} if corner.x < 0 else {"type": "gantry_leg"})
	for i in 6:
		var node := pipe.instantiate() as Node3D
		holder.add_child(node)
		node.global_position = Vector3(-40.0, 0.0, -30.0 + 10.0 * i)
		node.call("setup", {"type": "pipeline"})
	await wait_physics_frames(3)
	var yard := MapkitYard.for_node(holder)
	assert_eq(yard.count("gantry_leg"), 4, "four legs")
	assert_eq(yard.count("gantry_beam"), 2, "two beams, one per leg that names its partner")
	assert_eq(yard.count("pipeline"), 6, "six pipe lengths")
	assert_eq(yard.draws_of("pipeline"), 1, "one MultiMesh for the run")
	var beam := MapkitYard.mesh_of("gantry_beam").get_aabb()
	assert_true(beam.position.y >= MapkitYard.LEG.y - 0.2, "the beam is overhead (from %.1f m)" % beam.position.y)


## P1b (R47.28): the trim-sheet variant of the kit -- the same geometry, UV-mapped into the Material Maker sheet's bands.
func test_the_trim_look_wears_the_sheet_and_plain_does_not() -> void:
	var was := MapkitYard.look
	MapkitYard.look = "trim"
	var trim := MapkitYard.mesh_of("pipeline")
	MapkitYard.look = "plain"
	var plain := MapkitYard.mesh_of("pipeline")
	MapkitYard.look = was
	assert_true(trim != plain, "two meshes, one per look")
	var material := trim.surface_get_material(0) as StandardMaterial3D
	assert_true(material != null and material.albedo_texture != null, "the trim body wears the sheet")
	assert_true(material.normal_texture != null and material.emission_texture != null, "with its normal and emission maps")
	assert_true((plain.surface_get_material(0) as StandardMaterial3D).albedo_texture == null, "plain is flat colour")
	var uvs: PackedVector2Array = trim.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]
	var in_bands := true
	for uv in uvs:
		in_bands = in_bands and uv.y >= -0.001 and uv.y <= 1.001
	assert_true(uvs.size() > 0 and in_bands, "every vertex maps into the sheet (v in 0..1)")
