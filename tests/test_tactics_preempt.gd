extends TestCase
## R2 (round 10), squad's half: a player's order pre-empts everything. A fresh task on an element re-derives EVERY
## crew's order on the next tick — not on the element's next slot in the UPDATE_TICKS cycle, not only for the crews
## whose slot moved more than REISSUE_M, not only for the crews still under the element's command — and a standing
## hold yields to it. The lead (2026-09-20): *"I was trying to right click to move them in a different direction and
## they didnt respond."* control's integration test drives the same thing from the mouse on the default path; this
## one asserts the ORDER each crew holds two ticks after `Element.assign()`.

const WITHIN_TICKS := 2
const MEMBERS := ["Green_A_1", "Green_A_2", "Green_A_3", "Green_A_4"]


func _squad() -> Dictionary:
	var scenario := AiScenario.create(self)
	for i in 4:
		scenario.brain_tank(Match.Team.GREEN, MEMBERS[i], Vector3(-15.0 + i * 10.0, 0.0, 60.0), 0.0, {},
				"tank" if i < 2 else "ifv")
	var orders: Object = scenario.orders()
	var elements := Elements.install(scenario.game_match, orders)
	# The player commands GREEN, as in `make skirmish`: its elements take tasks from a human.
	scenario.game_match.set_meta("player_team", Match.Team.GREEN)
	await scenario.start()
	var alpha := elements.form(MEMBERS, "Alpha")
	return {"scenario": scenario, "elements": elements, "orders": orders, "alpha": alpha}


func _ids(orders: Object) -> Dictionary:
	var ids := {}
	for member: String in MEMBERS:
		ids[member] = int((orders.call("current", member) as Dictionary).get("id", -1))
	return ids


## Every crew NOT re-derived from the element's newest task ([] when all were). Re-derived means: the element issued
## the crew an order from the new task's plan, and the order Orders now holds for it is that one —
## the same intention (verb, target, goal within Orders' own SAME_ORDER_M). An order whose content did not change (a
## `follow` on the same leader) keeps its id: Orders drops an identical re-issue by design, and that is control's
## dedup, not a crew left behind (R2's request to control carries the task id for it).
func _not_rederived(alpha: Element, orders: Object) -> Array:
	var stale: Array = []
	for member: String in MEMBERS:
		var order: Dictionary = orders.call("current", member)
		var mine := alpha.issued_to(member)
		if order.is_empty():
			stale.append("%s has no order" % member)
		elif String(order.get("source", "")) != "element":
			stale.append("%s holds a '%s' order, not the element's" % [member, String(order.get("source", ""))])
		elif mine.is_empty() or int(mine.get("task", -1)) != alpha.task_seq:
			stale.append("%s was not re-issued from the new task (its last order is from task %d of %d)" \
					% [member, int(mine.get("task", -1)), alpha.task_seq])
		elif int(order.get("id", -1)) != int(mine.get("id", -2)) or String(order["verb"]) != String(mine["verb"]):
			stale.append("%s holds order %d (%s), not the element's %d (%s)" % [member, int(order.get("id", -1)),
					String(order["verb"]), int(mine.get("id", -2)), String(mine["verb"])])
		elif mine.get("to") is Vector3 and order.has("to"):
			var goal := Vector3(float(order["to"][0]), 0.0, float(order["to"][1]))
			if goal.distance_to(mine["to"]) > 3.0:
				stale.append("%s drives to %s, not the new slot %s" % [member, str(goal), str(mine["to"])])
	return stale


func _step(scenario: AiScenario, ticks: int) -> void:
	for i in ticks:
		await scenario.step()


func test_a_fresh_task_reorders_every_crew_within_two_ticks_whatever_the_cycle_phase() -> void:
	# Three re-tasks two ticks apart land on three different phases of the element's (tick + id) % UPDATE_TICKS
	# cycle, so a fix that only works when the task happens to arrive just before the element's own tick fails here.
	var context := await _squad()
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha: Element = context["alpha"]
	assert_eq(alpha.assign({"verb": "move", "to": [0, 20], "drills": false}), "", "setup: the squad takes a move")
	await _step(scenario, Element.UPDATE_TICKS * 4)
	var phases := {}
	for point: Array in [[40, 40], [-40, 40], [40, 0]]:
		phases[(scenario.game_match.tick + alpha.id) % Element.UPDATE_TICKS] = true
		assert_eq(alpha.assign({"verb": "move", "to": point, "drills": false}), "", "the player re-tasks it to %s" % str(point))
		await _step(scenario, WITHIN_TICKS)
		assert_eq(_not_rederived(alpha, orders), [],
				"every crew was re-ordered within %d ticks of the task to %s" % [WITHIN_TICKS, str(point)])
	assert_eq(phases.size(), Element.UPDATE_TICKS, "setup: the three re-tasks landed on every phase of the cycle")
	scenario.dispose()


