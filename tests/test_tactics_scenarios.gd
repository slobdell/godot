extends TestCase
## The quick subset of the battle-drill scenarios (tests/tactics/tactics_scenarios.gd), so `make check`
## guards the drills that work. The full set, with the measurements, runs faster than real time with
## `make tactics-drills` and `make tactics-measure`.
## Round 30 (brains B7, C30.9): split in two by each test's measured time (builder0, 5272d612, `make scenario-times`:
## 574 s alone, the floor of any shard plan at 5-6 shards); the tests are the same, byte for byte. Its other half:
## tests/test_tactics_scenarios_2.gd.
## Round 31 (C31.9 / R31.9): split again by each test's measured time (builder0 light lane, `make scenario-times`): its
## other parts are tests/test_tactics_scenarios_3.gd and _5.gd.


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
	# Derived, not written down: the line stands SBF_STANDOFF x the tanks' band off the point (56 m before CP4, ~36 m
	# after), and a crew may stand FACE_LEAD nearer on its sector. A number typed in here went stale when the bands moved.
	var standoff := ElementPlan.SBF_STANDOFF * TankBrain.fire_band(Weapons.profile(String(Units.stat("tank", "weapon"))))
	var floor_m := maxf(standoff, ElementPlan.SBF_MIN_STANDOFF_M) - ElementPlan.FACE_LEAD - 3.0
	assert_true(float(result["closest_m"]) >= floor_m, "nobody advances onto the point (closest %.0f m, line at %.0f m)"
			% [result["closest_m"], standoff])
	# Derived, not written down (lesson 112: a constant in a test is a scale assumption, and a formation has a size).
	# Four tanks abreast span three pitches; the bar is most of that, so the assertion is "abreast" and not "exactly
	# this wide". Depth is bounded by ONE pitch, which is what separates a line from a column at any hull size — the
	# resize grows both numbers together and neither literal would have.
	var pitch := TacticsFormation.pitch([{"unit": "tank"}], DoctrineTable.SPACING_DEFAULTS["open"])
	assert_true(float(result["frontage_m"]) >= pitch.x * 1.7,
			"abreast: a line %.0f m wide at a %.1f m pitch" % [result["frontage_m"], pitch.x])
	assert_true(float(result["depth_m"]) <= pitch.y + TacticsFormation.HULL_CLEAR_M,
			"not a column (%.0f m deep at a %.1f m pitch)" % [result["depth_m"], pitch.y])
	for distance: float in result["to_point_m"]:
		assert_true(distance <= standoff + 12.0, "every gun is within reach of the point (%.0f m)" % distance)
	assert_true(int(result["facing_point"]) >= 3, "the line faces the point (%d of 4)" % result["facing_point"])
	assert_true(int(result["shots"]) > 0, "and it fires from there")


func test_a_screen_stands_on_a_line_across_the_point() -> void:
	var result: Dictionary = await TacticsScenarios.task_posture(self, "screen", 30.0)
	print("MEASURE task_posture %s" % result)
	assert_eq(result["formation"], "line", "a screen is a line")
	assert_true(float(result["frontage_m"]) >= 36.0, "a wide one (%.0f m)" % result["frontage_m"])
	assert_true(float(result["depth_m"]) <= 14.0, "across the point, not along it (%.0f m deep)" % result["depth_m"])
	assert_true(float(result["center_to_point_m"]) <= 10.0, "centred on it (%.0f m off)" % result["center_to_point_m"])
