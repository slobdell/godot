extends TestCase
## Round 34 (the orchestrator's safety net, after the Terminus route stall): a player's element with route legs queued
## whose centre stops closing on its spot for Element.STALL_ARRIVE_S counts as arrived, so the route moves on instead of
## freezing. One still closing, a CPU element, or one with nothing queued is never forced.


func _element() -> Element:
	var e := Element.new()
	e.task = {"verb": "move", "to": [0.0, 0.0]}
	return e


func _run(e: Element, player: bool, queued: bool, distances: Array) -> void:
	var tick := 0
	for d: float in distances:
		e.track_stall(player, queued, "move", d, tick)
		tick += SimClock.TICK_RATE  # one sample a second


func test_a_player_route_stuck_short_of_its_spot_counts_as_arrived() -> void:
	var e := _element()
	var stuck: Array = [60.0, 50.0, 40.0]
	for i in int(Element.STALL_ARRIVE_S) + 2:
		stuck.append(39.0)  # no metre of progress
	_run(e, true, true, stuck)
	assert_true(e.stall_arrived, "stalled %.0f s: counted as arrived" % Element.STALL_ARRIVE_S)
	assert_true(ElementPlan._arrived_at(39.0, {"stall_arrived": true}), "and the plan reads it as arrived")


func test_still_closing_slowly_it_is_not_forced() -> void:
	var e := _element()
	var slow: Array = []
	for i in 40:
		slow.append(80.0 - i * 1.5)  # 1.5 m a second: progress
	_run(e, true, true, slow)
	assert_true(not e.stall_arrived, "closing: never forced")


func test_cpu_elements_and_single_moves_are_never_forced() -> void:
	var flat: Array = []
	for i in 40:
		flat.append(39.0)
	var cpu := _element()
	_run(cpu, false, true, flat)
	assert_true(not cpu.stall_arrived, "a CPU element is never forced (its sims stand)")
	var single := _element()
	_run(single, true, false, flat)
	assert_true(not single.stall_arrived, "nothing queued: never forced (only a route waits on its arrival)")


func test_a_squad_waiting_with_a_crew_under_way_is_never_forced() -> void:
	# A give-way or a crossing hold: the centre stands, but a crew still has a live move.
	var e := _element()
	var tick := 0
	for i in 40:
		e.track_stall(true, true, "move", 39.0, tick, true)
		tick += SimClock.TICK_RATE
	assert_true(not e.stall_arrived, "a crew under way restarts the clock")
