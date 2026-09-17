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
