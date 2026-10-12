extends TestCase
## Round 27 (scout S1 + S2): CombatMotion.plan_lay, the gun-lay planner for fixed guns. Pure: hand-built requests, no
## scene. A scout at the origin facing north (-Z) unless a test says otherwise; its target a tank.


func _request(target_at: Vector3, target_velocity := Vector3.ZERO, overrides := {}) -> Dictionary:
	var request := {"position": Vector3.ZERO, "forward": Vector3.FORWARD, "speed": 14.0, "reverse_speed": 7.0,
			"style": "standoff", "acceleration": 16.0, "braking": 22.0, "turn_rate_deg": 140.0, "wheels": true,
			"min_turn_radius": 5.0, "velocity": Vector3.ZERO, "aim_tolerance_deg": 4.0, "range": 45.0,
			"band": [12.0, 35.0], "hull_length": 3.04, "target_half_width": 1.45, "target_half_length": 4.85,
			"target": {"position": target_at, "forward": Vector3.RIGHT, "velocity": target_velocity},
			"map": null, "friends": [], "limit": 116.0}
	request.merge(overrides, true)
	CombatMotion.gunlay_pin = 1
	return request


func teardown() -> void:
	CombatMotion.gunlay_pin = -1
	super.teardown()


## His case: the tank side-on against the scout's nose drives away east. Backing west-ish swings the nose east and keeps
## the gun on it; driving forward runs into it or turns the tail to it.
func test_his_case_the_target_drives_east_from_the_nose_and_the_scout_reverses() -> void:
	var plan := CombatMotion.plan_lay(_request(Vector3(0, 0, -4), Vector3(8, 0, 0)))
	assert_true(not plan.is_empty(), "it plans")
	assert_true(bool(plan.get("reverse", false)), "it backs up (%s)" % plan)
	assert_true((plan["point"] as Vector3).x < 0.5, "west of where it stands, away from where the tank goes (%s)" % plan["point"])


func test_mirror_the_target_drives_west_and_it_backs_east() -> void:
	var plan := CombatMotion.plan_lay(_request(Vector3(0, 0, -4), Vector3(-8, 0, 0), {"target": {
			"position": Vector3(0, 0, -4), "forward": Vector3.LEFT, "velocity": Vector3(-8, 0, 0)}}))
	assert_true(bool(plan.get("reverse", false)), "it backs up (%s)" % plan)
	assert_true((plan["point"] as Vector3).x > -0.5, "east of where it stands (%s)" % plan["point"])


func test_a_still_target_on_the_nose_in_the_band_is_a_hold() -> void:
	var plan := CombatMotion.plan_lay(_request(Vector3(0, 0, -22)))
	assert_true(bool(plan.get("hold", false)), "gun on it, nothing moving: stop and shoot (%s)" % plan)


func test_a_still_target_off_the_nose_is_not_a_hold_for_wheels() -> void:
	# Wheels cannot turn standing: a hold 90 deg off would never fire (main's "holding at standoff" 127 deg off).
	var plan := CombatMotion.plan_lay(_request(Vector3(22, 0, 0)))
	assert_true(not bool(plan.get("hold", false)), "it drives to lay the gun (%s)" % plan)


func test_it_never_plans_into_the_turning_room() -> void:
	# A tank 16 m dead ahead, still: driving at it would bear at once but end inside 2 turning radii.
	var room := CombatMotion.turning_room(_request(Vector3(0, 0, -16)))
	assert_true(room > 13.0 and room < 15.0, "a scout on a tank: 2 x 5 m + hulls + margin (%.1f m)" % room)
	var plan := CombatMotion.plan_lay(_request(Vector3(0, 0, -16)))
	assert_true(bool(plan.get("hold", false)) or bool(plan.get("reverse", false)),
			"it holds or backs, never closes (%s)" % plan)


func test_out_of_reach_it_leaves_the_approach_to_the_ring() -> void:
	assert_true(CombatMotion.plan_lay(_request(Vector3(0, 0, -60))).is_empty(), "beyond the gun's range: no lay plan")


func test_the_switch_restores_the_ring() -> void:
	var request := _request(Vector3(0, 0, -4), Vector3(8, 0, 0))
	CombatMotion.gunlay_pin = 0
	var result := CombatMotion.choose(request)
	assert_true(not result.has("lay"), "--scout-off=gunlay: round 7's standoff ring (%s)" % result)
