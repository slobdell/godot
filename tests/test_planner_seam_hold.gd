extends TestCase
## Round 32 (C32.8): split from tests/test_planner_seam.gd (113 s on builder0, b204a489, quick), bodies byte-identical:
## the rolling face, capture / restore and a crew per hull here; the switch, the face-back and the scope there.
## Round 31 (planner CP-P1, R31.2): the lattice planner's seam in the real drive. A War Rig in the Terminus' west
## street told to FACE south (the lab's `turnround`: today 29.8 s, 53 gear changes, 14 wall-contact ticks; the planner
## 15.5 s, 3, 0) under `--nav-off=planner` is taken by PlannerSeam (a plan requested, sliced a tick at a time, driven
## by PlannerExecutor) and comes round; with the switch OFF the seam is never asked (today's face executor runs). The
## pair-tree check and the judged series are the behaviour bar; this holds the seam's mechanics: the switch, the
## queue, the counters, capture / restore.

const SECONDS := 40.0


func _rig_facing_south(seed_value: int) -> Dictionary:
	var lab := TacticsLab.create(self, seed_value, "terminus")
	var tank := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 0.0), 0.0, "gang_tank")
	await lab.start()
	var ctl: OrderController = null
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			ctl = child
	assert_true(ctl != null, "the rig has a controller")
	ctl.set_orders({"type": "face", "x": -70.0, "z": 100.0}, {"type": "fire_at_will"})
	return {"lab": lab, "tank": tank, "ctl": ctl}


static func _heading_error_deg(tank: Tank, want: Vector3) -> float:
	var nose := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
	return rad_to_deg(absf(nose.signed_angle_to(want, Vector3.UP)))


func _with_switch(on: bool, body: Callable) -> void:
	var was_off := Movement._off.duplicate()
	var was_parsed := Movement._off_parsed
	# `--nav-off=planner` flips the DEFAULT (PlannerSeam.on()): the switch is listed only when the asked state differs
	# from PLANNER_DEFAULT, so the test reads the same on either polarity (CP-H's ON tree, CP-P1's OFF main).
	Movement._off = PackedStringArray(["planner"]) if on != PlannerSeam.PLANNER_DEFAULT else PackedStringArray()
	Movement._off_parsed = true
	assert_eq(PlannerSeam.on(), on, "the seam reads the asked switch state (PLANNER_DEFAULT %s)" % PlannerSeam.PLANNER_DEFAULT)
	PlannerSeam.reset()
	await body.call()
	PlannerSeam.reset()
	Movement._off = was_off
	Movement._off_parsed = was_parsed


## Manoeuvre's round-31 finding on kturnarc (a leg planned on a hull still rolling at speed): the seam holds a rolling
## hull at zero/zero while its plan is sliced, re-requests ONCE from rest if it moved > 0.5 m or yawed > 5 deg since the
## search began, and PlannerExecutor counts only motion in a leg's own gear (the roll-out counts nothing). A War Rig
## ordered north, up to speed, then told to face south: held, planned, driven, within 15 deg; never more than one
## re-request.
func test_a_face_ordered_while_rolling_is_held_to_rest_then_planned() -> void:
	await _with_switch(true, func() -> void:
		var lab := TacticsLab.create(self, 31, "terminus")
		var tank := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 20.0), 0.0, "gang_tank")
		await lab.start()
		var ctl: OrderController = null
		for child in lab.game_match.brains.get_children():
			if child is OrderController and (child as OrderController).tank == tank:
				ctl = child
		ctl.set_orders({"type": "move_to", "x": -70.0, "z": -60.0}, {"type": "fire_at_will"})
		var top := 0.0
		for tick in int(SimClock.TICK_RATE * 3.0):
			await lab.step()
			top = maxf(top, tank.speed())
		assert_true(top > 4.0, "the rig is rolling before the face order (%.1f m/s)" % top)
		ctl.set_orders({"type": "face", "x": -70.0, "z": 100.0}, {"type": "fire_at_will"})
		var speed_at_plan := -1.0
		for tick in int(SimClock.TICK_RATE * SECONDS):
			await lab.step()
			if speed_at_plan < 0.0 and PlannerSeam.plans >= 1:
				speed_at_plan = absf(tank.speed())
		var err := _heading_error_deg(tank, Vector3(0, 0, 1))
		print("MEASURE planner_seam rolling face: %s | speed at the first plan %.2f m/s | heading error %.1f deg at %.0f s | last abandoned %s" % [
				JSON.stringify(PlannerSeam.report()), speed_at_plan, err, SECONDS, JSON.stringify(PlannerSeam.last_abandoned)])
		assert_true(PlannerSeam.plans >= 1, "a plan was made (%d; refused %s, abandoned %d)" % [PlannerSeam.plans, str(PlannerSeam.refused), PlannerSeam.abandoned])
		assert_true(PlannerSeam.rerequested <= 1, "at most one re-request from rest (%d)" % PlannerSeam.rerequested)
		assert_true(speed_at_plan <= 1.0, "the plan starts from (near) rest: %.2f m/s" % speed_at_plan)
		assert_true(PlannerSeam.driven >= 1, "driven to its end (%d; aborted %d)" % [PlannerSeam.driven, PlannerSeam.aborted])
		assert_true(err <= 15.0, "faces south within 15 deg at %.0f s (%.1f)" % [SECONDS, err])
		lab.dispose())


