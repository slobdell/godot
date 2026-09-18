extends TestCase
## Feel X4 (round 6): the lead's low camera puts the horizon in every frame, so the arena sits under a smog-lit sky
## inside a city instead of flat black.


func test_the_skyline_ring_wraps_the_arena_facing_in() -> void:
	var mesh := CitySkyline.ring(100.0, 50.0, -5.0, 16)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(vertices.size(), 34, "two vertices per edge of 16 segments, closing the loop")
	for i in vertices.size():
		assert_near(Vector2(vertices[i].x, vertices[i].z).length(), 100.0, 0.01, "every vertex on the ring")
		assert_true(normals[i].dot(-Vector3(vertices[i].x, 0.0, vertices[i].z).normalized()) > 0.99, "facing the centre")
		assert_near(vertices[i].y, -5.0 + 50.0 * uvs[i].y, 0.01, "UV.y runs foot to top")
	assert_near(uvs[vertices.size() - 1].x, 1.0, 0.001, "UV.x runs once around")


func test_the_arena_environment_has_a_sky_and_a_city() -> void:
	var previous := GameTheme.theme_name
	GameTheme.use("cyberpunk")
	var node: Node = add_to_tree(GameTheme.scene("arena.environment").instantiate())
	GameTheme.use(previous)
	var environment: Environment = node.get("environment")
	assert_eq(environment.background_mode, Environment.BG_COLOR,
			"no Sky resource: in Compatibility it leaked its radiance textures across a scene switch")
	var domes := node.find_children("*", "NightSky", true, false)
	assert_eq(domes.size(), 1, "the night sky is a dome")
	assert_true((domes[0] as MeshInstance3D).material_override is ShaderMaterial, "drawn by the night-sky shader")
	assert_true(NightSky.RADIUS > CitySkyline.RADIUS and NightSky.RADIUS < 1200.0, "behind the city, inside the camera's far plane")
	var skylines := node.find_children("*", "CitySkyline", true, false)
	assert_eq(skylines.size(), 1, "one city ring around the arena")
	assert_eq((skylines[0] as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "and it casts nothing")


func test_the_city_has_streets_out_to_the_skyline() -> void:
	## Control's played session at 12 degrees: past the stands the floor ended in a void.
	var skyline: CitySkyline = add_to_tree(CitySkyline.new())
	var ground := skyline.get_node("CityGround") as MeshInstance3D
	assert_true(ground != null, "a ground plane under the city")
	assert_near(ground.global_position.y, CitySkyline.GROUND_DEPTH, 0.001, "just under the arena floor")
	assert_true(ground.global_position.y < 0.0, "never above it (no z-fight with the floor)")
	var size := (ground.mesh as PlaneMesh).size
	assert_true(size.x >= CitySkyline.RADIUS * 2.0 - 0.1, "reaching the skyline ring (%s)" % size)
