extends TestCase
## Round 33 (brains B5c-v6, R33.8; traffic's X4 trace): a wheeled hull whose approach gate lies inside one of its own
## turning circles cannot reach it driving forward, and Steering's circle rule backed and filled round it (yard head-on
## s42 t3 Green_A_5: 11 -> 134 circle reverses in 16 s, 5 m from the gate, pointing the wrong way). Such a gate is
## latched ("inside_circle") and the hull drives onto its goal; not while it comes round a gate it reached facing away.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(-100, 0, 40)
const GOAL := Vector3(-100, 0, 0)
const EAST := [1.0, 0.0]


func teardown() -> void:
	Movement._off = Movement._parse_off()
	super.teardown()


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
	Movement.reset_gates()
	return orders


func test_a_point_beside_the_hull_is_inside_a_turning_circle_and_one_ahead_is_not() -> void:
	var here := Vector3(0, 0, 0)
	var north := Vector2(0, -1)
	assert_true(Movement.inside_turning_circle(here, north, Vector3(-3, 0, 0), 7.0), "3 m to the left: inside")
	assert_true(Movement.inside_turning_circle(here, north, Vector3(3, 0, -1), 7.0), "3 m to the right, 1 m on: inside")
	assert_true(not Movement.inside_turning_circle(here, north, Vector3(0, 0, -5), 7.0), "5 m dead ahead: reachable")
	assert_true(not Movement.inside_turning_circle(here, north, Vector3(-15, 0, 0), 7.0), "15 m to the side: outside")
	assert_true(not Movement.inside_turning_circle(here, north, here, 7.0), "on the hull: not a circle question")


## A_5's shape: given its gate from 40 m out, then (after a k-turn) standing 4.5 m from it, pointing north while the
## approach runs east: the gate sits inside its left circle.
func _beside_its_gate(orders: OrderController) -> Dictionary:
	var mover := orders.movement
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z, "facing": EAST}
	var gate := mover._approach_gate(GOAL, order)
	assert_true(gate != GOAL, "from 40 m out the car is given its gate")
	orders.tank.global_position = gate + Vector3(4.5, 0.0, 0.0)
	return {"order": order, "gate": gate}


func test_a_hull_standing_inside_the_circle_of_its_gate_latches_it_and_drives_onto_the_goal() -> void:
	var orders: OrderController = await _car()
	var setup := _beside_its_gate(orders)
	assert_true(Movement.inside_turning_circle(orders.tank.global_position, Vector2(0, -1), setup["gate"],
			orders.movement.wheel_radius()), "setup: the gate is inside its circle (radius %.1f)" % orders.movement.wheel_radius())
	assert_eq(orders.movement._approach_gate(GOAL, setup["order"]), GOAL, "the route aims at the goal")
	assert_eq(orders.movement._gate_dropped_why, "inside_circle", "and says why")
	assert_eq(Movement.gates_inside, 1, "counted")
	orders.tank.global_position = setup["gate"] + Vector3(-20.0, 0.0, 0.0)
	assert_eq(orders.movement._approach_gate(GOAL, setup["order"]), GOAL, "latched for this goal, wherever it drives")


func test_coming_round_a_gate_reached_facing_away_is_left_to_the_v4_turn() -> void:
	var orders: OrderController = await _car()
	var setup := _beside_its_gate(orders)
	orders.movement._gate_turning_for = GOAL
	orders.movement._gate_turning_tick = orders.movement._order_ticks
	assert_eq(orders.movement._approach_gate(GOAL, setup["order"]), setup["gate"], "it keeps coming round its gate")
	assert_eq(Movement.gates_inside, 0, "the inside rule did not fire")


func test_with_the_switch_off_the_gate_stands() -> void:
	Movement._off = PackedStringArray(["gateinside"])
	var orders: OrderController = await _car()
	var setup := _beside_its_gate(orders)
	assert_eq(orders.movement._approach_gate(GOAL, setup["order"]), setup["gate"], "v6 without it: the gate is re-aimed")
	assert_eq(Movement.gates_inside, 0, "nothing counted")
