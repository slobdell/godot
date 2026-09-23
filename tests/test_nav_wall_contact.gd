extends TestCase
## Round 10 (nav, item 1): the wall-contact instrument (`game/ai/wall_contact.gd`). *"Units are still driving into
## walls"* had no counter; these tests are its mutation checks. Cut the controller's `movement.observe_contact()` call
## and the first test goes red (no contacts counted for a hull pinned against a wall); cut the classification and the
## cause assertions go red.
##
## The fixture is the foundry's wall at (-36, -20): 18 m along x, 1.5 m deep (`Arena.OBSTACLE_SIZES["wall"]`).

const MATCH := preload("res://game/match/match.tscn")
const WALL_AT := Vector3(-36.0, 0.0, -20.0)


func _hull(game_match: Match, unit_id: String, at: Vector3, yaw: float) -> OrderController:
	var tank := game_match.spawn_tank("Driver", 0, Match.Team.GREEN, unit_id)
	tank.global_position = at
	tank.rotation.y = yaw
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	return ctl


## Item 3's arms are opt-in (`--nav-off=<name>` turns them ON): select exactly `names` for this test.
static func _arms(names: Array) -> PackedStringArray:
	var was := Movement._off
	Movement._off = PackedStringArray(names)
	Movement._off_parsed = true
	return was


func _run(seconds: float) -> void:
	for frame in int(SimClock.TICK_RATE * seconds):
		await tree.physics_frame


## THE MUTATION CHECK: a hull told to drive straight at the wall touches it, the counter says so, and the cause is
## `steer` (the commanded motion points into the wall), published per unit in `Movement.state()`.
func test_a_hull_driven_at_a_wall_is_counted_as_steered_into_it() -> void:
	WallContact.reset()
	await ArenaFixture.build(self, "foundry")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	# Facing -Z (yaw 0), 10 m north of the wall's near face, told to drive forward for 5 s.
	var ctl := _hull(game_match, "tank", WALL_AT + Vector3(0, 0, 11.0), 0.0)
	assert_eq(ctl.set_orders({"type": "drive", "throttle": 1.0, "turn": 0.0, "seconds": 5.0}, {"type": "hold_fire"}), "",
			"told to drive forward")
	await _run(5.0)
	var state := Movement.state(ctl.tank)
	print("MEASURE wall_contact driven: %s observed %d" % [WallContact.report(), WallContact.observed])
	assert_true(WallContact.observed > 0, "the instrument RAN (%d unit-ticks observed)" % WallContact.observed)
	assert_true(int(state.get("wall_contacts", 0)) > 10,
			"a hull pinned against a wall for seconds is counted (%s contact ticks)" % state.get("wall_contacts", 0))
	assert_eq(String(state.get("wall_contact_cause", "")), "steer", "and the cause is the commanded motion")
	assert_eq(String(state.get("wall_contact_driver", "")), "drive", "which a `drive` order produced")
	var by_cause: Dictionary = state.get("wall_contacts_by_cause", {})
	assert_eq(int(by_cause.get("steer", 0)), int(state.get("wall_contacts", 0)),
			"every contact tick of a hull driven straight in is `steer` (%s)" % by_cause)
	assert_eq(WallContact.hull_ticks, 0, "a wall is not a hull contact")


## THE CONTROL: the same hull driving along open ground touches nothing, and the denominator shows it was watched.
func test_a_hull_on_open_ground_touches_nothing() -> void:
	WallContact.reset()
	await ArenaFixture.build(self, "foundry")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	# Facing +X (yaw -90°) from (-100, 40), open ground eastwards for 20 m.
	var ctl := _hull(game_match, "tank", Vector3(-100, 0, 40), -PI / 2.0)
	ctl.set_orders({"type": "drive", "throttle": 1.0, "turn": 0.0, "seconds": 3.0}, {"type": "hold_fire"})
	await _run(3.0)
	assert_true(WallContact.observed > 30, "watched (%d unit-ticks)" % WallContact.observed)
	assert_eq(WallContact.ticks, 0, "no wall contact on open ground (%s)" % WallContact.report())
	assert_true(ctl.tank.global_position.x > -90.0, "and it really drove (x %.1f)" % ctl.tank.global_position.x)


