extends TestCase
## Render (round 5): arena's M2 kit props are dressed, batched per kind (M1: <= 2 draws a kind, no real lights), and sized
## to ArenaKit's boxes.


func _prop(slot_name: String, at: Vector3, look := {}) -> Node3D:
	var slot := VisualSlot.new()
	slot.slot = slot_name
	slot.position = at
	add_to_tree(slot)
	slot.invoke("setup", [look])
	return slot


func _yard() -> KitYard:
	var yard := KitYard.for_node(tree.root)
	await tree.process_frame
	yard.flush()
	return yard


func test_every_kit_prop_type_has_a_visual_slot() -> void:
	for type in ArenaKit.PROPS:
		assert_true(GameTheme.slots.has("prop." + type), "prop.%s is dressed (no stand-in, no invisible collision)" % type)


func test_many_barricades_are_one_multimesh() -> void:
	for i in 12:
		_prop("prop.barricade", Vector3(i * 7.0, 0, 30))
	var yard: KitYard = await _yard()
	assert_eq(yard.count("barricade"), 12, "every barricade registered")
	assert_eq(yard.draws_of("barricade"), 1, "one MultiMesh for all of them")
	var mesh := KitYard.barricade_mesh()
	assert_true(mesh.get_surface_count() <= 2, "at most two surfaces: <= 2 draws for the whole kind")
	var box := mesh.get_aabb()
	assert_near(box.size.x, KitYard.BARRICADE.x, 0.05, "as long as ArenaKit's barricade")
	assert_near(box.size.y, KitYard.BARRICADE.y, 0.05, "as tall: low cover you can see over")


func test_a_floodlight_lights_the_floor_without_a_real_light() -> void:
	var tower := _prop("prop.floodlight", Vector3(0, 0, -40))
	var yard: KitYard = await _yard()
	assert_true(yard.count("floodlight") >= 1 and yard.count("pool") >= 1, "a tower and its painted light pool")
	assert_eq(tower.find_children("*", "Light3D", true, false).size() + yard.find_children("*", "Light3D", true, false).size(), 0, "no real lights (M1)")
	var box := KitYard.floodlight_mesh().get_aabb()
	assert_true(box.size.x >= KitYard.FLOODLIGHT.x - 0.01 and box.size.y > KitYard.MAST_HEIGHT, "the footing fills its box and the mast rises above it")


func test_a_sign_shows_its_arena_name() -> void:
	_prop("prop.sign", Vector3(10, 0, 10), {"sign": "boulevard"})
	_prop("prop.sign", Vector3(-10, 0, -10), {"sign": "unknown_place"})
	var yard: KitYard = await _yard()
	var cells := yard.entries_of("sign").map(func(e: Array) -> int: return int((e[2] as Color).a))
	assert_true(cells.has(KitYard.SIGN_CELLS.find("boulevard")), "a boulevard sign reads BOULEVARD")
	assert_true(cells.has(KitYard.SIGN_CELLS.size() - 1), "an unknown name falls back to DEATH RACE")
	assert_near(KitYard.custom_data("sign", Color(1, 1, 1, 1), 0).r, (1.0 + 0.01) / KitYard.SIGN_CELLS.size(), 0.0001, "the atlas row goes to the shader")


func test_a_wreck_fits_arena_kits_box() -> void:
	var mesh := KitYard.wreck_mesh()
	assert_true(mesh != null, "the approved husk model loads")
	var box := mesh.get_aabb()
	assert_true(box.size.z >= box.size.x, "long axis along z like the box")
	assert_true(box.size.x <= KitYard.WRECK.x + 0.01 and box.size.z <= KitYard.WRECK.z + 0.01, "inside the 3.2 x 6.4 m footprint")
	assert_true(maxf(box.size.x / KitYard.WRECK.x, box.size.z / KitYard.WRECK.z) > 0.98, "and filling it on one axis")
	assert_near(box.position.y, 0.0, 0.01, "sitting on the ground")


func test_props_leaving_the_tree_leave_the_yard() -> void:
	var sign := _prop("prop.sign", Vector3(3, 0, 3), {"sign": "pit"})
	var yard: KitYard = await _yard()
	var before := yard.count("sign")
	sign.free()
	assert_eq(yard.count("sign"), before - 1, "freed props stop drawing")
