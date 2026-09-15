extends TestCase
## FireLanes: which friends a shot would pass through or splash (game/ai/fire_lanes.gd). Pure.


func _friend(friend_name: String, position: Vector3) -> Dictionary:
	return {"name": friend_name, "position": position}


func test_a_friend_on_the_line_blocks_a_direct_shot() -> void:
	var friends := [_friend("Ahead", Vector3(0, 0, -20)), _friend("Beside", Vector3(6, 0, -20)),
			_friend("Behind", Vector3(0, 0, 10)), _friend("Past", Vector3(0, 0, -45))]
	assert_eq(FireLanes.in_line(Vector3.ZERO, Vector3(0, 0, -40), friends), ["Ahead"],
			"only the friend between shooter and target (not beside, behind, or well past it) is in the lane")


func test_a_friend_just_past_the_target_still_counts() -> void:
	var friends := [_friend("RightBehindTarget", Vector3(0, 0, -42))]
	assert_eq(FireLanes.in_line(Vector3.ZERO, Vector3(0, 0, -40), friends), ["RightBehindTarget"],
			"a miss flies on: a friend 2 m past the target is at risk")


func test_spread_widens_the_lane_with_distance() -> void:
	var friends := [_friend("Offset", Vector3(2.5, 0, -60))]
	assert_true(FireLanes.in_line(Vector3.ZERO, Vector3(0, 0, -70), friends, 0.0).is_empty(), "a perfect gun misses a friend 2.5 m off the line")
	assert_eq(FireLanes.in_line(Vector3.ZERO, Vector3(0, 0, -70), friends, 2.0), ["Offset"],
			"a spreading gun at 60 m can hit a friend 2.5 m off the line")


func test_a_friend_near_the_burst_blocks_a_mortar_round() -> void:
	var friends := [_friend("Near", Vector3(6, 0, -100)), _friend("Far", Vector3(25, 0, -100))]
	assert_eq(FireLanes.in_splash(Vector3(0, 0, -100), friends, 8.0, 2.0), ["Near"], "the friend inside splash + scatter is at risk")


func test_a_friend_about_to_cross_counts_for_a_slow_shell() -> void:
	var crossing := {"name": "Crossing", "position": Vector3(-6, 0, -30), "velocity": Vector3(9, 0, 0)}
	assert_true(FireLanes.in_line(Vector3.ZERO, Vector3(0, 0, -40), [crossing], 0.0, 0.0).is_empty(), "a hitscan shot now passes before it arrives")
	assert_eq(FireLanes.in_line(Vector3.ZERO, Vector3(0, 0, -40), [crossing], 0.0, 45.0), ["Crossing"],
			"a shell taking 0.67 s to get there meets the friend driving into the lane")
