extends TestCase
## Round 31 (planner CP-P1, the first judged series' finding): THE KEEP CIRCLE. A War Rig that had arrived 4.5 m
## from its plaza slot (Terminus seed 134, Green_S0_4, t 19.5 s) was faced by the seam's plan "R+1.0x3.5" -- one 3.5 m
## reverse chord on full lock -- and sat 7.4 m from the slot for the rest of the leg, past the census's 7.0 m line: 13
## of the candidate's misses at gaps 7.0-8.5 m (base 1). Manoeuvre's plan_face obeys a SLOT LAW the seam's request
## did not carry (round 30 M1b: the plan may not END further from `face_slot` than it starts + FACE_SLOT_SLACK_M;
## round 31 M1b(2) under turnhull: EVERY pose within max(ORDER_ARRIVE, settle) - FACE_KEEP_MARGIN_M). `PlanRequest.keep`
## carries it: this file plans the trace's geometry on the Terminus navmesh with and without the circle and audits
## every 0.25 m pose of the kept plan against it.

const SLOT := Vector2(-2.7, 19.6)
const HERE := Vector2(-7.2, 20.3)
const HEADING_DEG := 82.0
const WANT_DEG := 100.0


func _face_request(arena: Arena) -> PlanRequest:
	var world := PlannerNavWorld.new()
	world.map = arena.get_world_3d().navigation_map
	world.bake_radius = Movement.bake_radius(arena)
	var f := Vector2(sin(deg_to_rad(HEADING_DEG)), -cos(deg_to_rad(HEADING_DEG)))
	var want := Vector2(sin(deg_to_rad(WANT_DEG)), -cos(deg_to_rad(WANT_DEG)))
	var stay := maxf(Movement.settle_radius("gang_tank") - 1.0, 1.5)
	var req := PlanRequest.for_unit("gang_tank").at(HERE.x, HERE.y, f.x, f.y) \
			.to(HERE.x, HERE.y, want.x, want.y, stay, PlannerSeam.FACE_TOL_DEG).in_world(world)
	req.arrive_gear = 0
	req.budget = PlannerSeam.BUDGET
	req.horizon_m = PlannerSeam.HORIZON_M
	return req


static func _from_slot(x: float, z: float) -> float:
	return Vector2(x - SLOT.x, z - SLOT.y).length()


static func _worst_pose(plan: PackedPlan) -> float:
	var worst := 0.0
	for pose: Variant in plan.poses:
		var p: Array = pose
		worst = maxf(worst, _from_slot(float(p[0]), float(p[1])))
	return worst


func test_a_kept_face_at_rest_ends_no_further_from_its_slot_than_it_starts() -> void:
	var terminus := await ArenaFixture.build(self, "terminus")
	var from_slot := _from_slot(HERE.x, HERE.y)
	var end_m := from_slot + Manoeuvre.FACE_SLOT_SLACK_M
	var free := Planner.plan(_face_request(terminus))
	var kept_req := _face_request(terminus).keep(SLOT.x, SLOT.y, INF, end_m)
	var kept := Planner.plan(kept_req)
	print("PLANNER_KEEP free: %s %s | ends %.2f m from the slot (started %.2f) | %d expansions | %s" % [
			free.code, free.describe(), _from_slot(free.end_x, free.end_z), from_slot, free.expansions, free.why])
	print("PLANNER_KEEP kept (end %.2f m): %s %s | ends %.2f m from the slot, worst pose %.2f | %d expansions | %s" % [
			end_m, kept.code, kept.describe(), _from_slot(kept.end_x, kept.end_z), _worst_pose(kept), kept.expansions, kept.why])
	assert_true(free.ok(), "the free face plans (%s)" % free.code)
	assert_true(kept.ok(), "the kept face plans too (%s: %s)" % [kept.code, kept.why])
	assert_true(_from_slot(kept.end_x, kept.end_z) <= end_m + 0.05, "the kept plan ends within %.2f m of the slot (%.2f)" % [end_m, _from_slot(kept.end_x, kept.end_z)])
	assert_true(not kept.poses.is_empty(), "the kept plan carries its poses")
	# The same request plans the same legs twice (the circle is a pure function of the pose).
	assert_eq(Planner.plan(kept_req).describe(), kept.describe(), "deterministic")
	terminus.free()
	await drain_navigation()


func test_a_kept_face_under_turnhull_keeps_every_pose_inside_the_inner_radius() -> void:
	var terminus := await ArenaFixture.build(self, "terminus")
	var from_slot := _from_slot(HERE.x, HERE.y)
	var settle := Movement.settle_radius("gang_tank")
	var all_m := maxf(maxf(TankBrain.ORDER_ARRIVE, settle) - Manoeuvre.FACE_KEEP_MARGIN_M, from_slot)
	var end_m := from_slot + Manoeuvre.FACE_SLOT_SLACK_M
	var kept := Planner.plan(_face_request(terminus).keep(SLOT.x, SLOT.y, all_m, end_m))
	print("PLANNER_KEEP turnhull (all %.2f, end %.2f): %s %s | ends %.2f m from the slot, worst pose %.2f | %d expansions | %s" % [
			all_m, end_m, kept.code, kept.describe(), _from_slot(kept.end_x, kept.end_z), _worst_pose(kept), kept.expansions, kept.why])
	assert_true(kept.ok(), "the kept face plans under the inner radius (%s: %s)" % [kept.code, kept.why])
	assert_true(_worst_pose(kept) <= all_m + 0.05, "every pose within %.2f m of the slot (worst %.2f)" % [all_m, _worst_pose(kept)])
	assert_true(_from_slot(kept.end_x, kept.end_z) <= end_m + 0.05, "the end within %.2f m (%.2f)" % [end_m, _from_slot(kept.end_x, kept.end_z)])
	terminus.free()
	await drain_navigation()
