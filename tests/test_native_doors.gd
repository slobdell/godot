extends TestCase
## Round 47 (native, C47.8, route R5's request): the native drive's own route query (drive_native.cpp path_query, the re-plan) is
## Pathing.query's answer with and without a blast door: no door registered = the native query on layer 1 (today's routes,
## byte-identical); a door registered = Pathing.query itself (RouteDoors.mask asks the doors' layers too). Route's stand-in door
## (tests/test_pathing_doors.gd): one NavigationLink3D across the Locks canal on the door's own layer bit. Poses: no door, the
## door open, shut (RouteDoors.is_open_fn), switched off (`--route-off=doors`), over several crossings of the canal.

const MATCH := preload("res://game/match/match.tscn")
const DOOR := Vector3(-45.0, 0.0, 0.0)
const ROUTES := [[Vector3(-50.0, 0.0, 40.0), Vector3(-45.0, 0.0, -40.0)], [Vector3(-40.0, 0.0, 30.0), Vector3(-52.0, 0.0, -30.0)],
		[Vector3(-30.0, 0.0, 45.0), Vector3(-60.0, 0.0, -45.0)], [Vector3(-48.0, 0.0, 20.0), Vector3(-44.0, 0.0, -20.0)],
		[Vector3(-45.0, 0.0, -40.0), Vector3(-50.0, 0.0, 40.0)]]


func teardown() -> void:
	RouteDoors.clear()
	RouteDoors.off = false
	RouteDoors.is_open_fn = Callable()


func _same(a: Dictionary, b: Dictionary) -> bool:
	return var_to_bytes(a) == var_to_bytes(b)


func test_the_native_drive_query_is_pathing_query_with_and_without_a_door() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the door query equality is not exercised in this run")
		return
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	RouteDoors.clear()
	await ArenaFixture.build(self, "locks")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("DoorCrew", 0, Match.Team.GREEN, "tank")
	tank.place(Vector3(-50.0, 0.0, 40.0), 0.0)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	var link := NavigationLink3D.new()
	link.start_position = DOOR + Vector3(0.0, 0.0, 12.0)
	link.end_position = DOOR - Vector3(0.0, 0.0, 12.0)
	link.bidirectional = true
	link.navigation_layers = RouteDoors.layer_of(0)
	add_to_tree(link)
	await wait_physics_frames(3)
	var mover := Movement.of(tank)
	assert_true(mover != null, "a mover")
	var compared := 0
	var mismatches := 0
	var through := 0
	var first := ""
	for pose in ["none", "open", "shut", "off"]:
		RouteDoors.clear()
		RouteDoors.off = pose == "off"
		RouteDoors.is_open_fn = (func(_id: StringName, _tick: int) -> bool: return false) if pose == "shut" else Callable()
		if pose != "none":
			RouteDoors.register(&"door_a", DOOR)
		for route: Array in ROUTES:
			var live: Dictionary = Pathing.query(tank, route[0], route[1])
			var native: Dictionary = NativeBridge.impl.drive_path_query(mover, route[0], route[1])
			compared += 1
			var points: PackedVector3Array = live.get("points", PackedVector3Array())
			for i in range(1, points.size()):
				var on := Geometry3D.get_closest_point_to_segment(DOOR, points[i - 1], points[i])
				if Vector2(on.x - DOOR.x, on.z - DOOR.z).length() <= 3.0:
					through += 1
					break
			if not _same(live, native):
				mismatches += 1
				if first == "":
					first = "%s %s: live %s native %s" % [pose, route, live, native]
	RouteDoors.is_open_fn = Callable()
	print("MEASURE native_doors compared=%d mismatches=%d through_the_door=%d" % [compared, mismatches, through])
	assert_eq(mismatches, 0, "the native drive's query = Pathing.query (%d); first: %s" % [compared, first])
	assert_true(through >= 3, "the open door was used by some routes (%d), so the door poses differ from today's" % through)
