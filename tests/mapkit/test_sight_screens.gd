extends TestCase
## Mapkit P3 (round 47, C47.7): the `sight` cover class. A sight screen blocks the eye ray and the cover map's sight
## term, and nothing else: a hull drives through it, a shell flies through it, the navmesh is baked as if it were not
## there. Behind ArenaKit.sight_on (`--kit-sight=off`); a map with no screens is byte-identical either way.

const SCREEN_AT := [0.0, 20.0]


func _layout() -> Dictionary:
	var data: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	data["schema"] = 2
	data["obstacles"] = data["obstacles"].filter(func(o: Dictionary) -> bool: return not o.has("kit"))
	# Clear the test strip of foundry's own cover so only the screen stands between the two eyes.
	data["obstacles"] = data["obstacles"].filter(func(o: Dictionary) -> bool:
			return absf(float(o["position"][1])) > 40.0 or absf(float(o["position"][0])) > 30.0)
	data["spawn_zones"] = {"green": {"center": [0.0, 102.0], "size": [150.0, 32.0]},
			"rust": {"center": [0.0, -102.0], "size": [150.0, 32.0]}}
	data["props"] = [
		{"type": "sight_screen", "position": SCREEN_AT, "rotation_deg": 0.0},
		{"type": "sight_screen", "position": [-SCREEN_AT[0], -SCREEN_AT[1]], "rotation_deg": 180.0},
	]
	return data


func _eye(arena: Arena, at: Vector3) -> Node3D:
	var node := Node3D.new()
	arena.add_child(node)
	node.global_position = at
	return node


func teardown() -> void:
	ArenaKit.sight_on = true
	super.teardown()


func test_the_class_is_declared_and_kept_out_of_the_hull_obstacles() -> void:
	assert_eq(ArenaKit.cover_of("sight_screen"), "sight", "sight_screen is the sight class")
	assert_true(ArenaKit.is_sight("sight_screen") and not ArenaKit.is_sight("barricade"), "is_sight")
	assert_eq(ArenaKit.SIGHT_LAYER & 3, 0, "the sight layer is neither the world (1) nor the vehicles (2)")
	assert_eq(ArenaKit.SIGHT_LAYER & Shell.HIT_MASK, 0, "shells never test the sight layer")
	var normal := Arena.normalize(_layout())
	assert_true(not normal["obstacles"].any(func(o: Dictionary) -> bool: return o["type"] == "sight_screen"),
			"a screen is not an obstacle (no hull collider, no navmesh hole)")


func test_a_screened_line_of_sight_is_blind_and_the_switch_restores_it() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	await wait_physics_frames(2)
	var a := _eye(arena, Vector3(SCREEN_AT[0], 0.0, SCREEN_AT[1] + 15.0))
	var b := _eye(arena, Vector3(SCREEN_AT[0], 0.0, SCREEN_AT[1] - 15.0))
	var beside := _eye(arena, Vector3(SCREEN_AT[0] + 20.0, 0.0, SCREEN_AT[1] - 15.0))
	await wait_physics_frames(1)
	assert_true(not Perception.has_line_of_sight(a, b), "the screen blinds the look across it")
	assert_true(Perception.has_line_of_sight(a, beside), "a look past the screen's end is clear")
	ArenaKit.sight_on = false
	assert_true(Perception.has_line_of_sight(a, b), "--kit-sight=off: the screen is scenery again")


func test_a_shell_and_a_hull_pass_through() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	await wait_physics_frames(2)
	var space := arena.get_world_3d().direct_space_state
	var from := Vector3(SCREEN_AT[0], 1.2, SCREEN_AT[1] + 15.0)
	var to := Vector3(SCREEN_AT[0], 1.2, SCREEN_AT[1] - 15.0)
	assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Shell.HIT_MASK)).is_empty(),
			"a shell's ray (HIT_MASK) crosses the screen")
	# A hull with the tank's own mask (world + vehicles) moves through the screen without touching it.
	var hull := CharacterBody3D.new()
	hull.collision_layer = 2
	hull.collision_mask = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3.0, 1.6, 6.0)
	shape.shape = box
	hull.add_child(shape)
	arena.add_child(hull)
	hull.global_position = Vector3(SCREEN_AT[0], 1.0, SCREEN_AT[1] + 8.0)
	await wait_physics_frames(1)
	var hit := hull.move_and_collide(Vector3(0, 0, -16.0), true)
	assert_true(hit == null, "a hull drives through (hit: %s)" % [hit.get_collider().name if hit != null else "none"])
	# And the navmesh is baked under it.
	var map := arena.get_world_3d().navigation_map
	var centre := Vector3(SCREEN_AT[0], 0.0, SCREEN_AT[1])
	var closest := NavigationServer3D.map_get_closest_point(map, centre)
	assert_true(Vector2(closest.x, closest.z).distance_to(Vector2(centre.x, centre.z)) < 0.5, "navmesh under the screen")


func test_the_cover_tables_count_a_screen_as_blocking_a_look() -> void:
	var layout := Arena.normalize(_layout())
	var behind := Vector3(SCREEN_AT[0], 0.0, SCREEN_AT[1] - 4.0)
	var viewer := Vector3(SCREEN_AT[0], 0.0, SCREEN_AT[1] + 40.0)
	var on := CoverTables.build(layout)
	ArenaKit.sight_on = false
	var off := CoverTables.build(layout)
	var heading := Vector3(1, 0, 0)  # the hull broadside to the screen, inside its 14 m span
	assert_true(on.cover_fraction(viewer, behind, heading, 6.0) > 0.5,
			"a hull behind a screen is mostly hidden (%.2f)" % on.cover_fraction(viewer, behind, heading, 6.0))
	assert_near(off.cover_fraction(viewer, behind, heading, 6.0), 0.0, 0.01, "with the switch off, exposed")


func test_a_map_without_screens_builds_the_same_cover_either_way() -> void:
	var layout := Arena.load_layout("yard")["layout"] as Dictionary
	var on := CoverTables.build(layout)
	ArenaKit.sight_on = false
	var off := CoverTables.build(layout)
	var viewer := Vector3(0, 0, 80)
	var same := true
	for x in range(-100, 101, 20):
		for z in range(-100, 101, 20):
			same = same and is_equal_approx(on.cover_fraction(viewer, Vector3(x, 0, z), Vector3.RIGHT, 6.0),
					off.cover_fraction(viewer, Vector3(x, 0, z), Vector3.RIGHT, 6.0))
	assert_true(same, "yard (no screens): identical cover tables ON and OFF")
