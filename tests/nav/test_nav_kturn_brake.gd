extends TestCase
## Round 14 (nav N3): a planned leg ends where the hull can STOP by its planned end. N1/N3 (builder0, 8 seeds): a War
## Rig's back-and-fill forward leg reached ~5.7 m/s over its 2.5 m and ended 0.25 m short of the clear reach; braking at
## 8 m/s2 the rig rolled ~2 m further, nose into the face, while the next leg already commanded reverse (241 of the
## rigs' 305 kturn reverse-gear contacts).
##
## Here a rig on open ground is handed a two-leg plan directly (4 m forward, then 3 m back, full lock): the control
## (the default: the switch is OPT-IN, `--nav-off=kturnbrake` turns it ON; Status N3) overshoots the forward leg's end by about the stopping distance — the mechanism
## reproduced, so the arm cannot pass by accident; with the arm the hull turns back within a short margin of it.
## (Measured along the first heading while the plan is driven: after it, the hull drives on to the goal. In the control
## the reverse leg is never driven at all: the forward roll counts as its distance.)

const MATCH := preload("res://game/match/match.tscn")
const START := Vector3(0.0, 0.0, 0.0)
const GOAL := Vector3(0.0, 0.0, -60.0)
const FORWARD_M := 4.0
const BACK_M := 3.0


func _drive(off: PackedStringArray) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = off
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = START
	tank.rotation.y = 0.0
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"})
	await wait_physics_frames(1)
	var mover := Movement.of(tank)
	var from := tank.global_position
	var nose := -tank.global_basis.z
	mover._kturn_turn = 1.0
	mover._kturn_plan_kind = "fill"
	mover._kturn_leg_no = 0
	mover._kturn_legs = [Vector2(-1.0, BACK_M)]
	mover._kturn_start_leg(Vector2(1.0, FORWARD_M))
	var furthest := 0.0
	var reversed_at := -1.0
	for frame in SimClock.TICK_RATE * 6:
		await tree.physics_frame
		var along := (tank.global_position - from).dot(nose)
		if mover.in_kturn():
			furthest = maxf(furthest, along)  # while the plan is being driven (after it, the hull drives on to the goal)
		if reversed_at < 0.0 and tank.speed() < -0.3:
			reversed_at = along
	Movement._off = saved
	return {"furthest_m": furthest, "reversed_at_m": reversed_at, "legs_left": mover._kturn_legs.size()}


func test_control_the_hull_overshoots_the_forward_leg_by_its_stopping_distance() -> void:
	var run := await _drive(PackedStringArray())
	assert_true(float(run["furthest_m"]) > FORWARD_M + 1.0, "control: during the plan it rolls well past the forward leg's end (%s)" % run)


func test_the_leg_ends_early_enough_to_stop_at_its_planned_end() -> void:
	var run := await _drive(PackedStringArray(["kturnbrake"]))
	assert_true(float(run["reversed_at_m"]) > 0.0, "the reverse leg is driven (%s)" % run)
	assert_true(float(run["reversed_at_m"]) <= FORWARD_M + 0.5 and float(run["furthest_m"]) <= FORWARD_M + 0.5,
			"from within 0.5 m of the forward leg's planned end (%s)" % run)
