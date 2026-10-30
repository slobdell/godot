extends TestCase
## Round 47 (route R0, C47.3): `Pathing.reroute(crew, reason)`, the door manoeuvre's no-progress watchdog asks for a new
## route through. A crew driving a route that no longer matches the ground it is on (here: its route replaced by a
## stale two-point line) is re-planned on the NEXT tick after the call, from where it stands, on whichever execute
## drives it (GDScript or the native-owned state); the reason is counted; a crew with no mover is refused.

const MATCH := preload("res://game/match/match.tscn")
const GOAL := Vector3(40.0, 0.0, 30.0)


func _driving_crew() -> Tank:
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Reroute1", 0, Match.Team.GREEN, "ifv")
	tank.place(Vector3(0.0, 0.0, 0.0), tank.rotation.y)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(3)
	assert_true(Pathing.is_ready(tank), "the navmesh is ready")
	assert_eq(orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"}), "", "ordered")
	await wait_physics_frames(10)
	return tank


func test_reroute_replans_the_crews_route_on_the_next_tick() -> void:
	var tank := await _driving_crew()
	var mover := Movement.of(tank)
	assert_true(mover != null and mover._path.size() >= 2, "the crew is driving a route")
	var real_end := mover._path[mover._path.size() - 1]
	# A stale route: two points nowhere near the goal, planned "for" the goal it has now (so no event re-plans it).
	var stale := PackedVector3Array([tank.global_position, tank.global_position + Vector3(-30.0, 0.0, -30.0)])
	mover._path = stale
	mover._path_index = 1
	mover.native_stale |= Movement.STALE_ALL
	await wait_physics_frames(2)
	assert_eq(mover._path, stale, "nothing re-plans a stale route by itself within two ticks (the A1 tube holds it)")
	var before := int(Pathing.reroutes.get(&"test_no_progress", 0))
	assert_true(Pathing.reroute(tank, &"test_no_progress"), "the door takes a crew with a mover")
	await wait_physics_frames(2)
	assert_true(mover._path != stale, "the next tick re-planned the route")
	assert_true(mover._path.size() >= 2, "a real route")
	var end := mover._path[mover._path.size() - 1]
	assert_true(Vector2(end.x - real_end.x, end.z - real_end.z).length() < 1.0,
			"to the same goal as before (%s v %s)" % [end, real_end])
	assert_eq(int(Pathing.reroutes.get(&"test_no_progress", 0)), before + 1, "and the reason was counted")


func test_reroute_refuses_a_crew_with_no_mover() -> void:
	assert_true(not Pathing.reroute(null, &"test"), "no crew")
	var stray := Node3D.new()
	add_to_tree(stray)
	assert_true(not Pathing.reroute(stray, &"test"), "a node no Movement drives")
