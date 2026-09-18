extends TestCase
## Control X5: a group ordered somewhere moves as a group. It arranges itself by role and situation (heavies in front,
## fragile units behind, a spread wedge for fast units charging, a line when holding), arrives together (fast units
## slow down, laggards catch up), faces the direction of travel, and a unit pushed away from its group rejoins it
## unless it was given its own order. G cycles a formation for players who want control.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const Fixture := preload("res://tests/support/control_fixture.gd")
## Open ground on the west side of the default arena.
const LANE_X := -100.0


func _match(units: Array) -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var entries := units.map(func(unit: String) -> Dictionary: return {"unit": unit})
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, {"name": "Test", "squads": [{"name": "Alpha", "units": entries}]}), "",
			"setup: doctrine")
	var tanks: Array[Tank] = []
	for i in units.size():
		var tank := game_match.tanks.get_node("Green_Alpha_%d" % (i + 1)) as Tank
		tank.global_position = Vector3(LANE_X + i * 6.0, 0.0, 50.0)
		tank.reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
		tanks.append(tank)
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	var executor := OrderExecutor.new()
	executor.game_match = game_match
	executor.orders = orders
	add_to_tree(executor)
	return [game_match, orders, tanks]


static func _names(tanks: Array[Tank]) -> Array:
	return tanks.map(func(t: Tank) -> String: return String(t.name))


## A slot's distance along the direction of travel (bigger = further forward).
static func _forwardness(order: Dictionary) -> float:
	return -float(order["slot"][1])


