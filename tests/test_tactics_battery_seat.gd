extends TestCase
## Round 33, brains battery stretch, switch (a) (bar: workstreams *Bars (round 33)*, "Battery seats"): A SET-UP BATTERY
## CREW KEEPS ITS SEAT. A battery crew that has set up (deploy_ratio >= 1, the situation's "deployed") keeps the seat it
## had, and its place is where it stands. Movers take the remaining places, and are never seated past a set-up
## squadmate while another place is open. Traced (laptop, parade gangs v law s43): at t=86 the coil swapped Battery_2's
## and Battery_5's places while 1, 3 and 4 were set up; Battery_2's new place was 20 m across the set-up trucks, Battery_3
## refused it, and it never moved again. `--battery-seat=off` is main's rule.


func teardown() -> void:
	ElementPlan.BATTERY_SEAT = true
	super.teardown()


## Five mortar carriers: three set up on seats 0, 1, 2 (standing near their slots), two still driving in from the south.
func _members() -> Array:
	var members: Array = []
	var at := [Vector3(-10, 0, 1), Vector3(0, 0, 2), Vector3(10, 0, 1), Vector3(-4, 0, 30), Vector3(4, 0, 30)]
	for i in 5:
		members.append({"name": "Battery_%d" % (i + 1), "unit": "artillery", "role": "artillery", "position": at[i],
				"speed": 6.5, "deployed": i < 3})
	return members


## The plan as `_group` reads it: last update's seats in the coil of five.
func _plan() -> Dictionary:
	var seats := {}
	for i in 5:
		seats["Battery_%d" % (i + 1)] = ["coil", 5, i]
	return {"leader": "", "previous_seats": seats, "slots": {}, "sectors": {}, "seats": {}, "orders": {}}


func test_a_mover_is_not_seated_past_a_set_up_squadmate_while_another_place_is_open() -> void:
	# Two seats ahead of crew M: seat 0 straight through the set-up truck at (0, 0, 10), seat 1 off to the side.
	var members := [{"name": "M", "unit": "artillery", "position": Vector3(0, 0, 20)},
			{"name": "S", "unit": "artillery", "position": Vector3(0, 0, 10)}]
	var offsets: Array[Vector2] = [Vector2(0, 0), Vector2(22, 0), Vector2(0, 10)]
	var plain := TacticsFormation.seat(members, offsets, Vector3.ZERO, Vector3.FORWARD, {"policy": "travel", "keep": {"S": 2}})
	assert_eq(int(plain["M"]), 0, "main's rule: the nearest seat, straight through the set-up truck (%s)" % plain)
	var ruled := TacticsFormation.seat(members, offsets, Vector3.ZERO, Vector3.FORWARD,
			{"policy": "travel", "keep": {"S": 2}, "set_up_at": [Vector3(0, 0, 10)]})
	assert_eq(int(ruled["M"]), 1, "the open seat that does not pass the set-up truck (%s)" % ruled)
	assert_eq(int(ruled["S"]), 2, "the set-up crew keeps its seat")


func test_the_only_open_seat_is_still_given_when_it_lies_past_one() -> void:
	var members := [{"name": "M", "unit": "artillery", "position": Vector3(0, 0, 20)},
			{"name": "S", "unit": "artillery", "position": Vector3(0, 0, 10)}]
	var offsets: Array[Vector2] = [Vector2(0, 0), Vector2(0, 10)]
	var ruled := TacticsFormation.seat(members, offsets, Vector3.ZERO, Vector3.FORWARD,
			{"policy": "travel", "keep": {"S": 1}, "set_up_at": [Vector3(0, 0, 10)]})
	assert_eq(int(ruled["M"]), 0, "no other place open: it still gets one (%s)" % ruled)


func test_set_up_crews_keep_their_seats_and_their_places_are_where_they_stand() -> void:
	var members := _members()
	var plan := _plan()
	ElementPlan._group(plan, members, "coil", Vector3.ZERO, Vector3.FORWARD, 10.0, "move", "", true)
	for i in 3:
		var name := "Battery_%d" % (i + 1)
		assert_eq(int(plan["seats"][name][2]), i, "%s, set up, keeps seat %d" % [name, i])
		var place: Vector3 = plan["slots"][name]
		assert_true(place.distance_to(members[i]["position"]) < 0.01,
				"%s's place is where it stands (%s v %s)" % [name, place, members[i]["position"]])
	var taken := {}
	for name: String in plan["seats"]:
		taken[int(plan["seats"][name][2])] = true
	assert_eq(taken.size(), 5, "every crew has a seat of its own (%s)" % plan["seats"])


func test_a_crew_still_packing_or_driving_is_seated_as_before() -> void:
	var members := _members()
	for member: Dictionary in members:
		member["deployed"] = false
	var ruled := _plan()
	ElementPlan._group(ruled, members, "coil", Vector3.ZERO, Vector3.FORWARD, 10.0, "move", "", true)
	ElementPlan.BATTERY_SEAT = false
	var plain := _plan()
	ElementPlan._group(plain, members, "coil", Vector3.ZERO, Vector3.FORWARD, 10.0, "move", "", true)
	assert_eq(ruled["seats"], plain["seats"], "nobody set up: main's seating")
	assert_eq(ruled["slots"], plain["slots"], "...and main's places")


func test_only_a_battery_keeps_set_up_seats() -> void:
	var members := _members()
	members[0]["unit"] = "tank"
	members[0]["role"] = "tank"
	var mixed := _plan()
	ElementPlan._group(mixed, members, "coil", Vector3.ZERO, Vector3.FORWARD, 10.0, "move", "", true)
	ElementPlan.BATTERY_SEAT = false
	var plain := _plan()
	ElementPlan._group(plain, members, "coil", Vector3.ZERO, Vector3.FORWARD, 10.0, "move", "", true)
	assert_eq(mixed["slots"], plain["slots"], "a tank among them: not a battery, main's places")


func test_the_switch_off_is_mains_rule() -> void:
	var members := _members()
	ElementPlan.BATTERY_SEAT = false
	var plan := _plan()
	ElementPlan._group(plan, members, "coil", Vector3.ZERO, Vector3.FORWARD, 10.0, "move", "", true)
	var moved := 0
	for i in 3:
		var place: Vector3 = plan["slots"]["Battery_%d" % (i + 1)]
		if place.distance_to(members[i]["position"]) > 0.5:
			moved += 1
	assert_true(moved > 0, "--battery-seat=off: the set-up crews get the coil's slots, not where they stand")
