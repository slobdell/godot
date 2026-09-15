extends TestCase
## K1 Orders API (control X1): UnitCommand validation, Orders.issue/current/queue/complete, order_changed, groups
## and formation slots. Pure data on a real Match (no brains need to think for these).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var doctrine := {"name": "Test", "squads": [
			{"name": "Alpha", "units": [{"unit": "tank"}, {"unit": "ifv"}, {"unit": "scout"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: green doctrine")
	var rust := {"name": "Test", "squads": [{"name": "Alpha", "units": [{"unit": "tank"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.RUST, rust), "", "setup: rust doctrine")
	var orders := Orders.new(game_match)
	return [game_match, orders]


func test_unit_command_validation_names_the_problem() -> void:
	assert_eq(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [1, 2]}), "", "a move with a destination is valid")
	assert_eq(UnitCommand.validate({"units": ["A"], "verb": "stop"}), "", "stop needs nothing else")
	assert_eq(UnitCommand.validate({"units": ["A"], "verb": "hold"}), "", "hold without a destination holds where it is")
	assert_true(UnitCommand.validate("move") != "", "a string is not a command")
	assert_true(UnitCommand.validate({"verb": "move", "to": [0, 0]}).contains("units"), "units are required")
	assert_true(UnitCommand.validate({"units": [], "verb": "stop"}).contains("units"), "an empty unit list is rejected")
	assert_true(UnitCommand.validate({"units": [3], "verb": "stop"}).contains("units"), "unit names are strings")
	assert_true(UnitCommand.validate({"units": ["A", "A"], "verb": "stop"}).contains("twice"), "a unit listed twice is rejected")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "dance"}).contains("verb"), "unknown verbs are rejected")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "move"}).contains("to"), "move needs a destination")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "attack_move"}).contains("to"), "attack-move needs a destination")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "attack"}).contains("target"), "attack needs a target")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "follow"}).contains("target"), "follow needs a target")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [NAN, 0]}).contains("to"), "NaN destinations are rejected")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [1]}).contains("to"), "destinations are [x, z]")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "stop", "queue": "yes"}).contains("queue"), "queue is a bool")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [0, 0], "formation": "blob"}).contains("formation"),
			"unknown formations are rejected")
	assert_eq(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [0, 0], "formation": "auto"}), "", "auto formation")
	assert_eq(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [0, 0], "formation": "wedge"}), "", "a named formation")
	assert_true(UnitCommand.validate({"units": ["A"], "verb": "move", "to": [0, 0], "speed": 2}).contains("speed"),
			"unknown keys are rejected (catches typos from scripts and LLMs)")


func test_unit_command_round_trips_through_json() -> void:
	var command := UnitCommand.make(["Green_Alpha_1"], "attack_move", {"to": [10.5, -3.0], "queue": true})
	var parsed: Variant = JSON.parse_string(JSON.stringify(command))
	assert_eq(UnitCommand.validate(parsed), "", "a command survives JSON (numbers come back as floats)")
	assert_eq(parsed["verb"], "attack_move", "the verb survives JSON")


func test_issue_checks_units_and_targets_against_the_match() -> void:
	var setup: Array = _setup()
	var orders: Orders = setup[1]
	assert_true(orders.issue({"units": ["Nobody"], "verb": "stop"}).contains("Nobody"), "unknown units are named in the error")
	assert_true(orders.issue({"units": ["Green_Alpha_1", "Rust_Alpha_1"], "verb": "stop"}).contains("team"),
			"one command can't mix teams")
	assert_true(orders.issue({"units": ["Green_Alpha_1"], "verb": "stop"}, Match.Team.RUST).contains("team"),
			"a team can't command the other team's units")
	assert_true(orders.issue({"units": ["Green_Alpha_1"], "verb": "attack", "target": "Green_Alpha_2"}).contains("enemy"),
			"attack targets an enemy")
	assert_true(orders.issue({"units": ["Green_Alpha_1"], "verb": "attack", "target": "Ghost"}).contains("Ghost"),
			"an unknown target is named")
	assert_eq(orders.issue({"units": ["Green_Alpha_1"], "verb": "attack", "target": "Rust_Alpha_1"}), "", "attack an enemy")
	assert_eq(orders.issue({"units": ["Green_Alpha_1"], "verb": "follow", "target": "Green_Alpha_2"}), "", "follow a friend")
	assert_true(orders.issue({"units": ["Green_Alpha_1"], "verb": "follow", "target": "Green_Alpha_1"}).contains("itself"),
			"a unit can't follow itself")


func test_a_new_order_replaces_the_current_one_and_signals() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	var changed: Array[String] = []
	orders.order_changed.connect(func(unit_name: String) -> void: changed.append(unit_name))
	assert_eq(orders.current("Green_Alpha_1"), {}, "a unit starts with no order")
	assert_eq(orders.issue({"units": ["Green_Alpha_2", "Green_Alpha_1"], "verb": "move", "to": [0, 40]}), "", "move accepted")
	assert_eq(changed, ["Green_Alpha_1", "Green_Alpha_2"] as Array[String], "order_changed fires for each unit, in name order")
	var order := orders.current("Green_Alpha_1")
	assert_eq(order["verb"], "move", "the current order is the move")
	assert_eq(order["issued_tick"], game_match.tick, "the order records the tick it was issued")
	assert_eq(order["units"], ["Green_Alpha_1", "Green_Alpha_2"], "the order knows its group")
	assert_true(order.has("slot") and order.has("goal") and order.has("heading"), "a group move carries a slot, goal, and heading")
	assert_eq(orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [20, 40]}), "", "a second move accepted")
	assert_eq(orders.current("Green_Alpha_1")["to"], [20.0, 40.0], "the new order replaced the old one at once")
	assert_eq(orders.current("Green_Alpha_2")["to"], [0.0, 40.0], "the other unit keeps its order")
	assert_true(orders.current("Green_Alpha_1")["id"] != orders.current("Green_Alpha_2")["id"], "different commands get different ids")