func test_automatic_formation_puts_heavies_in_front_and_fragile_units_behind() -> void:
	var setup: Array = _match(["artillery", "scout", "tank", "ifv", "lancer"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	assert_eq(orders.issue(UnitCommand.make(_names(tanks), "move", {"to": [LANE_X, -20.0]})), "", "move accepted")
	var by_role := {}
	for tank in tanks:
		by_role[Units.role_of(tank.unit_id)] = orders.current(String(tank.name))
	assert_eq(by_role["tank"]["formation"], "wedge", "a mixed group of five moves in a wedge")
	for role in ["ifv", "scout", "lancer", "artillery"]:
		assert_true(_forwardness(by_role["tank"]) > _forwardness(by_role[role]), "the tank leads the %s" % role)
	for role in ["tank", "ifv", "scout"]:
		assert_true(_forwardness(by_role[role]) > _forwardness(by_role["artillery"]) or role == "artillery",
				"the artillery stays behind the %s" % role)


func test_holding_groups_form_a_line_and_fast_charges_spread_into_a_wedge() -> void:
	var setup: Array = _match(["tank", "tank", "ifv", "scout", "scout", "scout"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	var heavies := _names(tanks.slice(0, 3))
	assert_eq(orders.issue(UnitCommand.make(heavies, "hold", {"to": [LANE_X, 0.0]})), "", "hold here accepted")
	var backs := heavies.map(func(n: String) -> float: return float(orders.current(n)["slot"][1]))
	assert_eq(orders.current(heavies[0])["formation"], "line", "a holding group forms a line")
	assert_true(backs.max() - backs.min() < 0.1, "abreast: every slot the same distance back (%s)" % [backs])
	var scouts := _names(tanks.slice(3))
	assert_eq(orders.issue(UnitCommand.make(scouts, "attack_move", {"to": [LANE_X, -60.0]})), "", "scout charge accepted")
	var slots := scouts.map(func(n: String) -> Vector2: return Vector2(orders.current(n)["slot"][0], orders.current(n)["slot"][1]))
	assert_eq(orders.current(scouts[0])["formation"], "wedge", "fast units charging spread into a wedge")
	var widest := 0.0
	for slot: Vector2 in slots:
		widest = maxf(widest, absf(slot.x))
	assert_true(widest >= GroupFormation.SPACING * 1.2, "the charge is spread wide (%.1f m to the side)" % widest)


func test_big_groups_move_in_rows_with_heavies_up_front() -> void:
	var setup: Array = _match(["scout", "scout", "ifv", "ifv", "tank", "tank", "tank", "artillery"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	assert_eq(orders.issue(UnitCommand.make(_names(tanks), "move", {"to": [LANE_X + 10.0, -20.0]})), "", "move accepted")
	var front := -INF
	for tank in tanks:
		front = maxf(front, _forwardness(orders.current(String(tank.name))))
	for tank in tanks:
		var in_front := absf(_forwardness(orders.current(String(tank.name))) - front) < 0.1
		if tank.unit_id == "tank":
			assert_true(in_front, "%s (a tank) is in the front row" % tank.name)
		elif tank.unit_id == "artillery":
			assert_true(not in_front, "the artillery is not in the front row")


func test_a_mixed_group_arrives_together() -> void:
	var setup: Array = _match(["scout", "tank"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	var scout := tanks[0]
	var tank := tanks[1]
	assert_eq(orders.issue(UnitCommand.make(_names(tanks), "move", {"to": [LANE_X + 3.0, -40.0]})), "", "move accepted")
	var arrived := {}
	var scout_top := 0.0
	for tick in SimClock.TICK_RATE * 20:
		await tree.physics_frame
		scout_top = maxf(scout_top, scout.estimated_velocity.length())
		for unit in tanks:
			if not arrived.has(unit.name) and orders.is_idle(String(unit.name)):
				arrived[unit.name] = tick
		if arrived.size() == 2:
			break
	print("MEASURE control_group_arrival_ticks %s scout_top_speed %.1f" % [arrived, scout_top])
	assert_eq(arrived.size(), 2, "both arrive")
	if arrived.size() == 2:
		assert_true(absi(int(arrived[scout.name]) - int(arrived[tank.name])) <= 90,
				"they arrive within 1.5 s of each other (%s)" % [arrived])
	assert_true(scout_top < scout.max_forward_speed * 0.85, "the scout holds back for the tank (top %.1f m/s)" % scout_top)


func test_a_laggard_catches_up_while_the_leader_waits() -> void:
	var setup: Array = _match(["ifv", "ifv"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	tanks[1].global_position = Vector3(LANE_X + 6.0, 0.0, 90.0)  # 40 m behind
	tanks[1].reset_physics_interpolation()  # teleport: interpolation must not draw it at its old spot
	assert_eq(orders.issue(UnitCommand.make(_names(tanks), "move", {"to": [LANE_X + 3.0, -10.0]})), "", "move accepted")
	var arrived := {}
	var laggard_top := 0.0
	for tick in SimClock.TICK_RATE * 25:
		await tree.physics_frame
		laggard_top = maxf(laggard_top, tanks[1].estimated_velocity.length())
		for unit in tanks:
			if not arrived.has(unit.name) and orders.is_idle(String(unit.name)):
				arrived[unit.name] = tick
		if arrived.size() == 2:
			break
	print("MEASURE control_laggard_arrival_ticks %s laggard_top_speed %.1f" % [arrived, laggard_top])
	assert_eq(arrived.size(), 2, "both arrive")
	if arrived.size() == 2:
		assert_true(absi(int(arrived[tanks[0].name]) - int(arrived[tanks[1].name])) <= 120,
				"the leader waits for the laggard (%s)" % [arrived])
	assert_true(laggard_top > tanks[1].max_forward_speed * 0.9, "the laggard drives flat out (top %.1f m/s)" % laggard_top)


func test_the_group_faces_its_direction_of_travel_on_arrival() -> void:
	var setup: Array = _match(["tank", "tank", "ifv"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	# Travel east: every hull starts pointing north.
	assert_eq(orders.issue(UnitCommand.make(_names(tanks), "move", {"to": [LANE_X + 45.0, 50.0]})), "", "move accepted")
	await wait_physics_frames(SimClock.TICK_RATE * 12)
	for tank in tanks:
		assert_true(orders.is_idle(String(tank.name)), "%s arrived" % tank.name)
		var forward := -tank.global_basis.z
		assert_true(forward.dot(Vector3.RIGHT) > 0.85, "%s faces east, the way it travelled (%s)" % [tank.name, forward])


func test_a_unit_pushed_away_rejoins_its_group_unless_it_has_its_own_order() -> void:
	var setup: Array = _match(["tank", "ifv", "ifv"])
	var orders: Orders = setup[1]
	var tanks: Array[Tank] = setup[2]
	assert_eq(orders.issue(UnitCommand.make(_names(tanks), "move", {"to": [LANE_X + 10.0, 10.0]})), "", "move accepted")
	await wait_physics_frames(SimClock.TICK_RATE * 10)
	var station := orders.station(String(tanks[1].name))
	assert_true(not station.is_empty(), "an arrived unit has a station with its group")
	assert_eq(station.get("units", []), _names(tanks), "the station remembers the group")
	var slot := Vector3(float(station["position"][0]), 0.0, float(station["position"][1]))
	tanks[1].global_position = slot + Vector3(12.0, 0.0, 22.0)
	await wait_physics_frames(SimClock.TICK_RATE * 8)
	assert_true(tanks[1].global_position.distance_to(slot) <= 5.0, "the pushed unit drove back to its slot (%.1f m away)" %
			tanks[1].global_position.distance_to(slot))
	assert_eq(orders.issue(UnitCommand.make([tanks[2].name], "move", {"to": [LANE_X - 5.0, -20.0]})), "", "own order accepted")
	await wait_physics_frames(SimClock.TICK_RATE * 8)
	var own := Vector3(LANE_X - 5.0, 0.0, -20.0)
	assert_true(tanks[2].global_position.distance_to(own) <= 5.0, "a unit given its own order stays where it was sent (%.1f m)" %
			tanks[2].global_position.distance_to(own))
	assert_eq(orders.station(String(tanks[2].name)).get("units", []), [String(tanks[2].name)], "its station is its own now")


func test_g_cycles_the_formation_for_the_next_orders() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	await f.select(["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"])
	assert_eq(f.controls.formation, UnitCommand.AUTO, "formations start automatic")
	await f.key(KEY_G)
	assert_eq(f.controls.formation, RtsControls.FORMATION_CYCLE[1], "G picks the next formation")
	await f.right_click(f.ground(Vector3(-15, 0, 15)))
	assert_eq(f.orders.current("Green_Alpha_1").get("formation", ""), RtsControls.FORMATION_CYCLE[1], "orders use it")
	for i in RtsControls.FORMATION_CYCLE.size() - 1:
		await f.key(KEY_G)
	assert_eq(f.controls.formation, UnitCommand.AUTO, "cycling all the way comes back to automatic")
