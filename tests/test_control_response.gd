extends TestCase
## The K1 response guarantee, end to end on real physics (control X1, X3): whatever a unit's brain was doing, a new
## order has it driving toward the order within 3 ticks. Also the minimal executor's verbs (move, queue, stop, hold,
## attack, follow, attack-move) until brains execute orders themselves (ai X1). Prints MEASURE lines.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const RESPONSE_TICKS := 3
## Open ground on the west side of the default arena (no obstacles between x -110..-80, z -40..60).
const LANE_X := -100.0


func _setup(units: Array = ["tank", "tank", "ifv"], enemy := false) -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var entries := units.map(func(unit: String) -> Dictionary: return {"unit": unit})
	var doctrine := {"name": "Test", "squads": [{"name": "Alpha", "formation": "line", "verb": "hold", "units": entries}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: doctrine loads")
	var tanks: Array[Tank] = []
	for i in units.size():
		var tank := game_match.tanks.get_node("Green_Alpha_%d" % (i + 1)) as Tank
		tank.global_position = Vector3(LANE_X + i * 10.0, 0.0, 40.0)
		tanks.append(tank)
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	var executor := OrderExecutor.new()
	executor.game_match = game_match
	executor.orders = orders
	add_to_tree(executor)
	if enemy:
		var bait := game_match.spawn_tank("Rust_Bait_1", 0, Match.Team.RUST)
		bait.global_position = Vector3(LANE_X + 10.0, 0.0, 5.0)
		bait.rotation.y = PI
	return [game_match, orders, tanks]


## True when the tank's command this tick steers it toward `goal`: turning the right way, or driving at it.
static func _steering_toward(tank: Tank, goal: Vector3) -> bool:
	var to_goal := Vector3(goal.x - tank.global_position.x, 0.0, goal.z - tank.global_position.z)
	var forward := -tank.global_basis.z
	var error := Vector3(forward.x, 0.0, forward.z).signed_angle_to(to_goal, Vector3.UP)
	var turning_right_way := absf(error) > deg_to_rad(5.0) and signf(-error) == signf(tank.command.turn) and absf(tank.command.turn) > 0.05
	var driving_at_it := absf(error) < deg_to_rad(70.0) and tank.command.throttle > 0.05
	return turning_right_way or driving_at_it


## Issue `command` and count ticks until every unit steers toward its goal; -1 if one never does within 30 ticks.
func _ticks_to_respond(orders: Orders, tanks: Array[Tank], command: Dictionary) -> int:
	assert_eq(orders.issue(command), "", "order accepted: %s" % UnitCommand.describe(command))
	for tick in 30:
		await tree.physics_frame
		var all := true
		for tank in tanks:
			var goal: Variant = orders.goal_position(String(tank.name))
			if goal == null or not _steering_toward(tank, goal):
				all = false
		if all:
			return tick + 1
	return -1


func test_units_respond_within_three_ticks_whatever_their_brain_was_doing() -> void:
	var setup: Array = _setup(["tank", "tank", "ifv"], true)
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	var names: Array = tanks.map(func(t: Tank) -> String: return String(t.name))
	var results := {}
	# 1. Brains in charge: holding a line here while an enemy sits in sight and range (fighting).
	assert_eq(game_match.command_squad(Match.Team.GREEN, {"squad": "Alpha", "verb": "hold", "to": [LANE_X + 10.0, 40.0],
			"facing": [0, -1], "formation": "line"}), "", "setup: the squad holds a line here")
	for tick in SimClock.TICK_RATE * 6:
		await tree.physics_frame
		if tick > 60 and tanks.any(func(t: Tank) -> bool:
				return (game_match.brains.get_node("Brain_" + t.name) as TankBrain).choice.get("option", "") == "ENGAGE"):
			break
	var states := tanks.map(func(t: Tank) -> String:
		return (game_match.brains.get_node("Brain_" + t.name) as TankBrain).choice.get("option", "?"))
	results["fighting (%s)" % ", ".join(states)] = await _ticks_to_respond(orders, tanks,
			UnitCommand.make(names, "move", {"to": [LANE_X + 10.0, 90.0]}))
	# 2. Already driving the other way under an order.
	await wait_physics_frames(SimClock.TICK_RATE)
	results["driving the other way"] = await _ticks_to_respond(orders, tanks,
			UnitCommand.make(names, "move", {"to": [LANE_X + 10.0, -30.0]}))
	# 3. Holding still in place.
	orders.issue(UnitCommand.make(names, "hold"))
	await wait_physics_frames(SimClock.TICK_RATE)
	results["holding"] = await _ticks_to_respond(orders, tanks, UnitCommand.make(names, "move", {"to": [LANE_X + 40.0, 40.0]}))
	# 4. Badly hurt (a brain would retreat) and freshly stopped.
	for tank in tanks:
		tank.health = 10
	orders.issue(UnitCommand.make(names, "stop"))
	await wait_physics_frames(30)
	results["hurt, just stopped"] = await _ticks_to_respond(orders, tanks, UnitCommand.make(names, "move", {"to": [LANE_X, 80.0]}))
	print("MEASURE control_response_ticks %s" % [results])
	for state in results:
		assert_true(results[state] > 0 and results[state] <= RESPONSE_TICKS,
				"every unit steers toward a new order within %d ticks when %s (took %d)" % [RESPONSE_TICKS, state, results[state]])


func test_a_group_move_arrives_and_completes() -> void:
	var setup: Array = _setup()
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	var names: Array = tanks.map(func(t: Tank) -> String: return String(t.name))
	assert_eq(orders.issue(UnitCommand.make(names, "move", {"to": [LANE_X + 10.0, 0.0]})), "", "move accepted")
	var goals := {}
	for unit_name: String in names:
		goals[unit_name] = orders.goal_position(unit_name)
	await wait_physics_frames(SimClock.TICK_RATE * 12)
	for tank in tanks:
		assert_true(tank.global_position.distance_to(goals[String(tank.name)]) <= 5.0,
				"%s reaches its slot (%.1f m away)" % [tank.name, tank.global_position.distance_to(goals[String(tank.name)])])
		assert_true(orders.is_idle(String(tank.name)), "%s's order completes on arrival" % tank.name)
	await wait_physics_frames(SimClock.TICK_RATE * 2)
	for tank in tanks:
		assert_true(tank.global_position.distance_to(goals[String(tank.name)]) <= 6.0, "%s stays where it was sent" % tank.name)


func test_queued_waypoints_are_driven_in_order() -> void:
	var setup: Array = _setup(["scout"])
	var orders: Orders = setup[1]
	var tank: Tank = setup[2][0]
	var waypoints := [[LANE_X, 10.0], [LANE_X + 20.0, 10.0], [LANE_X + 20.0, 30.0]]
	for point in waypoints:
		assert_eq(orders.issue(UnitCommand.make([tank.name], "move", {"to": point, "queue": true})), "", "waypoint queued")
	var reached := []
	for tick in SimClock.TICK_RATE * 20:
		await tree.physics_frame
		for i in waypoints.size():
			if not reached.has(i) and Vector2(tank.global_position.x, tank.global_position.z).distance_to(
					Vector2(waypoints[i][0], waypoints[i][1])) <= Orders.ARRIVE_RADIUS + 0.5:
				reached.append(i)
		if orders.is_idle(String(tank.name)):
			break
	assert_eq(reached, [0, 1, 2], "the scout visits the waypoints in the order they were queued")
	assert_true(orders.is_idle(String(tank.name)), "and is idle at the end")


func test_stop_halts_and_hold_keeps_position() -> void:
	var setup: Array = _setup(["tank"])
	var orders: Orders = setup[1]
	var tank: Tank = setup[2][0]
	orders.issue(UnitCommand.make([tank.name], "move", {"to": [LANE_X, -40.0]}))
	await wait_physics_frames(90)
	orders.issue(UnitCommand.make([tank.name], "stop"))
	await wait_physics_frames(SimClock.TICK_RATE)
	var stopped_at := tank.global_position
	await wait_physics_frames(SimClock.TICK_RATE * 2)
	assert_true(tank.global_position.distance_to(stopped_at) <= 1.5, "a stopped unit stays stopped (%.1f m)" % tank.global_position.distance_to(stopped_at))
	orders.issue(UnitCommand.make([tank.name], "hold"))
	tank.global_position += Vector3(8.0, 0.0, 0.0)  # shoved off its spot
	await wait_physics_frames(SimClock.TICK_RATE * 5)
	assert_true(tank.global_position.distance_to(stopped_at) <= Orders.ARRIVE_RADIUS + 1.0,
			"a holding unit returns to its spot (%.1f m)" % tank.global_position.distance_to(stopped_at))


func test_attack_closes_on_the_target_and_completes_when_it_dies() -> void:
	var setup: Array = _setup(["tank"], true)
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	var tank: Tank = setup[2][0]
	var bait := game_match.tanks.get_node("Rust_Bait_1") as Tank
	bait.global_position = Vector3(LANE_X, 0.0, -50.0)  # beyond the gun's reach
	var start := tank.global_position.distance_to(bait.global_position)
	assert_eq(orders.issue(UnitCommand.make([tank.name], "attack", {"target": "Rust_Bait_1"})), "", "attack accepted")
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_true(tank.global_position.distance_to(bait.global_position) < start - 10.0, "the attacker closes the distance")
	bait.apply_damage(100000)
	await wait_physics_frames(3)
	assert_true(orders.is_idle(String(tank.name)), "the attack order completes when the target dies")


func test_follow_keeps_station_behind_a_moving_friend() -> void:
	var setup: Array = _setup(["tank", "scout"])
	var orders: Orders = setup[1]
	var leader: Tank = setup[2][0]
	var follower: Tank = setup[2][1]
	assert_eq(orders.issue(UnitCommand.make([follower.name], "follow", {"target": leader.name})), "", "follow accepted")
	assert_eq(orders.issue(UnitCommand.make([leader.name], "move", {"to": [LANE_X, -30.0]})), "", "the leader drives off")
	await wait_physics_frames(SimClock.TICK_RATE * 10)
	var gap := follower.global_position.distance_to(leader.global_position)
	assert_true(gap <= 20.0, "the follower keeps up with the leader (%.1f m)" % gap)
	assert_eq(orders.current(String(follower.name)).get("verb", ""), "follow", "follow is a standing order")


func test_attack_move_stops_to_fight_what_it_meets() -> void:
	var setup: Array = _setup(["tank"], true)
	var game_match: Match = setup[0]
	var orders: Orders = setup[1]
	var tank: Tank = setup[2][0]
	var bait := game_match.tanks.get_node("Rust_Bait_1") as Tank
	bait.max_health = 100000
	bait.health = 100000
	bait.global_position = Vector3(LANE_X + 12.0, 0.0, -10.0)
	assert_eq(orders.issue(UnitCommand.make([tank.name], "attack_move", {"to": [LANE_X, -60.0]})), "", "attack-move accepted")
	var shots := [0]
	tank.fired.connect(func(_muzzle: Vector3, _direction: Vector3) -> void: shots[0] += 1)
	await wait_physics_frames(SimClock.TICK_RATE * 8)
	assert_true(shots[0] > 0, "the unit fights the enemy it meets")
	assert_true(tank.global_position.z > -40.0, "and doesn't drive past it to the destination (z %.0f)" % tank.global_position.z)
