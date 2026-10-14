extends TestCase
## Round 29 (traffic T1, his call: TAKE TURNS): the street hold, pure (Traffic.hold_of over a table loaded by hand, on
## ground drawn by hand). His Terminus west street: blocks at x -120..-80 and -60..-20, z -20..20, so the street runs
## x -80..-60 between z = -20 and 20, open ground (the ring roads) beyond both mouths. Forward is -Z and a hull's right
## is +X when it faces -Z (trip-up 2). Rows: [name, team, x, z, vx, vz, heading_x, heading_z, radius, moving, group,
## under way].

const R := 3.0


func _ground(x: float, z: float) -> bool:
	if z <= -20.0 or z >= 20.0:
		return true
	return not ((x > -120.0 and x < -80.0) or (x > -60.0 and x < -20.0))


## (TestCase has no setup hook: every test starts here, through _rows or directly.)
func _fresh() -> void:
	Traffic.ground_override = _ground
	Traffic.destinations = {}
	Traffic.set_off("hold", false)
	Traffic.reset_counters()


func teardown() -> void:
	Traffic.destinations = {}
	Traffic.ground_override = null
	Traffic.street_override = null
	Traffic.set_off("hold", false)
	super.teardown()


## Squad A (three crews) comes south out of the open toward the north mouth; squad B (three crews) is in the street
## coming north. `b_z`: B's lead; `frame`: the table's frame; `b_under_way`: B still driving.
func _rows(b_z: float, frame := 0, forget := true, b_under_way := true) -> void:
	if forget:
		_fresh()
	var rows := [
		["A1", 0, -70.0, 35.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A3", 0, -76.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
	]
	for k in 3:
		rows.append(["B%d" % (k + 1), 0, -70.0 + (k - 1) * 3.0, b_z - k * 9.0, 0.0, 6.0, 0.0, 1.0, R, b_under_way, "e:B",
				b_under_way])
	Traffic.load_rows(rows, frame, forget)


func test_the_squad_still_in_the_open_waits_beside_the_mouth_off_the_line() -> void:
	_rows(0.0)
	var hold := Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "one verdict for the squad pair")
	assert_true(not hold.is_empty(), "A (in the open) waits")
	assert_true(Traffic.hold_of("B1").is_empty(), "B (committed to the street) comes through")
	var spot: Vector2 = hold[0]
	assert_true(spot.y > 20.0, "the spot is short of the mouth (z > 20): %s" % spot)
	assert_true(spot.x >= -70.0 + 12.0, "and right of the street's centre line, off B's way out: %s" % spot)
	assert_true(Traffic.holding("A1"), "holding() says so (C29.3's gates read it)")
	assert_true(not Traffic.holding("B1"), "and not for the passing squad")
	assert_true(not bool(hold[2]), "A1 is not at its spot yet")
	var face: Vector2 = hold[1]
	assert_true(face.y < spot.y, "it faces its own way (south) while it waits")


func test_every_crew_of_the_waiting_squad_gets_its_own_spot_with_room() -> void:
	_rows(0.0)
	var spots: Array[Vector2] = []
	for name: String in ["A1", "A2", "A3"]:
		var hold := Traffic.hold_of(name)
		assert_true(not hold.is_empty(), "%s waits with its squad" % name)
		spots.append(hold[0])
	for a in spots.size():
		assert_true(spots[a].y > 20.0 and _ground(spots[a].x, spots[a].y), "spot %s on open ground short of the mouth" % spots[a])
		for b in range(a + 1, spots.size()):
			assert_true(spots[a].distance_to(spots[b]) >= 2.0 * R + Traffic.SPOT_GAP_M, "spots apart: %s %s" % [spots[a], spots[b]])
	assert_eq(Traffic.report()["tr_holds"], 3, "three crews sent to a spot")


