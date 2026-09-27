extends TestCase
## Round 12 (nav): a stalled hull asks whoever is ahead of it to give way (round 6's right-of-way, `_negotiate`), and
## "ahead" was a hull within BLOCKER_REACH (8 m) CENTRE TO CENTRE. Two War Rigs (14 m) nose to tail are 14 m apart
## centre to centre, so a rig pressed against a parked friend's tail found no one ahead, labelled itself "blocked by
## terrain" and pushed at full throttle for the rest of the leg (the Terminus drive, rigs seed 5, far ring road, 80 s,
## laptop — the rigs' largest arrival loss once the back-and-fill landed).
##
## The poses are that trace's: the parked rig arrived at (33.7, -30.4) heading 55 deg across the far ring road; the
## mover behind it at (19.9, -28.4) heading 83 deg, sent to (57, -33) beyond it. Control (`--nav-off=blockreach`): the
## mover never asks and never gets past. Fix: it asks, the parked rig gives way, the mover gets through.

const MATCH := preload("res://game/match/match.tscn")
const PARKED_AT := Vector3(33.7, 0.0, -30.4)
const PARKED_HDG := 55.0
const MOVER_AT := Vector3(19.9, 0.0, -28.4)
const MOVER_HDG := 83.0
const GOAL := Vector3(57.0, 0.0, -33.0)


## Heading as the drive test's trace prints it: atan2(nose.x, -nose.z), degrees.
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


func _drive(fix: bool, seconds: float) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = PackedStringArray() if fix else PackedStringArray(["blockreach"])
	var parked := game_match.spawn_tank("Parked", 0, Match.Team.GREEN, "gang_tank")
	var mover := game_match.spawn_tank("Mover", 1, Match.Team.GREEN, "gang_tank")
	_place(parked, PARKED_AT, PARKED_HDG)
	_place(mover, MOVER_AT, MOVER_HDG)
	var parked_orders := _controller(game_match, parked)
	var mover_orders := _controller(game_match, mover)
	await wait_physics_frames(2)
	# The parked rig is where it was sent: an order to its own spot, which it has reached.
	parked_orders.set_orders({"type": "move_to", "x": PARKED_AT.x, "z": PARKED_AT.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE)
	var parked_phase := String(Movement.state(parked).get("phase", ""))
	mover_orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"})
	var yielded := false
	var parked_moved := 0.0
	var blocked_by_terrain := 0
	for frame in int(SimClock.TICK_RATE * seconds):
		await tree.physics_frame
		var parked_mover := Movement.of(parked)
		if parked_mover != null and parked_mover.yield_to != "":
			yielded = true
		parked_moved = maxf(parked_moved, Vector2(parked.global_position.x - PARKED_AT.x, parked.global_position.z - PARKED_AT.z).length())
		var reading := Movement.state(mover)
		if reading.get("phase") == "blocked" and String(reading.get("blocked_by", "")) == "terrain":
			blocked_by_terrain += 1
	Movement._off = saved
	return {"parked_phase_before": parked_phase, "yielded": yielded, "parked_moved_m": parked_moved,
			"blocked_by_terrain_ticks": blocked_by_terrain,
			"goal_m": Vector2(GOAL.x - mover.global_position.x, GOAL.z - mover.global_position.z).length(),
			"mover_at": mover.global_position, "mover_phase": Movement.state(mover).get("phase")}


func test_control_the_mover_never_finds_the_parked_rig_ahead() -> void:
	var control := await _drive(false, 30.0)
	assert_eq(control["parked_phase_before"], "arrived", "precondition: the parked rig is parked (%s)" % control)
	assert_true(not control["yielded"], "control (blockreach off): nobody is asked to give way (%s)" % control)
	assert_true(control["goal_m"] > 25.0, "and the mover is still stuck behind it (%s)" % control)


func test_a_rig_pressed_against_a_parked_rig_asks_it_to_give_way_and_gets_past() -> void:
	var fixed := await _drive(true, 30.0)
	assert_eq(fixed["parked_phase_before"], "arrived", "precondition: the parked rig is parked (%s)" % fixed)
	assert_true(fixed["yielded"], "the parked rig is asked, and gives way (%s)" % fixed)
	assert_true(fixed["goal_m"] < 12.0, "and the mover gets past it to its goal (%s)" % fixed)
