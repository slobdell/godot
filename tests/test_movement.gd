extends TestCase
## N1, the Movement API (nav X1, round 6): request / state / eta / cancel, and the guarantee under them — a unit that
## cannot make progress says `blocked`, and names what it is blocked by, instead of standing still silently.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## An open lane on the west side of the default arena.
const LANE := Vector3(-100, 0, 20)


func _setup() -> Array:
	# Its OWN navmesh, not the previous test's (tests/support/arena_fixture.gd explains the trap).
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN)
	tank.global_position = LANE
	tank.rotation.y = 0.0
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	return [game_match, tank, orders]


func test_state_reports_driving_then_arrived() -> void:
	var setup: Array = await _setup()
	var tank: Tank = setup[1]
	var orders: OrderController = setup[2]
	assert_eq(Movement.state(tank), {}, "before anything drives it there is nothing to report")
	orders.set_orders({"type": "move_to", "x": LANE.x, "z": LANE.z - 30.0}, {"type": "hold_fire"})
	await wait_physics_frames(3)
	var reading := Movement.state(tank)
	assert_eq(reading.get("phase"), "driving", "under way: driving (got %s)" % reading)
	assert_true(float(reading["remaining_m"]) > 20.0, "remaining is the route left (%.1f m)" % float(reading["remaining_m"]))
	assert_true(float(reading["eta_s"]) > 1.0, "and an ETA comes with it (%.1f s)" % float(reading["eta_s"]))
	assert_eq(reading["blocked_by"], "", "nothing is blocking it")
	for frame in SimClock.TICK_RATE * 10:
		await tree.physics_frame
		if Movement.state(tank)["phase"] == "arrived":
			break
	assert_eq(Movement.state(tank)["phase"], "arrived", "30 m of open lane is driven in under 10 s")
	assert_true(Vector2(tank.global_position.x - LANE.x, tank.global_position.z - (LANE.z - 30.0)).length() <= 4.0,
			"and 'arrived' means it is there (%s)" % tank.global_position)


func test_blocked_names_the_hull_in_the_way() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var tank: Tank = setup[1]
	var orders: OrderController = setup[2]
	# A goal straight through a parked hull: the hull sits dead ahead, nose to nose, and the goal is right behind it.
	var wall := game_match.spawn_tank("Parked", 1, Match.Team.GREEN)
	wall.global_position = LANE + Vector3(0, 0, -5.5)
	wall.rotation.y = PI / 2.0
	orders.set_orders({"type": "move_to", "x": LANE.x, "z": LANE.z - 8.0, "direct": true}, {"type": "hold_fire"})
	var seen_blocked := false
	for frame in SimClock.TICK_RATE * 8:
		await tree.physics_frame
		var reading := Movement.state(tank)
		if reading["phase"] == "arrived":
			break
		if reading["phase"] == "blocked":
			seen_blocked = true
			assert_eq(reading["blocked_by"], "Parked", "it names the hull it is up against (got %s)" % reading)
			break
	assert_true(seen_blocked, "pushing nose to nose into a parked hull, it says it is blocked — never silently still (%s, at %s)" % [
			Movement.state(tank), tank.global_position])


func test_request_and_cancel() -> void:
	var setup: Array = await _setup()
	var tank: Tank = setup[1]
	var orders: OrderController = setup[2]
	await wait_physics_frames(1)
	Movement.request(tank, LANE + Vector3(0, 0, -20), {"arrive_radius": 2.0, "pace": 0.5})
	assert_eq(orders.move_order["type"], "move_to", "request is a move order")
	assert_near(float(orders.move_order["arrive"]), 2.0, 0.001, "carrying its arrive radius")
	assert_near(float(orders.move_order["speed"]), 0.5, 0.001, "and its pace")
	await wait_physics_frames(3)
	assert_true(tank.speed() > 0.1, "and the unit drives off")
	Movement.cancel(tank)
	assert_eq(orders.move_order["type"], "stop", "cancel stops it")
	await wait_physics_frames(2)
	assert_eq(Movement.state(tank)["phase"], "arrived", "and a stopped unit has nothing left to do")


