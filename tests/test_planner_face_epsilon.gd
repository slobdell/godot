extends TestCase
## Round 33 (planner P3, C33.6 (c)): **the War Rig's open-ground face-behind is served by the seam.** Its first plan
## lands at expansion 189 at Planner.EPSILON, past the hold's 180 (PENDING_TICKS x SLICE), so the seam abandoned it and
## today's face executor turned the rig. A FACE request's search weight (`PlannerSeam.face_epsilon()`,
## `--planner-face-epsilon`) lands the same plan inside the hold. Holds: today's bits by default (the weight 0), the
## offline plan at 2.0 inside the cap with today's legs, and the seam serving the stage (a plan driven, nothing
## abandoned) where at the default it abandons. Both paths (the GDScript session emulates the C++ step since c74f5943).

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 15.0)
const CANDIDATE := 2.0


func _face_request(arena: Node) -> PlanRequest:
	var world := PlannerNavWorld.new()
	world.map = arena.get_world_3d().navigation_map
	world.bake_radius = Movement.bake_radius(arena)
	var stay := maxf(Movement.settle_radius("gang_tank") - 1.0, 1.5)
	var req := PlanRequest.for_unit("gang_tank").at(START.x, START.z, 0.0, -1.0).to(START.x, START.z, 0.0, 1.0, stay, 8.0).in_world(world)
	req.budget = PlannerSeam.BUDGET
	req.horizon_m = PlannerSeam.HORIZON_M
	return req


func test_the_default_weight_is_todays() -> void:
	PlannerSeam.face_epsilon_override = -1.0
	assert_eq(PlannerSeam.FACE_EPSILON_DEFAULT, 0.0, "nothing ships until judged: a face's weight is Planner.EPSILON")


func test_the_weight_lands_the_face_behind_inside_the_hold() -> void:
	var arena := await ArenaFixture.build(self, "yard_open")
	var req := _face_request(arena)
	var today := Planner.plan(req)
	req.epsilon = CANDIDATE
	var weighted := Planner.plan(req)
	print("FACE_EPSILON today %s | %s ; at %.1f %s | %s" % [today.why, today.describe(), CANDIDATE, weighted.why, weighted.describe()])
	assert_eq(today.code, PackedPlan.OK, "today's search plans it")
	assert_true(today.expansions > PlannerSeam.EXPANSIONS_PER_HOLD, "the problem: today's plan lands past the hold (%d)" % today.expansions)
	assert_eq(weighted.code, PackedPlan.OK, "the weighted search plans it")
	assert_true(weighted.expansions <= PlannerSeam.EXPANSIONS_PER_HOLD, "inside the hold (%d <= %d)" % [weighted.expansions, PlannerSeam.EXPANSIONS_PER_HOLD])
	assert_true(weighted.cost_s <= today.cost_s * 1.05, "no dearer than today's plan (%.2f v %.2f s)" % [weighted.cost_s, today.cost_s])
	arena.free()


## The stage (test_manoeuvre_face_behind's): the seam's counters over the face.
func _stage(weight: float) -> Dictionary:
	PlannerSeam.face_epsilon_override = weight
	PlannerSeam.reset()
	var arena := await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.place(START, 0.0)
	var controller := OrderController.new()
	controller.tank = tank
	controller.tanks_root = game_match.tanks
	add_to_tree(controller)
	await wait_physics_frames(2)
	controller.set_orders({"type": "face", "x": START.x, "z": START.z + 100.0}, {"type": "hold_fire"})
	var aligned := -1
	for frame in SimClock.TICK_RATE * 60:
		await tree.physics_frame
		var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
		if absf(rad_to_deg(nose.angle_to(Vector2(0.0, 1.0)))) <= 10.0 and absf(tank.speed()) < 0.2:
			aligned = frame
			break
	var r := {"plans": PlannerSeam.plans, "abandoned": PlannerSeam.abandoned, "driven": PlannerSeam.driven,
			"aligned_s": float(aligned) / SimClock.TICK_RATE if aligned >= 0 else -1.0,
			"drift_m": Vector2(tank.global_position.x - START.x, tank.global_position.z - START.z).length()}
	PlannerSeam.face_epsilon_override = -1.0
	# Disposed (trip-up 83): a second stage's "Rig" beside an undisposed first one shares its name in the seam's table,
	# and each controller released the other's crew every tick (builder0, the first run of this file).
	controller.free()
	game_match.free()
	arena.free()
	await drain_navigation()
	PlannerSeam.reset()
	return r


func test_the_seam_serves_the_face_behind() -> void:
	var base := await _stage(0.0)
	var cand := await _stage(CANDIDATE)
	print("FACE_EPSILON stage: default %s | weighted %s" % [base, cand])
	assert_true(int(base["abandoned"]) >= 1 and int(base["plans"]) == 0, "control: at today's weight the seam abandons it (%s)" % base)
	assert_true(int(cand["plans"]) >= 1 and int(cand["abandoned"]) == 0, "weighted: the seam plans it (%s)" % cand)
	assert_true(float(cand["aligned_s"]) >= 0.0 and float(cand["aligned_s"]) <= 25.0, "and the rig comes round (%s)" % cand)
	assert_true(float(cand["drift_m"]) <= 8.0, "at its spot (%s)" % cand)
