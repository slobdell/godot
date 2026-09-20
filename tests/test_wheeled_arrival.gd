extends TestCase
## Round 8 (nav): a WHEELED hull arrives already pointing the way it was told to face, instead of arriving and then
## creeping round for six seconds (measured in control's group move: an IFV 45 degrees off at 12 s, on heading at 18 s).
## A move order may carry `"facing": [x, z]` (contract in _agents/workstreams.md, agreed with squad); a car plans a
## straight approach along it so the last leg does the turning, and tracked and hover hulls ignore it and pivot as before.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(-100, 0, 40)
const GOAL := Vector3(-100, 0, 0)


func _drive(unit_id: String, facing: Variant, seconds := 16.0) -> Array:
	await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, unit_id)
	tank.global_position = START
	tank.rotation.y = 0.0
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	var order := {"type": "move_to", "x": GOAL.x, "z": GOAL.z}
	if facing != null:
		order["facing"] = [(facing as Vector3).x, (facing as Vector3).z]
	assert_eq(orders.set_orders(order, {"type": "hold_fire"}), "", "the order is accepted")
	for frame in int(SimClock.TICK_RATE * seconds):
		await tree.physics_frame
		if Movement.state(tank)["phase"] == "arrived":
			break
	return [tank, Movement.state(tank)]


func test_a_car_arrives_pointing_the_way_it_was_told_to_face() -> void:
	var result: Array = await _drive("ifv", Vector3.RIGHT)
	var tank: Tank = result[0]
	var reading: Dictionary = result[1]
	assert_eq(reading.get("phase"), "arrived", "it gets there (%s)" % reading)
	var east := (-tank.global_basis.z).dot(Vector3.RIGHT)
	assert_true(east > 0.85, "and it is already facing east when it does (dot %.2f)" % east)


func test_the_same_car_without_a_facing_just_arrives() -> void:
	var result: Array = await _drive("ifv", null)
	assert_eq((result[1] as Dictionary).get("phase"), "arrived", "no facing asked, nothing changes")
	assert_true(Vector2((result[0] as Tank).global_position.x - GOAL.x, (result[0] as Tank).global_position.z - GOAL.z).length()
			<= Movement.settle_radius("ifv") + 1.0, "and it settles on the goal")


func test_a_tracked_hull_ignores_the_approach_and_still_arrives() -> void:
	var result: Array = await _drive("tank", Vector3.RIGHT)
	var tank: Tank = result[0]
	assert_eq((result[1] as Dictionary).get("phase"), "arrived", "a tank arrives as it always did")
	assert_true(Vector2(tank.global_position.x - GOAL.x, tank.global_position.z - GOAL.z).length() <= 4.0,
			"on the goal, not short of it (%s)" % tank.global_position)


## The same, from two other geometries, so the approach length is not fitted to one turn: straight on (the hull is
## already pointing the way when it sets off) and the far side (it has to come round).
func test_a_car_told_to_keep_going_arrives_still_pointing_that_way() -> void:
	var result: Array = await _drive("ifv", Vector3.FORWARD)
	var tank: Tank = result[0]
	assert_eq((result[1] as Dictionary).get("phase"), "arrived", "it gets there (%s)" % result[1])
	var along := (-tank.global_basis.z).dot(Vector3.FORWARD)
	assert_true(along > 0.85, "still pointing the way it drove (dot %.2f)" % along)


func test_a_car_told_to_face_the_way_it_came_swings_round_on_the_approach() -> void:
	var result: Array = await _drive("ifv", Vector3.BACK, 22.0)
	var tank: Tank = result[0]
	assert_eq((result[1] as Dictionary).get("phase"), "arrived", "it gets there (%s)" % result[1])
	var back := (-tank.global_basis.z).dot(Vector3.BACK)
	assert_true(back > 0.85, "facing back the way it came (dot %.2f)" % back)


## Round 9 (nav, N0): the gate counter tells "never OFFERED a facing" from "offered one and REFUSED the gate".
## Round 8's facing A/B came back with `gates aimed 0` in both arms and could not say which of those it was — the first
## is a broken instrument, the second is a finding about the mechanism, and they read identically from outside.
func _gates(unit_id: String, facing: Variant, seconds := 16.0) -> Dictionary:
	Movement.reset_gates()
	await _drive(unit_id, facing, seconds)
	return Movement.gate_report()


func test_a_wheeled_hull_with_a_facing_is_offered_the_gate_and_aims_at_one() -> void:
	var gates: Dictionary = await _gates("ifv", Vector3.RIGHT)
	assert_true(int(gates["offered"]) > 0, "a car told which way to face is offered the gate (%s)" % gates)
	assert_true(int(gates["aimed"]) > 0, "and it routes to one at least once (%s)" % gates)
	assert_eq(int(gates["offered"]), int(gates["aimed"]) + int(gates["refused"]),
			"every offer is either aimed at or refused, never lost (%s)" % gates)


func test_a_car_with_no_facing_is_never_offered_the_gate() -> void:
	var gates: Dictionary = await _gates("ifv", null)
	assert_eq(int(gates["offered"]), 0, "no facing in the order, nothing to offer (%s)" % gates)
	assert_eq(int(gates["refused"]), 0, "and nothing is counted as a refusal either (%s)" % gates)


func test_a_tracked_hull_is_never_offered_the_gate() -> void:
	var gates: Dictionary = await _gates("tank", Vector3.RIGHT)
	assert_eq(int(gates["offered"]), 0, "the approach arc is a car's problem: a tank pivots (%s)" % gates)


func test_a_malformed_facing_is_refused_with_its_reason() -> void:
	var gates: Dictionary = await _gates("ifv", Vector3.ZERO, 4.0)
	assert_true(int(gates["offered"]) > 0, "the order carried a `facing` key, so it was offered (%s)" % gates)
	assert_eq(int(gates["aimed"]), 0, "a zero direction names no heading (%s)" % gates)
	assert_true(int((gates["refusals"] as Dictionary).get("bad_facing", 0)) > 0,
			"and the refusal says WHY, not just that it happened (%s)" % gates)
