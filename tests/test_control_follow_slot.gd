extends TestCase
## Round 7 (K1, for squad's formation flow): `follow` may carry `"slot": [right, back]` in the target's frame, so an
## element can say "follow the leader, at my place in the formation" and each follower gets a live SLIDING goal (nav's
## PID engages on a sliding goal; a jump over 3 m resets it, which is what re-ordering every member did).

const Fixture := preload("res://tests/support/control_fixture.gd")


func test_a_follower_keeps_its_slot_in_the_leaders_frame_as_the_leader_turns() -> void:
	var f := Fixture.new(self)
	await f.build(false)
	var leader := f.place("Green_Alpha_1", Vector3(0, 0, 40))
	leader.rotation.y = 0.0  # facing north (-Z)
	leader.reset_physics_interpolation()
	var command := UnitCommand.make(["Green_Alpha_2"], "follow", {"target": "Green_Alpha_1", "slot": [8.0, 6.0]})
	assert_eq(UnitCommand.validate(command), "", "follow takes a slot")
	assert_eq(f.orders.issue(command, Match.Team.GREEN), "", "and Orders accepts it")
	var goal: Vector3 = Orders.goal_of(f.orders.current("Green_Alpha_2"), f.game_match)
	assert_true(goal.distance_to(Vector3(8, 0, 46)) < 0.01, "8 m right and 6 m back of a north-facing leader (%s)" % goal)
	# The leader turns hard (90° in a second, in 30 ticks): the goal swings with it and never jumps.
	var worst := 0.0
	var last := goal
	for tick in 30:
		leader.rotation.y -= deg_to_rad(3.0)
		var now: Vector3 = Orders.goal_of(f.orders.current("Green_Alpha_2"), f.game_match)
		worst = maxf(worst, now.distance_to(last))
		last = now
	print("MEASURE control_follow_slot worst goal step per tick %.2f m (leader turning 90°/s, slot 10 m out)" % worst)
	assert_true(worst < 1.0, "the goal slides (worst step %.2f m per tick, nav resets its PID over 3 m)" % worst)
	assert_true(last.distance_to(Vector3(-6, 0, 48)) < 0.05, "and ends 8 m right / 6 m back of an east-facing leader (%s)" % last)


func test_a_slot_is_one_units_place_and_only_for_follow() -> void:
	assert_true(UnitCommand.validate(UnitCommand.make(["A", "B"], "follow", {"target": "C", "slot": [1.0, 2.0]})) != "",
			"a slot is one unit's place, not a group's")
	assert_true(UnitCommand.validate(UnitCommand.make(["A"], "move", {"to": [0.0, 0.0], "slot": [1.0, 2.0]})) != "",
			"only follow takes a slot")
	assert_true(UnitCommand.validate(UnitCommand.make(["A"], "follow", {"target": "C", "slot": [1.0]})) != "",
			"a slot is [right, back]")
