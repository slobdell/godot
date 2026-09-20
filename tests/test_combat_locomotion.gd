extends TestCase
## Round 3 combat: contract K3 (locomotion) in _agents/workstreams.md. The catalog's locomotion fields and the
## pure `TankMotion.predict` that ai plans maneuvers with and control previews paths with.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0
const K3_FIELDS := ["locomotion", "min_turn_radius_m", "acceleration_mps2", "braking_mps2", "lateral_grip"]


func test_every_unit_has_the_k3_fields() -> void:
	for unit_id: String in Units.PROFILES:
		var unit := Units.profile(unit_id)
		for key: String in K3_FIELDS:
			assert_true(unit.has(key), "%s is missing %s" % [unit_id, key])
		assert_true(Units.LOCOMOTIONS.has(unit.get("locomotion")), "%s has a known locomotion (%s)" % [unit_id, unit.get("locomotion")])
		assert_true(float(unit.get("acceleration_mps2", 0.0)) > 0.0, "%s accelerates" % unit_id)
		assert_true(float(unit.get("braking_mps2", 0.0)) > 0.0, "%s brakes" % unit_id)
		var grip := float(unit.get("lateral_grip", -1.0))
		assert_true(grip > 0.0 and grip <= 1.0, "%s: lateral_grip in (0, 1] (%.2f)" % [unit_id, grip])
		if unit.get("locomotion") == "wheels":
			assert_true(float(unit.get("min_turn_radius_m", 0.0)) > 0.0, "%s: wheels have a turning circle" % unit_id)


func _state(unit_id: String, speed := 0.0) -> Dictionary:
	return TankMotion.state_for(unit_id, Vector3(10.0, 0.0, 5.0), Vector3.FORWARD, speed)


func test_predict_is_pure_and_returns_one_pose_per_tick() -> void:
	var state := _state("tank")
	var before := state.duplicate(true)
	var first := TankMotion.predict(state, 1.0, 0.3, 45)
	var second := TankMotion.predict(state, 1.0, 0.3, 45)
	assert_eq(first.size(), 45, "one pose per tick")
	assert_eq(first, second, "same inputs, same poses")
	assert_eq(state, before, "the input state is untouched")
	for key in ["position", "forward", "speed", "velocity"]:
		assert_true((first[0] as Dictionary).has(key), "a pose has %s" % key)


func test_full_throttle_accelerates_to_top_speed_in_a_straight_line() -> void:
	var unit := Units.profile("tank")
	var poses := TankMotion.predict(_state("tank"), 1.0, 0.0, SimClock.TICK_RATE * 2)
	var last: Dictionary = poses[-1]
	assert_near(float(last["speed"]), float(unit["max_forward_speed"]), 0.001, "top speed after 2 s")
	var seconds_to_top := float(unit["max_forward_speed"]) / float(unit["acceleration_mps2"])
	assert_near(float(poses[0]["speed"]), float(unit["acceleration_mps2"]) / float(SimClock.TICK_RATE), 0.001, "one tick of acceleration")
	var expected_z := 5.0 - (float(unit["max_forward_speed"]) * (2.0 - seconds_to_top / 2.0))
	assert_near((last["position"] as Vector3).z, expected_z, 0.2, "distance covered = accelerate, then cruise")
	assert_near((last["position"] as Vector3).x, 10.0, 0.0001, "no drift sideways")


func test_braking_uses_the_braking_rate() -> void:
	var unit := Units.profile("tank")
	var poses := TankMotion.predict(_state("tank", float(unit["max_forward_speed"])), 0.0, 0.0, 1)
	assert_near(float(poses[0]["speed"]), float(unit["max_forward_speed"]) - float(unit["braking_mps2"]) / float(SimClock.TICK_RATE), 0.001,
			"a tick off the throttle sheds braking_mps2 per tick")


func test_tracks_pivot_in_place_and_turn_right_for_positive_turn() -> void:
	var unit := Units.profile("tank")
	var tracked := _state("tank")
	tracked["locomotion"] = "tracks"
	var poses := TankMotion.predict(tracked, 0.0, 1.0, SimClock.TICK_RATE / 2)
	var last: Dictionary = poses[-1]
	assert_true((last["position"] as Vector3).is_equal_approx(Vector3(10.0, 0.0, 5.0)), "a pivot stays put")
	var turned := rad_to_deg(Vector3.FORWARD.signed_angle_to(last["forward"], Vector3.UP))
	# Round 8 (nav): the yaw rate ramps up over TankMotion.YAW_RAMP_SECONDS instead of starting at full rate (the lead's
	# camera showed the instant start as robotic). Half a second of full turn is therefore the full-rate half second
	# less the ramp's cost, which is between half a tick and a whole tick of rate more than the continuous triangle
	# (the rate is stepped once per tick, so each tick holds the rate it reached at its START).
	var rate := float(unit["hull_turn_rate_deg"])
	var least := rate * (0.5 - TankMotion.YAW_RAMP_SECONDS / 2.0)
	assert_true(turned <= -least + 0.01 and turned >= -(least + rate * TankMotion.TICK_SECONDS),
			"half a second of full turn after the ramp, clockwise (right): %.2f in [%.2f, %.2f]" % [
					turned, -(least + rate * TankMotion.TICK_SECONDS), -least])
	assert_near((last["forward"] as Vector3).length(), 1.0, 0.0001, "forward stays a unit vector")


