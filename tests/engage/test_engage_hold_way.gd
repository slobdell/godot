extends TestCase
## Round 43 (engage A6, R43.13 / R43.18): THE STREET HOLD'S VERDICT READS WHERE CREWS ARE GOING, AND BINDS ONLY THE CREWS
## ON THE STREET. His Locks 56416 match, tick 478: his Guns_3, yielding with its nose EAST while ordered south-west, met a
## Hunter coming west through a corridor; Traffic read a head-on meeting, read the Guns squad's way as east (the mean of its
## crews' noses), and dealt a spot behind that corridor's mouth to every Guns crew, two of them 60-76 m away on routes to
## the bridge. Under `holdway` (1) a crew's direction in the table is its ORDERED way (its route's next point; a test's
## row[12..13]), so a yielding crew is not "coming the other way" and a squad's way is where it was sent; (2) at the verdict
## (v2, R43.20, `holdroute`) a crew whose route to its SQUAD'S DESTINATION never runs through the street is released, near
## or far. Two switches, so Bar A6 v2 judges the way read alone (ARM-W) and both (ARM-WR) against one base.
##
## The same ground as tests/test_traffic_hold.gd: the Terminus west street, x -80..-60 between z -20 and 20. Rows: [name, team,
## x, z, vx, vz, heading_x, heading_z, radius, moving, group, under way, ordered_x, ordered_z].

const R := 3.0


func _ground(x: float, z: float) -> bool:
	if z <= -20.0 or z >= 20.0:
		return true
	return not ((x > -120.0 and x < -80.0) or (x > -60.0 and x < -20.0))


func _fresh(holdway: bool, holdroute := false) -> void:
	Traffic.ground_override = _ground
	# The street by fact, not by the walk's angle: the band between the blocks (a diagonal squad way made `_mouth`'s
	# side probes leave the band before they met a block, and the mouth landed on the street's far edge).
	Traffic.street_override = func(x: float, z: float) -> bool: return x > -80.0 and x < -60.0 and z > -20.0 and z < 20.0
	Traffic.destinations = {}
	Traffic.set_off("hold", false)
	Traffic.set_off("holdway", not holdway)
	Traffic.set_off("holdroute", not holdroute)
	Traffic.set_off("holdfar", true)
	Traffic.reset_counters()


func teardown() -> void:
	Traffic.destinations = {}
	Traffic.ground_override = null
	Traffic.street_override = null
	Traffic.set_off("hold", false)
	Traffic.set_off("holdway", Traffic.DEFAULT_OFF.has("holdway"))
	Traffic.set_off("holdroute", Traffic.DEFAULT_OFF.has("holdroute"))
	Traffic.set_off("holdfar", Traffic.DEFAULT_OFF.has("holdfar"))
	super.teardown()


## Squad B: three crews in the street coming north (ordered north). Squad A, by case:
##   "yielding": A1 at the north mouth with its VELOCITY east (pushed sideways) but ORDERED south through the street,
##               two squadmates behind it ordered south: a real head-on (the control: by velocity A1 reads "going east").
##   "sideways": A1 at the mouth with velocity and nose SOUTH (into the street) but ORDERED EAST along the ring road, its
##               squadmates east of it the same (pushed south for the moment, ordered east): his mis-aimed case (by noses
##               and velocities it is a head-on and the squad's way is south; by orders it is not).
func _rows(holdway: bool, case_name: String, team := 0, holdroute := false) -> void:
	_fresh(holdway, holdroute)
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
	# The squads' destinations (A6 v2's route test reads them): A south beyond the street in the yielding case, east along
	# the ring road in the sideways case; B north beyond the street.
	Traffic.destinations = {"e:A": [Vector2(-70.0, -55.0) if case_name == "yielding" else Vector2(30.0, 40.0), 8.0],
			"e:B": [Vector2(-70.0, 75.0), 8.0]}
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


