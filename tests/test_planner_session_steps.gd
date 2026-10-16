extends TestCase
## Round 32 (the orchestrator's face-behind question): **a session without the library answers on the same call as the
## C++ session.** Under NATIVE=off `Planner.begin_session` plans whole at begin; it used to answer on the first
## `step_session`, so the seam's 180-expansion cap never applied and test_manoeuvre_behind's War Rig face-behind (189
## expansions) was DRIVEN under NATIVE=off but ABANDONED under native. `Planner.emulate_step` replays the C++ `step(n)`
## on the whole plan; this holds the call each answers, for fixed slices and for a mixed sequence of step sizes (the
## twin harnesses' replay: one big step of the expansions already handed), on the offline fixtures, a refusal, and the
## face-behind on the yard_open navmesh. Both static session and `Planner.Session`. Skipped (said) without the library.

const SLICES: Array[int] = [1, 2, 3, 50]
const MIXED: Array[int] = [2, 2, 7, 1, 40, 2, 3, 300, 2, 2, 2, 1000, 5000]


func _skip() -> bool:
	if not Planner.native_usable() or not Planner._session_impl.has_method("refused_at_begin"):
		print("native: absent, the session-step equality is not exercised in this run")
		return true
	return false


## The calls the session takes to answer, and the done flag after each call of `sizes` (cycled to the cap).
func _calls(req: PlanRequest, native: bool, sizes: Array[int], cap := 20000) -> Array:
	Planner.native_on = native
	Planner.begin_session(req)
	var flags: Array[bool] = []
	var i := 0
	while i < cap:
		var done := Planner.step_session(sizes[i % sizes.size()])
		flags.append(done)
		i += 1
		if done:
			break
	var plan := Planner.session_result()
	Planner.cancel_session()
	Planner.native_on = true
	return [flags.size(), plan.code, plan.describe(), plan.expansions]


func _both(label: String, req: PlanRequest) -> void:
	for slice: int in SLICES:
		var sizes: Array[int] = [slice]
		var cpp := _calls(req, true, sizes)
		var gd := _calls(req, false, sizes)
		assert_eq(gd, cpp, "%s, slice %d: the no-library session answers on the C++ call (calls, code, legs, expansions)" % [label, slice])
	var cpp_mixed := _calls(req, true, MIXED)
	var gd_mixed := _calls(req, false, MIXED)
	assert_eq(gd_mixed, cpp_mixed, "%s, mixed step sizes: the same call" % label)
	# The per-crew session (the shared queue's) the same way.
	for native: bool in [true, false]:
		Planner.native_on = native
		var session := Planner.Session.new()
		session.begin(req)
		var calls := 0
		while calls < 6000:
			calls += 1
			if session.step(2):
				break
		session.cancel()
		Planner.native_on = true
		assert_eq(calls, int(_calls(req, true, [2] as Array[int])[0]), "%s: Planner.Session (%s) answers on the C++ call" % [
				label, "native" if native else "no library"])
	print("SESSION_STEPS %s: slice 2 answers on call %d (%s)" % [label, int(_calls(req, true, [2] as Array[int])[0]), req.goal_x])


func test_offline_fixtures_answer_on_the_same_call() -> void:
	if _skip():
		return
	var f6a := PlannerFixtures.turn_round("gang_tank", 20.0)
	f6a.budget = 6000
	f6a.epsilon = 2.0
	_both("F6a rig turn-round 20 m", f6a)
	var f6b := PlannerFixtures.turn_round("gang_tank", 12.0)
	f6b.budget = 4000
	_both("F6b rig 12 m (the fine retry)", f6b)
	var tj := PlannerFixtures.t_junction("gang_tank")
	tj.budget = 3000
	_both("T-junction rig", tj)
	_both("mouth IFV", PlannerFixtures.mouth_with_hull("ifv"))
	_both("slot 180 scout", PlannerFixtures.slot_180("law_scout", 14.0))
	_both("wedge rig", PlannerFixtures.wedge("gang_tank"))
	var blocked := PlannerFixtures.mouth_with_hull("gang_tank")
	blocked.at(blocked.goal_x, blocked.goal_z, 1.0, 0.0)   # start on the goal: answered at begin (already there or blocked)
	_both("an answer at begin", blocked)


func test_the_war_rig_face_behind_answers_on_the_same_call() -> void:
	if _skip():
		return
	var arena := await ArenaFixture.build(self, "yard_open")
	var world := PlannerNavWorld.new()
	world.map = arena.get_world_3d().navigation_map
	world.bake_radius = Movement.bake_radius(arena)
	var stay := maxf(Movement.settle_radius("gang_tank") - 1.0, 1.5)
	var req := PlanRequest.for_unit("gang_tank").at(0.0, 15.0, 0.0, -1.0).to(0.0, 15.0, 0.0, 1.0, stay, 8.0).in_world(world)
	req.budget = PlannerSeam.BUDGET
	req.horizon_m = PlannerSeam.HORIZON_M
	_both("face-behind, yard_open", req)
	var calls := int(_calls(req, false, [PlannerSeam.SLICE] as Array[int])[0])
	assert_true(calls > PlannerSeam.pending_cap(), "no library: the face-behind outlasts the seam's hold too (%d calls v the cap %d), as with it" % [
			calls, PlannerSeam.pending_cap()])
	arena.free()
