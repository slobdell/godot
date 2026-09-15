extends TestCase
## Assets X1: stackable 20 ft and 40 ft shipping containers. A few hundred triangles each, one shared texture set, every
## container of a kind drawn by one MultiMesh however many are placed, per-instance looks chosen in the shader.

const PROP_20 := preload("res://game/theme/arena_kit/prop_container_20.tscn")
const PROP_40 := preload("res://game/theme/arena_kit/prop_container_40.tscn")


func _yard(node: Node) -> ContainerYard:
	var yard := ContainerYard.for_node(node)
	yard.flush()
	return yard


func _place(scene: PackedScene, position: Vector3, data := {}) -> Node3D:
	var holder := Node3D.new()
	holder.position = position
	add_to_tree(holder)
	var prop := scene.instantiate() as Node3D
	holder.add_child(prop)
	if not data.is_empty():
		prop.call("setup", data)
	return prop


func test_the_meshes_match_iso_sizes_with_a_few_hundred_triangles() -> void:
	for kind in ContainerYard.KINDS:
		var mesh := ContainerMesh.build(ContainerYard.KINDS[kind])
		var box := mesh.get_aabb()
		assert_near(box.size.x, ContainerYard.KINDS[kind], 0.01, "%s is its ISO length along X" % kind)
		assert_near(box.size.y, ContainerMesh.HEIGHT, 0.01, "%s is 2.59 m tall (8 ft 6 in)" % kind)
		assert_near(box.size.z, ContainerMesh.WIDTH, 0.01, "%s is 2.44 m wide (8 ft)" % kind)
		assert_near(box.position.y, 0.0, 0.001, "%s sits on the ground" % kind)
		var triangles := (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		assert_true(triangles >= 150 and triangles <= 600, "%s has a few hundred triangles (%d)" % [kind, triangles])
		var arrays := mesh.surface_get_arrays(0)
		assert_true(arrays[Mesh.ARRAY_TEX_UV2] != null and arrays[Mesh.ARRAY_TANGENT] != null,
				"%s carries panel coordinates for stencils and tangents for the corrugation normals" % kind)
		var doors := 0
		var leaves := {}
		for uv2: Vector2 in arrays[Mesh.ARRAY_TEX_UV2]:
			if uv2.y < 0.0 and absf(uv2.x) > 0.5:
				doors += 1
				leaves[signf(uv2.x)] = true
				assert_near(absf(uv2.x), ContainerYard.KINDS[kind] / 2.0 + ContainerMesh.HINGE_OUTSET, 0.001,
						"door vertices know their hinge line")
		assert_true(doors > 0 and leaves.size() == 2, "%s has two door leaves the shader can swing open" % kind)


func test_a_40_ft_container_is_its_own_mesh_with_the_same_texel_density() -> void:
	var short := ContainerMesh.build(ContainerYard.KINDS["container_20"])
	var long := ContainerMesh.build(ContainerYard.KINDS["container_40"])
	var span := func(mesh: ArrayMesh) -> float:
		var lo := INF
		var hi := -INF
		for uv: Vector2 in mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV]:
			lo = minf(lo, uv.x)
			hi = maxf(hi, uv.x)
		return hi - lo
	assert_near(span.call(long) / span.call(short), 12.19 / 6.06, 0.08,
			"UVs are in meters, so the corrugation tiles instead of stretching")


func test_every_container_of_a_kind_is_one_multimesh_draw() -> void:
	var before := {}
	for kind in ContainerYard.KINDS:
		before[kind] = _yard(tree.root).count(kind)
	for i in 12:
		_place(PROP_20, Vector3(i * 7.0, 0, 40))
	for i in 3:
		_place(PROP_40, Vector3(i * 14.0, 0, 60))
	var yard := _yard(tree.root)
	assert_eq(yard.count("container_20") - before["container_20"], 12, "twelve 20 ft containers registered")
	assert_eq(yard.count("container_40") - before["container_40"], 3, "three 40 ft containers registered")
	var draws := yard.find_children("*", "MultiMeshInstance3D", false, false)
	assert_eq(draws.size(), 2, "one MultiMesh per kind, however many containers are placed")
	for draw: MultiMeshInstance3D in draws:
		assert_eq(draw.multimesh.instance_count, yard.count(String(draw.name)), "%s draws every registered container" % draw.name)


