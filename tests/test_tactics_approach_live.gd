extends TestCase
## Round 27, brains B0 (C27.3), end to end: his attack with a drawn approach comes in from that side in a real match
## (the arena, the brains, nav, a target that shoots back), not only in the plan (test_tactics_approach.gd). The stage is
## ApproachStage: four tanks 100 m south of two enemy tanks, told to attack one coming in from the east. Pooled
## (`make approach-series`, builder0, 3 seeds x 6 start ticks): 18/18 within 35 deg of the east side (median 27, worst
## 30), the control 0/18 (median 88).


func test_an_attack_comes_in_from_the_side_he_drew() -> void:
	var report: Dictionary = await ApproachStage.run(self, 1, 40.0, ApproachStage.FROM_EAST)
	print("MEASURE b0_approach east %s" % JSON.stringify(report))
	assert_eq(String(report["error"]), "", "setup: an attack with an approach is a valid task")
	assert_true(float(report["in_s"]) >= 0.0, "it came round onto the side drawn (%s s)" % report["in_s"])
	assert_true(float(report["reach_off_deg"]) >= 0.0 and float(report["reach_off_deg"]) <= 35.0,
			"it closed in from within 35 deg of the side drawn (%s deg off)" % report["reach_off_deg"])
	assert_true(float(report["killed_s"]) >= 0.0, "and killed the target (%s s)" % report["killed_s"])


func test_control_without_an_approach_it_comes_straight_in() -> void:
	var report: Dictionary = await ApproachStage.run(self, 1, 40.0, null)
	print("MEASURE b0_approach none %s" % JSON.stringify(report))
	assert_true(float(report["reach_off_deg"]) >= 60.0,
			"no approach: it closes from the south, where it started (%s deg off east)" % report["reach_off_deg"])
	assert_true(float(report["killed_s"]) >= 0.0, "and kills it (%s s)" % report["killed_s"])
