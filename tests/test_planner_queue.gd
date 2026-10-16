extends TestCase
## Round 32 (planner, hand-over (3): the gang-press queue that starves). Under `--planner-queue=shared` a request whose
## goal is blocked is answered on the tick it is asked (refuse early), never held behind another crew's search; under
## the FIFO (today's default) it waits its turn. The plan of the crew whose search runs is the same either way, and a
## snapshot taken mid-search (capture / restore, the twin harnesses' door) replays the shared queue exactly.
##
## The street: three War Rigs in the Terminus' west street, nose to tail, all facing north. P_1 (z 0) is told to face
## south (its search runs first: the controllers' order); P_2 (z 20) to face east, which the turned box cannot do with
## P_3 parked 8 m behind it (GOAL_BLOCKED, or the walls' refusal: a refusal either way).

const SECONDS := 8.0


func _street(seed_value: int) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, "terminus")
	var one := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 0.0), 0.0, "gang_tank")
	var two := lab.gun(Match.Team.GREEN, "Green_P_2", Vector3(-70.0, 0.0, 20.0), 0.0, "gang_tank")
	lab.gun(Match.Team.GREEN, "Green_P_3", Vector3(-70.0, 0.0, 28.0), 0.0, "gang_tank")
	await lab.start()
	var ctls := {}
	for child in lab.game_match.brains.get_children():
		if child is OrderController:
			ctls[String((child as OrderController).tank.name)] = child
	(ctls["Green_P_1"] as OrderController).set_orders({"type": "face", "x": -70.0, "z": 100.0}, {"type": "fire_at_will"})
	(ctls["Green_P_2"] as OrderController).set_orders({"type": "face", "x": 30.0, "z": 20.0}, {"type": "fire_at_will"})
	(ctls["Green_P_3"] as OrderController).set_orders({"type": "hold"}, {"type": "hold_fire"})
	return {"lab": lab, "one": one, "two": two}


## One run: the queue mode, optionally a capture + restore `snap_at` ticks in. What each crew's ask came to and when.
func _run(shared: bool, snap_at := -1) -> Dictionary:
	PlannerSeam.reset()
	PlannerSeam.queue_override = 1 if shared else 0
	var scene: Dictionary = await _street(31)
	var lab: TacticsLab = scene["lab"]
	var asked := Engine.get_physics_frames()
	var refusal: Array = []   # P_2's FIRST refusal (it asks again after RETRY_TICKS and is refused again)
	for tick in int(SimClock.TICK_RATE * SECONDS):
		if tick == snap_at:
			PlannerSeam.restore(PlannerSeam.capture())
		await lab.step()
		if refusal.is_empty():
			refusal = PlannerSeam.last_refusal("Green_P_2")
	var plans := PlannerSeam.last_plans.duplicate(true)
	for plan: Dictionary in plans:
		plan.erase("tick")
	var out := {"report": PlannerSeam.report(), "p2_refused_after": int(refusal[0]) - asked if not refusal.is_empty() else -1,
			"p2_code": String(refusal[1]) if not refusal.is_empty() else "", "plans": plans,
			"one": [snappedf((scene["one"] as Tank).global_position.x, 0.001), snappedf((scene["one"] as Tank).global_position.z, 0.001)]}
	lab.dispose()
	PlannerSeam.queue_override = -1
	PlannerSeam.reset()
	return out


func test_a_blocked_ask_is_answered_at_once_under_the_shared_queue() -> void:
	if not PlannerSeam.on():
		print("planner seam OFF on this tree: the queue is not exercised")
		return
	var fifo := await _run(false)
	var shared := await _run(true)
	print("MEASURE planner_queue: fifo P_2 %s after %d ticks, report %s | shared P_2 %s after %d ticks, report %s" % [
			fifo["p2_code"], fifo["p2_refused_after"], JSON.stringify(fifo["report"]),
			shared["p2_code"], shared["p2_refused_after"], JSON.stringify(shared["report"])])
	assert_true(String(shared["p2_code"]) != "", "shared: P_2's face east was refused (%s)" % shared["p2_code"])
	assert_true(int(shared["p2_refused_after"]) <= 1, "shared: refused on the ask's tick (%d)" % shared["p2_refused_after"])
	assert_true(int((shared["report"] as Dictionary)["refused_early"]) >= 1, "shared: counted as refused early")
	assert_eq(fifo["p2_code"], shared["p2_code"], "the same refusal either way")
	assert_true(int(fifo["p2_refused_after"]) >= int(shared["p2_refused_after"]), "the FIFO answers it no sooner")
	var fifo_holds: Dictionary = (fifo["report"] as Dictionary)["holds"]
	var shared_holds: Dictionary = (shared["report"] as Dictionary)["holds"]
	assert_true(int(shared_holds["max"]) <= int(fifo_holds["max"]), "the longest hold no longer (%d v %d)" % [shared_holds["max"], fifo_holds["max"]])
	assert_eq((shared["plans"] as Array).size() >= 1, (fifo["plans"] as Array).size() >= 1, "P_1 plans in both or neither")
	if not (fifo["plans"] as Array).is_empty() and not (shared["plans"] as Array).is_empty():
		assert_eq((shared["plans"] as Array)[0]["legs"], (fifo["plans"] as Array)[0]["legs"], "P_1's plan is the same legs")


func test_a_snapshot_mid_search_replays_the_shared_queue() -> void:
	if not PlannerSeam.on():
		return
	var plain := await _run(true)
	var snapped := await _run(true, 3)
	assert_eq(snapped["plans"], plain["plans"], "capture + restore at tick 3: the same plans")
	assert_eq(snapped["one"], plain["one"], "and P_1 ends where it ended")
	assert_eq((snapped["report"] as Dictionary)["holds"], (plain["report"] as Dictionary)["holds"], "the same holds")
