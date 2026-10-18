extends TestCase
## Round 30 (brains B5c-v4): the arrival gate keeps the yard crossing's win (a gate reached is latched) AND the 180-degree
## arrival (a car told to face the way it came still comes round and parks facing it). Traced side by side (builder0,
## round 29's a8df3dc3 state): both reach their gate facing away; in open ground the car comes round it in ~8 s, on the
## yard (seed 23 t3) coming round ran Green_A_5 into the containers twice (last crew 39.9 s v the latch's 22.1 s). So a
## car comes round only where a turning circle fits beside the gate, and only until it is stuck or out of time. Plus the
## B_4 refinement (Terminus seed 3): a hull already within the approach length of a new goal gets no gate behind it.
## Lesson 305: the 90 AND 180 degree cases, and the counters that say the rule fired (lesson 300).

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(-100, 0, 40)
const GOAL := Vector3(-100, 0, 0)


func _car(at := START, unit_id := "ifv") -> OrderController:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, unit_id)
	tank.global_position = at
	tank.rotation.y = 0.0
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	for frame in 300:
		if Pathing.is_ready(tank):
			break
		await tree.physics_frame
	Movement.reset_gates()
	return orders


func _drive(orders: OrderController, facing: Vector3, seconds := 22.0) -> Dictionary:
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": [facing.x, facing.z]}
	assert_eq(orders.set_orders(order, {"type": "hold_fire"}), "", "the order is accepted")
	for frame in int(SimClock.TICK_RATE * seconds):
		await tree.physics_frame
		if Movement.state(orders.tank)["phase"] == "arrived":
			break
	return Movement.state(orders.tank)


func _dot(orders: OrderController, facing: Vector3) -> float:
	return (-orders.tank.global_basis.z).dot(facing)


func test_a_car_told_to_face_the_way_it_came_comes_round_its_gate_and_parks_facing_it() -> void:
	var orders: OrderController = await _car()
	var reading := await _drive(orders, Vector3.BACK)
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	assert_true(_dot(orders, Vector3.BACK) > 0.85, "facing back the way it came (dot %.2f)" % _dot(orders, Vector3.BACK))
	assert_true(Movement.gates_turned > 0, "it came round its gate: open ground has a turning circle beside it (%s)"
			% Movement.gate_report())
	assert_eq(Movement.gates_latched_away, 0, "and never latched facing away (%s)" % Movement.gate_report())


func test_a_car_told_to_face_ninety_degrees_off_arrives_on_it() -> void:
	var orders: OrderController = await _car()
	var reading := await _drive(orders, Vector3.RIGHT)
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	assert_true(_dot(orders, Vector3.RIGHT) > 0.85, "facing east (dot %.2f)" % _dot(orders, Vector3.RIGHT))
	assert_true(Movement.gates_reached_latched > 0, "its gate was reached and latched (%s)" % Movement.gate_report())


func test_a_turning_circle_beside_the_gate_is_what_lets_a_car_come_round() -> void:
	var orders: OrderController = await _car()
	var map: RID = orders.tank.get_world_3d().navigation_map
	var radius := orders.movement.wheel_radius()
	assert_true(radius > 0.0, "an IFV turns on wheels")
	assert_true(Movement._turn_room(Vector3(-100, 0, -17.5), Vector2(0, 1), radius, map),
			"open ground behind the goal has a turning circle beside the gate")
	assert_true(not Movement._turn_room(Vector3(5000, 0, 0), Vector2(0, 1), radius, map), "off the arena it has none")


func test_coming_round_is_bounded_by_a_stall_on_terrain_and_by_time_but_not_by_circling() -> void:
	var orders: OrderController = await _car()
	var mover := orders.movement
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": [0.0, 1.0]}
	var gate := mover._approach_gate(GOAL, order)
	assert_true(gate != GOAL, "from 40 m out the car is given its gate")
	mover._gate_turning_for = GOAL
	mover._gate_turning_tick = mover._order_ticks
	mover.phase = "blocked"
	mover.blocked_by = "no_path"
	assert_eq(mover._approach_gate(GOAL, order), gate, "circling reads as no_path: it keeps coming round")
	mover.blocked_by = "terrain"
	assert_eq(mover._approach_gate(GOAL, order), GOAL, "stuck on terrain while turning: the gate is latched")
	assert_eq(mover._gate_dropped_why, "turn_blocked", "and says why")
	mover._gate_dropped_for = Vector3.INF
	mover.phase = "driving"
	mover.blocked_by = ""
	mover._order_ticks = mover._gate_turning_tick + int(Movement.GATE_TURN_SECONDS * SimClock.TICK_RATE) + 1
	assert_eq(mover._approach_gate(GOAL, order), GOAL, "out of time coming round: latched")
	assert_eq(mover._gate_dropped_why, "turn_capped", "and says why")


func test_a_hull_already_beside_its_new_goal_gets_no_gate_behind_it() -> void:
	# B_4's case: 9 m from its slot, the gate 17.5 m back the other way (judged on the nominal approach, before the
	# roomy rule shortens it). Straight in, not 37 m round by the gate.
	var orders: OrderController = await _car(GOAL + Vector3(0, 0, 9))
	var reading := await _drive(orders, Vector3.RIGHT, 12.0)
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	assert_true(Movement.gates_near > 0, "the near rule fired (%s)" % Movement.gate_report())
	assert_eq(Movement.gates_aimed, 0, "and no gate was ever aimed at for that goal (%s)" % Movement.gate_report())


func test_a_scout_short_of_its_slot_told_to_face_back_drives_in_not_round_a_far_gate() -> void:
	# The planner's F4 reproduction (stream/planner e63a3099, main bd05077d, builder0, n = 1, relayed by the
	# orchestrator): a law_scout 9 m short of its slot, heading at it, told to face back the way it came, drove 102 m
	# through a gate 13.75 m beyond the slot. The near rule's second sighting, on a scout, not only B_4's rig.
	var orders: OrderController = await _car(GOAL + Vector3(0, 0, 9), "law_scout")
	var from := orders.tank.global_position
	var metres := 0.0
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": [0.0, 1.0]}
	assert_eq(orders.set_orders(order, {"type": "hold_fire"}), "", "the order is accepted")
	for frame in int(SimClock.TICK_RATE * 12.0):
		await tree.physics_frame
		metres += Movement._flat_distance(from, orders.tank.global_position)
		from = orders.tank.global_position
		if Movement.state(orders.tank)["phase"] == "arrived":
			break
	assert_eq(Movement.state(orders.tank).get("phase"), "arrived", "it gets there (%s)" % Movement.state(orders.tank))
	assert_true(Movement.gates_near > 0, "the near rule fired (%s)" % Movement.gate_report())
	assert_true(metres < 30.0, "a short drive in, not round a far gate (%.1f m)" % metres)


func test_the_near_rule_leaves_a_car_far_from_its_goal_its_gate() -> void:
	var orders: OrderController = await _car()
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": [1.0, 0.0]}
	assert_true(orders.movement._approach_gate(GOAL, order) != GOAL, "40 m out, the gate stands")
	assert_eq(Movement.gates_near, 0, "the near rule did not fire")


func test_with_the_switch_off_nothing_of_v4_fires() -> void:
	var was := Movement._off
	Movement._off = PackedStringArray(["gategiveup"])
	var orders: OrderController = await _car()
	var reading := await _drive(orders, Vector3.BACK)
	Movement._off = was
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	assert_eq([Movement.gates_turned, Movement.gates_latched_away, Movement.gates_near], [0, 0, 0], "today's gate, untouched")
