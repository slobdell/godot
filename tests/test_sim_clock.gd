extends TestCase
## Round 5: one tick rate for the whole simulation (_agents/sim_tick_rate.md). SimClock.TICK_RATE, project.godot's
## physics_ticks_per_second and the Makefile's SIM_HZ (every headless run's --fixed-fps) must agree, or a match runs
## at one rate while its durations are counted at another.


func test_the_engine_ticks_at_the_rate_the_simulation_counts_in() -> void:
	assert_eq(int(ProjectSettings.get_setting("physics/common/physics_ticks_per_second")), SimClock.TICK_RATE,
			"project.godot physics_ticks_per_second == SimClock.TICK_RATE")


func test_make_runs_headless_matches_at_that_rate() -> void:
	var makefile := FileAccess.get_file_as_string("res://Makefile")
	var found := RegEx.create_from_string("(?m)^SIM_HZ\\s*:=\\s*(\\d+)").search(makefile)
	assert_true(found != null, "the Makefile defines SIM_HZ")
	if found != null:
		assert_eq(int(found.get_string(1)), SimClock.TICK_RATE, "Makefile SIM_HZ == SimClock.TICK_RATE")


func test_durations_convert_both_ways() -> void:
	assert_eq(SimClock.ticks(1.0), SimClock.TICK_RATE, "a second is TICK_RATE ticks")
	assert_eq(SimClock.ticks(0.0), 0, "nothing is no ticks")
	assert_eq(SimClock.ticks(0.001), 1, "any positive duration is at least one tick")
	assert_near(SimClock.seconds(SimClock.TICK_RATE * 3), 3.0, 0.000001, "and back")
	assert_eq(Match.INTEL_EVERY_TICKS, SimClock.ticks(0.1), "intel runs ten times a second at any rate")
