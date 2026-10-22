extends TestCase
## Round 37 (orders O5, R36.11): a CPU screen point is clear of another element's way when it is ASIDE_CLEAR_M or more
## from the straight line from that element's centre to its destination. Pure (ElementCommander._clear_of).


func test_a_point_on_another_elements_way_is_not_clear() -> void:
	var ways := [[Vector3(0, 0, 0), Vector3(0, 0, -100)]]
	assert_true(not ElementCommander._clear_of(Vector3(3, 0, -50), ways), "3 m off the line: on its way")
	assert_true(ElementCommander._clear_of(Vector3(ElementCommander.ASIDE_CLEAR_M + 0.5, 0, -50), ways), "beside it: clear")
	assert_true(ElementCommander._clear_of(Vector3(0, 0, -100 - ElementCommander.ASIDE_CLEAR_M - 1.0), ways),
			"beyond the destination: clear")


func test_no_ways_is_clear() -> void:
	assert_true(ElementCommander._clear_of(Vector3(1, 0, 1), []), "nobody else moving")


func test_one_step_aside_clears_a_line_through_the_point() -> void:
	var ways := [[Vector3(0, 0, 0), Vector3(0, 0, -100)]]
	var steps := ceili(ElementCommander.ASIDE_CLEAR_M / ElementCommander.ASIDE_STEP_M)
	assert_true(steps <= ElementCommander.ASIDE_MAX_STEPS, "the step search reaches a clear point (%d steps)" % steps)
	assert_true(ElementCommander._clear_of(Vector3(ElementCommander.ASIDE_STEP_M * steps, 0, -50), ways), "that point is clear")
