extends TestCase
## Round 13 (nav R1): the give-way instrument (`Movement.yield_log`, the drive test's `--yield-log`). Every give-way
## logs the spot it chose, the hull that took it, the room behind its tail and whether the straight run to the spot
## keeps the whole outline clear; WallContact fills in the contacts made while giving way. An instrument nothing
## asserts on is not one (navigation.md, round 9): this checks the record is written for a real give-way, and that its
## contact counts are the SAME contacts WallContact's run totals count under driver `yield` (no double count, no loss).
##
## The poses are round 12's blocker-reach case (`test_nav_blocker_reach.gd`): a War Rig parked across the far ring
## road is asked to give way by a rig pressed against its tail.

const MATCH := preload("res://game/match/match.tscn")
const PARKED_AT := Vector3(33.7, 0.0, -30.4)
const PARKED_HDG := 55.0
const MOVER_AT := Vector3(19.9, 0.0, -28.4)
const MOVER_HDG := 83.0
const GOAL := Vector3(57.0, 0.0, -33.0)


func _place(tank: Tank, at: Vector3, heading_deg: float) -> void:
	var h := deg_to_rad(heading_deg)
	var nose := Vector3(sin(h), 0.0, -cos(h))
	tank.global_position = at
	tank.rotation.y = atan2(-nose.x, -nose.z)
	tank.reset_physics_interpolation()


func _controller(game_match: Match, tank: Tank) -> OrderController:
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	return orders


func _drive(logging: bool) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = PackedStringArray()
	var parked := game_match.spawn_tank("Parked", 0, Match.Team.GREEN, "gang_tank")
	var mover := game_match.spawn_tank("Mover", 1, Match.Team.GREEN, "gang_tank")
	_place(parked, PARKED_AT, PARKED_HDG)
	_place(mover, MOVER_AT, MOVER_HDG)
	var parked_orders := _controller(game_match, parked)
	var mover_orders := _controller(game_match, mover)
	await wait_physics_frames(2)
	parked_orders.set_orders({"type": "move_to", "x": PARKED_AT.x, "z": PARKED_AT.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE)
	WallContact.reset()
	Movement.reset_route_arms()
	Movement.yield_log = logging
	mover_orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE * 20)
	Movement.yield_log = false
	Movement._off = saved
	return {"rows": Movement.yield_log_rows.duplicate(true), "contacts": WallContact.report(),
			"yields": Movement.yields_started, "parked_at": parked.global_position, "mover_at": mover.global_position}


func test_a_rig_giving_way_is_logged_with_its_spot_hull_and_room() -> void:
	var run := await _drive(true)
	var rows: Array = run["rows"]
	assert_true(not rows.is_empty(), "the parked rig's give-way is logged (%s)" % run)
	var row: Dictionary = rows[0]
	assert_eq(row["unit"], "Parked", "the asked rig is the one giving way (%s)" % row)
	assert_eq(row["via"], "asked", "it gave way because it was asked (%s)" % row)
	assert_near(float(row["length_m"]), float(Movement.hull_box("gang_tank")[2]), 0.11, "the hull's own length (%s)" % row)
	assert_true(String(row["spot"]).begins_with("spot(") or String(row["spot"]).begins_with("back("), "the spot is named (%s)" % row)
	assert_true(row.has("room_behind_m") and row.has("sweep"), "room behind and the outline sweep are measured (%s)" % row)
	assert_true(row["gear"] in ["forward", "reverse"], "the gear it drives there in (%s)" % row)


func test_the_logged_contacts_are_wallcontacts_own_yield_contacts() -> void:
	var run := await _drive(true)
	var rows: Array = run["rows"]
	var logged := 0
	var logged_reverse := 0
	for row: Dictionary in rows:
		logged += int(row["contacts"])
		logged_reverse += int(row["reverse_contacts"])
	var by_driver_gear: Dictionary = run["contacts"]["by_driver_gear"]
	var total := 0
	for key: String in by_driver_gear:
		if key.begins_with("yield/"):
			total += int(by_driver_gear[key])
	assert_eq(logged, total, "every yield-driven contact lands in exactly one give-way's record (%s)" % run)
	assert_eq(logged_reverse, int(by_driver_gear.get("yield/reverse", 0)), "and the reverse ones too (%s)" % run)
	assert_eq(int(run["contacts"]["by_driver"].get("yield", 0)), total, "by_driver and by_driver_gear agree (%s)" % run)


func test_nothing_is_logged_unless_asked() -> void:
	var run := await _drive(false)
	assert_true((run["rows"] as Array).is_empty(), "measurement only: off by default (%s)" % run)
	assert_true(int(run["yields"]) > 0, "control: a give-way still happened (%s)" % run)
