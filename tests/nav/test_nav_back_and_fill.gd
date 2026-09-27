extends TestCase
## Round 12 (nav N2): the War Rig's refused back-ups. The round-11 planned reverse searches ONE back-up; for a 14 m hull
## with a 12 m turning radius lying across an ~21 m Terminus street there is often none (N1: 132 refusals against 78
## legs on the rig drive, laptop). The back-and-fill (`Movement._plan_fill`) alternates gear on one lock, each leg
## checked against the navmesh with the whole outline, and drives it as legs.
##
## The pose is one N1 logged (rigs-8, laptop, `54f39923`): a War Rig on the north spawn line, the goal 52 m away and
## 95 degrees off its nose, a single back-up blocked after 2 m by its rear corner. The control arm
## (`--nav-off=kturnfill`, the same tree) must REFUSE there (kturn_none, no plan) — his complaint reproduced, so the
## treatment cannot pass by accident; the treatment must plan a multi-leg manoeuvre and drive it.

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(-0.7, 0.0, 78.1)
const GOAL := Vector3(-19.1, 0.0, 29.7)
## Signed angle from the nose to the goal (Vector3.signed_angle_to about UP), as logged.
const ERROR_DEG := -95.0


func _drive(fill: bool, seconds: float) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	var to_goal := Vector3(GOAL.x - START.x, 0.0, GOAL.z - START.z).normalized()
	var forward := to_goal.rotated(Vector3.UP, -deg_to_rad(ERROR_DEG))
	tank.global_position = START
	tank.rotation.y = atan2(-forward.x, -forward.z)  # the basis' -Z is the nose
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	var saved := Movement._off
	Movement._off = PackedStringArray() if fill else PackedStringArray(["kturnfill"])
	Movement.reset_route_arms()
	orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"})
	var contacts := 0
	var multi_contacts := 0
	var cusps := 0
	var gear := 0
	var start_error := absf(ERROR_DEG)
	var best_error := start_error
	for frame in int(SimClock.TICK_RATE * seconds):
		await tree.physics_frame
		var reading := Movement.state(tank)
		var touching := bool(reading.get("wall_contact", false))
		if touching:
			contacts += 1
		var arms := Movement.route_arms()
		var driving_plan := int(arms["kturn_multi"]) > 0 and String(reading.get("wall_contact_driver", "")) == "kturn"
		if touching and driving_plan:
			multi_contacts += 1
		var speed := tank.speed()
		if absf(speed) > 0.3:
			var now := 1 if speed > 0.0 else -1
			if gear != 0 and now != gear:
				cusps += 1
			gear = now
		var nose := -tank.global_basis.z
		var to := Vector3(GOAL.x - tank.global_position.x, 0.0, GOAL.z - tank.global_position.z)
		best_error = minf(best_error, rad_to_deg(absf(Vector3(nose.x, 0.0, nose.z).signed_angle_to(to, Vector3.UP))))
	var arms := Movement.route_arms()
	Movement._off = saved
	return {"multi": int(arms["kturn_multi"]), "multi_legs": int(arms["kturn_multi_legs"]), "none": int(arms["kturn_none"]),
			"single": int(arms["kturns"]), "aborted": int(arms["kturn_aborted"]), "contacts": contacts,
			"multi_contacts": multi_contacts, "cusps": cusps, "best_error": best_error,
			"at": tank.global_position, "goal_m": Vector2(GOAL.x - tank.global_position.x, GOAL.z - tank.global_position.z).length()}


func test_control_without_the_back_and_fill_the_single_back_up_refuses_here() -> void:
	var control := await _drive(false, 3.0)
	assert_true(control["none"] >= 1, "control (kturnfill off): the planned reverse finds no single back-up here (%s)" % control)
	assert_eq(control["multi"], 0, "and no multi-leg plan exists in the control arm (%s)" % control)


func test_the_back_and_fill_plans_the_turn_the_single_back_up_cannot() -> void:
	var planned := await _drive(true, 3.0)
	assert_true(planned["multi"] >= 1, "a back-and-fill was planned where the single back-up refused (%s)" % planned)
	assert_true(planned["multi_legs"] >= 2 * planned["multi"], "and it is MULTI-leg (%s)" % planned)


func test_driving_it_turns_the_rig_toward_its_goal_without_touching_a_wall() -> void:
	var planned := await _drive(true, 25.0)
	assert_true(planned["multi"] >= 1, "planned (%s)" % planned)
	assert_eq(planned["multi_contacts"], 0, "no wall contact while a back-and-fill leg is driven (%s)" % planned)
	assert_true(planned["best_error"] < 30.0, "the nose comes round to within 30 deg of the goal (%s)" % planned)
	assert_true(planned["goal_m"] < 45.0, "and the rig is under way toward it (%s)" % planned)
