extends TestCase
## Round 27, brains B2 (DECLARED): a re-seat keeps every crew PARKED on its own slot in its seat; the crew that was
## stuck takes one of the seats still open. Round 26's Sumps re-seat freed an IFV pressing a parked tank by handing the
## tank a far seat (0312 -> 1302), and the tank ended 19-26 m off its slot while the element read arrived (lesson 293).
## The live half is the Sumps cell (`make squad-settle ARENA=sumps ... SETTLE_FLAGS=--drills=on`, B1's line).


## Four crews in a file, the column's seats ahead of them; crew B parked on seat 1, crew A stuck behind it.
func _members() -> Array:
	return [{"name": "A", "unit": "law_ifv", "position": Vector3(0, 0, 12)},
			{"name": "B", "unit": "law_tank", "position": Vector3(0, 0, 4)},
			{"name": "C", "unit": "law_tank", "position": Vector3(6, 0, -2)},
			{"name": "D", "unit": "law_tank", "position": Vector3(-6, 0, -2)}]


func _offsets() -> Array[Vector2]:
	return [Vector2(0, -12), Vector2(0, -4), Vector2(0, 4), Vector2(0, 12)]


func test_a_kept_seat_is_taken_and_no_other() -> void:
	var opts := {"policy": "travel", "keep": {"B": 3}}
	var seats := TacticsFormation.seat(_members(), _offsets(), Vector3.ZERO, Vector3.FORWARD, opts)
	assert_eq(int(seats["B"]), 3, "B keeps seat 3 whatever the costs say")
	var taken := {}
	for name: String in seats:
		taken[int(seats[name])] = true
	assert_eq(taken.size(), 4, "every crew still has a seat of its own (%s)" % seats)


func test_without_keep_the_seating_is_unchanged() -> void:
	var plain := TacticsFormation.seat(_members(), _offsets(), Vector3.ZERO, Vector3.FORWARD, {"policy": "travel"})
	var empty := TacticsFormation.seat(_members(), _offsets(), Vector3.ZERO, Vector3.FORWARD,
			{"policy": "travel", "keep": {}})
	assert_eq(empty, plain, "an empty keep is the old seating")


func test_the_parked_crew_keeps_its_seat_and_the_stuck_one_goes_round_it() -> void:
	var members := _members()
	var plain := TacticsFormation.seat(members, _offsets(), Vector3.ZERO, Vector3.FORWARD, {"policy": "travel"})
	# B stands on the slot of the seat it had (seat 1 here); kept, it stays there.
	var kept := TacticsFormation.seat(members, _offsets(), Vector3.ZERO, Vector3.FORWARD,
			{"policy": "travel", "keep": {"B": 1}})
	assert_eq(int(kept["B"]), 1, "B, parked, keeps its seat")
	assert_true(int(kept["A"]) != 1, "A does not take B's seat")
	print("MEASURE b2_keep plain %s kept %s" % [plain, kept])


func test_the_plan_carries_the_kept_seats_on_a_reseat_only() -> void:
	DoctrineTable.clear_cache()
	var table: DoctrineTable = DoctrineTable.load_table("law")["table"]
	var members: Array = []
	for i in 4:
		members.append({"name": "Green_S_%d" % (i + 1), "position": Vector3(i * 8.0 - 12.0, 0.0, 40.0),
				"forward": Vector3.FORWARD, "role": "tank", "unit": "law_tank", "speed": 9.0, "range": 70.0,
				"effective_range": 45.0, "sight": 62.0, "health": 1.0, "suppression": 0.0, "taking_fire": false})
	var situation := {"tick": 1000, "team": 0, "center": Vector3(0, 0, 40), "heading": Vector3.FORWARD,
			"leader": "Green_S_1", "members": members, "contacts": [], "terrain": "open", "threat": "none",
			"composition": "heavy", "strength": 800.0, "enemy_strength": 0.0, "taking_fire": false, "arrived": false}
	var task := {"verb": "move", "to": [0.0, -60.0]}
	var state := {"task": task, "drill": "", "drill_tick": 0, "drill_point": null, "drill_target": "", "drill_why": "",
			"anchor": null, "bounding": 0, "arrived": false, "heading": Vector3.FORWARD, "seats": {}}
	var first := ElementPlan.build(situation, state, table)
	var seats: Dictionary = first["seats"]
	var parked := "Green_S_3"
	var again := state.duplicate()
	again["seats"] = seats
	again["anchor"] = first["anchor"]
	again["reseat"] = true
	again["reseat_keep"] = {parked: seats[parked]}
	var reseated := ElementPlan.build(situation, again, table)
	assert_eq(reseated["seats"][parked], seats[parked], "the parked crew keeps its seat through the re-seat")
	again["reseat"] = false
	var not_reseating := ElementPlan.build(situation, again, table)
	assert_true(not (not_reseating.get("reseat_keep", {}) as Dictionary).has(parked),
			"no re-seat: nothing kept (the keep is the re-seat's)")
