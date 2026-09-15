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
	var poses := TankMotion.predict(_state("tank"), 1.0, 0.0, 120)
	var last: Dictionary = poses[-1]
	assert_near(float(last["speed"]), float(unit["max_forward_speed"]), 0.001, "top speed after 2 s")
	var seconds_to_top := float(unit["max_forward_speed"]) / float(unit["acceleration_mps2"])
	assert_near(float(poses[0]["speed"]), float(unit["acceleration_mps2"]) / 60.0, 0.001, "one tick of acceleration")
	var expected_z := 5.0 - (float(unit["max_forward_speed"]) * (2.0 - seconds_to_top / 2.0))
	assert_near((last["position"] as Vector3).z, expected_z, 0.2, "distance covered = accelerate, then cruise")
	assert_near((last["position"] as Vector3).x, 10.0, 0.0001, "no drift sideways")


func test_braking_uses_the_braking_rate() -> void:
	var unit := Units.profile("tank")
	var poses := TankMotion.predict(_state("tank", float(unit["max_forward_speed"])), 0.0, 0.0, 1)
	assert_near(float(poses[0]["speed"]), float(unit["max_forward_speed"]) - float(unit["braking_mps2"]) / 60.0, 0.001,
			"a tick off the throttle sheds braking_mps2 / 60")


func test_tracks_pivot_in_place_and_turn_right_for_positive_turn() -> void:
	var unit := Units.profile("tank")
	var tracked := _state("tank")
	tracked["locomotion"] = "tracks"
	var poses := TankMotion.predict(tracked, 0.0, 1.0, 30)
	var last: Dictionary = poses[-1]
	assert_true((last["position"] as Vector3).is_equal_approx(Vector3(10.0, 0.0, 5.0)), "a pivot stays put")
	var turned := rad_to_deg(Vector3.FORWARD.signed_angle_to(last["forward"], Vector3.UP))
	assert_near(turned, -float(unit["hull_turn_rate_deg"]) * 0.5, 0.5, "half a second at the full rate, clockwise (right)")
	assert_near((last["forward"] as Vector3).length(), 1.0, 0.0001, "forward stays a unit vector")


func test_predict_matches_a_real_tank_on_open_ground() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var tank := game_match.spawn_tank("Driver", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(LANE_X, 0.0, 30.0)
	await wait_physics_frames(3)
	var start := TankMotion.state_of(tank)
	var poses := TankMotion.predict(start, 1.0, 0.5, 60)
	for tick in 60:
		tank.command = TankCommand.new(1.0, 0.5, Vector3.ZERO, false)
		await tree.physics_frame
	var predicted: Dictionary = poses[-1]
	var actual := tank.global_position
	assert_near(Vector2(actual.x, actual.z).distance_to(Vector2(predicted["position"].x, predicted["position"].z)), 0.0, 0.3,
			"one second of driving lands where predict said (%s vs %s)" % [actual, predicted["position"]])
	var heading_error := rad_to_deg(absf((-tank.global_basis.z).signed_angle_to(predicted["forward"], Vector3.UP)))
	assert_true(heading_error < 2.0, "and faces the same way (%.2f° off)" % heading_error)
	assert_near(tank.speed(), float(predicted["speed"]), 0.05, "at the same speed")
