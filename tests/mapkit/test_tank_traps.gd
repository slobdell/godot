extends TestCase
## Mapkit P4 (round 47): tank traps, the lead's pick (hedgehogs). A `low` kit prop: a hull stops, a shell and a look go
## over; a field is ONE MultiMesh (MapkitYard), never one draw per hog; the bake carves every hog.

const TRAP_AT := [0.0, 24.0]


func _layout() -> Dictionary:
	var data: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	data["schema"] = 2
	data["obstacles"] = data["obstacles"].filter(func(o: Dictionary) -> bool:
			return not o.has("kit") and (absf(float(o["position"][1])) > 40.0 or absf(float(o["position"][0])) > 30.0))
	data["spawn_zones"] = {"green": {"center": [0.0, 102.0], "size": [150.0, 32.0]},
			"rust": {"center": [0.0, -102.0], "size": [150.0, 32.0]}}
	data["props"] = [
		{"type": "tank_trap", "position": TRAP_AT, "rotation_deg": 30.0},
		{"type": "tank_trap", "position": [-TRAP_AT[0], -TRAP_AT[1]], "rotation_deg": 210.0},
	]
	return data


func test_the_type_is_low_cover_under_the_muzzles() -> void:
	assert_eq(ArenaKit.cover_of("tank_trap"), "low", "low cover")
	var size := ArenaKit.size_of({"type": "tank_trap"})
	assert_true(size.y < 1.05, "the box is under the lowest muzzle (1.05 m): %.2f" % size.y)
	assert_true(maxf(size.x, size.z) < Arena.SOLID_FOOTPRINT_M, "one box, small enough for the bake to carve")


func test_a_hull_stops_and_a_shell_and_a_look_go_over() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	await wait_physics_frames(2)
	var space := arena.get_world_3d().direct_space_state
	var from := Vector3(TRAP_AT[0], 1.1, TRAP_AT[1] + 10.0)
	var to := Vector3(TRAP_AT[0], 1.1, TRAP_AT[1] - 10.0)
	assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, Shell.HIT_MASK)).is_empty(),
			"a round at 1.1 m flies over the hog")
	assert_true(space.intersect_ray(PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.2, to + Vector3.UP * 0.2,
			Perception.eye_mask())).is_empty(), "an eye at 1.3 m sees over it")
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from - Vector3.UP * 0.6, to - Vector3.UP * 0.6, 1))
	assert_true(not hit.is_empty(), "a hull's height (0.5 m) meets it")
	var map := arena.get_world_3d().navigation_map
	var centre := Vector3(TRAP_AT[0], 0.0, TRAP_AT[1])
	var closest := NavigationServer3D.map_get_closest_point(map, centre)
	assert_true(Vector2(closest.x, closest.z).distance_to(Vector2(centre.x, centre.z)) > 1.5, "the bake carves the hog")


func test_a_field_is_one_multimesh() -> void:
	var holder := Node3D.new()
	add_to_tree(holder)
	var scene := GameTheme.scene("prop.tank_trap")
	assert_true(scene != null, "prop.tank_trap is dressed")
	for i in 24:
		var hog := scene.instantiate() as Node3D
		holder.add_child(hog)
		hog.global_position = Vector3(-40.0 + 3.5 * i, 0.0, 60.0)
	await wait_physics_frames(3)
	var yard := MapkitYard.for_node(holder)
	assert_eq(yard.count("hedgehog"), 24, "every hog registered")
	assert_eq(yard.draws_of("hedgehog"), 1, "one MultiMesh for the field")
	assert_true(MapkitYard.mesh_of("hedgehog").get_surface_count() <= 2, "two surfaces: steel and the glowing tips")
	var box := MapkitYard.mesh_of("hedgehog").get_aabb()
	assert_true(box.size.x <= 1.65 and box.size.z <= 1.65, "drawn inside its 1.6 m footprint (%s)" % box.size)
