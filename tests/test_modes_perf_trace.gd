extends TestCase
## Round 16 (play P2, P6): every `make skirmish` carries its own frame-time trace beside the recording, so "it was
## choppy on the Locks" is read from a file; and "choppy" is told apart from "slow" (the slow-motion trap).


func test_a_second_of_frames_becomes_one_row() -> void:
	var wall := PackedFloat32Array([30.0, 33.0, 50.0, 207.0])
	var row := PerfTrace.summarize(wall, 200.0, 6, 120000, 8000, PackedFloat32Array([18.0, 20.0, 22.0, 19.0]))
	assert_eq(row["frames"], 4, "four frames")
	assert_eq(row["avg_ms"], 80.0, "320 ms over 4 frames")
	assert_eq(row["max_ms"], 207.0, "the worst frame")
	assert_eq(row["ticks_per_frame"], 1.5, "6 ticks over 4 frames")
	assert_eq(row["tick_ms"], 20.0, "120 ms of tick scripts over 6 ticks")
	assert_eq(row["ui_ms"], 2.0, "8 ms of game+UI _process over 4 frames")
	assert_eq(row["gpu_ms"], 19.0, "the median GPU frame (lower middle of four)")
	assert_eq(row["game_speed"], 0.63, "200 ms of battle in 320 ms of wall clock")
	assert_eq(row["over34"], 0.5, "two frames of four missed the locked-30 line")


func test_the_trace_sits_beside_the_recording_but_is_not_one() -> void:
	var path := PerfTrace.trace_path("build/recordings/2026-10-02T18-59-00-sumps.jsonl")
	assert_eq(path, "build/recordings/2026-10-02T18-59-00-sumps.perf", "same name, its own extension")
	assert_true(not path.ends_with(".jsonl"), "the recorder's prune (newest KEEP *.jsonl) never counts it")


func test_it_runs_in_his_games_and_never_in_tests_benches_or_harnesses() -> void:
	assert_true(PerfTrace.wanted(LaunchFlags.parse(["--skirmish"]), false), "a windowed skirmish traces")
	assert_true(not PerfTrace.wanted(LaunchFlags.parse(["--skirmish"]), true), "headless: nobody is watching frames")
	for flag in ["--scripted", "--perf-scene=/x.json", "--no-record", "--perf-trace=off"]:
		assert_true(not PerfTrace.wanted(LaunchFlags.parse(["--skirmish", flag]), false), "not with %s" % flag)


func test_slow_is_told_apart_from_choppy() -> void:
	assert_eq(PerfTrace.slow_label(1.0), "", "real time says nothing")
	assert_eq(PerfTrace.slow_label(0.97), "", "a hair under is noise")
	assert_eq(PerfTrace.slow_label(0.6), "SLOW x0.60", "the battle at 60 % speed says so")
