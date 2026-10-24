extends TestCase
## Round 39 (settle, for orders' G3 v6): ElementPlan.deploy_preview, the deploy read at the click. Pure: the same answer
## twice, no counter moves; its seats are the deal its worst leg reports; with the fit off a herringbone on open ground
## reads as the halt pick does. On a bare arena (no lab): the terrain reads open.

static func _members() -> Array:
	var out: Array = []
	var at := [[0, 0], [8, 2], [-8, 3], [3, 12], [-4, -10]]
	for i in at.size():
		out.append({"name": "Green_Alpha_%d" % (i + 1), "unit": "tank", "position": Vector3(at[i][0], 0, at[i][1])})
	return out


func test_pure_and_repeatable() -> void:
	var table := DoctrineTable.for_faction("law")
	var turned := ElementPlan.deploy_fit_turned
	var cleared := ElementPlan.route_seats_cleared
	var a := ElementPlan.deploy_preview(_members(), Vector3(2, 0, 1), Vector3(0, 0, -1), table)
	var b := ElementPlan.deploy_preview(_members(), Vector3(2, 0, 1), Vector3(0, 0, -1), table)
	print("MEASURE preview: %s worst %.1f m total %.1f m spacing %.1f" % [a["shape"], a["worst_m"], a["total_m"], a["spacing"]])
	assert_eq(a, b, "the same answer twice")
	assert_eq(ElementPlan.deploy_fit_turned, turned, "no counter moved")
	assert_eq(ElementPlan.route_seats_cleared, cleared, "no counter moved")
	assert_eq((a["seats"] as Dictionary).size(), 5, "a seat each")


func test_worst_is_the_longest_leg_of_its_seats() -> void:
	var members := _members()
	var p := ElementPlan.deploy_preview(members, Vector3(2, 0, 1), Vector3(0, 0, -1), DoctrineTable.for_faction("law"))
	var worst := 0.0
	for member: Dictionary in members:
		var seat: Vector3 = p["seats"][member["name"]]
		worst = maxf(worst, Vector2(seat.x - member["position"].x, seat.z - member["position"].z).length())
	assert_true(absf(worst - float(p["worst_m"])) < 0.01, "worst %.2f v legs %.2f" % [p["worst_m"], worst])


func test_a_grounding_callable_is_used() -> void:
	var calls := [0]
	var ground := func(point: Vector3, _unit: String, _anchor: Variant) -> Vector3:
		calls[0] += 1
		return point
	ElementPlan.deploy_preview(_members(), Vector3(2, 0, 1), Vector3(0, 0, -1), DoctrineTable.for_faction("law"), ground)
	assert_true(calls[0] > 0, "grounded")


func test_nobody_no_preview() -> void:
	assert_true(ElementPlan.deploy_preview([], Vector3.ZERO, Vector3.FORWARD, DoctrineTable.for_faction("law")).is_empty(), "{}")
