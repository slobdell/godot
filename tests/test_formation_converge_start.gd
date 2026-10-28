extends TestCase
## Round 43 (manoeuvre S3, R43.14; `--converge-on-crew=on`, OFF until Bar S): a converging station starts ON the crew. Today's
## `converge` rebuilds a crew's start from the route pose at its along-offset; behind the anchor's start that pose is extrapolated
## back along the route's FIRST leg, and where that leg bends away from the start pose's tangent the rebuilt point lands a hull's
## length off the crew (terminus / crossing 7001: 7.5 m right-behind a War Rig, 110 degrees off its nose, inside its turning
## circle, so it k-turned for it). Pure: ElementPlan.transit_starts / converge on a bent route.

var _was := false


func before_each() -> void:
	_was = ElementPlan.CONVERGE_ON_CREW


func after_each() -> void:
	ElementPlan.CONVERGE_ON_CREW = _was


## A route whose first leg runs south-east for 12 m and then bends south-west; the anchor starts 14 m along it (past the
## corner); the crews stand abreast at z = 0, BEHIND the anchor's start.
static func bent_route() -> Array:
	return [Vector3(0.0, 0.0, 0.0), Vector3(8.5, 0.0, -8.5), Vector3(-30.0, 0.0, -60.0)]


static func crews() -> Array:
	var members: Array = []
	for i in 5:
		members.append({"name": "Green_Guns_%d" % (i + 1), "unit": "gang_tank", "position": Vector3(-13.0 + i * 6.5, 0.0, 2.0)})
	return members


static func stations_for(members: Array, route: Array, start_s: float) -> Dictionary:
	# The shape's stations far along the route (what the crews converge on); any points will do for the start test.
	var out := {}
	for i in members.size():
		out[String(members[i]["name"])] = Vector3(-30.0 + i * 6.0, 0.0, -50.0)
	return out


func test_off_the_rebuilt_start_misses_the_crew_past_a_bend() -> void:
	ElementPlan.CONVERGE_ON_CREW = false
	var members := crews()
	var route := bent_route()
	var starts := ElementPlan.transit_starts(members, route, 14.0, 20.0)
	var transit := {"route": route, "s": 14.0, "start_s": 14.0, "starts": starts["starts"], "converge_m": starts["converge_m"], "worlds": starts["worlds"]}
	var at_start := ElementPlan.converge(stations_for(members, route, 14.0), transit)
	var worst := 0.0
	for member: Dictionary in members:
		worst = maxf(worst, (at_start[String(member["name"])] as Vector3).distance_to(member["position"]))
	assert_true(worst > 3.0, "OFF: behind a bent first leg the rebuilt start is metres off the crew (worst %.1f m)" % worst)


func test_on_every_station_starts_on_its_crew_and_still_converges() -> void:
	ElementPlan.CONVERGE_ON_CREW = true
	var members := crews()
	var route := bent_route()
	var starts := ElementPlan.transit_starts(members, route, 14.0, 20.0)
	assert_true(starts.has("worlds") and (starts["worlds"] as Dictionary).size() == 5, "the starts carry each crew's world point")
	var stations := stations_for(members, route, 14.0)
	var transit := {"route": route, "s": 14.0, "start_s": 14.0, "starts": starts["starts"], "converge_m": starts["converge_m"], "worlds": starts["worlds"]}
	var at_start := ElementPlan.converge(stations, transit)
	for member: Dictionary in members:
		assert_near((at_start[String(member["name"])] as Vector3).distance_to(member["position"]), 0.0, 0.01,
				"ON: %s's station starts ON the crew" % member["name"])
	# Part way, the station has moved toward the click (along the route) and toward its seat; at the end it is the seat.
	transit["s"] = 14.0 + 10.0
	var later := ElementPlan.converge(stations, transit)
	for member: Dictionary in members:
		var name := String(member["name"])
		var moved: Vector3 = (later[name] as Vector3) - (at_start[name] as Vector3)
		assert_true(moved.z < -3.0, "%s's station has moved on along the route (dz %.1f)" % [name, moved.z])
	transit["s"] = 14.0 + float(starts["converge_m"]) + 1.0
	var done := ElementPlan.converge(stations, transit)
	for member: Dictionary in members:
		var name := String(member["name"])
		assert_near((done[name] as Vector3).distance_to(stations[name]), 0.0, 0.01, "%s converged on its seat" % name)


func test_on_a_straight_route_both_agree() -> void:
	var members := crews()
	var route: Array = [Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, -80.0)]
	var starts := ElementPlan.transit_starts(members, route, 10.0, 20.0)
	var stations := stations_for(members, route, 10.0)
	var transit := {"route": route, "s": 16.0, "start_s": 10.0, "starts": starts["starts"], "converge_m": starts["converge_m"], "worlds": starts["worlds"]}
	ElementPlan.CONVERGE_ON_CREW = false
	var off := ElementPlan.converge(stations, transit)
	ElementPlan.CONVERGE_ON_CREW = true
	var on := ElementPlan.converge(stations, transit)
	for member: Dictionary in members:
		var name := String(member["name"])
		assert_near((off[name] as Vector3).distance_to(on[name]), 0.0, 0.01, "a straight route: the frame and the carried point agree for %s" % name)
