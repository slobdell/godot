extends "res://tests/tactics/mixed_legs_case.gd"
## Round 35, manoeuvre W1c (R35.39): the stall gate's intent reading must leave an element's own file jam to the element's
## re-seat (round 18 D5). The joint dev's third red: four Law tanks attack-moved across the Sumps with W1c (+ T9) ON, run after
## another test in the same process, rocked Green_M_3 nose-on to its parked squadmate Green_M_2 for 40 s (reseats 0, never
## arrived) while every passing run re-seated once. With the scope (another element's crew only) the element's way out stands.
## W1c is pinned ON here whatever the tree's default.


func test_four_tanks_across_the_sumps_arrive_with_the_stall_intent_on() -> void:
	var was := Movement._off
	Movement._off = PackedStringArray([]) if Manoeuvre.STALL_INTENT_DEFAULT else PackedStringArray(["stallintent"])
	Movement._off_parsed = true
	seconds = 90.0
	var result: Dictionary = await _attack_move(["law_tank", "law_tank", "law_tank", "law_tank"], "sumps", 1)
	Movement._off = was
	print("MEASURE w1c_sumps four tanks, W1c ON: %s" % result)
	assert_true(float(result["arrived_s"]) > 0.0, "four tanks attack-moved 150 m across the Sumps arrive with W1c on (%s)" % result)
