extends TestCase
## Round 31 (planner CP-P1, the gate's k-turn finding): manoeuvre's War Rig nose-on to the Terminus (40, 0) block at a
## 2 m gap, ordered to (10, 31) behind and to the side, plans 4 legs under the seam (R3 F2 R12 F31.5: 3 cusps) where
## today's k-turn drives 2 (R4.5, F30). This SWEEP plans the seam's own request on the arena navmesh and varies one
## thing at a time -- the goal (the seam's horizon-clipped point v the order's point), the arrival tolerance, the end
## heading's tolerance, the cusp's cost (brake/accel), the arrive gear -- and prints every plan, so the lever that
## buys a 2-3 leg answer is read off one run, not guessed. Measurement: the assertions are the arms.

const START := Vector3(40.0, 0.0, 29.0)   # FACE_Z 20 + half 7 + gap 2 (gang_tank hull 14 m)
const GOAL := Vector3(10.0, 0.0, 31.0)


func _req(world: PlannerNavWorld, goal: Vector3, tol_m: float, tol_deg: float, heading: Vector2, cusp_scale: float, arrive_gear: int) -> PlanRequest:
	var req := PlanRequest.for_unit("gang_tank").at(START.x, START.z, 0.0, -1.0) \
			.to(goal.x, goal.z, heading.x, heading.y, tol_m, tol_deg).in_world(world)
	req.budget = PlannerSeam.BUDGET
	req.horizon_m = PlannerSeam.HORIZON_M
	req.arrive_gear = arrive_gear
	req.brake /= cusp_scale
	req.accel /= cusp_scale
	return req


func test_the_war_rig_k_turn_request_swept() -> void:
	var terminus := await ArenaFixture.build(self, "terminus")
	var world := PlannerNavWorld.new()
	world.map = terminus.get_world_3d().navigation_map
	world.bake_radius = Movement.bake_radius(terminus)
	var to := GOAL - START
	var clipped := START + to.normalized() * (PlannerSeam.HORIZON_M * 0.8)
	var along := Vector2(to.x, to.z).normalized()
	var rows: Array = [
		# label, goal, tol_m, tol_deg, heading, cusp_scale, arrive_gear
		["seam as is: clipped goal, tol 1 m, free heading, gear 1", clipped, 1.0, 180.0, along, 1.0, 1],
		["order's goal, tol 1 m, free heading", GOAL, 1.0, 180.0, along, 1.0, 1],
		["clipped, tol 2.5 m, free heading", clipped, 2.5, 180.0, along, 1.0, 1],
		["clipped, tol 1 m, heading along within 30 deg", clipped, 1.0, 30.0, along, 1.0, 1],
		["clipped, tol 1 m, heading along within 8 deg", clipped, 1.0, 8.0, along, 1.0, 1],
		["clipped, tol 1 m, free heading, cusp x2", clipped, 1.0, 180.0, along, 2.0, 1],
		["clipped, tol 1 m, free heading, cusp x4", clipped, 1.0, 180.0, along, 4.0, 1],
		["clipped, tol 1 m, free heading, any arrive gear", clipped, 1.0, 180.0, along, 1.0, 0],
		["clipped, tol 2.5 m, heading within 30 deg, cusp x2", clipped, 2.5, 30.0, along, 2.0, 1],
		["halfway (12 m), tol 1.5 m, free heading", START + to.normalized() * 12.0, 1.5, 180.0, along, 1.0, 1],
	]
	var worst := 0
	for row: Array in rows:
		var req := _req(world, row[1], float(row[2]), float(row[3]), row[4], float(row[5]), int(row[6]))
		var t0 := Time.get_ticks_usec()
		var out: PackedPlan = Planner.plan(req)
		var ms := (Time.get_ticks_usec() - t0) / 1000.0
		print("PLANNER_SWEEP kturn | %s | %s %s | legs %d cusps %d metres %.1f cost %.1f s | expansions %d %.1f ms | end (%.1f, %.1f) f (%.2f, %.2f) | goal (%.1f, %.1f)" % [
				row[0], out.code, out.describe(), out.legs.size(), out.cusps, out.metres, out.cost_s, out.expansions, ms,
				out.end_x, out.end_z, out.end_fx, out.end_fz, (row[1] as Vector3).x, (row[1] as Vector3).z])
		if out.ok():
			worst = maxi(worst, out.legs.size())
	var base := _req(world, clipped, 1.0, 180.0, along, 1.0, 1)
	var plan: PackedPlan = Planner.plan(base)
	print("PLANNER_SWEEP kturn ascii (seam as is):\n" + plan.ascii(world, START.x - 40.0, START.z - 25.0, START.x + 15.0, START.z + 25.0, START.x, START.z, clipped.x, clipped.z))
	terminus.free()
	await drain_navigation()
	assert_true(worst > 0, "the sweep planned (%d legs at worst)" % worst)