func test_shift_queues_orders_and_complete_advances_the_queue() -> void:
	var setup: Array = _setup()
	var orders: Orders = setup[1]
	var name := "Green_Alpha_1"
	var changes := [0]
	orders.order_changed.connect(func(_unit: String) -> void: changes[0] += 1)
	assert_eq(orders.issue({"units": [name], "verb": "move", "to": [0, 60], "queue": true}), "", "a queued order on an idle unit")
	assert_eq(orders.current(name)["to"], [0.0, 60.0], "a queued order on an idle unit starts at once")
	assert_eq(orders.issue({"units": [name], "verb": "move", "to": [30, 60], "queue": true}), "", "queue a second waypoint")
	assert_eq(orders.issue({"units": [name], "verb": "attack_move", "to": [30, 20], "queue": true}), "", "queue a third")
	assert_eq(orders.current(name)["to"], [0.0, 60.0], "queuing doesn't change the current order")
	assert_eq(orders.queue(name).size(), 2, "two orders wait in the queue")
	assert_eq(changes[0], 1, "only the order that started signalled")
	orders.complete(name)
	assert_eq(orders.current(name)["to"], [30.0, 60.0], "complete starts the next waypoint")
	assert_eq(changes[0], 2, "completing signals the change")
	orders.complete(name)
	assert_eq(orders.current(name)["verb"], "attack_move", "then the attack-move")
	orders.complete(name)
	assert_eq(orders.current(name), {}, "the unit is idle when the queue runs out")
	assert_eq(orders.queue(name), [], "and the queue is empty")
	assert_eq(changes[0], 4, "going idle signals too")


func test_an_unqueued_order_clears_the_queue_and_stop_clears_everything() -> void:
	var setup: Array = _setup()
	var orders: Orders = setup[1]
	var name := "Green_Alpha_1"
	orders.issue({"units": [name], "verb": "move", "to": [0, 60]})
	orders.issue({"units": [name], "verb": "move", "to": [30, 60], "queue": true})
	orders.issue({"units": [name], "verb": "move", "to": [-30, 60]})
	assert_eq(orders.queue(name), [], "a plain order drops the queue")
	orders.issue({"units": [name], "verb": "move", "to": [30, 60], "queue": true})
	orders.issue({"units": [name], "verb": "stop", "queue": true})
	assert_eq(orders.current(name).get("verb", ""), "stop", "stop is never queued: it takes effect at once")
	assert_eq(orders.queue(name), [], "stop clears the queue")
	orders.complete(name)
	assert_eq(orders.current(name), {}, "a completed stop leaves the unit idle")


func test_group_moves_give_each_unit_its_own_slot_around_the_destination() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	var names := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
	for i in names.size():
		(game_match.tanks.get_node(names[i]) as Tank).global_position = Vector3(-10.0 + i * 10.0, 0.0, 80.0)
	assert_eq(orders.issue({"units": names, "verb": "move", "to": [0, 20]}), "", "group move accepted")
	var goals: Array[Vector2] = []
	for unit_name in names:
		var order := orders.current(unit_name)
		goals.append(Vector2(order["goal"][0], order["goal"][1]))
		assert_near(Vector2(order["heading"][0], order["heading"][1]).dot(Vector2(0, -1)), 1.0, 0.05,
				"%s's group heads north toward the destination" % unit_name)
	for i in goals.size():
		assert_true(goals[i].distance_to(Vector2(0, 20)) <= 25.0, "every goal is near the destination (%s)" % goals[i])
		for j in range(i + 1, goals.size()):
			assert_true(goals[i].distance_to(goals[j]) >= 6.0, "units don't share a spot (%s vs %s)" % [goals[i], goals[j]])
	var alone := Orders.new(game_match)
	alone.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [5, 20]})
	assert_eq(alone.current("Green_Alpha_1")["goal"], [5.0, 20.0], "a single unit goes exactly where it was sent")


func test_destinations_outside_the_arena_are_pulled_inside() -> void:
	var setup: Array = _setup()
	var orders: Orders = setup[1]
	assert_eq(orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [500, -500]}), "", "an edge click still orders")
	var goal: Array = orders.current("Green_Alpha_1")["goal"]
	assert_true(absf(goal[0]) <= Match.DRIVABLE_LIMIT and absf(goal[1]) <= Match.DRIVABLE_LIMIT, "the goal is drivable (%s)" % [goal])


func test_a_destroyed_unit_forgets_its_orders() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [0, 0]})
	orders.issue({"units": ["Green_Alpha_1"], "verb": "move", "to": [0, 10], "queue": true})
	var tank := game_match.tanks.get_node("Green_Alpha_1") as Tank
	tank.apply_damage(100000)
	await wait_physics_frames(2)
	assert_eq(orders.current("Green_Alpha_1"), {}, "a dead unit has no order")
	assert_eq(orders.queue("Green_Alpha_1"), [], "and no queue")
	assert_true(orders.issue({"units": ["Green_Alpha_1"], "verb": "stop"}).contains("destroyed"), "dead units can't be ordered")


func test_orders_is_reachable_from_the_match() -> void:
	var setup: Array = _setup()
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	Orders.attach(game_match, orders)
	assert_eq(Orders.of(game_match), orders, "Orders.of(match) finds the match's Orders")
