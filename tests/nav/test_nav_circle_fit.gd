extends TestCase
## Round 14 (nav N2): the circle rule consults the wall. A wheeled hull whose steering point is inside its turning
## circle used to reverse at full lock whatever was behind it (N1, builder0: all of the War Rigs' `route/reverse` wall
## contacts). Now each reverse the rule is about to drive is swept with the hull's dense outline first; when it does not
## fit, a forward arc on the other lock instead.
##
## The pose is test_nav_reverse_log's: an IFV with its tail 1 m off the (40, 0) block's north face, facing away, its
## point inside the right-hand circle. The control (`circlefit` off, same tree) backs into the face — the case
## reproduced, so the arm cannot pass by accident. And in the open, where the reverse fits, the rule's reverse is kept.
## The gate is OPT-IN (falsified on the Terminus drive, Status N2); this pins what it does when it is on.

const MATCH := preload("res://game/match/match.tscn")
## OPT-IN: the switch turns the gate ON (it measured worse on the drive; Status N2). The default is the rule.
const ARM: Array[String] = ["circlefit"]
const CONTROL: Array[String] = []
const IFV_HALF := 3.77
const WALL_AT := Vector3(40.0, 0.0, 20.0 + IFV_HALF + 1.0)
const WALL_GOAL := Vector3(35.0, 0.0, 20.0 + IFV_HALF + 1.0 + 3.0)


func _drive(at: Vector3, yaw: float, goal: Vector3, off: PackedStringArray, seconds: int) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = off
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, "ifv")
	tank.global_position = at
	tank.rotation.y = yaw
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	WallContact.reset()
	Movement.reset_route_arms()
	orders.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	var arrived := -1
	for frame in SimClock.TICK_RATE * seconds:
		await tree.physics_frame
		if arrived < 0 and Movement.state(tank).get("phase") == "arrived":
			arrived = frame
	var report := WallContact.report()
	Movement._off = saved
	return {"arms": Movement.route_arms(), "why": report["by_reverse_why"], "driver_gear": report["by_driver_gear"],
			"contacts": int(report["contact_unit_ticks"]), "arrived": arrived, "at": tank.global_position}


func test_control_the_rule_backs_its_tail_into_the_face() -> void:
	var run := await _drive(WALL_AT, PI, WALL_GOAL, PackedStringArray(CONTROL), 20)
	assert_true(int(run["why"].get("circle", 0)) > 0, "control: the circle rule's reverse meets the face (%s)" % run)


func test_with_the_sweep_it_does_not_back_into_the_face_and_still_gets_there() -> void:
	var run := await _drive(WALL_AT, PI, WALL_GOAL, PackedStringArray(ARM), 20)
	var arms: Dictionary = run["arms"]
	assert_true(int(arms["circle_forward"]) >= 1, "the reverse did not fit: a forward arc instead (%s)" % run)
	assert_eq(int(run["why"].get("circle", 0)), 0, "no circle-reverse contact (%s)" % run)
	assert_eq(int(run["driver_gear"].get("route/reverse", 0)), 0, "no route reverse contact at all (%s)" % run)
	assert_true(int(run["arrived"]) >= 0, "and it gets there (%s)" % run)


func test_in_the_open_the_rules_reverse_is_kept() -> void:
	# The ring road west of the plaza, clear all round: the same geometry with nothing behind.
	var at := Vector3(-40.0, 0.0, 30.0)
	var run := await _drive(at, PI, at + Vector3(-5.0, 0.0, 3.0), PackedStringArray(ARM), 12)
	var arms: Dictionary = run["arms"]
	assert_true(int(arms["circle_kept"]) >= 1 and int(arms["circle_forward"]) == 0, "the reverse fits: the rule's own reverse (%s)" % run)
	assert_eq(int(run["contacts"]), 0, "without touching anything (%s)" % run)
	assert_true(int(run["arrived"]) >= 0, "and it gets there (%s)" % run)
