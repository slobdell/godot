extends TestCase
## Round 40 (settle; orders' G1 v6 trace, terminus 5 route s8206): the dry read of a deploy's deal (ElementPlan._trace_deals,
## measurement only under --deploy-trace). Pure: four crews bunched at the origin; main's seating sends the crew at the
## east end to the far west seat; the least-total deal on the same lay never drives further in total than main's.


static func _member(n: String, at: Vector3) -> Dictionary:
	return {"name": n, "unit": "tank", "role": "tank", "position": at}


func test_the_least_total_deal_is_no_longer_than_mains() -> void:
	var members: Array = []
	for i in 4:
		members.append(_member("Green_D_%d" % (i + 1), Vector3((i - 1.5) * 3.0, 0, 0)))
	var slots := {}
	var placed := TacticsFormation.place(members, "line", Vector3.ZERO, Vector3.FORWARD, 10.0,
			{"halt": true, "corridor_m": INF, "layout": true})
	var seats: Array = placed.map(func(e: Dictionary) -> Vector3: return e["to"])
	seats.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x > b.x)
	for i in 4:
		slots["Green_D_%d" % (i + 1)] = seats[i]  # west crew to the east seat: crossed
	var plan := {"formation": "line", "slots": slots}
	var read := ElementPlan._trace_deals(plan, {"members": members, "tick": 0}, Vector3.ZERO, Vector3.FORWARD, 10.0)
	print("MEASURE deal read: %s" % [read])
	assert_true(read.has("main") and read.has("ordered"), "both deals read")
	assert_true(float(read["ordered"][1]) <= float(read["main"][1]) + 0.1, "least total <= main's crossed seating")
	assert_true(float(read["ordered"][0]) < float(read["main"][0]), "and its longest drive is shorter here")
	assert_true(float(read["spread_m"]) > 4.0 and float(read["spread_m"]) < 5.0, "spread: 4.5 m from the centroid")
