extends TestCase
## Round 20 (brains M1): a squad forms up ON THE MOVE. Every crew's travelling station starts where the crew stands and
## eases onto its seat in the shape over the anchor's first `converge_m` (ElementPlan.transit_starts / converge), so
## nobody shuffles before the squad sets off and no crew is sent away from the click.


func teardown() -> void:
	ElementPlan.CONVERGE_ENABLED = true
	super.teardown()


const ROUTE: Array = [Vector3(0, 0, 0), Vector3(0, 0, -120)]


## Five crews abreast at the spawn across -Z (x = -28 .. 28, 14 m apart), seated in a wedge at pitch 14 (seat 0 the
## point). The anchor starts `start_s` along the route, as Element._advance_transit lays it.
func _case(start_s: float, positions: Array = []) -> Dictionary:
	if positions.is_empty():
		for i in 5:
			positions.append(Vector3(-28.0 + 14.0 * i, 0.0, 0.0))
	var members: Array = []
	var seats := {}
	# The least-driving seating of an abreast row into a wedge: the middle crew takes the point, the flanks the wings.
	var seat_of := [3, 1, 0, 2, 4]
	for i in positions.size():
		var unit_name := "Green_%d" % (i + 1)
		members.append({"name": unit_name, "position": positions[i]})
		seats[unit_name] = ["wedge", positions.size(), seat_of[i]]
	var plan := {"formation": "wedge", "pitch": Vector2(14, 14), "seats": seats}
	var depth := TacticsFormation.depth("wedge", positions.size(), 14.0)
	var starts := ElementPlan.transit_starts(members, ROUTE, start_s, depth)
	return {"members": members, "plan": plan, "starts": starts, "depth": depth}


func _transit(case: Dictionary, start_s: float, s: float) -> Dictionary:
	var pose := ElementPlan.route_pose(ROUTE, s)
	return {"route": ROUTE, "length": 120.0, "s": s, "start_s": start_s, "anchor": pose["point"],
			"heading": pose["tangent"], "starts": case["starts"]["starts"], "converge_m": case["starts"]["converge_m"]}


func _stations(case: Dictionary, start_s: float, s: float) -> Dictionary:
	var transit := _transit(case, start_s, s)
	return ElementPlan.converge(ElementPlan.stations_along(case["plan"], transit), transit)


func test_at_the_order_every_station_starts_from_its_crew() -> void:
	var start := 0.5 * TacticsFormation.depth("wedge", 5, 14.0)
	var case := _case(start)
	var stations := _stations(case, start, start)
	for member: Dictionary in case["members"]:
		var at: Vector3 = member["position"]
		var station: Vector3 = stations[member["name"]]
		var ahead := at + Vector3(0, 0, -ElementPlan.CONVERGE_LEAD_M)  # the route runs down -Z (the lead is 0 as shipped)
		assert_true(station.distance_to(ahead) < 0.01, "%s's first station starts from it (%s vs %s)" % [member["name"], station, ahead])


func test_every_station_moves_toward_the_click_from_the_first_metre() -> void:
	var start := 0.5 * TacticsFormation.depth("wedge", 5, 14.0)
	# Include a crew standing well AHEAD of the row that is seated at the back of the wedge: the hardest case.
	var case := _case(start, [Vector3(-28, 0, 0), Vector3(-14, 0, 0), Vector3(0, 0, 0), Vector3(14, 0, 0),
			Vector3(28, 0, -22)])
	var span := float(case["starts"]["converge_m"])
	var last := _stations(case, start, start)
	var s := start
	while s < start + span + 2.0:
		s += 0.5
		var now := _stations(case, start, s)
		for unit: String in now:
			# The route runs down -Z: progress toward the click is z decreasing.
			assert_true((now[unit] as Vector3).z <= (last[unit] as Vector3).z + 1e-4,
					"%s's station never runs back along the route (s %.1f: %.3f after %.3f)" % [unit, s, now[unit].z, last[unit].z])
		last = now


func test_after_the_convergence_the_stations_are_round_12s_shape() -> void:
	var start := 0.5 * TacticsFormation.depth("wedge", 5, 14.0)
	var case := _case(start)
	var span := float(case["starts"]["converge_m"])
	assert_true(span >= ElementPlan.CONVERGE_MIN_M, "converges over at least %.0f m (%.1f)" % [ElementPlan.CONVERGE_MIN_M, span])
	var s := start + span + 0.1
	var transit := _transit(case, start, s)
	var shape := ElementPlan.stations_along(case["plan"], transit)
	assert_eq(ElementPlan.converge(shape, transit), shape, "formed: exactly the shape's stations")
	# Half-way it is between the two.
	var mid := _stations(case, start, start + 0.5 * span)
	var formed := ElementPlan.stations_along(case["plan"], _transit(case, start, start + 0.5 * span))
	assert_true((mid["Green_1"] as Vector3).distance_to(formed["Green_1"]) > 0.5, "half-way the flank is not yet in its seat")


func test_the_control_arm_and_a_crew_without_a_start_take_the_shape() -> void:
	var start := 0.5 * TacticsFormation.depth("wedge", 5, 14.0)
	var case := _case(start)
	var transit := _transit(case, start, start + 3.0)
	var shape := ElementPlan.stations_along(case["plan"], transit)
	(transit["starts"] as Dictionary).erase("Green_3")
	var eased := ElementPlan.converge(shape, transit)
	assert_eq(eased["Green_3"], shape["Green_3"], "a crew that joined later goes to the shape")
	assert_true((eased["Green_1"] as Vector3).distance_to(shape["Green_1"]) > 1.0, "the others are eased in")
	ElementPlan.CONVERGE_ENABLED = false
	assert_eq(ElementPlan.converge(shape, transit), shape, "--converge=off: round 12's stations")


func test_the_shape_is_formed_before_the_hand_off_on_a_short_move() -> void:
	var start := 0.5 * TacticsFormation.depth("wedge", 5, 14.0)
	var members := [{"name": "A", "position": Vector3(-10, 0, 0)}, {"name": "B", "position": Vector3(10, 0, 0)}]
	var short_route: Array = [Vector3(0, 0, 0), Vector3(0, 0, -40)]
	var starts := ElementPlan.transit_starts(members, short_route, start, 2.0 * start)
	assert_true(float(starts["converge_m"]) <= 40.0 - ElementPlan.TRANSIT_HANDOFF_M - start + 1e-4,
			"converged by the hand-off (%.1f m)" % float(starts["converge_m"]))
