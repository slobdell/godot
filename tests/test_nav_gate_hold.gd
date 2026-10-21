extends TestCase
## Round 29 (brains B5c): a car's arrival gate is held to what the car can do with it. Traced (builder0): on yard_open's
## crossing a car at its gate pointing off the heading drove for the goal, left the gate's 2.5 m, was sent back and
## circled it for 33 s; on Sumps a gate sat 2.7 m from a parked squadmate and the crew shoved at it for 8 s; on Terminus a
## gate 4.7 m from the arena edge was reached and the car ground against the edge. The rule (ON by default since the
## flip; `--nav-off=gategiveup` is the control arm): a gate reached, or stalled at, is done for
## that goal, and a gate is laid only where a turning circle fits round it (a shorter run-in that has the room, or none).

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(-100, 0, 40)
const GOAL := Vector3(-100, 0, 0)


func _car() -> OrderController:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, "ifv")
	tank.place(START, 0.0)
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	for frame in 300:
		if Pathing.is_ready(tank):
			break
		await tree.physics_frame
	return orders


func _drive(orders: OrderController, facing: Vector3, seconds := 16.0) -> Dictionary:
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": [facing.x, facing.z]}
	assert_eq(orders.set_orders(order, {"type": "hold_fire"}), "", "the order is accepted")
	for frame in int(SimClock.TICK_RATE * seconds):
		await tree.physics_frame
		if Movement.state(orders.tank)["phase"] == "arrived":
			break
	return Movement.state(orders.tank)


func _switch(on: bool) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray() if on else PackedStringArray(["gategiveup"])
	Movement.reset_gates()
	return was


func test_with_the_switch_off_no_gate_is_latched_given_up_or_shortened() -> void:
	var was := _switch(false)
	var orders: OrderController = await _car()
	var reading := await _drive(orders, Vector3.RIGHT)
	Movement._off = was
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	assert_eq([Movement.gates_given_up, Movement.gates_reached_latched, Movement.gates_shortened], [0, 0, 0],
			"today's gate, untouched")


func test_a_reached_gate_is_latched_and_the_car_still_arrives_on_its_heading() -> void:
	var was := _switch(true)
	var orders: OrderController = await _car()
	var reading := await _drive(orders, Vector3.RIGHT)
	Movement._off = was
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	assert_true(Movement.gates_reached_latched > 0, "the gate was reached and held done (lesson 300)")
	var east := (-orders.tank.global_basis.z).dot(Vector3.RIGHT)
	assert_true(east > 0.85, "and the latch does not spoil the approach: facing east (dot %.2f)" % east)


func test_a_gate_given_up_for_a_goal_stays_given_up_until_the_goal_moves() -> void:
	var was := _switch(true)
	var orders: OrderController = await _car()
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": [1.0, 0.0]}
	assert_true(orders.movement._approach_gate(GOAL, order) != GOAL, "in the open the car is given a gate")
	orders.movement._gate_dropped_for = GOAL
	assert_eq(orders.movement._approach_gate(GOAL + Vector3(1.0, 0.0, 0.0), order), GOAL + Vector3(1.0, 0.0, 0.0),
			"a metre's drift is the same goal: still no gate")
	var far := GOAL + Vector3(0.0, 0.0, -30.0)
	assert_true(orders.movement._approach_gate(far, order) != far, "a new goal gets its gate back")
	Movement._off = was


func test_a_gate_needs_a_turning_circle_of_navmesh_round_it() -> void:
	var orders: OrderController = await _car()
	var map: RID = orders.tank.get_world_3d().navigation_map
	var radius := orders.movement.wheel_radius()
	assert_true(radius > 0.0, "an IFV turns on wheels")
	assert_true(Movement._gate_has_room(START, radius, map), "open ground where the car starts has the room")
	assert_true(not Movement._gate_has_room(Vector3(5000.0, 0.0, 0.0), radius, map), "off the arena it has none")
