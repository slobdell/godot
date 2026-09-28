extends TestCase
## Round 14 (nav N1): the instrument for the other 53 % (`Movement.reverse_log`, the drive test's `--reverse-log`).
## Every circle-rule reverse episode and every planned k-turn leg is logged with what it saw and what it then did;
## WallContact splits route reverses by the rule that reversed. An instrument nothing asserts on is not one
## (navigation.md, round 9): this checks the records are written for a real episode and a real leg, and that their
## contact counts are the SAME contacts WallContact's totals count (no double count, no loss).
##
## Circle: an IFV (7 m turning radius) parked with its tail 1 m off the (40, 0) block's north face (z = 20), facing
## away from it, ordered to a point inside its right-hand turning circle: Steering's rule backs it at full lock into the
## face. K-turn: `test_nav_planned_reverse.gd`'s pose (nose-on to the same face, goal behind and to the side).

const MATCH := preload("res://game/match/match.tscn")
const IFV_HALF := 3.77
const CIRCLE_AT := Vector3(40.0, 0.0, 20.0 + IFV_HALF + 1.0)
## Facing +z (away from the block): 3 m ahead and 5 m to the right (-x) is inside the right-hand circle.
const CIRCLE_GOAL := Vector3(35.0, 0.0, 20.0 + IFV_HALF + 1.0 + 3.0)
const KTURN_AT := Vector3(40.0, 0.0, 26.3)
const KTURN_GOAL := Vector3(10.0, 0.0, 31.0)


func _drive(at: Vector3, yaw: float, goal: Vector3, logging: bool, seconds: int) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = PackedStringArray()
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
	Movement.reverse_log = logging
	orders.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE * seconds)
	Movement.reverse_log = false
	Movement._off = saved
	return {"circles": Movement.circle_log.duplicate(true), "legs": Movement.kturn_leg_log.duplicate(true),
			"contacts": WallContact.report(), "arms": Movement.route_arms()}


func test_a_circle_reverse_is_logged_with_its_sweep_and_its_contacts() -> void:
	var run := await _drive(CIRCLE_AT, PI, CIRCLE_GOAL, true, 8)
	var circles: Array = run["circles"]
	assert_true(not circles.is_empty(), "the circle rule's reverse is logged (%s)" % run)
	var row: Dictionary = circles[0]
	assert_true(row.has("ahead_m") and row.has("right_m") and row.has("point_is_goal"), "the point, in hull coordinates (%s)" % row)
	assert_true(row.has("needed_m") and row.has("clear_m") and row.has("fits"), "the sweep is measured (%s)" % row)
	assert_true(not bool(row["fits"]), "with the tail 1 m off a face the committed reverse does not fit (%s)" % row)
	var logged := 0
	for circle: Dictionary in circles:
		logged += int(circle["reverse_contacts"])
	var why: Dictionary = run["contacts"]["by_reverse_why"]
	assert_true(int(why.get("circle", 0)) > 0, "the tail meets the face while the rule backs it (%s)" % run["contacts"])
	assert_eq(logged, int(why.get("circle", 0)), "every circle reverse contact lands in exactly one episode (%s)" % run)
	var total := 0
	for key: String in why:
		total += int(why[key])
	assert_eq(total, int(run["contacts"]["by_driver_gear"].get("route/reverse", 0)),
			"by_reverse_why splits route/reverse exactly (%s)" % run["contacts"])


func test_a_kturn_leg_is_logged_planned_against_driven() -> void:
	var run := await _drive(KTURN_AT, 0.0, KTURN_GOAL, true, 20)
	var legs: Array = run["legs"]
	assert_true(int(run["arms"]["kturns"]) >= 1 and not legs.is_empty(), "a planned leg is logged (%s)" % run)
	var row: Dictionary = legs[0]
	assert_eq(int(row["gear"]), -1, "the first leg of a single back-up is a reverse (%s)" % row)
	assert_true(float(row["planned_m"]) > 0.0 and row.has("pred_end") and row.has("pred_margin_m"), "the plan is recorded (%s)" % row)
	assert_true(String(row.get("end", "")) in ["done", "next", "lead_hit", "timeout", "cancelled", "reset"], "how it ended (%s)" % row)
	assert_true(row.has("driven_m") and row.has("drift_m") and row.has("end_margin_m"), "and the drive against the plan (%s)" % row)
	assert_true(float(row["drift_m"]) < 0.5, "a leg in the open is driven as planned: the plant's yaw law is the planner's (%s)" % row)
	var logged := 0
	for leg: Dictionary in legs:
		logged += int(leg["contacts"])
	var total := 0
	var by_driver_gear: Dictionary = run["contacts"]["by_driver_gear"]
	for key: String in by_driver_gear:
		if key.begins_with("kturn/"):
			total += int(by_driver_gear[key])
	assert_eq(logged, total, "every kturn-driven contact lands in exactly one leg (%s)" % run)


func test_nothing_is_logged_unless_asked() -> void:
	var run := await _drive(CIRCLE_AT, PI, CIRCLE_GOAL, false, 4)
	assert_true((run["circles"] as Array).is_empty() and (run["legs"] as Array).is_empty(), "measurement only (%s)" % run)
	assert_true(int(run["arms"]["circle_reverses"]) > 0, "control: the circle rule still reversed (%s)" % run)
