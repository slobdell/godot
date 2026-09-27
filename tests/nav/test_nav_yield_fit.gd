extends TestCase
## Round 13 (nav R2): a yield spot the hull fits. Round 6's give-way checked only a spot's CENTRE against the navmesh;
## a 14 m War Rig asked to give way took `back(6)` — 6 m back from a centre 7 m from its tail — with its tail 0.5 m
## from Block_6 and backed into it for 72 contact ticks (builder0 `5866e387`, rigs seed 7, first leg, `--yield-log`).
##
## The pose is that give-way's: the rig at (-3.5, 72.9) heading 46 deg on the Terminus. A second rig comes at it nose
## first along its line, so the table's spots lie behind or beside it. Control (`--nav-off=yieldfit`): it accepts a
## spot whose run the outline sweep refuses and scrapes the wall getting there. Fix: every spot it accepts passes the
## sweep, and giving way costs (almost) no wall contact.

const MATCH := preload("res://game/match/match.tscn")
const RIG_AT := Vector3(-3.5, 0.0, 72.9)
const RIG_HDG := 46.0
## The asker, this far ahead of the rig along its nose, facing it.
const ASKER_AHEAD_M := 16.0


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


func _ask(fit: bool) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = PackedStringArray() if fit else PackedStringArray(["yieldfit"])
	var rig := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	var asker := game_match.spawn_tank("Asker", 1, Match.Team.GREEN, "gang_tank")
	var h := deg_to_rad(RIG_HDG)
	var nose := Vector3(sin(h), 0.0, -cos(h))
	_place(rig, RIG_AT, RIG_HDG)
	_place(asker, RIG_AT + nose * ASKER_AHEAD_M, RIG_HDG + 180.0)
	var rig_orders := _controller(game_match, rig)
	_controller(game_match, asker)
	await wait_physics_frames(2)
	rig_orders.set_orders({"type": "move_to", "x": RIG_AT.x, "z": RIG_AT.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE)
	WallContact.reset()
	Movement.reset_route_arms()
	Movement.yield_log = true
	var mover := Movement.of(rig)
	var way := Vector2(-nose.x, -nose.z)
	var accepted := mover.ask("Asker", asker.global_position, way)
	var point := mover._yield_point
	var run_ok := accepted and mover._yield_run_ok(rig.get_world_3d().navigation_map, point)
	await wait_physics_frames(SimClock.TICK_RATE * 7)
	Movement.yield_log = false
	Movement._off = saved
	var report := WallContact.report()
	var by_driver_gear: Dictionary = report["by_driver_gear"]
	var yield_contacts := 0
	for key: String in by_driver_gear:
		if key.begins_with("yield/"):
			yield_contacts += int(by_driver_gear[key])
	return {"accepted": accepted, "spot": (Movement.yield_log_rows[0] as Dictionary).get("spot", "") if not Movement.yield_log_rows.is_empty() else "",
			"run_ok": run_ok, "yield_contacts": yield_contacts, "yield_reverse": int(by_driver_gear.get("yield/reverse", 0)),
			"unfit": Movement.yield_spots_unfit, "rig_at": rig.global_position}


func test_control_the_rig_takes_a_spot_it_does_not_fit_and_scrapes() -> void:
	var control := await _ask(false)
	print("YIELD_FIT control %s" % control)
	assert_true(control["accepted"], "control: round 6 finds a spot (%s)" % control)
	assert_true(not control["run_ok"], "control: its run leaves the clear reach (%s)" % control)
	assert_true(int(control["yield_contacts"]) >= 10, "control: and it scrapes the wall giving way (%s)" % control)
	assert_eq(int(control["unfit"]), 0, "control: the arm refuses nothing (%s)" % control)


func test_a_rig_accepts_only_a_spot_it_fits_and_gives_way_without_the_wall() -> void:
	var fixed := await _ask(true)
	print("YIELD_FIT fixed %s" % fixed)
	assert_true(int(fixed["unfit"]) > 0, "the arm refused at least the spot the control took (%s)" % fixed)
	if fixed["accepted"]:
		assert_true(fixed["run_ok"], "an accepted spot's run keeps the whole outline clear (%s)" % fixed)
	# The control scrapes >= 10 ticks (the test above); the fix at most a couple (the plant is not the model).
	assert_true(int(fixed["yield_contacts"]) <= 2, "giving way costs (almost) no wall contact (%s)" % fixed)


## The sweep itself: a spot straight ahead down an open street fits; one behind a tail pressed to a block does not.
func test_the_run_sweep_passes_open_ground_and_refuses_a_wall() -> void:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rig := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	_place(rig, RIG_AT, RIG_HDG)
	var orders := _controller(game_match, rig)
	await wait_physics_frames(2)
	orders.set_orders({"type": "move_to", "x": RIG_AT.x, "z": RIG_AT.z}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE)
	var mover := Movement.of(rig)
	var map := rig.get_world_3d().navigation_map
	var h := deg_to_rad(RIG_HDG)
	var nose := Vector3(sin(h), 0.0, -cos(h))
	assert_true(not mover._yield_run_ok(map, RIG_AT - nose * 6.0), "6 m straight back into Block_6: refused")
	var open := mover._yield_run_ok(map, RIG_AT + nose * 8.0)
	var room := Movement._free_run(map, RIG_AT + nose * 7.0, nose, float(mover._kturn_frame(rig)[2]))
	assert_true(open or room < 9.0, "8 m straight ahead fits when the street is open there (room ahead %.1f m)" % room)
