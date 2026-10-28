extends TestCase
## Round 43 (engage A3, R43.8): THE FAR CREW OF A WAITING SQUAD IS NOT SENT TO THE STREET'S MOUTH. His Locks 56416 match
## (round 42's playtest): at tick 478 Traffic's street hold ruled his Guns squad waits for his Hunters, and `_begin_wait`
## dealt a spot behind the mouth to every moving crew of the squad, so the lead War Rig, 80 m from the mouth at (-105, 46),
## was steered at (-29.7, 100.0) for 18 s and drove 90 m north-east away from his attack-move (engage's A1 trace on the
## faithful replay; `--traffic-off=hold` removed the drive). Under `holdfar` a crew farther behind the mouth than the spot
## grid reaches (HOLD_BACK_M's last row + its hull) is released from the hold: it keeps its route (ORCA as always) and
## reaches the street long after the passer is through. The crews AT the street still take turns as round 29's T1 says.
##
## The same ground as tests/test_traffic_hold.gd: the Terminus west street, x -80..-60 between z -20 and 20, open ground
## beyond both mouths. Rows: [name, team, x, z, vx, vz, heading_x, heading_z, radius, moving, group, under way].

const R := 3.0
## The far crew: this far north of the mouth (z 20), well beyond HOLD_BACK_M's 43 m + a hull.
const FAR_Z := 120.0


func _ground(x: float, z: float) -> bool:
	if z <= -20.0 or z >= 20.0:
		return true
	return not ((x > -120.0 and x < -80.0) or (x > -60.0 and x < -20.0))


func _fresh(holdfar: bool) -> void:
	Traffic.ground_override = _ground
	Traffic.destinations = {}
	Traffic.set_off("hold", false)
	Traffic.set_off("holdfar", not holdfar)
	Traffic.reset_counters()


func teardown() -> void:
	Traffic.destinations = {}
	Traffic.ground_override = null
	Traffic.street_override = null
	Traffic.set_off("hold", false)
	Traffic.set_off("holdfar", Traffic.DEFAULT_OFF.has("holdfar"))
	super.teardown()


