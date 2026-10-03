extends TestCase
## Round 17 (sim F5): Godot hands every physics callback `physics_step * Engine.time_scale`, so the time scale is
## simulation input. The kill-cam slowed a FINISHED match on a wall-clock schedule and the same windowed seed became two
## fights from the end of the match on (the Sumps "fork at 601-630"). The class: only a finished match may be slowed;
## a live match being slowed is said, once.

const MATCH := preload("res://game/match/match.tscn")



func test_a_live_match_slowed_says_so_once() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	expect_warning("Engine.time_scale is 0.5 on live tick*")
	Engine.time_scale = 0.5
	game_match._physics_process(SimClock.TICK_SECONDS * 0.5)
	game_match._physics_process(SimClock.TICK_SECONDS * 0.5)
	Engine.time_scale = 1.0
	assert_true(game_match._time_scale_warned, "the guard fired")


func test_a_finished_match_may_be_slowed() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match._finished = true
	Engine.time_scale = 0.2
	game_match._physics_process(SimClock.TICK_SECONDS * 0.2)
	Engine.time_scale = 1.0
	assert_true(not game_match._time_scale_warned, "the kill-cam's slow motion after the result is not a defect")


func test_full_speed_is_silent() -> void:
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match._physics_process(SimClock.TICK_SECONDS)
	assert_true(not game_match._time_scale_warned, "nothing to say at full speed")
