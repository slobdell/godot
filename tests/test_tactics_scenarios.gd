extends TestCase
## The quick subset of the battle-drill scenarios (tests/tactics/tactics_scenarios.gd), so `make check`
## guards the drills that work. The full set, with the measurements, runs faster than real time with
## `make tactics-drills` and `make tactics-measure`.


func test_an_element_ambushed_at_close_range_assaults_through_it() -> void:
	# The lead: "if a unit gets ambushed, the standard operating procedure is to face the direction of the
	# ambush and charge forward."
	var result: Dictionary = await TacticsScenarios.near_ambush(self, 18.0)
	var drills: Array = result["drills"]
	assert_true(drills.has("near_ambush"), "the element recognises a near ambush (ran %s)" % [drills])
	assert_true(drills.has("assault_through"), "and assaults through it (ran %s)" % [drills])
	assert_true(int(result["through_tick"]) > 0, "it actually drove past the ambush position")


func test_a_halted_element_watches_both_flanks() -> void:
	var result: Dictionary = await TacticsScenarios.herringbone(self, 8.0)
	# Which shape depends on the ground: the herringbone in lanes or cover, the coil in the open.
	assert_true(["herringbone", "coil"].has(String(result["formation"])),
			"a halt with something out there forms all-round security (got %s)" % result["formation"])
	assert_true(int(result["left"]) > 0 and int(result["right"]) > 0,
			"with vehicles facing out to both sides (bearings %s)" % [result["bearings"]])
	assert_true(float(result["coverage"]) > 0.8, "so the element watches almost all of the circle")


# ---- Round 6 (X5): each task produces the posture its name claims -----------------------------------------------

func test_support_by_fire_forms_a_firing_line_at_a_standoff_and_fires_from_it() -> void:
	# The lead pressed support by fire and "the units definitely did not form up".
	var result: Dictionary = await TacticsScenarios.task_posture(self, "support_by_fire", 30.0)
	print("MEASURE task_posture %s" % result)
	assert_true(Array(result["drills"]).has("support_by_fire"), "the element runs the task (ran %s)" % [result["drills"]])
	assert_true(not Array(result["drills"]).has("far_ambush") and not Array(result["drills"]).has("react_to_contact"),
			"and contact never turns it into an advance or a flank (ran %s)" % [result["drills"]])
	assert_true(float(result["closest_m"]) >= 35.0, "nobody advances onto the point (closest %.0f m)" % result["closest_m"])
	assert_true(float(result["frontage_m"]) >= 24.0, "abreast: a line %.0f m wide" % result["frontage_m"])
	assert_true(float(result["depth_m"]) <= 16.0, "not a column (%.0f m deep)" % result["depth_m"])
	for distance: float in result["to_point_m"]:
		assert_true(distance <= 80.0, "every gun is within reach of the point (%.0f m)" % distance)
	assert_true(int(result["facing_point"]) >= 3, "the line faces the point (%d of 4)" % result["facing_point"])
	assert_true(int(result["shots"]) > 0, "and it fires from there")


func test_a_screen_stands_on_a_line_across_the_point() -> void:
	var result: Dictionary = await TacticsScenarios.task_posture(self, "screen", 30.0)
	print("MEASURE task_posture %s" % result)
	assert_eq(result["formation"], "line", "a screen is a line")
	assert_true(float(result["frontage_m"]) >= 36.0, "a wide one (%.0f m)" % result["frontage_m"])
	assert_true(float(result["depth_m"]) <= 14.0, "across the point, not along it (%.0f m deep)" % result["depth_m"])
	assert_true(float(result["center_to_point_m"]) <= 10.0, "centred on it (%.0f m off)" % result["center_to_point_m"])


func test_a_move_ends_formed_up_on_the_spot_and_stops_issuing() -> void:
	var result: Dictionary = await TacticsScenarios.task_posture(self, "move", 30.0)
	print("MEASURE task_posture %s" % result)
	assert_true(float(result["center_to_point_m"]) <= 8.0, "the element's middle is where it was sent (%.1f m off)"
			% result["center_to_point_m"])
	assert_true(float(result["worst_off_slot_m"]) <= 8.0, "every vehicle is in its slot (worst %.1f m)"
			% result["worst_off_slot_m"])
	assert_true(int(result["orders_last_10s"]) <= 2, "and the leader has stopped re-issuing (%d orders in the last 10 s)"
			% result["orders_last_10s"])


func test_an_ambush_holds_its_fire_until_the_kill_zone_is_full() -> void:
	# The lead: "We want to be able to set up ambushes, do flanking maneuvers."
	var result: Dictionary = await TacticsScenarios.ambush(self)
	print("MEASURE ambush %s" % result)
	assert_true(int(result["entered_tick"]) > 0, "setup: the enemy drove into the kill zone")
	assert_eq(int(result["shots_before"]), 0, "not one shot before it was in the kill zone")
	assert_true(int(result["sprung_tick"]) >= int(result["entered_tick"]), "sprung when it arrived, not before")
	assert_true(int(result["shots_after"]) > 0, "and then every gun fired")
