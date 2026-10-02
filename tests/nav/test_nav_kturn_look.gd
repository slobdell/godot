extends TestCase
## Round 15 (nav V2, N5): the planner looks earlier from a moving hull. The rigs' late first legs (builder0, `f70afa98`,
## seeds 1-8): a War Rig already >= 45 deg off its point, the full-lock arc's hit 9 -> 4 m away, ACCELERATING to 8 m/s
## (stop 4.3 m), planned only when the hit crossed 5 m — inside its stopping distance, so it touched braking. With V2 it
## plans when the hit is within 5 m plus its stop, from where it will come to rest.
##
## V2 first reversed at the wider trigger; on the Terminus probe below (a rig from rest, a point behind and to its side)
## it backed up at a 7 m hit the carrot steers wide of, touched and never arrived, where the control turned clean. So
## the wider look EASES OFF instead, and that probe is kept as the no-regression case. The mechanism is pinned directly
## (the throttle cap, its creep floor, the switch); what it does to the rigs is the drive's (Status V2). OPT-IN:
## `--nav-off=kturnlook` turns it on.

const MATCH := preload("res://game/match/match.tscn")


func _drive(off: PackedStringArray, start: Vector3, yaw: float, goal: Vector3) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = start
	tank.rotation.y = yaw
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	var saved := Movement._off
	Movement._off = off
	Movement.reset_route_arms()
	Movement.reverse_log = true
	orders.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"})
	var first_contact := -1
	var first_reverse := -1
	var contacts := 0
	var top_speed := 0.0
	var arrived := -1
	for frame in SimClock.TICK_RATE * 30:
		await tree.physics_frame
		var reading := Movement.state(tank)
		if bool(reading.get("wall_contact", false)):
			contacts += 1
			if first_contact < 0:
				first_contact = frame
		top_speed = maxf(top_speed, tank.speed())
		if first_reverse < 0 and tank.speed() < -0.3:
			first_reverse = frame
		if reading.get("phase") == "arrived":
			arrived = frame
			break
	var arms := Movement.route_arms()
	var legs: Array = Movement.kturn_leg_log.duplicate(true)
	Movement.reverse_log = false
	Movement._off = saved
	var first: Dictionary = legs[0] if not legs.is_empty() else {}
	return {"first_contact": first_contact, "first_reverse": first_reverse, "contacts": contacts, "arrived": arrived,
			"kturns": int(arms["kturns"]), "looked": int(arms["kturn_looked"]), "eased": int(arms["kturn_eased"]), "top_speed": snappedf(top_speed, 0.1),
			"first_leg": {"v0": first.get("v0"), "hit_m": first.get("hit_m"), "stop_m": first.get("stop_m"),
				"roll_margin_m": first.get("roll_margin_m"), "contacts": first.get("contacts")}}



func test_a_turn_the_carrot_makes_is_not_a_reverse() -> void:
	var run := await _drive(PackedStringArray(["kturnlook"]), Vector3(40, 0, 42), 0.0, Vector3(14, 0, 31))
	assert_eq([run["kturns"], run["contacts"]], [0, 0], "the rig turns onto its point without a planned leg or a touch (%s)" % run)
	assert_true(int(run["arrived"]) >= 0, "and arrives (%s)" % run)


## A rig rolling at speed with an easing cap set: the commanded throttle is held to the cap (never under the creep band),
## and not at all with `kturnlook` off.
func _eased_throttle(off: PackedStringArray, hit: float) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var saved := Movement._off
	Movement._off = off
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.global_position = Vector3.ZERO
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	orders.set_orders({"type": "move_to", "x": 0.0, "z": -60.0}, {"type": "hold_fire"})
	await wait_physics_frames(SimClock.TICK_RATE)
	var mover := orders.movement
	var stop := mover._look_stop()
	if stop > 0.0:
		mover._ease_for(hit)
	var cmd := orders.compute_command(1.0 / SimClock.TICK_RATE)
	Movement._off = saved
	return {"stop": stop, "cap": mover._ease_throttle, "throttle": cmd.throttle, "speed": tank.speed()}


func test_easing_caps_the_throttle_above_the_creep_band() -> void:
	var near := await _eased_throttle(PackedStringArray(["kturnlook"]), 3.0)
	assert_true(float(near["stop"]) > 0.5, "the rig is rolling (%s)" % near)
	assert_true(absf(float(near["throttle"]) - (TankMotion.WHEEL_CREEP_THROTTLE + 0.05)) < 0.001,
			"a hit 3 m off: held at the creep floor, not under it (%s)" % near)


func test_easing_is_off_by_default() -> void:
	var run := await _eased_throttle(PackedStringArray(), 3.0)
	assert_eq(float(run["stop"]), 0.0, "opt-in: no look, no cap by default (%s)" % run)
	assert_true(float(run["throttle"]) > 0.9, "full throttle up the open street (%s)" % run)
