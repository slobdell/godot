extends TestCase
## Doctrine X1 (contract L1): elements form, their leader puts everyone in a slot and issues ONE K1 order
## each, a fallen leader is replaced, and a player's order always wins over the element's.

const TICKS := Element.UPDATE_TICKS


func _element_scenario() -> Dictionary:
	var scenario := AiScenario.create(self)
	var tanks: Array = []
	for i in 4:
		tanks.append(scenario.brain_tank(Match.Team.GREEN, "Green_A_%d" % (i + 1),
				Vector3(-15.0 + i * 10.0, 0.0, 60.0), 0.0, {}, "tank" if i < 2 else "ifv"))
	var orders: Object = scenario.orders()
	var elements := Elements.install(scenario.game_match, orders)
	await scenario.start()
	return {"scenario": scenario, "elements": elements, "orders": orders, "tanks": tanks}


func test_forming_an_element_gives_every_unit_a_leader_and_a_slot() -> void:
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var alpha := elements.form(["Green_A_1", "Green_A_2", "Green_A_3", "Green_A_4"], "Alpha")
	assert_eq(alpha.leader, "Green_A_1", "the first vehicle on the roster leads")
	assert_eq(elements.of("Green_A_3"), alpha, "and every member can be looked up by name")
	assert_eq(alpha.assign({"verb": "move", "to": [0, 0]}), "", "the element takes a move task")
	for i in TICKS * 3:
		await scenario.step()
	var state := alpha.state()
	assert_eq((state["slots"] as Dictionary).size(), 4, "every vehicle has a place in the formation")
	assert_true(TacticsFormation.NAMES.has(state["formation"]), "the leader picked a formation: %s" % state["formation"])
	assert_true(DoctrineTable.TECHNIQUES.has(state["technique"]), "and a movement technique")
	assert_true(String(state["reason"]).length() > 3, "with a reason a player can read: '%s'" % state["reason"])
	scenario.dispose()


func test_the_leader_issues_one_order_per_vehicle_and_they_drive_to_their_slots() -> void:
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha := elements.form(["Green_A_1", "Green_A_2", "Green_A_3", "Green_A_4"], "Alpha")
	alpha.assign({"verb": "move", "to": [0, -20]})
	for i in TICKS * 2:
		await scenario.step()
	var seen := 0
	for member in alpha.members():
		var order: Dictionary = orders.call("current", member)
		if order.is_empty():
			continue
		seen += 1
		assert_eq((order["units"] as Array).size(), 1, "%s has its own order, not a group one" % member)
		assert_true(["move", "attack_move"].has(String(order["verb"])), "%s is moving" % member)
	assert_eq(seen, 4, "every vehicle in the element has an order")
	var before := _spread(alpha, scenario)
	for i in 60 * 6:
		await scenario.step()
	assert_true((scenario.game_match.tanks.get_node("Green_A_1") as Tank).global_position.z < 45.0,
			"the element actually drove north toward its objective")
	assert_true(_spread(alpha, scenario) <= before + 12.0,
			"and it stayed formed up on the way (spread %.1f m -> %.1f m)" % [before, _spread(alpha, scenario)])
	scenario.dispose()


func test_when_the_leader_dies_the_next_vehicle_takes_over() -> void:
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var alpha := elements.form(["Green_A_1", "Green_A_2", "Green_A_3", "Green_A_4"], "Alpha")
	alpha.assign({"verb": "move", "to": [0, 20]})
	var lost := []
	elements.leader_lost.connect(func(id: int, fallen: String, successor: String) -> void:
		lost.append([id, fallen, successor]))
	for i in TICKS * 2:
		await scenario.step()
	var leader := scenario.game_match.tanks.get_node("Green_A_1") as Tank
	leader.apply_damage(100000)
	for i in TICKS * 3:
		await scenario.step()
	assert_eq(alpha.leader, "Green_A_2", "the senior survivor takes over")
	assert_true(not alpha.members().has("Green_A_1"), "and the destroyed vehicle leaves the element")
	assert_eq(lost.size(), 1, "the HUD is told once that the leader is down")
	assert_eq(elements.of("Green_A_1"), null, "a dead vehicle belongs to no element")
	scenario.dispose()


func test_a_players_order_always_wins_and_the_element_takes_the_unit_back_when_it_is_done() -> void:
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha := elements.form(["Green_A_1", "Green_A_2", "Green_A_3", "Green_A_4"], "Alpha")
	alpha.assign({"verb": "move", "to": [0, -30]})
	for i in TICKS * 2:
		await scenario.step()
	assert_eq(orders.call("issue", {"units": ["Green_A_3"], "verb": "move", "to": [40.0, 60.0]}), "",
			"the player orders one vehicle somewhere else")
	var player_order: Dictionary = orders.call("current", "Green_A_3")
	var player_id := int(player_order["id"])
	for i in TICKS * 4:
		await scenario.step()
	assert_eq(int((orders.call("current", "Green_A_3") as Dictionary).get("id", -1)), player_id,
			"the element never overwrites it")
	assert_true(alpha.is_detached("Green_A_3"), "and it shows the vehicle as out of its hands")
	orders.call("complete", "Green_A_3")
	for i in TICKS * 3:
		await scenario.step()
	assert_true(not alpha.is_detached("Green_A_3"), "when the player's order is finished the element takes it back")
	scenario.dispose()


func test_a_unit_belongs_to_exactly_one_element() -> void:
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var alpha := elements.form(["Green_A_1", "Green_A_2", "Green_A_3"], "Alpha")
	var bravo := elements.form(["Green_A_3", "Green_A_4"], "Bravo")
	assert_eq(elements.of("Green_A_3"), bravo, "a re-formed vehicle follows its new leader")
	assert_true(not alpha.members().has("Green_A_3"), "and leaves the old element")
	assert_eq(elements.all().size(), 2, "both elements are listed, in id order")
	elements.disband(alpha)
	assert_eq(elements.of("Green_A_1"), null, "a disbanded element releases its vehicles")
	assert_eq(elements.all().size(), 1, "and is gone from the list")
	scenario.dispose()


## The biggest distance between two members: how bunched up or strung out the element is.
func _spread(element: Element, scenario: AiScenario) -> float:
	var positions: Array = []
	for member in element.members():
		var tank := scenario.game_match.tanks.get_node_or_null(NodePath(member)) as Tank
		if tank != null and tank.is_alive():
			positions.append(tank.global_position)
	var widest := 0.0
	for i in positions.size():
		for j in range(i + 1, positions.size()):
			widest = maxf(widest, (positions[i] as Vector3).distance_to(positions[j]))
	return widest