func test_predict_matches_a_real_tank_on_open_ground() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var tank := game_match.spawn_tank("Driver", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(LANE_X, 0.0, 30.0)
	await wait_physics_frames(3)
	var start := TankMotion.state_of(tank)
	var poses := TankMotion.predict(start, 1.0, 0.5, SimClock.TICK_RATE)
	for tick in SimClock.TICK_RATE:
		tank.command = TankCommand.new(1.0, 0.5, Vector3.ZERO, false)
		await tree.physics_frame
	var predicted: Dictionary = poses[-1]
	var actual := tank.global_position
	assert_near(Vector2(actual.x, actual.z).distance_to(Vector2(predicted["position"].x, predicted["position"].z)), 0.0, 0.3,
			"one second of driving lands where predict said (%s vs %s)" % [actual, predicted["position"]])
	var heading_error := rad_to_deg(absf((-tank.global_basis.z).signed_angle_to(predicted["forward"], Vector3.UP)))
	assert_true(heading_error < 2.0, "and faces the same way (%.2f° off)" % heading_error)
	assert_near(tank.speed(), float(predicted["speed"]), 0.05, "at the same speed")


# ---- X4: arcade driving -----------------------------------------------------------------------

## A wheeled state with explicit numbers, so the math is checked independently of catalog tuning.
func _car(speed := 0.0, grip := 1.0) -> Dictionary:
	var state := TankMotion.state_for("scout", Vector3.ZERO, Vector3.FORWARD, speed)
	state["locomotion"] = "wheels"
	state["min_turn_radius_m"] = 6.0
	state["hull_turn_rate_deg"] = 150.0
	state["max_forward_speed"] = 14.0
	state["max_reverse_speed"] = 7.0
	state["acceleration_mps2"] = 12.0
	state["braking_mps2"] = 20.0
	state["lateral_grip"] = grip
	return state


func _yaw_deg(forward: Vector3) -> float:
	## Degrees turned from north; positive = right (clockwise from above).
	return -rad_to_deg(Vector3.FORWARD.signed_angle_to(forward, Vector3.UP))


func test_the_roster_drives_on_the_proposed_locomotion() -> void:
	for unit_id in ["scout", "ifv", "artillery", "lancer"]:
		assert_eq(Units.profile(unit_id)["locomotion"], "wheels", "%s rolls on wheels" % unit_id)
	assert_eq(Units.profile("tank")["locomotion"], "tracks", "the dozer tank keeps its tracks")
	assert_true(float(Units.profile("scout")["min_turn_radius_m"]) < float(Units.profile("artillery")["min_turn_radius_m"]),
			"the rally truck turns tighter than the crane carrier")


func test_wheels_do_not_rotate_standing_still() -> void:
	var poses := TankMotion.predict(_car(), 0.0, 0.0, SimClock.TICK_RATE)
	assert_true((poses[-1]["forward"] as Vector3).is_equal_approx(Vector3.FORWARD), "no throttle, no turn: nothing moves")
	var brake := _car()
	var held := TankMotion.predict(brake, 0.0, 1.0, 1)
	assert_true(absf(_yaw_deg(held[0]["forward"])) < 0.01, "a turn at a standstill doesn't pivot the hull on the spot")


func test_wheel_yaw_rate_is_speed_over_radius() -> void:
	# The tick's yaw uses the speed the tick started with.
	var slow := TankMotion.predict(_car(6.0), 6.0 / 14.0, 1.0, 1)
	var expected := rad_to_deg(6.0 / 6.0) / SimClock.TICK_RATE
	assert_near(_yaw_deg(slow[0]["forward"]), expected, expected * 0.01, "6 m/s on a 6 m circle: 1 rad/s")
	var half := TankMotion.predict(_car(6.0), 6.0 / 14.0, 0.5, 1)
	assert_near(_yaw_deg(half[0]["forward"]), rad_to_deg(6.0 / 12.0) / SimClock.TICK_RATE, 0.005, "half lock = twice the radius")
	var fast_car := _car(14.0)
	fast_car["hull_turn_rate_deg"] = 100.0  # 14 m/s on a 6 m circle would be 134°/s
	var fast := TankMotion.predict(fast_car, 1.0, 1.0, 1)
	assert_near(_yaw_deg(fast[0]["forward"]), 100.0 / SimClock.TICK_RATE, 0.02, "at speed the yaw rate caps at hull_turn_rate_deg")


func test_a_full_lock_circle_has_the_minimum_radius() -> void:
	var state := _car(8.4)  # 0.6 throttle: above the multi-point-turn creep, below the yaw-rate cap
	var poses := TankMotion.predict(state, 0.6, 1.0, SimClock.TICK_RATE * 20)
	var min_x := INF
	var max_x := -INF
	for pose: Dictionary in poses:
		min_x = minf(min_x, (pose["position"] as Vector3).x)
		max_x = maxf(max_x, (pose["position"] as Vector3).x)
	assert_near(max_x - min_x, 12.0, 0.5, "the circle's diameter is twice min_turn_radius_m")
	assert_true(min_x > -0.3, "turning right circles to the right of the start")


func test_turn_is_the_hulls_yaw_in_either_gear() -> void:
	# A driver steers the wheels the other way in reverse; TankCommand.turn names the yaw the hull should make, so
	# brains that swing a reversing hull's back like its front (Steering.reverse_toward) still work on wheels.
	var poses := TankMotion.predict(_car(-4.0), -4.0 / 7.0, 1.0, SimClock.TICK_RATE / 2)
	var yawed := _yaw_deg(poses[-1]["forward"])
	assert_near(yawed, rad_to_deg(4.0 / 6.0) * 0.5, 1.5, "turn right while reversing at 4 m/s on a 6 m circle: 19° right (%.1f°)" % yawed)
	var creeping_back := TankMotion.predict(_car(-4.0), 0.0, 1.0, SimClock.TICK_RATE / 3)
	assert_true(float(creeping_back[-1]["speed"]) < 0.0, "a turn with no throttle while reversing keeps backing around the circle")


func test_a_turn_command_at_a_standstill_is_a_multi_point_turn() -> void:
	# Tank-style steering (turn in place, throttle 0) becomes forward and reverse legs on wheels, so a car rotates near
	# its spot (brains facing a target, an arrived group facing its heading) instead of stalling or driving off.
	var poses := TankMotion.predict(_car(), 0.0, 1.0, SimClock.TICK_RATE * 8)
	var yawed := 0.0
	var farthest := 0.0
	var previous := Vector3.FORWARD
	var went_back := false
	for pose: Dictionary in poses:
		yawed += -rad_to_deg(previous.signed_angle_to(pose["forward"], Vector3.UP))
		previous = pose["forward"]
		farthest = maxf(farthest, (pose["position"] as Vector3).length())
		went_back = went_back or float(pose["speed"]) < -0.5
	assert_true(float(poses[0]["speed"]) > 0.0, "the first leg rolls forward")
	assert_true(went_back, "then it backs up")
	assert_true(yawed > 150.0, "turning right the whole time: %.0f° in 8 s" % yawed)
	assert_true(farthest < 4.0, "without wandering off its spot (%.1f m at most)" % farthest)


func test_low_grip_drifts_and_high_grip_carves() -> void:
	var slide := func(grip: float) -> float:
		var poses := TankMotion.predict(_car(14.0, grip), 1.0, 1.0, SimClock.TICK_RATE / 2)
		var last: Dictionary = poses[-1]
		var velocity: Vector3 = last["velocity"]
		var forward: Vector3 = last["forward"]
		return absf(velocity.dot(Vector3(-forward.z, 0.0, forward.x)))
	var loose: float = slide.call(0.3)
	var planted: float = slide.call(1.0)
	assert_true(loose > 1.0, "a loose rally truck slides sideways through a hard turn (%.1f m/s)" % loose)
	assert_true(planted < 0.2 * loose, "full grip carves (%.2f m/s)" % planted)


func test_momentum_coasts_and_brakes() -> void:
	var car := _car(14.0)
	var coast := TankMotion.predict(car, 0.0, 0.0, SimClock.TICK_RATE)
	var stop_ticks := 0
	for pose: Dictionary in coast:
		if float(pose["speed"]) > 0.0:
			stop_ticks += 1
	assert_near(float(stop_ticks), 14.0 / 20.0 * float(SimClock.TICK_RATE), 2.0, "off the throttle it sheds braking_mps2")
	var reverse := TankMotion.predict(_car(14.0), -1.0, 0.0, SimClock.TICK_RATE)
	assert_true(float(reverse[-1]["speed"]) < 0.0, "full reverse brakes through zero, then backs up")


func test_predict_matches_a_real_scout_carving_a_turn() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var scout := game_match.spawn_tank("Driver", 0, Match.Team.GREEN, "scout")
	scout.global_position = Vector3(LANE_X, 0.0, 60.0)
	await wait_physics_frames(3)
	for tick in SimClock.TICK_RATE:  # get up to speed first
		scout.command = TankCommand.new(1.0, 0.0, Vector3.ZERO, false)
		await tree.physics_frame
	var start := TankMotion.state_of(scout)
	var poses := TankMotion.predict(start, 1.0, 0.8, SimClock.TICK_RATE)
	for tick in SimClock.TICK_RATE:
		scout.command = TankCommand.new(1.0, 0.8, Vector3.ZERO, false)
		await tree.physics_frame
	var predicted: Dictionary = poses[-1]
	var actual := scout.global_position
	assert_near(Vector2(actual.x, actual.z).distance_to(Vector2(predicted["position"].x, predicted["position"].z)), 0.0, 0.5,
			"a second of carving lands where predict said (%s vs %s)" % [actual, predicted["position"]])
	var heading_error := rad_to_deg(absf((-scout.global_basis.z).signed_angle_to(predicted["forward"], Vector3.UP)))
	assert_true(heading_error < 2.0, "facing the same way (%.2f° off)" % heading_error)
