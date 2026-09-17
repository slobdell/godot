extends TestCase
## Render X1 (M1): the arithmetic behind `make perf-scene`. The frame numbers themselves need a GPU (the make target).


func test_schedule_puts_all_between_every_layer_and_ends_on_all() -> void:
	var phases := PerfScene.schedule(["no_a", "no_b"], 2)
	assert_eq(phases, ["all", "no_a", "all", "no_b", "all", "no_a", "all", "no_b", "all"], "all brackets every toggle, twice over")


func test_layer_cost_is_the_bracketing_all_phases_minus_the_layer() -> void:
	# The battle drifts from 20 ms to 24 ms; hiding the layer saves 5 ms at each point in the drift.
	var phases := [
		{"phase": "all", "avg_ms": 20.0}, {"phase": "no_a", "avg_ms": 16.0}, {"phase": "all", "avg_ms": 22.0},
		{"phase": "no_a", "avg_ms": 18.0}, {"phase": "all", "avg_ms": 24.0},
	]
	var costs := PerfScene.layer_costs(phases)
	assert_eq(costs.get("no_a"), 5.0, "(20+22)/2-16 = 5 and (22+24)/2-18 = 5, averaged")


func test_layer_cost_ignores_a_toggle_without_all_on_both_sides() -> void:
	var phases := [{"phase": "no_a", "avg_ms": 10.0}, {"phase": "all", "avg_ms": 20.0}, {"phase": "no_b", "avg_ms": 15.0}]
	assert_true(PerfScene.layer_costs(phases).is_empty(), "no bracketing pair, no cost")


func test_percentile_and_mean() -> void:
	var values := PackedFloat32Array([4.0, 1.0, 3.0, 2.0, 100.0])
	assert_eq(PerfScene.mean(values), 22.0, "mean")
	assert_eq(PerfScene.percentile(values, 0.5), 3.0, "median of the sorted samples")
	assert_eq(PerfScene.percentile(PackedFloat32Array(), 0.95), 0.0, "empty is 0")


func test_sixty_fps_holds_at_the_most_vehicles_whose_median_frame_stayed_under_60_hz() -> void:
	var phases := [
		{"phase": "all", "vehicles": 60, "avg_ms": 133.0}, {"phase": "all", "vehicles": 30, "avg_ms": 40.0},
		{"phase": "all", "vehicles": 14, "avg_ms": 16.2}, {"phase": "no_hud", "vehicles": 12, "avg_ms": 12.0},
		{"phase": "all", "vehicles": 12, "avg_ms": 19.4}, {"phase": "all", "vehicles": 12, "avg_ms": 19.9},
		{"phase": "all", "vehicles": 10, "avg_ms": 14.0}, {"phase": "all", "vehicles": 10, "avg_ms": 18.9},
		{"phase": "all", "vehicles": 10, "avg_ms": 13.0},
	]
	assert_eq(PerfScene.holds_60fps_at(phases), 10, "one noisy phase at 10 doesn't sink it; 12 didn't hold, so 14 doesn't count")
	assert_eq(PerfScene.holds_60fps_at([{"phase": "all", "vehicles": 60, "avg_ms": 30.0}]), 0, "never held")


func test_a_locked_30_is_judged_on_its_worst_frames_not_its_median() -> void:
	var phases := [
		{"phase": "all", "vehicles": 60, "avg_ms": 28.0, "p99_ms": 58.0},
		{"phase": "all", "vehicles": 40, "avg_ms": 25.0, "p99_ms": 31.0},
		{"phase": "all", "vehicles": 20, "avg_ms": 18.0, "p99_ms": 24.0},
	]
	assert_eq(PerfScene.holds_30fps_at(phases), 40, "60 vehicles average 28 ms but drop to 58: not locked")
	assert_eq(PerfScene.holds_60fps_at(phases), 0, "and none of it is 60")
