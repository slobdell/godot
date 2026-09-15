extends TestCase
## Round-3 X2: CombatMotion picks where a fighting unit drives next (circle-strafe, angle the front armor, attack runs).
## Pure: hand-built requests, no scene. Me at the origin facing north (−Z) unless a test says otherwise.


func _request(style: String, target_at: Vector3, overrides := {}) -> Dictionary:
	var request := {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 9.0, "reverse_speed": 4.0, "style": style,
			"target": {"position": target_at, "forward": Vector3.BACK}, "band": [20.0, 45.0], "side": 1, "phase": "run",
			"map": null, "friends": [], "limit": 116.0}
	request.merge(overrides, true)
	return request


func _direction(result: Dictionary) -> Vector3:
	return Vector3((result["point"] as Vector3).x, 0.0, (result["point"] as Vector3).z).normalized()


func test_in_its_band_a_turret_unit_circles_instead_of_parking() -> void:
	var result := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30)))
	assert_true(not result.is_empty(), "a direction is chosen")
	var along := _direction(result).dot(Vector3.FORWARD)
	assert_true(absf(along) < 0.45, "it moves across the line to the target, not at or away from it (cos %.2f)" % along)


func test_the_side_decides_which_way_around() -> void:
	var left := _direction(CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"side": 1})))
	var right := _direction(CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"side": -1})))
	assert_true(left.x * right.x < 0.0, "opposite sides circle opposite ways (%s vs %s)" % [left, right])


func test_a_heavy_hull_keeps_its_front_toward_the_target_while_moving() -> void:
	var result := CombatMotion.choose(_request("angle", Vector3(0, 0, -30)))
	var direction := _direction(result)
	var hull := -direction if result["reverse"] else direction
	assert_true(hull.dot(Vector3.FORWARD) >= 0.5, "the front stays within 60° of the target (hull %s)" % hull)
	assert_true(absf(direction.dot(Vector3.FORWARD)) < 0.95, "and it still moves sideways, not straight in or out")


func test_out_of_its_band_it_closes_in_or_backs_off() -> void:
	var far := _direction(CombatMotion.choose(_request("strafe", Vector3(0, 0, -80))))
	assert_true(far.dot(Vector3.FORWARD) > 0.3, "80 m out with a 45 m band: it closes (%s)" % far)
	var close := _direction(CombatMotion.choose(_request("strafe", Vector3(0, 0, -8))))
	assert_true(close.dot(Vector3.FORWARD) < -0.3, "8 m away with a 20 m minimum: it opens the range (%s)" % close)


func test_it_works_toward_the_targets_side_and_rear() -> void:
	# The target faces west; I'm south of it. Circling either way is equal except that east leads behind it.
	var result := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"target": {"position": Vector3(0, 0, -30),
			"forward": Vector3.LEFT}, "side": 1}))
	var east := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"target": {"position": Vector3(0, 0, -30),
			"forward": Vector3.LEFT}, "side": -1}))
	assert_true(_direction(result).x > 0.0 or _direction(east).x > 0.0, "at least one side heads for its rear")
	assert_true(float(east["score"]) != float(result["score"]), "the rear side scores differently from the front side")


func test_it_never_drives_into_a_wall() -> void:
	# A wall right where it would circle without one.
	var free := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30)))
	var wanted: Vector3 = free["point"]
	var map := CoverMap.from_features([{"position": Vector2(wanted.x, wanted.z) * 0.6, "size": [4.0, 4.0]}])
	var blocked := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"map": map, "side": 1}))
	assert_true(not blocked.is_empty(), "another direction is found")
	var end: Vector3 = blocked["point"]
	assert_true(not map.path_blocked(Vector2.ZERO, Vector2(end.x, end.z), 1.0), "its path clears the wall (%s)" % end)
	print("MEASURE ai_motion free %s, with a wall %s" % [free["point"], blocked["point"]])


func test_it_keeps_its_distance_from_friends() -> void:
	var first := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30)))
	var crowded := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"friends": [first["point"]]}))
	var end: Vector3 = crowded["point"]
	assert_true(end.distance_to(first["point"]) > 3.0, "a friend where it wanted to go pushes it elsewhere")


