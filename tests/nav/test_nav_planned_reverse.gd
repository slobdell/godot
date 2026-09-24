extends TestCase
## Round 11 (nav R1, the lead: *"they'll drive into a wall before trying to back up ... it would be more ideal if the
## units detected that their path would bump into a wall, and therefore they need to go in reverse first; a real-world
## driver would execute a 3 point turn as necessary"*).
##
## One wheeled hull (the IFV: 7.54 m long, 7 m turning radius) parked nose-on to a Terminus block face, 2.5 m off it,
## ordered to a point on the ring road behind and to its side. The ORDER of events is the assertion: with the planned
## reverse, the first reverse comes before any wall contact; without it (`kturn` off, the paired control on the same
## tree), the hull touches the wall first — which is his complaint, reproduced, so the test cannot pass by accident.

const MATCH := preload("res://game/match/match.tscn")
## The (40, 0) block's north face is z = 20; the IFV's centre is its half-length (3.77 m) plus 2.5 m north of it.
const START := Vector3(40.0, 0.0, 26.3)
const GOAL := Vector3(10.0, 0.0, 31.0)


func _drive(kturn: bool) -> Dictionary:
	await ArenaFixture.build(self, "terminus")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var tank := game_match.spawn_tank("Mover", 0, Match.Team.GREEN, "ifv")
	tank.global_position = START
	tank.rotation.y = 0.0  # forward (-Z of the basis) points -z: straight at the block's face
	tank.reset_physics_interpolation()
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	await wait_physics_frames(2)
	var start_forward := -tank.global_basis.z
	var start_at := tank.global_position
	var saved := Movement._off
	Movement._off = PackedStringArray() if kturn else PackedStringArray(["kturn"])
	Movement.reset_route_arms()
	orders.set_orders({"type": "move_to", "x": GOAL.x, "z": GOAL.z}, {"type": "hold_fire"})
	var first_contact := -1
	var first_reverse := -1
	var contacts := 0
	var arrived := -1
	for frame in SimClock.TICK_RATE * 30:
		await tree.physics_frame
		var reading := Movement.state(tank)
		if bool(reading.get("wall_contact", false)):
			contacts += 1
			if first_contact < 0:
				first_contact = frame
		if first_reverse < 0 and tank.speed() < -0.3:
			first_reverse = frame
		if reading.get("phase") == "arrived":
			arrived = frame
			break
	var arms := Movement.route_arms()
	Movement._off = saved
	return {"first_contact": first_contact, "first_reverse": first_reverse, "contacts": contacts, "arrived": arrived,
			"kturns": int(arms["kturns"]), "press": int(arms["press_escapes"]), "unstick": int(arms["unstick_fires"]),
			"at": tank.global_position, "start_at": start_at, "start_forward": start_forward}


func test_control_without_the_planned_reverse_it_touches_the_wall_first() -> void:
	var control := await _drive(false)
	assert_true(control["first_contact"] >= 0 and (control["first_reverse"] < 0 or control["first_contact"] < control["first_reverse"]),
			"control (kturn off): the hull touches the wall before it backs up - his complaint, reproduced (%s)" % control)


func test_nose_to_a_wall_it_reverses_before_touching_it() -> void:
	var planned := await _drive(true)
	assert_true(planned["kturns"] >= 1, "a reverse leg was planned (%s)" % planned)
	assert_true(planned["first_reverse"] >= 0 and (planned["first_contact"] < 0 or planned["first_reverse"] < planned["first_contact"]),
			"with it: the first reverse comes BEFORE any wall contact (%s)" % planned)
	assert_eq(planned["contacts"], 0, "and the turn is made without touching the wall at all (%s)" % planned)
	assert_true(planned["arrived"] >= 0, "and it gets there (%s)" % planned)
	assert_eq(planned["press"] + planned["unstick"], 0, "with no reactive back-off (%s)" % planned)