func test_eta_follows_the_route_not_the_crow() -> void:
	var setup: Array = await _setup()
	var tank: Tank = setup[1]
	await wait_physics_frames(1)
	var ahead := LANE + Vector3(0, 0, -40)
	var straight := 40.0 / (tank.max_forward_speed * Movement.ETA_CRUISE_SHARE)
	assert_near(Movement.eta(tank, ahead), straight, 0.6, "open ground, already facing it: distance over cruise speed")
	var behind := LANE + Vector3(0, 0, 40)
	assert_true(Movement.eta(tank, behind) > straight + 1.0, "a point behind costs the pivot too")
	assert_near(Movement.eta(tank, tank.global_position), 0.0, 0.001, "zero when already there")


func test_asked_to_give_way_it_steps_off_the_line_and_resumes() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var asker: Tank = setup[1]
	var asker_orders: OrderController = setup[2]
	# A friend parked in the lane, 12 m up it, holding a stop order.
	var parked := game_match.spawn_tank("Parked", 1, Match.Team.GREEN)
	parked.global_position = LANE + Vector3(0, 0, -12)
	var parked_orders := OrderController.new()
	parked_orders.tank = parked
	parked_orders.tanks_root = game_match.tanks
	add_to_tree(parked_orders)
	await wait_physics_frames(2)
	var mover := Movement.of(parked)
	assert_true(mover != null, "setup: the parked unit has a mover")
	assert_true(mover.ask("Mover", asker.global_position, Vector2(0, -1)), "asked, it finds a spot and gives way")
	var reading := Movement.state(parked)
	assert_eq(reading["phase"], "yielding", "and says so (%s)" % reading)
	assert_eq(reading["blocked_by"], "Mover", "naming who it is giving way to")
	assert_true(absf(mover._yield_point.x - LANE.x) >= 2.0 * Avoidance.radius_of(parked.unit_id),
			"its spot is off the asker's line (%s)" % mover._yield_point)
	asker_orders.set_orders({"type": "move_to", "x": LANE.x, "z": LANE.z - 30.0}, {"type": "hold_fire"})
	var resumed := false
	for frame in SimClock.TICK_RATE * 10:
		await tree.physics_frame
		if Movement.state(parked)["phase"] != "yielding":
			resumed = true
			break
	assert_true(resumed, "once the asker is past it stops giving way")
	assert_eq(parked_orders.move_order["type"], "stop", "and its own order is still the one it had")
	assert_true(not mover.ask("Mover", asker.global_position, Vector2(0, -1)),
			"it never gives way twice in a row to the same unit")


func test_an_unreachable_goal_says_so_instead_of_arriving() -> void:
	# Lesson 76: the navmesh answers an unreachable goal with a route to the nearest reachable point. A goal inside a
	# solid obstacle must read as blocked / no_path at the end of that route — never as arrived, never as driving on.
	# Round 11: the goal is the CENTRE of a 40 m Terminus block, 20 m from any face — beyond Movement.REPAIR_MAX_M, so
	# the one repair is refused and the honest report stands (a small prop's inside is now repaired: the test below).
	var reading := await _drive_into_block(Vector3(40.0, 0.0, 0.0))
	assert_eq(reading.get("reachable"), false, "the route is known not to reach the goal (%s)" % reading)
	assert_eq(reading.get("phase"), "blocked", "and at the end of it the unit says blocked, not arrived (%s)" % reading)
	assert_eq(reading.get("blocked_by"), "no_path", "because there is no path there (%s)" % reading)
	assert_eq(float(reading.get("repaired_m", -1.0)), 0.0, "and it was not quietly sent somewhere else (%s)" % reading)


