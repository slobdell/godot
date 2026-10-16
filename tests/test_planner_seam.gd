extends TestCase
## Round 32 (C32.8): split; the rolling face, capture / restore and a crew per hull are in tests/test_planner_seam_hold.gd.
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


func test_with_the_planner_switched_off_the_seam_is_never_asked() -> void:
	await _with_switch(false, func() -> void:
		assert_true(not PlannerSeam.on(), "planner is OFF (the switch set against PLANNER_DEFAULT)")
		var scene: Dictionary = await _rig_facing_south(31)
		var lab: TacticsLab = scene["lab"]
		for i in int(SimClock.TICK_RATE * 5.0):
			await lab.step()
		assert_eq(PlannerSeam.requests, 0, "OFF: no plan was requested")
		assert_true(not PlannerSeam.live("Green_P_1"), "OFF: live() is false")
		assert_eq(PlannerSeam.last_refusal("Green_P_1"), [], "OFF: last_refusal() is []")
		lab.dispose())


func test_a_war_rig_told_to_face_back_in_a_terminus_street_is_taken_by_the_seam() -> void:
	await _with_switch(true, func() -> void:
		assert_true(PlannerSeam.on(), "planner is ON (the switch set for it)")
		var scene: Dictionary = await _rig_facing_south(31)
		var lab: TacticsLab = scene["lab"]
		var tank: Tank = scene["tank"]
		var mover: Movement = (scene["ctl"] as OrderController).movement
		var face_plans_before := Manoeuvre.face_plans
		var done_at := -1.0
		var max_pending := 0
		var was_live := false
		var manoeuvring_ticks := 0
		var ticks := int(SimClock.TICK_RATE * SECONDS)
		for tick in ticks:
			await lab.step()
			if PlannerSeam.live("Green_P_1"):
				was_live = true
				assert_true(mover.manoeuvring(), "manoeuvring() reads the seam's hold")
				manoeuvring_ticks += 1
			max_pending = maxi(max_pending, PlannerSeam.pending_ticks)
			if done_at < 0.0 and PlannerSeam.driven >= 1:
				done_at = float(tick) / SimClock.TICK_RATE
		var err := _heading_error_deg(tank, Vector3(0, 0, 1))
		var report := PlannerSeam.report()
		print("MEASURE planner_seam face: %s | driven at %.1f s | heading error %.1f deg at %.0f s | manoeuvring ticks %d | plan_face plans %d" % [
				JSON.stringify(report), done_at, err, SECONDS, manoeuvring_ticks, Manoeuvre.face_plans - face_plans_before])
		assert_true(was_live, "the seam held the rig at some point")
		assert_true(PlannerSeam.requests >= 1, "a plan was requested (%d)" % PlannerSeam.requests)
		assert_true(PlannerSeam.plans >= 1, "a plan was made (%d; refused %s)" % [PlannerSeam.plans, str(PlannerSeam.refused)])
		assert_true(PlannerSeam.driven >= 1, "a plan was driven to its end (%d; aborted %d, abandoned %d)" % [PlannerSeam.driven, PlannerSeam.aborted, PlannerSeam.abandoned])
		assert_true(err <= 15.0, "the rig faces south within 15 deg at %.0f s (%.1f)" % [SECONDS, err])
		assert_eq(Manoeuvre.face_plans - face_plans_before, 0, "today's plan_face was not asked while the seam took the face")
		assert_true(not PlannerSeam.live("Green_P_1"), "released once driven")
		lab.dispose())


## R31.7 (the scope): a hull under SCOPE_MIN_HULL_M is never taken, ON or OFF; today's face executor turns it.
func test_a_short_hull_is_never_taken_by_the_seam() -> void:
	await _with_switch(true, func() -> void:
		var lab := TacticsLab.create(self, 31, "terminus")
		var tank := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 0.0), 0.0, "law_scout")
		await lab.start()
		var ctl: OrderController = null
		for child in lab.game_match.brains.get_children():
			if child is OrderController and (child as OrderController).tank == tank:
				ctl = child
		ctl.set_orders({"type": "face", "x": -70.0, "z": 100.0}, {"type": "fire_at_will"})
		var face_plans_before := Manoeuvre.face_plans
		for tick in int(SimClock.TICK_RATE * 15.0):
			await lab.step()
			assert_true(not PlannerSeam.live("Green_P_1"), "a scout is never live in the seam")
		assert_true(not PlannerSeam.in_scope("law_scout"), "law_scout (3.8 m) is out of scope")
		assert_true(PlannerSeam.in_scope("gang_tank"), "gang_tank (14 m) is in scope")
		assert_eq(PlannerSeam.requests, 0, "no plan was requested for a scout")
		var err := _heading_error_deg(tank, Vector3(0, 0, 1))
		print("MEASURE planner_seam scout out of scope: today's face plans %d | heading error %.1f deg at 15 s" % [Manoeuvre.face_plans - face_plans_before, err])
		lab.dispose())
