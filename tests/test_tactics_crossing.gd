extends TestCase
## Round 25 (brains F0/F1): HIS CROSSING (tests/tactics/crossing_stage.gd). "a vehicle further back (the presumable
## point man) was trying to get to the front ... squads trying to get into formation should determine whose position
## is whose based on who is already closest to the position in that formation." His five Guns from the 15.7 s order of
## his recording (the Crossing, seed 35967), a plain move over the east bridge. Before F1 (round 24's close, laptop,
## seeds 1-3): the crew seated on the point started behind two squadmates along the route in 10 of 11 runs, wedge and
## column, both sides; the column swapped its order on the way 3-6 times. Both sides are held to the same.

const SECONDS := 60.0


func _case(formation: String, side: String) -> Dictionary:
	var report: Dictionary = await CrossingStage.run(self, 1, "crossing", formation, side, SECONDS)
	print("MEASURE crossing %s %s seed 1: %s" % [formation, side, report])
	assert_eq(int(report["point_passes"]), 0, "%s %s: the crew on the point did not start behind a squadmate (%s, seats %s)" % [
			formation, side, report["point"], report["seats"]])
	assert_eq(int(report["crossed"]), int(report["crews"]), "%s %s: every crew crossed (%s)" % [formation, side,
			report["cross_s"]])
	return report


func test_his_wedge_is_led_by_the_crew_already_in_front() -> void:
	var report := await _case("wedge", "green")
	# F2: the wedge files over the 14 m deck instead of laying its flanks on the rim beside it (before F2, seed 1: three
	# crews' stations on the rim 7-9 s each; the flank crews parked beside the mouth).
	assert_true(float(report["wet_station_s"].values().reduce(func(a, b): return a + b, 0.0)) <= 0.5,
			"no station on the water or its rim beside the deck (%s)" % report["wet_station_s"])


func test_the_cpus_column_keeps_its_order_into_the_crossing() -> void:
	await _case("column", "rust")


## Round 25 (brains stretch b): the crossing guard on every map with a deck (the Crossing above). His wedge, a plain
## move, over the map's first carving by its deck (CrossingStage's derived stage), seed 1 at START_TICK: every crew
## across and the travelling shape never laid on the water or its rim beside the deck (F2). builder0 at F2: 0 rim
## crew-s and every crew across on each of these at all start ticks 1-18.
func _deck_map(arena: String, side := "green") -> void:
	var report: Dictionary = await CrossingStage.run(self, 1, arena, "wedge", side, SECONDS)
	print("MEASURE crossing %s wedge %s seed 1: crossed %d/%d last %.1f s, rim %s" % [arena, side, int(report["crossed"]),
			int(report["crews"]), float(report["crossed_s"]), report["wet_station_s"]])
	assert_eq(int(report["crossed"]), int(report["crews"]), "%s: every crew crossed (%s)" % [arena, report["cross_s"]])
	var rim: float = (report["wet_station_s"] as Dictionary).values().reduce(func(a, b): return a + b, 0.0)
	assert_true(rim <= 0.5, "%s: no station on the water or its rim beside the deck (%s)" % [arena, report["wet_station_s"]])


func test_the_locks_swing_bridge() -> void:
	await _deck_map("locks")


func test_the_sumps_catwalk() -> void:
	await _deck_map("sumps", "rust")


func test_the_terminus_canal_bridge() -> void:
	await _deck_map("terminus_canal")
