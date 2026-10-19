extends TestCase
## Round 35 (orders D4): THE DEPLOY'S SEATING. A squad deploying from its travel wedge into its halt is seated so its
## LONGEST leg is the shortest it can be (then the least total), not by the least total alone: traced (laptop, Terminus 5
## click, seed 34, squad 4), the least total handed the last crew in a 45 m leg past its squadmates in a street.
## Pure: ElementPlan._deploy_keep.


var _was := ElementPlan.DEPLOY_MINIMAX


func teardown() -> void:
	ElementPlan.DEPLOY_MINIMAX = _was
	super.teardown()


func _members(points: Array) -> Array:
	var out: Array = []
	for i in points.size():
		out.append({"name": "Green_S_%d" % (i + 1), "unit": "tank", "role": "tank", "position": points[i]})
	return out


func _longest(members: Array, keep: Dictionary, formation: String, anchor: Vector3, heading: Vector3) -> float:
	var seats := {}
	for entry in TacticsFormation.place(members, formation, anchor, heading, 14.0, {"halt": true, "corridor_m": INF, "layout": true}):
		seats[int(entry["index"])] = (entry["to"] as Vector3) + TacticsFormation.rotate(heading, deg_to_rad(float(entry["sector"]))) * ElementPlan.FACE_LEAD
	var worst := 0.0
	for member: Dictionary in members:
		var seat: Vector3 = seats[int(keep[String(member["name"])])]
		worst = maxf(worst, Vector2((member["position"] as Vector3).x - seat.x, (member["position"] as Vector3).z - seat.z).length())
	return worst


func test_every_crew_gets_one_seat() -> void:
	ElementPlan.DEPLOY_MINIMAX = true  # parked OFF by default (D4's A/B)
	var members := _members([Vector3(-30, 0, 10), Vector3(-15, 0, 0), Vector3(0, 0, -10), Vector3(15, 0, 0), Vector3(30, 0, 10)])
	var keep := ElementPlan._deploy_keep(members, "herringbone", Vector3.ZERO, Vector3.FORWARD, 14.0)
	assert_eq(keep.size(), 5, "a seat each")
	var used := keep.values()
	used.sort()
	assert_eq(used, [0, 1, 2, 3, 4], "five different seats")


func test_the_longest_leg_is_no_longer_than_any_other_seating() -> void:
	ElementPlan.DEPLOY_MINIMAX = true
	# A wedge (wide across) deploying into a herringbone (deep along): every one of the 120 seatings is no better.
	var members := _members([Vector3(-30, 0, 10), Vector3(-15, 0, 0), Vector3(0, 0, -10), Vector3(15, 0, 0), Vector3(30, 0, 10)])
	var keep := ElementPlan._deploy_keep(members, "herringbone", Vector3.ZERO, Vector3.FORWARD, 14.0)
	var chosen := _longest(members, keep, "herringbone", Vector3.ZERO, Vector3.FORWARD)
	var identity := {}
	for i in members.size():
		identity[String(members[i]["name"])] = i
	assert_true(chosen <= _longest(members, identity, "herringbone", Vector3.ZERO, Vector3.FORWARD) + 0.01,
			"the longest leg %.1f m, no longer than the seating in list order" % chosen)


func test_switched_off_and_out_of_range() -> void:
	ElementPlan.DEPLOY_MINIMAX = false
	assert_true(ElementPlan._deploy_keep(_members([Vector3.ZERO, Vector3(10, 0, 0)]), "coil", Vector3.ZERO, Vector3.FORWARD, 14.0).is_empty(),
			"--deploy-minimax=off: _group's own seating")
	ElementPlan.DEPLOY_MINIMAX = true
	assert_true(ElementPlan._deploy_keep(_members([Vector3.ZERO]), "coil", Vector3.ZERO, Vector3.FORWARD, 14.0).is_empty(), "one crew: nothing to choose")
