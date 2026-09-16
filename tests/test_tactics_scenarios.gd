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
	assert_eq(String(result["formation"]), "herringbone", "a halt with something out there is a herringbone")
	assert_true(int(result["left"]) > 0 and int(result["right"]) > 0,
			"with vehicles facing out to both sides (bearings %s)" % [result["bearings"]])
	assert_true(float(result["coverage"]) > 0.8, "so the element watches almost all of the circle")
