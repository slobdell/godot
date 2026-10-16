extends "res://tests/tactics/mixed_legs_case.gd"
## Round 32 (C32.8 / R31.9): split from one slow file; what its tests share is in tests/tactics/mixed_legs_case.gd.


## The mechanism: closed-up is judged against the seats the element GAVE (pinned leader, previous seating), so a squad
## standing in those seats reads as closed up whatever the role ranking would choose fresh.
func test_cohesion_is_judged_against_the_seats_the_element_gave() -> void:
	var heading := Vector3.FORWARD
	var anchor := Vector3.ZERO
	var members: Array = [
		{"name": "A", "position": Vector3.ZERO, "role": "scout", "unit": "law_scout", "speed": 14.0},
		{"name": "B", "position": Vector3.ZERO, "role": "scout", "unit": "law_scout", "speed": 14.0},
		{"name": "C", "position": Vector3.ZERO, "role": "ifv", "unit": "law_ifv", "speed": 11.0},
		{"name": "D", "position": Vector3.ZERO, "role": "tank", "unit": "law_tank", "speed": 8.0}]
	# Seat them as the element would with A pinned as leader and A,B,C,D as the previous seating, then stand each crew
	# exactly in its slot.
	var opts := {"leader": "A", "previous": {"A": 0, "B": 1, "C": 2, "D": 3}, "policy": "exposure"}
	for entry in TacticsFormation.place(members, "wedge", anchor, heading, TacticsFormation.DEFAULT_SPACING, opts):
		for member: Dictionary in members:
			if String(member["name"]) == String(entry["unit"]):
				member["position"] = entry["to"]
	var table := DoctrineTable.for_faction("law")
	assert_true(ElementPlan._cohesive(members, anchor, "wedge", heading, TacticsFormation.DEFAULT_SPACING, table, INF,
			{"leader": "A", "previous": opts["previous"]}), "standing in the seats it was given is closed up")


## Round 18, brains D5: on the Sumps a squad attack-moved 150 m never arrived (0 of 8 even at 180 s, four tanks
## included). In the 14 m lane along the centre block the squad goes single file; the pinned leader was BEHIND a
## squadmate but held the front seat, and the squadmate parked in its own seat squarely in the leader's path. The seating
## is stable by design and never uncrossed the file. A crew that keeps driving without closing on its slot now gets the
## element to re-seat once, fresh (leader unpinned), so the file's order becomes the shape's.
func test_four_tanks_attack_moved_across_the_sumps_arrive() -> void:
	seconds = 90.0
	var result: Dictionary = await _attack_move(["law_tank", "law_tank", "law_tank", "law_tank"], "sumps", 1)
	print("MEASURE mixed_legs sumps seed 1: four tanks %s" % result)
	assert_true(float(result["arrived_s"]) > 0.0, "four tanks attack-moved 150 m across the Sumps arrive (%s)" % result)


## Round 18, after D5: the re-seat fired where it could not help. A Law two-scout squad on the Sumps arrived in 19.9 s with
## D4 alone and 37.0 s with D5 (7 re-seats over four seeds): a wheeled scout pinned on a wall with nobody in its way
## triggered re-seats of OTHER crews, and closing-up judged only against grounded slots waited for it. Now a re-seat
## needs a squadmate in the crew's way, and closing-up counts the nearer of the nominal and the grounded slot.
func test_a_two_scout_squad_across_the_sumps_arrives_without_needless_re_seats() -> void:
	seconds = 60.0
	var result: Dictionary = await _attack_move(["law_scout", "law_scout", "law_ifv", "law_tank"], "sumps", 1)
	print("MEASURE mixed_legs sumps seed 1: two scouts %s" % result)
	assert_true(float(result["arrived_s"]) > 0.0 and float(result["arrived_s"]) <= 25.0,
			"a Law two-scout squad attack-moved 150 m across the Sumps arrives in about 20 s (%s)" % result)
	assert_eq(int(result["reseats"]), 0, "with no re-seat: nobody stood in anybody's way")