## `bake`: a box placed after the navmesh was baked sits on ground the mesh calls clear. A routed hull whose path runs
## through it touches it, and the instrument names the arena rather than the mover.
func test_an_unbaked_obstacle_on_the_route_is_named_bake() -> void:
	WallContact.reset()
	await ArenaFixture.build(self, "foundry")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8.0, 3.0, 2.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(-100, 1.5, 20)
	add_to_tree(body)
	var ctl := _hull(game_match, "tank", Vector3(-100, 0, 40), 0.0)
	ctl.set_orders({"type": "move_to", "x": -100.0, "z": 0.0}, {"type": "hold_fire"})
	await _run(6.0)
	var by_cause: Dictionary = WallContact.by_cause
	print("MEASURE wall_contact unbaked: %s" % [WallContact.report()])
	assert_true(WallContact.ticks > 0, "the routed hull touched the unbaked box (%s)" % WallContact.report())
	assert_eq(int(by_cause.get("bake", 0)), WallContact.ticks, "and every contact is named `bake` (%s)" % by_cause)
	assert_true(int(WallContact.by_driver.get("route", 0)) > 0, "while the navmesh route drove it (%s)" % WallContact.by_driver)


## The lane lookup reads `Arena.active`'s declared lanes (Terminus): a point on the avenue is on the avenue.
func test_lane_lookup_names_terminus_streets() -> void:
	var was := Arena.active
	Arena.active = Arena.load_layout("terminus")["layout"]
	var avenue := WallContact.lane_at(Vector3(2.0, 0, 60.0))
	var ring := WallContact.lane_at(Vector3(-90.0, 0, 30.0))
	var lot := WallContact.lane_at(Vector3(-35.0, 0, 60.0))
	Arena.active = was
	assert_eq(avenue, "the avenue", "x=2 on the avenue")
	assert_eq(ring, "the ring road", "the ring road's west arm")
	assert_eq(lot, "", "a block's interior is on no lane")


func test_polyline_distance() -> void:
	var path := PackedVector3Array([Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(10, 0, 10)])
	assert_true(absf(WallContact.distance_to_polyline(Vector3(5, 0, 3), path) - 3.0) < 0.001, "3 m off the first leg")
	assert_true(absf(WallContact.distance_to_polyline(Vector3(12, 0, 5), path) - 2.0) < 0.001, "2 m off the second")


## Item 3a's positive control: a hull ordered (`direct`, so no route bends it away) at a point BEHIND the wall presses
## into it and gets nowhere. The pressed-wall escape must fire, and back it off the wall.
func test_a_hull_pressed_on_a_wall_backs_off() -> void:
	var was := _arms(["press"])
	WallContact.reset()
	var fired := Movement.press_escapes
	await ArenaFixture.build(self, "foundry")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var ctl := _hull(game_match, "ifv", WALL_AT + Vector3(0, 0, 6.0), 0.0)
	ctl.set_orders({"type": "move_to", "x": WALL_AT.x, "z": WALL_AT.z - 10.0, "direct": true}, {"type": "hold_fire"})
	var nearest := INF
	var backed := 0.0
	for frame in int(SimClock.TICK_RATE * 6):
		await tree.physics_frame
		var gap := ctl.tank.global_position.z - (WALL_AT.z + 0.75)
		if bool(Movement.state(ctl.tank).get("wall_contact", false)):
			nearest = minf(nearest, gap)
		if nearest < INF:
			backed = maxf(backed, gap - nearest)
	Movement._off = was
	print("MEASURE press_escape: escapes %d, contacts %d, backed off %.2f m after touching" % [
			Movement.press_escapes - fired, WallContact.ticks, backed])
	assert_true(WallContact.ticks > 0, "the hull reached the wall (%d contact ticks)" % WallContact.ticks)
	assert_true(Movement.press_escapes > fired, "the escape fired (%d)" % (Movement.press_escapes - fired))
	assert_true(backed > 1.0, "and the hull backed away from the face after touching it (%.2f m)" % backed)


