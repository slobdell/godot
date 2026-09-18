extends TestCase
## X3 (round 6): the form-up estimate is navigation's (N1). A unit's ETA to its slot is Movement.eta — the navmesh
## route at a cruising share of top speed — so it is at least the straight-line time, and the element's form-up ETA is
## its slowest member's.


func test_the_form_up_eta_is_navigations_and_the_slowest_members() -> void:
	var s := AiScenario.create(self, 5)
	var near := s.dummy(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), 0.0)
	var far := s.dummy(Match.Team.GREEN, "Green_A_2", Vector3(-100, 0, 80), 0.0)
	await s.start()
	var slot := Vector3(-100, 0, 0)
	assert_near(FormUp.eta(near, slot), Movement.eta(near, slot), 1e-6, "the estimate is nav's Movement.eta")
	var straight := 40.0 / near.max_forward_speed
	assert_true(FormUp.eta(near, slot) >= straight - 0.01, "no faster than driving flat out in a straight line (%.1f s vs %.1f s)"
			% [FormUp.eta(near, slot), straight])
	var etas := FormUp.etas({"Green_A_1": near, "Green_A_2": far}, {"Green_A_1": slot, "Green_A_2": slot})
	assert_near(FormUp.group_eta(etas), float(etas["Green_A_2"]), 1e-6, "the element is formed up when its slowest member is")
	var paces := FormUp.paces({"Green_A_1": near, "Green_A_2": far}, {"Green_A_1": slot, "Green_A_2": slot}, etas)
	assert_true(float(paces["Green_A_1"]) < 1.0, "the nearer one slows down (%.2f)" % paces["Green_A_1"])
	assert_near(float(paces["Green_A_2"]), 1.0, 0.01, "the laggard drives flat out")
	s.dispose()