func test_a_fresh_task_near_the_old_one_still_reorders_every_crew() -> void:
	# The re-issue suppression compares PLACES (REISSUE_M, SETTLED_M): a task whose slots land within 8 m of the old
	# ones was swallowed whole, which is every re-drag of a heading on the same spot.
	var context := await _squad()
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha: Element = context["alpha"]
	alpha.assign({"verb": "move", "to": [0, 20], "drills": false})
	await _step(scenario, Element.UPDATE_TICKS * 4)
	assert_eq(alpha.assign({"verb": "move", "to": [2, 21], "facing": [1, 0], "drills": false}), "",
			"the player re-drags the same spot with a new heading")
	await _step(scenario, WITHIN_TICKS)
	assert_eq(_not_rederived(alpha, orders), [], "every crew was re-ordered, though every slot moved under 8 m")
	# The heading itself reaches the leader's order only when Orders stops calling two element moves 2 m apart "the
	# same order" across a new task: control's half (R2's `task` key). Asserted from the day that key exists.
	var leader_order: Dictionary = orders.call("current", alpha.leader)
	if UnitCommand.KEYS.has("task"):
		assert_eq(leader_order.get("facing", []), [1.0, 0.0], "the leader's order carries the re-dragged heading")
	else:
		print("WAITING control R2: Orders has no `task` key yet; the leader holds facing=%s" \
				% str(leader_order.get("facing", "none")))
	scenario.dispose()


func test_a_fresh_task_takes_back_a_crew_the_player_had_ordered_directly() -> void:
	# A crew on a direct player order is `detached` until that order finishes. The task is the player's NEWER word to
	# the whole squad, so the crew comes back under it at once rather than when its old errand ends.
	var context := await _squad()
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha: Element = context["alpha"]
	alpha.assign({"verb": "move", "to": [0, 20], "drills": false})
	await _step(scenario, Element.UPDATE_TICKS * 2)
	assert_eq(orders.call("issue", {"units": ["Green_A_3"], "verb": "move", "to": [40.0, 60.0], "source": "player"}), "",
			"setup: the player sends one crew off on its own")
	await _step(scenario, Element.UPDATE_TICKS * 2)
	assert_true(alpha.is_detached("Green_A_3"), "setup: the element counts that crew as out of its hands")
	alpha.assign({"verb": "move", "to": [-40, 20], "drills": false})
	await _step(scenario, WITHIN_TICKS)
	assert_eq(_not_rederived(alpha, orders), [], "every crew, the detached one included, is on the new task")
	assert_true(not alpha.is_detached("Green_A_3"), "and the element commands it again")
	scenario.dispose()


func test_a_standing_hold_yields_to_a_new_task() -> void:
	var context := await _squad()
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha: Element = context["alpha"]
	# A dragged heading becomes a standing `hold` on arrival (d29115ae); a short move gets there quickly.
	alpha.assign({"verb": "move", "to": [0, 56], "facing": [1, 0], "drills": false})
	var holding := 0
	for i in SimClock.TICK_RATE * 30:
		await scenario.step()
		holding = 0
		for member: String in MEMBERS:
			if String((orders.call("current", member) as Dictionary).get("verb", "")) == "hold":
				holding += 1
		if holding == MEMBERS.size():
			break
	assert_eq(holding, MEMBERS.size(), "setup: every crew is on a standing hold")
	alpha.assign({"verb": "move", "to": [40, 20], "drills": false})
	await _step(scenario, WITHIN_TICKS)
	assert_eq(_not_rederived(alpha, orders), [], "every holding crew was re-ordered within %d ticks" % WITHIN_TICKS)
	for member: String in MEMBERS:
		assert_true(String((orders.call("current", member) as Dictionary).get("verb", "")) != "hold",
				"%s is no longer holding" % member)
	scenario.dispose()


