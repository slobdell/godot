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
	for i in SimClock.TICK_RATE * 6:
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


func test_a_facing_the_player_dragged_reaches_the_order_of_the_crew_that_has_one() -> void:
	# THE LEAD'S COMMONEST ORDER, and control's post-CP2 playtest caught it losing the heading. A facing drag on a
	# WHOLE SQUAD goes down the task path (`"drills": false`, `rts_controls.gd:530`), where the chosen facing reaches
	# `plan["heading"]` and zeroes the sectors -- so the formation is laid facing where he dragged -- and then the
	# per-unit orders threw the heading away and the squad arrived pointing whichever way it had driven.
	#
	# It was my own X5 rule that dropped it: `_group` gave a crew a facing only at a HALT, because on the move a crew's
	# heading is the direction of travel and nav derives that for itself. True of every heading DOCTRINE chooses, false
	# of the one the PLAYER chooses.
	#
	# WHAT THIS ASSERTS, AND WHAT IT DOES NOT. The leader is given a `move` to its own slot and now carries the facing.
	# Every other crew is given a `follow` on the leader while the element flows into formation (`_flow` replaces the
	# order with verb, target and slot, no destination), and a facing on THAT would be an arrival heading for a moving
	# target, so it deliberately carries none. Whether a follower ends up on the dragged heading once the flow joins is
	# a live question and NOT settled here -- see the Status note; measuring it needs a window between `flow_joined` and
	# `arrived` that is very narrow, because the flow joins when the LEADER reaches its own slot.
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha := elements.form(["Green_A_1", "Green_A_2"], "Alpha")
	var east := Vector3(1.0, 0.0, 0.0)
	assert_eq(alpha.assign({"verb": "move", "to": [0, -20], "facing": [east.x, east.z], "drills": false}), "",
			"the element takes a plain move task with a facing on it")
	for i in TICKS * 2:
		await scenario.step()
	var moving := 0
	var following := 0
	for member in alpha.members():
		var order: Dictionary = orders.call("current", member)
		if order.is_empty():
			continue
		if String(order["verb"]) == "follow":
			following += 1
			assert_true(not order.has("facing"),
					"%s is following the leader, so it is given no arrival heading" % member)
			continue
		moving += 1
		if not order.has("facing"):
			# Reported, then skipped: reading the key anyway turns one honest failure into an engine error that
			# buries it.
			assert_true(false, "%s was told which way to end up facing" % member)
			continue
		var look := Vector3(float(order["facing"][0]), 0.0, float(order["facing"][1])).normalized()
		assert_true(look.dot(east) > 0.99,
				"%s is told to face the way the player dragged (dot %.3f)" % [member, look.dot(east)])
	assert_true(moving >= 1, "at least one crew is driving to its own slot, so the facing had somewhere to land")
	assert_eq(moving + following, 2, "and both crews were ordered, so this is not passing on an empty list")
	scenario.dispose()


func test_a_move_with_no_facing_still_leaves_the_heading_to_nav() -> void:
	# The other arm, and the one that keeps the fix honest. With no facing on the task, NO order may carry one, so a
	# crew's heading stays the direction it drove -- which is what nav derives and what every arrival behaviour in
	# `test_wheeled_arrival` is built on. If this goes red, the fix above has become a facing on every order, which
	# would quietly take the derived heading away from nav.
	var context := await _element_scenario()
	var elements: Elements = context["elements"]
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha := elements.form(["Green_A_1", "Green_A_2"], "Alpha")
	alpha.assign({"verb": "move", "to": [0, -20], "drills": false})
	for i in TICKS * 2:
		await scenario.step()
	var seen := 0
	for member in alpha.members():
		var order: Dictionary = orders.call("current", member)
		if order.is_empty():
			continue
		seen += 1
		assert_true(not order.has("facing"),
				"%s drove without being told a heading, so nav derives it from travel" % member)
	assert_eq(seen, 2, "and both crews were ordered, so this is not passing on an empty list")
	scenario.dispose()
