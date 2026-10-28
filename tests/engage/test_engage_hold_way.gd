extends TestCase
## Round 43 (engage A6, R43.13 / R43.18): THE STREET HOLD'S VERDICT READS WHERE CREWS ARE GOING, AND BINDS ONLY THE CREWS
## ON THE STREET. His Locks 56416 match, tick 478: his Guns_3, yielding with its nose EAST while ordered south-west, met a
## Hunter coming west through a corridor; Traffic read a head-on meeting, read the Guns squad's way as east (the mean of its
## crews' noses), and dealt a spot behind that corridor's mouth to every Guns crew, two of them 60-76 m away on routes to
## the bridge. Under `holdway` (1) a crew's direction in the table is its ORDERED way (its route's next point; a test's
## row[12..13]), so a yielding crew is not "coming the other way" and a squad's way is where it was sent; (2) at the verdict
## a crew whose own route never runs through the street is released, near or far.
##
## The same ground as tests/test_traffic_hold.gd: the Terminus west street, x -80..-60 between z -20 and 20. Rows: [name, team,
## x, z, vx, vz, heading_x, heading_z, radius, moving, group, under way, ordered_x, ordered_z].

const R := 3.0


func _ground(x: float, z: float) -> bool:
	if z <= -20.0 or z >= 20.0:
		return true
	return not ((x > -120.0 and x < -80.0) or (x > -60.0 and x < -20.0))


func _fresh(holdway: bool) -> void:
	Traffic.ground_override = _ground
	Traffic.destinations = {}
	Traffic.set_off("hold", false)
	Traffic.set_off("holdway", not holdway)
	Traffic.set_off("holdfar", true)
	Traffic.reset_counters()


func teardown() -> void:
	Traffic.destinations = {}
	Traffic.ground_override = null
	Traffic.street_override = null
	Traffic.set_off("hold", false)
	Traffic.set_off("holdway", Traffic.DEFAULT_OFF.has("holdway"))
	Traffic.set_off("holdfar", Traffic.DEFAULT_OFF.has("holdfar"))
	super.teardown()


## Squad B: three crews in the street coming north (ordered north). Squad A, by case:
##   "yielding": A1 at the north mouth with its VELOCITY east (pushed sideways) but ORDERED south through the street,
##               two squadmates behind it ordered south: a real head-on (the control: by velocity A1 reads "going east").
##   "sideways": A1 at the mouth with velocity and nose SOUTH (into the street) but ORDERED EAST along the ring road, its
##               squadmates east of it the same (pushed south for the moment, ordered east): his mis-aimed case (by noses
##               and velocities it is a head-on and the squad's way is south; by orders it is not).
func _rows(holdway: bool, case_name: String, team := 0) -> void:
	_fresh(holdway)
	var rows := []
	match case_name:
		"yielding":
			rows = [
				["A1", team, -70.0, 26.0, 6.0, 0.0, 1.0, 0.0, R, true, "e:A", true, 0.0, -1.0],
				["A2", team, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
				["A3", team, -76.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
			]
		"sideways":
			rows = [
				["A1", team, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 1.0, 0.0],
				["A2", team, -50.0, 34.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 1.0, 0.0],
				["A3", team, -40.0, 30.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 1.0, 0.0],
			]
	for k in 3:
		rows.append(["B%d" % (k + 1), team, -70.0 + (k - 1) * 3.0, 0.0 - k * 9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0])
	Traffic.load_rows(rows, 0, true)


func test_control_a_crew_pushed_sideways_reads_as_coming_the_other_way_by_its_velocity() -> void:
	# OFF: A's velocities read south, B's north: a head-on verdict, the squad's way south, A1 held. The point of the control
	# is only that round 29's table reads velocities and noses, not orders.
	_rows(false, "sideways")
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "the control: by noses and velocities A1 (south) meets B1 (north): a verdict")
	assert_true(not Traffic.hold_of("A1").is_empty(), "and A1 is held")


func test_under_holdway_a_squad_ordered_along_the_ring_road_does_not_wait_for_a_squad_leaving_the_street() -> void:
	# His case: A1's nose points into the street but its order runs east; B comes north out of the street. Not a head-on
	# meeting by anyone's ORDERED way: no verdict, nobody held, nobody sent to a spot.
	_rows(true, "sideways")
	Traffic.hold_of("A1")
	Traffic.hold_of("A2")
	Traffic.hold_of("B1")
	assert_eq(Traffic.report()["tr_verdicts"], 0, "no verdict: A is going east, B north")
	assert_true(Traffic.hold_of("A1").is_empty() and Traffic.hold_of("A2").is_empty(), "nobody held")
	assert_eq(Traffic.report()["tr_holds"], 0, "no spots dealt")


func test_under_holdway_a_crew_yielding_sideways_still_meets_head_on_by_its_order() -> void:
	# A1 pushed east for a moment, ordered south through the street B is coming up: a real head-on. The verdict stands and
	# A1, whose route runs through the street, is held at a spot short of the mouth.
	_rows(true, "yielding")
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict: by its ORDER A1 is coming south")
	var hold := Traffic.hold_of("A1")
	assert_true(not hold.is_empty(), "A1 is held")
	assert_true((hold[0] as Vector2).y > 20.0, "at a spot short of the mouth: %s" % hold[0])
	assert_eq(Traffic.report()["tr_way_released"], 0, "every A crew's route runs through the street: none released")
	assert_true(Traffic.hold_of("B1").is_empty(), "B comes through")


func test_under_holdway_a_near_crew_whose_route_misses_the_street_is_released() -> void:
	# A real head-on for A1-A3 (ordered south), and A4 30 m from the mouth but ordered EAST along the ring road (its route
	# never enters the street): A4 is released at the verdict, its squadmates held.
	_rows(true, "yielding")
	var rows := [
		["A1", 0, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A4", 0, -95.0, 40.0, 6.0, 0.0, 1.0, 0.0, R, true, "e:A", true, 1.0, 0.0],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
	]
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict for A1/A2 v B")
	assert_true(Traffic.hold_of("A4").is_empty(), "A4 (ordered east, its way never enters the street) is released")
	assert_true(not Traffic.holding("A4"), "holding() false for it (the native drive reads the same table)")
	assert_true(not Traffic.hold_of("A1").is_empty() and not Traffic.hold_of("A2").is_empty(), "A1, A2 held")
	assert_eq(Traffic.report()["tr_way_released"], 1, "one released by its way")
	assert_eq(Traffic.report()["tr_holds"], 2, "two spots dealt")


func test_control_the_near_crew_is_dealt_a_spot_with_the_switch_off() -> void:
	_rows(false, "yielding")
	var rows := [
		["A1", 0, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A4", 0, -95.0, 40.0, 6.0, 0.0, 1.0, 0.0, R, true, "e:A", true, 1.0, 0.0],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
	]
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict")
	assert_true(not Traffic.hold_of("A4").is_empty(), "round 29: A4 is dealt a spot like everyone in the squad")
	assert_eq(Traffic.report()["tr_way_released"], 0, "nobody released")


func test_symmetric_for_the_cpus_squads() -> void:
	_rows(true, "sideways", 1)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 0, "a team-1 squad ordered along the ring road is not held either")


func test_the_switch_is_off_by_default_until_bar_a6() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("holdway") or not Traffic.off("holdway"), "either listed OFF (before the bar) or ON")