func test_at_its_spot_a_crew_stops_and_keeps_holding() -> void:
	_rows(0.0)
	var spot: Vector2 = Traffic.hold_of("A1")[0]
	var rows := [["A1", 0, spot.x, spot.y + 1.0, 0.0, 0.0, 0.0, -1.0, R, true, "e:A"]]
	for k in 3:
		rows.append(["B%d" % (k + 1), 0, -70.0, 8.0 - k * 9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B"])
	Traffic.load_rows(rows, 30, false)
	var hold := Traffic.hold_of("A1")
	assert_true(not hold.is_empty() and bool(hold[2]), "at its spot: holding, and there")


func test_it_goes_once_the_passing_squads_last_crew_is_behind_it() -> void:
	_rows(0.0)
	assert_true(not Traffic.hold_of("A1").is_empty(), "A1 holds")
	# B's last crew (B3) is at z = 60 - 18 = 42; A1 at 35 going south: B3 is 7 m behind it.
	_rows(60.0, 60, false)
	assert_true(Traffic.hold_of("A1").is_empty(), "every crew of B is behind A1: it goes")
	assert_true(Traffic.report()["tr_released_passed"] >= 1, "released because B passed")
	assert_true(not Traffic.hold_of("A2").is_empty(), "A2 (z = 44) still has B3 (z = 42) beside it: it holds")
	_rows(70.0, 61, false)
	assert_true(Traffic.hold_of("A2").is_empty(), "and goes once B's tail is behind it")
	assert_true(Traffic.hold_of("A3").is_empty(), "and so does A3")
	# Free again later: no new verdict for this pair inside REMEET_S.
	_rows(0.0, 90, false)
	assert_true(Traffic.hold_of("A2").is_empty(), "the pair is not held again at once")


func test_a_passing_crew_that_has_arrived_does_not_keep_it_waiting() -> void:
	_rows(0.0)
	assert_true(not Traffic.hold_of("A1").is_empty(), "A1 holds")
	_rows(0.0, 30, false, false)
	assert_true(Traffic.hold_of("A1").is_empty(), "B is not under way any more: nobody to wait for")


func test_the_cap_sends_it_on_whatever_the_other_squad_does() -> void:
	_rows(0.0)
	assert_true(not Traffic.hold_of("A1").is_empty(), "A1 holds")
	_rows(0.0, ceili(Traffic.HOLD_CAP_S * SimClock.TICK_RATE) - 1, false)
	assert_true(not Traffic.hold_of("A1").is_empty(), "still holding just before the cap")
	_rows(0.0, ceili(Traffic.HOLD_CAP_S * SimClock.TICK_RATE), false)
	assert_true(Traffic.hold_of("A1").is_empty(), "at the cap it goes")
	assert_eq(Traffic.report()["tr_released_cap"], 1, "released by the cap")
	_rows(0.0, ceili(Traffic.HOLD_CAP_S * SimClock.TICK_RATE) + 6, false)
	assert_true(Traffic.hold_of("A1").is_empty(), "and the pair is not held again at once")
	assert_true(not Traffic.holding("A1"), "holding() lapses with it")


func test_holding_lapses_when_the_mover_stops_asking() -> void:
	_rows(0.0)
	Traffic.hold_of("A1")
	assert_true(Traffic.holding("A1"), "holding")
	_rows(0.0, Traffic.LIVE_TICKS + 1, false)
	assert_true(not Traffic.holding("A1"), "a crew no longer driving (it did not ask) is not holding")


func test_open_ground_is_not_a_street_meeting() -> void:
	_rows(0.0)
	Traffic.ground_override = func(_x: float, _z: float) -> bool: return true
	_rows(0.0, 0, false)
	assert_true(Traffic.hold_of("A1").is_empty(), "no walls: ORCA's meeting, nobody holds")
	assert_eq(Traffic.report()["tr_verdicts"], 0, "and no verdict")


func test_squads_going_the_same_way_do_not_hold() -> void:
	_fresh()
	Traffic.load_rows([
		["A1", 0, -70.0, 35.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["B1", 0, -70.0, 0.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:B"],
	])
	assert_true(Traffic.hold_of("A1").is_empty(), "following, not meeting")


func test_off_switch() -> void:
	_rows(0.0)
	Traffic.set_off("hold", true)
	_rows(0.0, 0, false)
	assert_true(Traffic.hold_of("A1").is_empty(), "--traffic-off=hold: nobody holds")
	assert_true(not Traffic.holding("A1"), "and holding() is false")


func test_spots_keep_clear_of_the_passing_squads_way_out() -> void:
	# B is going north-east, right where A's first spots would be, in a formation 10 m across (seed 2's worst run in v2:
	# the waiting squad held on the passing squad's arrival slots).
	_rows(0.0)
	var to := Vector2(-50.0, 40.0)
	Traffic.destinations["e:B"] = [to, 10.0]
	var centre := Vector2(-70.0, 19.0)
	var ab := to - centre
	for name: String in ["A1", "A2", "A3"]:
		var hold := Traffic.hold_of(name)
		assert_true(not hold.is_empty(), "%s still waits" % name)
		var spot: Vector2 = hold[0]
		var t := clampf((spot - centre).dot(ab) / ab.length_squared(), 0.0, 1.0)
		assert_true((centre + ab * t).distance_to(spot) >= 2.0 * R + Traffic.PASSER_CLEAR_M - 0.01,
				"%s's spot %s is off B's run from the mouth to its destination" % [name, spot])
		assert_true(to.distance_to(spot) >= 2.0 * R + 10.0 + Traffic.PASSER_CLEAR_M - 0.01,
				"%s's spot %s is outside B's formation at its destination" % [name, spot])
