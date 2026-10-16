extends TestCase
## Round 32 (the orchestrator's main bug, traffic's check on cf81aedc): **a snapshot never copies a crew whose hull is
## freed.** Crews are keyed by hull NAME; a test that disposes its match with a crew still held leaves that crew in
## `PlannerSeam._crews` until the next tick's `_sweep`, and a twin harness (`tests/native/mover_state.gd`, through
## `traffic_twin.gd`) that captures before any seam tick copied it: `Crew.copy` -> `PlannerExecutor.from_state` assigned
## the freed hull ("Invalid assignment ... 'tank' ... 'previously freed'") and the exit-leak gate counted the strays.
## Here: a War Rig driving a plan, its match disposed, then capture / restore with no seam tick between.


func test_a_capture_after_the_match_is_freed_copies_no_dead_crew() -> void:
	PlannerSeam.reset()
	var lab := TacticsLab.create(self, 31, "terminus")
	var tank := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 0.0), 0.0, "gang_tank")
	await lab.start()
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			(child as OrderController).set_orders({"type": "face", "x": -70.0, "z": 100.0}, {"type": "fire_at_will"})
	var driving := false
	for tick in int(SimClock.TICK_RATE * 8.0):
		await lab.step()
		var crew: PlannerSeam.Crew = PlannerSeam._crews.get("Green_P_1")
		if crew != null and crew.executor != null:
			driving = true
			break
	assert_true(driving, "the rig is driving a plan (requests %d, plans %d)" % [PlannerSeam.requests, PlannerSeam.plans])
	lab.dispose()   # the match freed with its crew still held; no seam tick follows
	assert_true(not is_instance_valid(tank), "the hull is freed")
	var snapshot := PlannerSeam.capture()
	assert_eq((snapshot["crews"] as Dictionary).size(), 0, "no crew of a freed hull in the snapshot")
	assert_true(not (snapshot["queue"] as Array).has("Green_P_1"), "nor in its queue")
	PlannerSeam.restore(snapshot)
	assert_true(not PlannerSeam.live("Green_P_1"), "restored: nothing live")
	PlannerSeam.reset()