## Round 11 (nav R2 item 3): repair, don't just report. A goal 3 m inside a block face is one the hull can stand
## beside: Movement re-grounds it once with the hull's envelope and drives there, and says how far it moved it.
## The repair is OPT-IN until order completion honours it (Movement.repair_on()); switched on here for the test.
func test_a_goal_just_inside_a_wall_is_repaired_once_and_arrived_at() -> void:
	Movement.reset_route_arms()
	var saved := Movement._off
	Movement._off = PackedStringArray(["repair"])
	# The (40, 0) block's north face is z = 20; the goal is 3 m inside it.
	var reading := await _drive_into_block(Vector3(40.0, 0.0, 17.0), "arrived")
	Movement._off = saved
	assert_eq(reading.get("phase"), "arrived", "the repaired goal is driven to and arrived at (%s)" % reading)
	assert_true(float(reading.get("repaired_m", 0.0)) >= 3.0 and float(reading.get("repaired_m", 0.0)) <= Movement.REPAIR_MAX_M,
			"and the reading says how far the goal was moved (%s)" % reading.get("repaired_m"))
	assert_eq(int(Movement.route_arms()["goal_repairs"]), 1, "one repair, counted (%s)" % Movement.route_arms())


## Drive a tank from the ring road at `goal` inside a Terminus block until `until` (or blocked); the last reading.
func _drive_into_block(goal: Vector3, until := "blocked") -> Dictionary:
	await ArenaFixture.build(self, "terminus")  # its OWN navmesh, not the last test's (ArenaFixture header)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN)
	tank.global_position = Vector3(goal.x, 0.0, 31.0)  # the ring road, north of the block
	tank.rotation.y = 0.0  # nose north... it has to turn round: the goal is behind it
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	orders.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	var reading := {}
	for frame in SimClock.TICK_RATE * 15:
		await tree.physics_frame
		reading = Movement.state(tank)
		if reading["phase"] == until or reading["phase"] == "blocked":
			break
	return reading


func test_two_hulls_spawned_on_one_spot_separate_and_both_drive_off() -> void:
	# An overfull spawn line or a respawn can put two hulls exactly on top of each other. In round 5 such pairs never
	# moved at all (8 of them in every 60-unit maze run). Avoidance parts them by name, in opposite directions.
	var setup: Array = await _setup()
	var game_match: Match = setup[0]
	var first: Tank = setup[1]
	var first_orders: OrderController = setup[2]
	var second := game_match.spawn_tank("Stacked", 1, Match.Team.GREEN)
	second.global_position = first.global_position
	second.rotation.y = first.rotation.y
	var second_orders := OrderController.new()
	second_orders.tank = second
	second_orders.tanks_root = game_match.tanks
	add_to_tree(second_orders)
	var goal := LANE + Vector3(0, 0, -30)
	first_orders.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	second_orders.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_true(first.global_position.distance_to(second.global_position) > 3.0,
			"they came apart (%.1f m)" % first.global_position.distance_to(second.global_position))
	for tank: Tank in [first, second]:
		assert_true(tank.global_position.distance_to(LANE) > 6.0, "%s drove off (%.1f m from the start)" % [tank.name,
				tank.global_position.distance_to(LANE)])


func test_pathing_query_says_whether_a_route_gets_there() -> void:
	# Lesson 76: reachability is the route ending at the goal, not a route coming back. Pathing.query reports it, and
	# reports the gaps rather than comparing them against a tolerance of the caller's choosing.
	var arena := await ArenaFixture.build(self, "yard")
	var open_from := NavigationServer3D.map_get_closest_point(arena.get_world_3d().navigation_map, Vector3(-40, 0, 90))
	var open_to := NavigationServer3D.map_get_closest_point(arena.get_world_3d().navigation_map, Vector3(40, 0, -90))
	var open := Pathing.query(arena, open_from, open_to)
	assert_true(bool(open["ready"]) and bool(open["reachable"]) and bool(open["goal_on_mesh"]),
			"across open ground: reachable and on the mesh (%s)" % [open])
	assert_near(float(open["end_gap_m"]), 0.0, Pathing.MESH_EPSILON, "no gap at the end")
	var inside: Vector3 = ArenaFixture.inside_cover(arena.layout)
	var into_cover := Pathing.query(arena, open_from, inside)
	assert_true(not bool(into_cover["goal_on_mesh"]), "a goal inside a container is off the mesh (%s)" % [into_cover])
	assert_true(float(into_cover["goal_gap_m"]) > 1.0, "by more than a metre (%.2f m)" % float(into_cover["goal_gap_m"]))
	assert_true(bool(into_cover["reachable"]), "but the route still ends at its nearest drivable point (%s)" % [into_cover])
