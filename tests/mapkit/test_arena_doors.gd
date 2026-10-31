extends TestCase
## Mapkit P2 (round 47): the blast doors in the world (game/arena/arena_doors.gd). A door's collider follows
## BlastDoors' schedule; a closing door never lands on a crew (it HOLDS while a vehicle is in the doorway, then seals);
## the navmesh is baked with every doorway open (the route reads the schedule, C47.8).

const DOOR_A := [-40.0, 30.0]


func _layout() -> Dictionary:
	var data: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	data["obstacles"] = data["obstacles"].filter(func(o: Dictionary) -> bool: return not o.has("kit"))
	data["doors"] = [
		{"name": "west_gate", "group": "gates", "position": DOOR_A, "rotation_deg": 0.0},
		{"name": "east_gate", "group": "gates", "position": [-DOOR_A[0], -DOOR_A[1]], "rotation_deg": 180.0},
	]
	return data


## A stand-in vehicle on the vehicle layer, its box `size`, at ground point (x, z).
func _vehicle(arena: Arena, at: Vector2, size := Vector3(3.0, 1.6, 6.0)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = "Green_Test_1"
	body.collision_layer = ArenaDoors.VEHICLE_LAYER
	body.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(at.x, size.y / 2.0, at.y)
	arena.add_child(body)
	return body


func test_a_layout_with_doors_builds_a_slab_per_door_outside_the_navmesh_sources() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	assert_true(arena.doors != null, "the arena built its doors")
	assert_eq(arena.doors.bodies.size(), 2, "one slab per door")
	for id: String in arena.doors.bodies:
		var body: StaticBody3D = arena.doors.bodies[id]
		assert_true(not arena.obstacles_root.is_ancestor_of(body), "%s is not under Obstacles (the bake source)" % id)
		assert_true(not body.is_in_group("navigation_source"), "%s is not a navigation source" % id)
	# The doorway is walkable navmesh: the closest navmesh point to the door's centre is the centre itself.
	var map := arena.get_world_3d().navigation_map
	var centre := Vector3(DOOR_A[0], 0.0, DOOR_A[1])
	var closest := NavigationServer3D.map_get_closest_point(map, centre)
	assert_true(Vector2(closest.x, closest.z).distance_to(Vector2(centre.x, centre.z)) < 0.5,
			"the navmesh covers the doorway (closest point %s)" % closest)


func test_the_collider_follows_the_schedule() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	var doors := arena.doors
	var tick := [0]
	doors.tick_source = func() -> int: return tick[0]
	var first := doors.doors.next_change("west_gate", 0)
	tick[0] = first - 1
	await wait_physics_frames(2)
	assert_true(not doors.is_sealed("west_gate"), "open before its change")
	tick[0] = first
	await wait_physics_frames(2)
	assert_true(doors.is_sealed("west_gate") and doors.is_sealed("east_gate"), "both mirrored doors shut at the change")
	var reopen := doors.doors.next_change("west_gate", first)
	tick[0] = reopen
	await wait_physics_frames(2)
	assert_true(not doors.is_sealed("west_gate"), "open again on schedule")


func test_a_closing_door_waits_for_a_crew_in_the_doorway_then_seals() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	var doors := arena.doors
	var events: Array[Dictionary] = []
	doors.door_event.connect(func(e: Dictionary) -> void: events.append(e))
	var tick := [0]
	doors.tick_source = func() -> int: return tick[0]
	var first := doors.doors.next_change("west_gate", 0)
	tick[0] = first - SimClock.ticks(BlastDoors.WARN_S) - 2
	await wait_physics_frames(2)
	# A hull straddling the west doorway, nose through the slot.
	var crew := _vehicle(arena, Vector2(DOOR_A[0] + 2.0, DOOR_A[1]))
	await wait_physics_frames(2)
	tick[0] = first + 3
	await wait_physics_frames(2)
	assert_true(not doors.is_sealed("west_gate"), "the door does not close on the crew")
	assert_true(doors.is_held("west_gate"), "it is held")
	assert_true(doors.is_sealed("east_gate"), "the empty mirror door shuts on time")
	var held := events.filter(func(e: Dictionary) -> bool: return e["kind"] == "held")
	assert_eq(held.size(), 1, "one held event")
	assert_eq(String(held[0].get("crew", "")) if not held.is_empty() else "", "Green_Test_1", "naming the crew")
	assert_true(events.any(func(e: Dictionary) -> bool: return e["kind"] == "warn_close" and e["door"] == "west_gate"),
			"the warning came first")
	# The crew drives clear: the door seals.
	crew.position.z += 8.0
	await wait_physics_frames(3)
	tick[0] = first + 6
	await wait_physics_frames(2)
	assert_true(doors.is_sealed("west_gate"), "sealed once the doorway is clear")
	assert_true(events.any(func(e: Dictionary) -> bool: return e["kind"] == "sealed" and e["door"] == "west_gate"),
			"and says so")


func test_a_door_that_is_shut_stays_shut_when_a_crew_arrives() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout())
	var doors := arena.doors
	var tick := [0]
	doors.tick_source = func() -> int: return tick[0]
	tick[0] = doors.doors.next_change("west_gate", 0) + 1
	await wait_physics_frames(2)
	assert_true(doors.is_sealed("west_gate"), "shut")
	_vehicle(arena, Vector2(DOOR_A[0], DOOR_A[1] + 4.0))  # pressed against the shut slab's face
	tick[0] += 1
	await wait_physics_frames(2)
	assert_true(doors.is_sealed("west_gate"), "a crew nosing a shut door does not open it")


func test_validation_runs_through_arena() -> void:
	var data := _layout()
	data["doors"].pop_back()
	assert_true(Arena.validate(data).contains("no mirror"), "Arena.validate refuses an unmirrored door")
	assert_eq(Arena.validate(_layout()), "", "and accepts the mirrored pair")


func test_the_dev_arena_loads_with_its_two_doors_and_is_a_fixture() -> void:
	var loaded := Arena.load_layout("doors_dev")
	assert_true(not loaded.has("error"), "doors_dev loads: %s" % loaded.get("error", ""))
	if loaded.has("error"):
		return
	var layout: Dictionary = loaded["layout"]
	assert_true(Arena.is_fixture(layout), "a fixture: never dealt (C47.8: doors stay on the dev arena until route reads them)")
	assert_eq(BlastDoors.from_layout(layout, 7001).ids(), PackedStringArray(["west_gate", "east_gate"]), "two doors")
	var arena := await ArenaFixture.build(self, "doors_dev")
	assert_eq(arena.doors.bodies.size(), 2, "built")
	# The flank gaps never close: a path from base to base exists through them with both doors shut (the navmesh is
	# baked open, so this checks the WALL leaves the flanks open; the doors' own effect on routes is route's, C47.8).
	var map := arena.get_world_3d().navigation_map
	var path := NavigationServer3D.map_get_path(map, Vector3(-100.0, 0.0, 60.0), Vector3(-100.0, 0.0, -60.0), true)
	assert_true(path.size() >= 2 and Vector2(path[path.size() - 1].x, path[path.size() - 1].z).distance_to(Vector2(-100.0, -60.0)) < 1.5,
			"the west flank gap is open: %d points" % path.size())