func test_under_holdroute_a_crew_whose_route_to_the_destination_misses_the_street_is_released() -> void:
	# A real head-on for A1/A2 (ordered south, destination south beyond the street), and A4 east of the blocks at (-20, 40):
	# its route to the squad's destination runs by the MIDDLE street (x -20..20), never within 20 m of this one's mouth
	# (-70, 20): released at the verdict; its squadmates held.
	_rows(true, "yielding", 0, true)
	var rows := [
		["A1", 0, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A4", 0, -20.0, 40.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
	]
	Traffic.destinations = {"e:A": [Vector2(-70.0, -55.0), 8.0], "e:B": [Vector2(-70.0, 75.0), 8.0]}
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict for A1/A2 v B")
	assert_true(Traffic.hold_of("A4").is_empty(), "A4 (its way to the destination runs by another street) is released")
	assert_true(not Traffic.holding("A4"), "holding() false for it (the native drive reads the same table)")
	assert_true(not Traffic.hold_of("A1").is_empty() and not Traffic.hold_of("A2").is_empty(), "A1, A2 held")
	assert_eq(Traffic.report()["tr_way_released"], 1, "one released by its route")
	assert_eq(Traffic.report()["tr_holds"], 2, "two spots dealt")


func test_under_holdroute_a_crew_whose_leg_lies_beside_the_street_but_whose_route_crosses_it_is_held() -> void:
	# Bar A6's first cut let this crew through: A4 at (-85, 40), its current leg laid to a seat east of it (its ordered way
	# east) while its squad's destination lies south through the street. v2 judges the route to the destination: held.
	_rows(true, "yielding", 0, true)
	var rows := [
		["A1", 0, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A4", 0, -85.0, 40.0, 6.0, 0.0, 1.0, 0.0, R, true, "e:A", true, 1.0, 0.0],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
	]
	Traffic.destinations = {"e:A": [Vector2(-70.0, -55.0), 8.0], "e:B": [Vector2(-70.0, 75.0), 8.0]}
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict")
	assert_true(not Traffic.hold_of("A4").is_empty(), "A4 is held: its route to the destination runs through this street")
	assert_eq(Traffic.report()["tr_way_released"], 0, "nobody released")
	assert_eq(Traffic.report()["tr_holds"], 3, "three spots dealt")


func test_the_way_read_alone_releases_nobody() -> void:
	# ARM-W (R43.20): `holdway` without `holdroute`: the verdict still binds every crew of the waiting squad.
	_rows(true, "yielding")
	var rows := [
		["A1", 0, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A4", 0, -20.0, 40.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
	]
	Traffic.destinations = {"e:A": [Vector2(-70.0, -55.0), 8.0], "e:B": [Vector2(-70.0, 75.0), 8.0]}
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict")
	assert_true(not Traffic.hold_of("A4").is_empty(), "A4 is held (no release in this arm)")
	assert_eq(Traffic.report()["tr_way_released"], 0, "nobody released")


func test_control_the_near_crew_is_dealt_a_spot_with_the_switches_off() -> void:
	_rows(false, "yielding")
	var rows := [
		["A1", 0, -70.0, 26.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["A4", 0, -20.0, 40.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A", true, 0.0, -1.0],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true, 0.0, 1.0],
	]
	Traffic.destinations = {"e:A": [Vector2(-70.0, -55.0), 8.0], "e:B": [Vector2(-70.0, 75.0), 8.0]}
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "a verdict")
	assert_true(not Traffic.hold_of("A4").is_empty(), "round 29: A4 is dealt a spot like everyone in the squad")
	assert_eq(Traffic.report()["tr_way_released"], 0, "nobody released")


func test_symmetric_for_the_cpus_squads() -> void:
	_rows(true, "sideways", 1)
	Traffic.hold_of("A1")
	assert_eq(Traffic.report()["tr_verdicts"], 0, "a team-1 squad ordered along the ring road is not held either")


func test_the_switches_are_off_by_default_until_bar_a6() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("holdway") or not Traffic.off("holdway"), "either listed OFF (before the bar) or ON")
	assert_true(Traffic.DEFAULT_OFF.has("holdroute") or not Traffic.off("holdroute"), "either listed OFF (before the bar) or ON")
