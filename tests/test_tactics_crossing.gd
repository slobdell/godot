extends TestCase
## Round 25 (brains F0/F1): HIS CROSSING (tests/tactics/crossing_stage.gd). "a vehicle further back (the presumable
## point man) was trying to get to the front ... squads trying to get into formation should determine whose position
## is whose based on who is already closest to the position in that formation." His five Guns from the 15.7 s order of
## his recording (the Crossing, seed 35967), a plain move over the east bridge. Before F1 (round 24's close, laptop,
## seeds 1-3): the crew seated on the point started behind two squadmates along the route in 10 of 11 runs, wedge and
## column, both sides; the column swapped its order on the way 3-6 times. Both sides are held to the same.

const SECONDS := 60.0


func _case(formation: String, side: String) -> void:
	var report: Dictionary = await CrossingStage.run(self, 1, "crossing", formation, side, SECONDS)
	print("MEASURE crossing %s %s seed 1: %s" % [formation, side, report])
	assert_eq(int(report["point_passes"]), 0, "%s %s: the crew on the point did not start behind a squadmate (%s, seats %s)" % [
			formation, side, report["point"], report["seats"]])
	assert_eq(int(report["crossed"]), int(report["crews"]), "%s %s: every crew crossed (%s)" % [formation, side,
			report["cross_s"]])


func test_his_wedge_is_led_by_the_crew_already_in_front() -> void:
	await _case("wedge", "green")


func test_the_cpus_column_keeps_its_order_into_the_crossing() -> void:
	await _case("column", "rust")
