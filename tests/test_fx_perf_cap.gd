extends TestCase
## Round 22 (perf P1, C22.3): the arithmetic behind `make perf-cap` -- his frame at 25 and 50 a side, played the way he
## plays (the next living group attack-moved every 12 s, the camera on it), one plain `all` phase after another. The
## frame numbers themselves need a display (the make target).


func test_no_layers_is_cycles_plain_phases() -> void:
	assert_eq(PerfScene.schedule([], 3), ["all", "all", "all"], "--perf-layers=none: one `all` phase per cycle, nothing toggled")
	assert_eq(PerfScene.schedule([], 0), ["all"], "at least one phase")


func test_layer_flag_none_means_no_layers() -> void:
	assert_eq(PerfScene.layers_from_flag("none", ["no_a"]), [], "none")
	assert_eq(PerfScene.layers_from_flag("", ["no_a"]), ["no_a"], "unset keeps the default")
	assert_eq(PerfScene.layers_from_flag("no_b,no_c", ["no_a"]), ["no_b", "no_c"], "a list")


func test_the_driver_takes_the_next_living_group_after_the_last_one() -> void:
	var living := {1: 5, 2: 0, 3: 0, 4: 2, 5: 1}
	assert_eq(PerfScene.next_drive_group([1, 2, 3, 4, 5], 1, living), 4, "2 and 3 are dead: 4")
	assert_eq(PerfScene.next_drive_group([1, 2, 3, 4, 5], 5, living), 1, "after the last, the first again")
	assert_eq(PerfScene.next_drive_group([1, 2, 3, 4, 5], 0, living), 1, "nothing ordered yet: the first")
	assert_eq(PerfScene.next_drive_group([1, 2, 3, 4, 5], 4, {1: 0, 4: 3}), 4, "only the last one left: it again")
	assert_eq(PerfScene.next_drive_group([1, 2], 1, {}), -1, "nobody alive: no order")
	assert_eq(PerfScene.next_drive_group([], 0, {1: 5}), -1, "no groups: no order")


func test_the_driver_aims_at_the_nearest_enemy_else_the_fallback() -> void:
	var from := Vector3(0, 0, 0)
	var enemies := [Vector3(50, 0, 0), Vector3(0, 0, -20), Vector3(-90, 0, 0)]
	assert_eq(PerfScene.nearest_point(from, enemies, Vector3(1, 2, 3)), Vector3(0, 0, -20), "the nearest")
	assert_eq(PerfScene.nearest_point(from, [], Vector3(1, 2, 3)), Vector3(1, 2, 3), "none left: the far base")


func test_the_run_summary_pools_every_frame_not_the_phase_means() -> void:
	# Two phases: one smooth (ten 20 ms frames), one with a 100 ms spike in ten. The run's numbers pool every frame.
	var frames := PackedFloat32Array()
	for i in 10:
		frames.append(20.0)
	for i in 9:
		frames.append(20.0)
	frames.append(100.0)
	var run := PerfScene.run_stats(frames, 40, 400000, PerfScene.cap_line_ms(30.0))
	assert_eq(run["frames"], 20, "every sampled frame")
	assert_eq(run["avg_ms"], 24.0, "(19 x 20 + 100) / 20")
	assert_eq(run["p95_ms"], 20.0, "floor(0.95 x 19) = the 19th of 20 sorted: still 20 ms")
	assert_eq(run["max_ms"], 100.0, "the spike")
	assert_eq(run["tick_script_ms"], 10.0, "400 000 us over 40 ticks")
	assert_eq(run["ticks_per_frame"], 2.0, "40 ticks over 20 frames")
	assert_eq(run["over_cap_share"], 0.05, "one frame in twenty over the locked-30 line")


func test_the_process_sweep_names_each_ui_script_once() -> void:
	var entries := [
		{"path": "res://game/ui/hud.gd", "priority": 0}, {"path": "res://game/ui/hud.gd", "priority": 0},
		{"path": "res://game/control/radar.gd", "priority": -5},
		{"path": "res://game/theme/fx/fx_world.gd", "priority": 1000},
		{"path": "res://tests/helper.gd", "priority": 0}, {"path": "", "priority": 0},
	]
	assert_eq(PerfScene.proc_layer_names(entries), ["proc:control/radar.gd", "proc:ui/hud.gd"],
			"hud once, FxWorld (its own bucket) and non-game scripts left out, sorted")
