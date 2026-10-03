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


# ---- Round 16 (play P1): `make perf-play`, his path measured -------------------------------------------------------

func test_over_share_is_the_fraction_of_frames_longer_than_the_line() -> void:
	var frames := PackedFloat32Array([33.4, 33.3, 50.0, 34.5, 20.0])
	assert_eq(PerfScene.over_share(frames, PerfScene.cap_line_ms(30.0)), 0.4, "34.5 and 50 are over 34.33; a 33.4 capped frame is not")
	assert_eq(PerfScene.over_share(PackedFloat32Array(), 34.0), 0.0, "no frames, nothing over")


func test_the_play_run_measures_the_player_layers_by_default() -> void:
	for layer in ["no_visfield", "no_visfield_thread", "no_controls", "no_audio", "no_recorder"]:
		assert_true(PerfScene.PLAY_LAYERS.has(layer), "%s is in perf-play's default schedule" % layer)
	assert_true(not PerfScene.PLAY_LAYERS.has("no_vehicles"), "the play run keeps every vehicle on screen: it is his frame")


func test_the_play_orders_send_every_group_at_the_enemy_spread_across_the_front() -> void:
	var orders := PerfScene.play_orders([1, 2, 3], Vector3(0.0, 0.0, -80.0), Vector3.RIGHT)
	assert_eq(orders.size(), 3, "one order per control group")
	assert_eq(orders[0]["group"], 1, "group 1 first")
	assert_eq(orders[0]["verb"], "attack_move", "they fight on the way")
	assert_eq(orders[1]["to"], [0.0, -80.0], "the middle group goes straight at the enemy base")
	assert_eq(orders[0]["to"], [-PerfScene.PLAY_SPREAD_M, -80.0], "the others spread along the front")


func test_a_summary_line_reads_the_phases_it_was_given() -> void:
	var phases := [
		{"phase": "all", "vehicles": 50, "avg_ms": 40.0, "p95_ms": 50.0, "p99_ms": 60.0, "gpu_ms": 20.0, "over_cap_share": 0.5,
				"tick_script_ms": 24.0, "ticks_per_frame": 1.2, "process_game_ui_ms": 2.5},
		{"phase": "no_audio", "vehicles": 50, "avg_ms": 39.0, "p95_ms": 49.0, "p99_ms": 59.0, "gpu_ms": 20.0, "over_cap_share": 0.4,
				"tick_script_ms": 24.0, "ticks_per_frame": 1.2, "process_game_ui_ms": 2.5},
		{"phase": "all", "vehicles": 48, "avg_ms": 38.0, "p95_ms": 48.0, "p99_ms": 58.0, "gpu_ms": 18.0, "over_cap_share": 0.3,
				"tick_script_ms": 22.0, "ticks_per_frame": 1.0, "process_game_ui_ms": 2.3},
	]
	var means := PerfScene.all_means(phases, ["avg_ms", "over_cap_share", "tick_script_ms"])
	assert_eq(means["avg_ms"], 39.0, "the mean of the two `all` phases")
	assert_eq(means["over_cap_share"], 0.4, "the choppy share over the `all` phases")
	assert_eq(means["tick_script_ms"], 23.0, "and the tick")


func test_game_speed_is_game_time_over_wall_time() -> void:
	# Saturated: three 33 ms ticks a frame is all Godot will simulate, but the frame took 300 ms by the clock.
	var game := PackedFloat32Array([100.0, 100.0])
	var wall := PackedFloat32Array([300.0, 200.0])
	assert_eq(PerfScene.game_speed(game, wall), 0.4, "100 ms of battle per 250 ms of wall clock: 40 % speed")
	assert_eq(PerfScene.game_speed(PackedFloat32Array(), PackedFloat32Array()), 1.0, "no frames reads as real time")