func test_a_cpu_element_keeps_its_cycle() -> void:
	# The pre-emption is the PLAYER's: a CPU commander re-tasks by its own cadence and its elements plan on theirs,
	# which is what keeps the sim baseline (CPU against CPU) where it was. Over three phases of the cycle, at least
	# one task must still be waiting for the element's own tick one tick after it was given.
	var scenario := AiScenario.create(self)
	for i in 4:
		scenario.brain_tank(Match.Team.GREEN, MEMBERS[i], Vector3(-15.0 + i * 10.0, 0.0, 60.0), 0.0, {}, "tank")
	var orders: Object = scenario.orders()
	var elements := Elements.install(scenario.game_match, orders)
	await scenario.start()
	var alpha := elements.form(MEMBERS, "Alpha")
	alpha.assign({"verb": "move", "to": [0, 20], "drills": false})
	await _step(scenario, Element.UPDATE_TICKS * 4)
	var waited := 0
	for point: Array in [[40, 40], [-40, 40], [40, 0], [-40, 0]]:
		var before := _ids(orders)
		alpha.assign({"verb": "move", "to": point, "drills": false})
		await scenario.step()
		if _ids(orders) == before:
			waited += 1
		await _step(scenario, Element.UPDATE_TICKS + 1)
	assert_true(waited > 0, "with no player on the team the element plans on its own tick (%d of 4 waited)" % waited)
	scenario.dispose()


func test_crews_that_finished_their_move_and_went_idle_take_the_new_task() -> void:
	# control's repath-test "arrived" state (Terminus, builder0): a squad sent 15 m, 15 s later a right-click 40 m off;
	# the crews that had finished their element move and gone idle got no order through tick +8.
	var context := await _squad()
	var scenario: AiScenario = context["scenario"]
	var orders: Object = context["orders"]
	var alpha: Element = context["alpha"]
	alpha.assign({"verb": "move", "to": [0, 45], "drills": false})
	var idle := 0
	for i in SimClock.TICK_RATE * 30:
		await scenario.step()
		idle = 0
		for member: String in MEMBERS:
			if (orders.call("current", member) as Dictionary).is_empty():
				idle += 1
		if idle >= 2:
			break
	assert_true(idle >= 2, "setup: crews finished the move and went idle (%d of 4)" % idle)
	alpha.assign({"verb": "move", "to": [40, 45], "drills": false})
	await _step(scenario, WITHIN_TICKS)
	assert_eq(_not_rederived(alpha, orders), [], "every crew, the idle ones included, is on the new task")
	scenario.dispose()


func test_an_idle_crew_is_given_the_follow_its_flow_asks_for() -> void:
	# The same hole outside a player task's first update (a CPU element, or any later update): _should_issue's idle
	# branch had no case for a crew whose last order was our finished move and whose new one is a `follow`.
	var scenario := AiScenario.create(self)
	for i in 4:
		scenario.brain_tank(Match.Team.GREEN, MEMBERS[i], Vector3(-15.0 + i * 10.0, 0.0, 60.0), 0.0, {}, "tank")
	var orders: Object = scenario.orders()
	var elements := Elements.install(scenario.game_match, orders)
	await scenario.start()
	var alpha := elements.form(MEMBERS, "Alpha")
	alpha.assign({"verb": "move", "to": [0, 30], "drills": false})
	var idle: Array = []
	for i in SimClock.TICK_RATE * 30:
		await scenario.step()
		idle = []
		for member: String in MEMBERS:
			if member != alpha.leader and (orders.call("current", member) as Dictionary).is_empty() \
					and String(alpha.issued_to(member).get("verb", "")) == "move":
				idle.append(member)
		if idle.size() >= 2:
			break
	# control's case exactly: the crew's LAST element order is a finished `move` to its final slot (the flow had
	# joined), not a `follow` — an idle crew last on a follow is re-issued by the branch above it.
	assert_true(idle.size() >= 2, "setup: followers finished their final move and went idle (%s)" % str(idle))
	alpha.assign({"verb": "move", "to": [0, -30], "drills": false})
	await _step(scenario, Element.UPDATE_TICKS * 2)
	var still_idle: Array = []
	print("MEASURE idle_follow idle %s -> %s" % [str(idle), str(idle.map(func(m: String) -> String:
			return "%s %s (was %s)" % [m, String((orders.call("current", m) as Dictionary).get("verb", "none")),
					String(alpha.issued_to(m).get("verb", "?"))]))])
	for member: String in idle:
		if (orders.call("current", member) as Dictionary).is_empty():
			still_idle.append(member)
	assert_eq(still_idle, [], "a CPU element's idle crews are given their follow within two cycles")
	scenario.dispose()
