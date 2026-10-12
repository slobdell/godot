extends TestCase
## Round 27, brains B1 (lesson 293): the arrive line counts EVERY crew. Round 26's Sumps cell read "arrived" with a
## crew 19-26 m off its slot; ArrivalLine (tests/tactics/arrival_line.gd) is the measuring line the arrive series use
## since: every living crew within its radius (the order's 3.5 m, or a car's settle radius) of its own slot, held 1 s.


func _crews(offsets: Array, unit := "tank") -> Array:
	var crews: Array = []
	for i in offsets.size():
		var slot := Vector3(i * 8.0, 0.0, -50.0)
		crews.append({"name": "Green_S_%d" % (i + 1), "unit": unit, "slot": slot,
				"position": slot + Vector3(float(offsets[i]), 0.0, 0.0)})
	return crews


func test_every_crew_on_its_slot_is_in() -> void:
	assert_true(ArrivalLine.all_in(_crews([0.0, 1.0, -2.0, 3.0])), "four crews within 3.5 m of their slots: in")


func test_one_crew_20_m_off_fails_it() -> void:
	# The mutation check (lesson 293's case): the element may say arrived; the line must not.
	assert_true(not ArrivalLine.all_in(_crews([0.0, 0.0, 20.0, 0.0])), "a crew 20 m off its slot: NOT in")
	assert_true(not ArrivalLine.all_in(_crews([0.0, 0.0, 4.0, 0.0])), "a tank 4 m off (radius 3.5): not in")


func test_a_crew_on_another_crews_slot_is_not_on_its_own() -> void:
	var crews := _crews([0.0, 0.0, 0.0, 0.0])
	var swapped: Dictionary = crews[3]
	swapped["position"] = (crews[0] as Dictionary)["slot"]
	assert_true(not ArrivalLine.all_in(crews), "standing on a squadmate's slot is not standing on your own")


func test_a_car_settles_within_its_own_radius() -> void:
	var radius := ArrivalLine.radius_of("scout")
	assert_true(radius >= TankBrain.ORDER_ARRIVE, "a car's radius is at least the order's (%.1f m)" % radius)
	assert_near(ArrivalLine.radius_of("tank"), TankBrain.ORDER_ARRIVE, 0.001, "a tank's is the order's 3.5 m")
	assert_true(ArrivalLine.all_in(_crews([radius - 0.1], "scout")), "a car just inside its settle radius: in")
	assert_true(not ArrivalLine.all_in(_crews([radius + 0.1], "scout")), "just outside: not in")


func test_a_missing_slot_or_nobody_is_not_an_arrival() -> void:
	var crews := _crews([0.0, 0.0])
	(crews[1] as Dictionary)["slot"] = null
	assert_true(not ArrivalLine.all_in(crews), "a crew with no slot is not on it")
	assert_true(not ArrivalLine.all_in([]), "nobody left: not arrived")


func test_it_must_hold_for_a_second() -> void:
	var line := ArrivalLine.new()
	var hold := int(ArrivalLine.HOLD_S * SimClock.TICK_RATE)
	var inside := _crews([0.0, 0.0])
	var out := _crews([0.0, 9.0])
	for tick in hold - 1:
		line.sample(100 + tick, inside)
	line.sample(100 + hold - 1, out)
	assert_eq(line.arrived_tick, -1, "in for less than a second, then out: not arrived")
	for tick in hold + 1:
		line.sample(200 + tick, inside)
	assert_eq(line.arrived_tick, 200, "held a second from tick 200: arrived at 200")
	line.sample(400, out)
	assert_eq(line.arrived_tick, 200, "an arrival stands once made")
	assert_eq(String(line.worst["name"]), "Green_S_2", "the worst crew is reported")
	assert_near(float(line.worst["off_m"]), 9.0, 0.001, "with its distance")