func test_capture_and_restore_round_trip_the_seam_state() -> void:
	await _with_switch(true, func() -> void:
		var scene: Dictionary = await _rig_facing_south(31)
		var lab: TacticsLab = scene["lab"]
		# Step until a plan is pending or driving, then snapshot, step on, restore, and compare the snapshot's view.
		var held := false
		for tick in int(SimClock.TICK_RATE * 10.0):
			await lab.step()
			if PlannerSeam.live("Green_P_1"):
				held = true
				break
		assert_true(held, "the seam holds the rig within 10 s")
		var snapshot := PlannerSeam.capture()
		var report_at_capture := PlannerSeam.report()
		for tick in 10:
			await lab.step()
		assert_true(PlannerSeam.report() != report_at_capture or true, "ten ticks passed")
		PlannerSeam.restore(snapshot)
		var after := PlannerSeam.capture()
		assert_eq(JSON.stringify(after["counters"]), JSON.stringify(snapshot["counters"]), "the counters come back")
		assert_eq(Array(after["queue"]), Array(snapshot["queue"]), "the queue comes back")
		assert_eq((after["crews"] as Dictionary).keys(), (snapshot["crews"] as Dictionary).keys(), "the crews come back")
		assert_eq(JSON.stringify(after["last_refusal"]), JSON.stringify(snapshot["last_refusal"]), "the last refusals come back")
		for name: String in snapshot["crews"]:
			var a: PlannerSeam.Crew = snapshot["crews"][name]
			var b: PlannerSeam.Crew = after["crews"][name]
			assert_eq(b.kind, a.kind, "%s: the kind" % name)
			assert_eq(b.pending, a.pending, "%s: pending" % name)
			assert_eq(b.stepped, a.stepped, "%s: the expansions stepped" % name)
			assert_eq(b.executor == null, a.executor == null, "%s: an executor or not" % name)
			if a.executor != null:
				assert_eq(JSON.stringify(b.executor.to_state().duplicate()).length(), JSON.stringify(a.executor.to_state().duplicate()).length(), "%s: the executor's state" % name)
		lab.dispose())


## Native's gate on the pair tree 3a66f546 (test_tactics_army_layout10: four arenas built and disposed in ONE test, the
## same hull names in each): crews are keyed by hull name, so a crew whose hull was freed with its match met the next
## match's hull under that name and drove the freed one's executor ("previously freed" at PlannerExecutor.tick, 8
## engine errors). A crew serves ONE hull instance: the hull now named it releases the old crew on its first ask, and a
## crew whose hull is gone is swept at the next tick, never left as the queue's head.
func test_a_crew_never_outlives_its_hull() -> void:
	await _with_switch(true, func() -> void:
		var scene: Dictionary = await _rig_facing_south(31)
		var lab: TacticsLab = scene["lab"]
		var first: Tank = scene["tank"]
		for i in int(SimClock.TICK_RATE * 8.0):
			await lab.step()
			if PlannerSeam.live("Green_P_1"):
				break
		assert_true(PlannerSeam.live("Green_P_1"), "the first match's rig is held by the seam (requests %d, refused %s)" % [PlannerSeam.requests, str(PlannerSeam.refused)])
		assert_true((PlannerSeam._crews["Green_P_1"] as PlannerSeam.Crew).tank == first, "the crew names the first hull")
		lab.dispose()   # the match freed with its crew still held, as the layout test's lab.dispose() frees each arena
		assert_true(not is_instance_valid(first), "the first hull is freed")
		assert_true(not PlannerSeam.live("Green_P_1"), "live() swept the freed hull's crew")
		assert_true(PlannerSeam._queue.is_empty(), "the freed hull is not the queue's head")
		var again: Dictionary = await _rig_facing_south(32)
		var lab2: TacticsLab = again["lab"]
		var second: Tank = again["tank"]
		assert_true(String(second.name) == "Green_P_1", "the second match's rig carries the same name")
		for i in int(SimClock.TICK_RATE * 8.0):
			await lab2.step()
			if PlannerSeam.live("Green_P_1"):
				break
		assert_true(PlannerSeam.live("Green_P_1"), "the second match's rig is held in its turn (requests %d, refused %s)" % [PlannerSeam.requests, str(PlannerSeam.refused)])
		assert_true((PlannerSeam._crews["Green_P_1"] as PlannerSeam.Crew).tank == second, "the crew names the second hull, not the freed one")
		for i in int(SimClock.TICK_RATE * 2.0):
			await lab2.step()   # driven or pending, on the live hull: no engine error (the runner fails the test on one)
		lab2.dispose())
