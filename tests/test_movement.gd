extends TestCase
## N1, the Movement API (nav X1, round 6): request / state / eta / cancel, and the guarantee under them — a unit that
## cannot make progress says `blocked`, and names what it is blocked by, instead of standing still silently.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## An open lane on the west side of the default arena.
const LANE := Vector3(-100, 0, 20)


func _setup() -> Array:
	var arena: Node3D = ARENA.instantiate()
	add_to_tree(arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	for frame in SimClock.TICK_RATE:
		if Pathing.is_ready(arena):
			break
		await tree.physics_frame
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
