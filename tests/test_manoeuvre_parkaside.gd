extends TestCase
## Round 43 (Bar S v2, `--traffic-on=parkaside`, Traffic.DEFAULT_OFF until judged): a seat under a PARKED friend of another squad
## is taken beside it. Bar S's read: with the seat bound a second squad clicked 17 m from the first is dealt seats on the first's
## parked hulls and the two squads ask each other to give way (Locks +6.9 s a run). Open ground (yard_open); forward is -Z.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("parkaside", Traffic.DEFAULT_OFF.has("parkaside"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A War Rig parked 20 m ahead of me (no order: arrived, still; its 7 m radius keeps a Gun Truck from "arriving" at its centre);
## me, a Gun Truck, ordered to a point half a metre from its centre. ON runs the GDScript drive (Traffic._chain_native).
func _stage() -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3.ZERO, 0.0, "gang_ifv")
	var parked := _lab.gun(Match.Team.GREEN, "Green_Parked", Vector3(0.0, 0.0, -20.0), 0.0, "gang_tank")
	await _lab.start()
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 0.5, "z": -20.5}, {"type": "fire_at_will"})
	return [me, parked]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("parkaside"), "Bar S v2's rule is opt-in until judged")


func test_a_seat_under_a_parked_friend_is_taken_beside_it() -> void:
	var out := {}
	for arm in ["off", "on"]:
		Traffic.set_off("parkaside", arm == "off")
		var staged := await _stage()
		var me := staged[0] as Tank
		var parked := staged[1] as Tank
		var mover := Movement.of(me)
		var parked_mover := Movement.of(parked)
		Movement.reset_route_arms()
		var stuck_ticks := 0
		var parked_yield_ticks := 0
		var arrived_tick := -1
		for i in 12 * SimClock.TICK_RATE:
			await _lab.step()
			if mover.phase == "yielding" or mover.phase == "blocked":
				stuck_ticks += 1
			if parked_mover != null and parked_mover.phase == "yielding":
				parked_yield_ticks += 1
			if mover.phase == "arrived" and arrived_tick < 0 and i > 10:
				arrived_tick = i
				break
		var gap := Vector2(me.global_position.x - parked.global_position.x, me.global_position.z - parked.global_position.z).length()
		var goal: Vector3 = mover._goal if mover._goal != Vector3.INF else Vector3.INF
		out[arm] = {"arrived": arrived_tick, "gap": gap, "stuck": stuck_ticks, "parked_yield": parked_yield_ticks,
				"moved": int(Movement.route_arms().get("parkaside_moved", 0)),
				"goal_off": Vector2(goal.x - parked.global_position.x, goal.z - parked.global_position.z).length() if goal != Vector3.INF else -1.0,
				"parked_moved": Vector2(parked.global_position.x, parked.global_position.z + 20.0).length()}
		_lab.dispose()
		_lab = null
	var off: Dictionary = out["off"]
	var on: Dictionary = out["on"]
	assert_eq(int(off["moved"]), 0, "OFF: no seat is moved")
	assert_true(int(on["moved"]) >= 1, "ON: the seat under the parked friend is moved beside it (counter %d)" % on["moved"])
	assert_true(float(on["goal_off"]) >= Avoidance.radius_of("gang_ifv") + Avoidance.radius_of("gang_tank") + Movement.PARKASIDE_CLEAR_M - 0.1,
			"ON: the goal taken is outside the friend's clearance disc (%.1f m from it)" % on["goal_off"])
	assert_true(int(on["arrived"]) > 0, "ON: I arrive beside it (tick %d)" % on["arrived"])
	assert_true(float(on["gap"]) >= Avoidance.radius_of("gang_ifv") + Avoidance.radius_of("gang_tank") - 0.5, "ON: ...standing clear of it (%.1f m)" % on["gap"])
	assert_true(int(on["stuck"]) <= 15, "ON: no yielding / blocked ticks to speak of (%d)" % on["stuck"])
	assert_true(float(on["parked_moved"]) < 1.0, "ON: the parked friend never moved (%.1f m)" % on["parked_moved"])
	assert_true(int(off["stuck"]) > int(on["stuck"]) or int(off["parked_yield"]) > 0 or float(off["parked_moved"]) >= 1.0,
			"OFF: today the two negotiate: me stuck %d ticks, the friend yielding %d ticks, moved %.1f m" % [off["stuck"], off["parked_yield"], off["parked_moved"]])


func test_a_squadmate_and_a_moving_friend_are_not_moved_for() -> void:
	Traffic.set_off("parkaside", false)
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3.ZERO, 0.0, "gang_ifv")
	var moving := _lab.gun(Match.Team.GREEN, "Green_Moving", Vector3(0.0, 0.0, -20.0), 0.0, "gang_ifv")
	await _lab.start()
	Movement.of(moving).ctl.set_orders({"type": "move_to", "x": 0.0, "z": -60.0}, {"type": "fire_at_will"})
	for i in 20:
		await _lab.step()
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 0.5, "z": -20.5}, {"type": "fire_at_will"})
	Movement.reset_route_arms()
	for i in 10:
		await _lab.step()
	assert_eq(int(Movement.route_arms().get("parkaside_moved", 0)), 0, "a friend under way is not parked: the seat stands")