func test_stacks_climb_one_container_height_per_level_and_leave_with_their_prop() -> void:
	var yard := _yard(tree.root)
	var start := yard.count("container_20")
	var prop := _place(PROP_20, Vector3(300, 0, 300), {"stack": 3})
	yard.flush()
	assert_eq(yard.count("container_20") - start, 3, "stack 3 is three containers")
	var heights: Array[float] = []
	for xform in yard.transforms_near("container_20", Vector3(300, 0, 300), 1.0):
		heights.append(xform.origin.y)
	heights.sort()
	assert_eq(heights.size(), 3, "all three stand on the same footprint")
	for level in 3:
		assert_near(heights[level], level * ContainerMesh.HEIGHT, 0.02, "level %d sits on the one below" % level)
	prop.get_parent().free()
	yard.flush()
	assert_eq(yard.count("container_20"), start, "a removed prop takes its containers with it")


func test_a_scaled_slot_still_draws_unstretched_containers() -> void:
	# Arena scales a prop's visual by size / default size; a stack layout that only raises the height must not stretch.
	var yard := _yard(tree.root)
	var start := yard.count("container_40")
	var holder := Node3D.new()
	holder.position = Vector3(-300, 0, 300)
	holder.scale = Vector3(1, 2, 1)
	add_to_tree(holder)
	holder.add_child(PROP_40.instantiate())
	yard.flush()
	assert_eq(yard.count("container_40") - start, 2, "a visual scaled 2× in height reads as a stack of two")
	for xform in yard.transforms_near("container_40", Vector3(-300, 0, 300), 1.0):
		assert_near(xform.basis.get_scale().y, 1.0, 0.001, "containers keep their real size")


func test_looks_are_seeded_by_position_and_follow_faction_and_layout_overrides() -> void:
	var a := ContainerYard.look(Vector3(10, 0, 20), 0, {})
	assert_eq(ContainerYard.look(Vector3(10, 0, 20), 0, {}), a, "the same spot always gets the same container")
	var differ := false
	for i in 8:
		if ContainerYard.look(Vector3(10 + i * 7, 0, 20), 0, {}) != a:
			differ = true
	assert_true(differ, "neighbors vary in paint, rust, or stencil")
	for i in 20:
		var law := ContainerYard.look(Vector3(i * 3.0, 0, 5), 0, {"faction": "law"})
		assert_true(ContainerYard.FACTIONS["law"]["paints"].has(ContainerYard.paint_of(law)), "the Law paints its containers from its palette")
		assert_true(ContainerYard.FACTIONS["law"]["stencils"].has(ContainerYard.stencil_of(law)), "and stencils them EVIDENCE or IMPOUND")
	var custom := ContainerYard.look(Vector3.ZERO, 0, {"paint": "orange", "stencil": "gang_tag", "rust": 0.9, "doors": "open"})
	assert_eq(ContainerYard.paint_of(custom), ContainerYard.PAINTS.keys().find("orange"), "a layout can name the paint")
	assert_eq(ContainerYard.stencil_of(custom), ContainerYard.STENCILS.find("gang_tag"), "and the stencil")
	assert_near(custom.b, 0.9, 0.001, "and the rust")
	assert_near(custom.a, 1.0, 0.001, "and open doors")
	assert_near(ContainerYard.look(Vector3.ZERO, 1, {"doors": "open"}).a, 0.0, 0.001, "only the bottom container can open its doors")


func test_both_themes_fill_the_container_slots() -> void:
	var previous := GameTheme.theme_name
	for theme in ["default", "cyberpunk"]:
		GameTheme.use(theme)
		for kind in ContainerYard.KINDS:
			var packed := GameTheme.scene("prop." + kind)
			var prop := packed.instantiate() if packed != null else null
			assert_true(prop != null and prop.has_method("setup"), "%s fills prop.%s" % [theme, kind])
			if prop != null:
				prop.free()
	GameTheme.use(previous)