## Squad A: three crews coming south out of the open toward the north mouth, and A4 the same way FAR_Z - 20 m behind the
## mouth (his War Rig: 76 m from a mouth its own way never reached), standing west of the blocks at `far_x` so that its own
## straight way south misses the held street (x -80..-60) by 50 m. Squad B: three crews in the street coming north. `team`
## puts both squads on that team (the CPU's).
func _rows(holdfar: bool, team := 0, far_x := -120.0) -> void:
	_fresh(holdfar)
	var rows := [
		["A1", team, -70.0, 35.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A2", team, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A3", team, -76.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A4", team, far_x, FAR_Z, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
	]
	for k in 3:
		rows.append(["B%d" % (k + 1), team, -70.0 + (k - 1) * 3.0, 0.0 - k * 9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true])
	Traffic.load_rows(rows, 0, true)


func test_today_the_far_crew_is_dealt_a_spot_at_the_mouth_and_drives_to_it() -> void:
	_rows(false)
	Traffic.hold_of("A1")  # the crew at the street looks first and makes the verdict (A4, 100 m back, sees no meeting itself)
	var hold := Traffic.hold_of("A4")
	assert_eq(Traffic.report()["tr_verdicts"], 1, "one verdict for the squad pair")
	assert_true(not hold.is_empty(), "the control: A4, %d m behind the mouth, is held" % int(FAR_Z - 20.0))
	var spot: Vector2 = hold[0]
	assert_true(spot.y > 20.0 and spot.y <= 20.0 + Traffic.HOLD_BACK_M[Traffic.HOLD_BACK_M.size() - 1] + 1.0,
			"its spot is in the grid behind the MOUTH, %d m from where it stands: %s" % [int(FAR_Z - spot.y), spot])
	assert_eq(Traffic.report()["tr_holds"], 4, "all four crews sent to a spot")
	assert_eq(Traffic.report()["tr_far_released"], 0, "nobody released (the switch is off)")


func test_under_holdfar_the_far_crew_keeps_its_route_and_the_near_crews_still_wait() -> void:
	_rows(true)
	Traffic.hold_of("A1")  # the verdict
	assert_eq(Traffic.report()["tr_verdicts"], 1, "one verdict for the squad pair")
	assert_true(Traffic.hold_of("A4").is_empty(), "A4 is not held: it keeps its route (its way south misses the street by 50 m)")
	assert_true(not Traffic.holding("A4"), "holding() says so")
	for name: String in ["A1", "A2", "A3"]:
		var hold := Traffic.hold_of(name)
		assert_true(not hold.is_empty(), "%s (at the street) still waits" % name)
		assert_true((hold[0] as Vector2).y > 20.0, "at a spot short of the mouth")
	assert_true(Traffic.hold_of("B1").is_empty(), "B comes through")
	assert_eq(Traffic.report()["tr_holds"], 3, "three crews sent to a spot")
	assert_eq(Traffic.report()["tr_far_released"], 1, "one far crew released at the verdict (its way misses the held street)")
	assert_eq(Traffic.report()["tr_far_held"], 0, "none held in place")


func test_a_crew_just_inside_the_grids_reach_is_still_held() -> void:
	_rows(true)
	# Reload with A4 at the grid's edge: 43 m + a hull behind the mouth.
	var rows := [
		["A1", 0, -70.0, 35.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A4", 0, -70.0, 20.0 + Traffic.HOLD_BACK_M[Traffic.HOLD_BACK_M.size() - 1] + 2.0 * R - 1.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true],
	]
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")  # the verdict
	assert_true(not Traffic.hold_of("A4").is_empty(), "within the grid's reach: held as before")
	assert_eq(Traffic.report()["tr_far_released"], 0, "nobody released")


func test_a_far_crew_whose_route_runs_into_the_street_waits_where_it_stands() -> void:
	# A4 50 m behind the mouth (past the grid's 43 m + a hull) and heading straight for the street: its own route reaches the
	# same mouth, so it holds where it is (R43.8's second branch) instead of driving on into the passer.
	_rows(true, 0, -70.0)
	var rows := [
		["A1", 0, -70.0, 35.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A2", 0, -64.0, 44.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["A4", 0, -70.0, 70.0, 0.0, -6.0, 0.0, -1.0, R, true, "e:A"],
		["B1", 0, -70.0, 0.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true],
		["B2", 0, -73.0, -9.0, 0.0, 6.0, 0.0, 1.0, R, true, "e:B", true],
	]
	Traffic.load_rows(rows, 0, true)
	Traffic.hold_of("A1")  # the verdict
	var hold := Traffic.hold_of("A4")
	assert_true(not hold.is_empty(), "A4 is held")
	assert_true((hold[0] as Vector2).distance_to(Vector2(-70.0, 70.0)) < 0.01, "where it stands, not at the mouth: %s" % hold[0])
	assert_true(bool(hold[2]), "and it is there already (it stops)")
	assert_true(Traffic.holding("A4"), "holding() says so, as for any held crew (native reads the same table)")
	assert_eq(Traffic.report()["tr_far_held"], 1, "counted as held in place")
	assert_eq(Traffic.report()["tr_far_released"], 0, "not released")
	assert_true(not Traffic.hold_of("A1").is_empty(), "the crew at the street waits at its spot")
	# ...and from 100 m straight back (the control test's geometry) the same: its way runs into the street.
	_rows(true, 0, -70.0)
	Traffic.hold_of("A1")
	var far := Traffic.hold_of("A4")
	assert_true(not far.is_empty() and (far[0] as Vector2).distance_to(Vector2(-70.0, FAR_Z)) < 0.01, "held where it stands, 100 m back")
	assert_eq(Traffic.report()["tr_far_held"], 1, "counted")


func test_symmetric_for_the_cpus_squads() -> void:
	_rows(true, 1)
	Traffic.hold_of("A1")  # the verdict
	assert_true(Traffic.hold_of("A4").is_empty(), "a team-1 far crew is released the same way")
	assert_true(not Traffic.hold_of("A1").is_empty(), "its squadmate at the street waits")
	assert_eq(Traffic.report()["tr_far_released"], 1, "counted")


func test_the_switch_is_off_by_default_until_bar_a() -> void:
	# Bar A ships it ON by removing the name from DEFAULT_OFF (then `--traffic-off=holdfar` is the escape).
	assert_true(Traffic.DEFAULT_OFF.has("holdfar") or not Traffic.off("holdfar"), "either listed OFF (before the bar) or ON")