## Item 3c: a hull sent to a point hard against a wall (inside the bake's erosion band, so the route ends on the mesh
## edge 2.0 m from the face) with a tight arrive radius. The CONTROL (arm off) must press the face for most of the
## order, or the treatment below proves nothing.
func _nose_run(arms: Array) -> Dictionary:
	var was := _arms(arms)
	WallContact.reset()
	var escapes := Movement.press_escapes
	var stops := Movement.nose_stops
	await ArenaFixture.build(self, "foundry")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	# Facing the wall (-Z), 14 m north of it, sent to 0.5 m off its north face, arriving within 0.5 m. A TRACKED hull:
	# a wheeled one settles a share of its turning circle short (`Movement.settle_radius`) and never gets there, which
	# is how the first version of this control read 0 contacts. The tank is 8.62 m long: its nose is 4.3 m ahead of
	# the centre that the route brings to the mesh edge, 2.0 m from the face.
	var ctl := _hull(game_match, "tank", WALL_AT + Vector3(0, 0, 14.0), 0.0)
	ctl.set_orders({"type": "move_to", "x": WALL_AT.x, "z": WALL_AT.z + 1.25, "arrive": 0.5}, {"type": "hold_fire"})
	await _run(8.0)
	var state := Movement.state(ctl.tank)
	Movement._off = was
	var out := {"contacts": WallContact.ticks, "stops": Movement.nose_stops - stops,
			"escapes": Movement.press_escapes - escapes, "phase": state.get("phase"), "by": state.get("blocked_by")}
	print("MEASURE nose_stop %s: %s" % [arms, out])
	return out


func test_nose_stop_control_a_hull_sent_against_a_wall_presses_it() -> void:
	var out := await _nose_run([])
	assert_true(int(out["contacts"]) > 30, "without the arm the nose presses the face (%d contact ticks)" % out["contacts"])
	assert_eq(int(out["stops"]), 0, "and the arm never ran")


func test_a_nose_on_the_wall_at_the_end_of_the_route_stops() -> void:
	var out := await _nose_run(["nosestop"])
	assert_true(int(out["stops"]) > 0, "the nose stop held the hull (%d)" % out["stops"])
	assert_true(int(out["contacts"]) <= 10, "it touched the face briefly, not for the order's length (%d ticks)" % out["contacts"])


## Item 4: the oriented pair radius. Two War Rigs (3.32 x 14) side by side need their half-widths abeam, and their
## half-lengths nose to tail; the disc gave 9.16 m both ways.
func test_the_oriented_radius_is_narrow_abeam_and_long_end_on() -> void:
	var disc := Avoidance.radius_of("gang_tank")
	# Rows: [name, x, z, vx, vz, radius, still, half_width, half_length, heading_x, heading_z]; both face -Z.
	Avoidance.load_rows([["A", 0.0, 0.0, 0.0, 0.0, disc, true, 1.66, 7.0, 0.0, -1.0],
			["B", 5.0, 0.0, 0.0, 0.0, disc, true, 1.66, 7.0, 0.0, -1.0]])
	var abeam := Avoidance.pair_radius(0, 1, Vector2(1, 0))
	var end_on := Avoidance.pair_radius(0, 1, Vector2(0, 1))
	assert_true(absf(abeam - (1.66 * 2 + 2 * Avoidance.RADIUS_MARGIN)) < 0.01, "abeam: two half-widths (%.2f m)" % abeam)
	assert_true(absf(end_on - (7.0 * 2 + 2 * Avoidance.RADIUS_MARGIN)) < 0.01, "end on: two half-lengths (%.2f m)" % end_on)
	assert_true(abeam < disc * 2.0 and end_on > disc * 2.0,
			"narrower than the disc abeam, longer end on (disc pair %.2f m)" % (disc * 2.0))


## Item 6: a goal outside the leash is replaced by the circle's point nearest it; inside, it is untouched.
func test_a_goal_outside_the_leash_is_held_to_its_edge() -> void:
	var inside := Movement.within_leash(Vector3(3, 0, 4), [0.0, 0.0, 10.0])
	var outside := Movement.within_leash(Vector3(30, 0, 40), [0.0, 0.0, 10.0])
	assert_true(inside.is_equal_approx(Vector3(3, 0, 4)), "inside the leash the goal stands (%s)" % inside)
	assert_true(outside.is_equal_approx(Vector3(6, 0, 8)), "outside, the nearest point of the circle (%s)" % outside)
	assert_eq(OrderController._validate({"type": "move_to", "x": 1.0, "z": 2.0, "leash": [0.0, 0.0, 5.0]}, OrderController.MOVE_TYPES), "",
			"a move_to may carry a leash")
	assert_true(OrderController._validate({"type": "move_to", "x": 1.0, "z": 2.0, "leash": [0.0, 0.0]}, OrderController.MOVE_TYPES) != "",
			"and a malformed one is refused")