func test_a_fixed_gun_runs_at_the_target_then_breaks_away() -> void:
	var run := _direction(CombatMotion.choose(_request("run", Vector3(0, 0, -30), {"phase": "run"})))
	assert_true(run.dot(Vector3.FORWARD) > 0.8, "a run points the hull (and the gun) at the target (%s)" % run)
	var target := Vector3(0, 0, -6)
	var extend := _direction(CombatMotion.choose(_request("run", target, {"phase": "extend"})))
	var end := extend * 9.0 * CombatMotion.HORIZON_SECONDS
	assert_true(end.distance_to(target) > 6.0 and extend.dot(Vector3.FORWARD) < 0.9,
			"breaking away opens the distance (driving past it is fine, straight at it isn't) (%s)" % extend)


func test_wheels_only_pick_turns_they_can_drive() -> void:
	# Target behind: a tracked hull may pivot or reverse, a car with a 12 m turning circle can't swing around in 1 s.
	var result := CombatMotion.choose(_request("run", Vector3(0, 0, 30), {"wheels": true, "min_turn_radius": 12.0,
			"speed": 12.0}))
	assert_true(not result.is_empty(), "a drivable direction exists")
	assert_true(_direction(result).dot(Vector3.FORWARD) > -0.2, "it doesn't pretend to U-turn in place (%s)" % _direction(result))


func test_the_same_request_gives_the_same_answer() -> void:
	var request := _request("angle", Vector3(12, 0, -27), {"friends": [Vector3(5, 0, 3)]})
	assert_eq(CombatMotion.choose(request), CombatMotion.choose(request.duplicate(true)), "deterministic")


func test_it_steers_out_of_the_path_of_an_incoming_shell() -> void:
	var calm := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30)))
	var wanted := _direction(calm)
	# A shell from a second gun 60 m out, aimed where the calm choice leaves me when it arrives in ~0.86 s (the hull spends
	# most of that swinging onto the new heading, so barely a meter along it).
	var aim := wanted * 1.0
	var from := Vector3(0, 0, -60)
	var velocity := (aim - from).normalized() * 70.0
	var shell := {"position": from, "velocity": velocity, "eta_ticks": roundi(from.distance_to(aim) / 70.0 * 60.0)}
	var dodged := CombatMotion.choose(_request("strafe", Vector3(0, 0, -30), {"incoming": [shell], "velocity": Vector3.ZERO}))
	assert_true(bool(dodged["dodging"]), "it knows it's dodging")
	assert_true((dodged["point"] as Vector3).distance_to(calm["point"]) > 3.0, "it picks another way (%s, calm %s)" % [dodged["point"], calm["point"]])
	assert_true(not bool(calm.get("dodging", false)), "no rounds, no dodging")


func test_closest_approach() -> void:
	assert_near(IncomingFire.closest_approach(Vector3.ZERO, Vector3.ZERO, Vector3(10, 0, -50), Vector3(0, 0, 70), 2.0), 10.0, 0.01,
			"a round passing 10 m to the side")
	assert_near(IncomingFire.closest_approach(Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, -70), Vector3(0, 0, 70), 2.0), 0.0, 0.01,
			"driving into its path: it arrives where I'll be in 1 s")
	assert_near(IncomingFire.closest_approach(Vector3.ZERO, Vector3(10, 0, 0), Vector3(10, 0, -70), Vector3(0, 0, 70), 0.5), 35.36, 0.01,
			"...but not within half a second")


func test_boxed_in_by_obstacles_it_still_picks_a_way_out() -> void:
	# Obstacles all around (an x3 scout drove between a crate and its target and froze there for 6 s, firing from a
	# standstill: every candidate end was inside a grown obstacle, so nothing was chosen).
	var features := []
	for x in [-12.0, 0.0, 12.0]:
		for z in [-12.0, 0.0, 12.0]:
			features.append({"position": Vector2(x, z), "size": [6.0, 6.0]})
	var map := CoverMap.from_features(features)
	var result := CombatMotion.choose(_request("run", Vector3(0, 0, -30), {"map": map}))
	assert_true(not result.is_empty(), "it still moves instead of standing in the open")
