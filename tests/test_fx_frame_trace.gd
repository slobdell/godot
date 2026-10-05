extends TestCase
## Finale E1/E4 (round 18): FrameTrace's summary -- the largest frame within a second of the final kill, the typical frame
## before it, and the match past load (its median says whether a machine can judge; its largest frame is the hitch).


func _rows(times_ms: Array, ticks: Array) -> Array:
	var rows: Array = []
	var t := 0
	for i in times_ms.size():
		rows.append({"t_us": t, "ms": float(times_ms[i]), "tick": int(ticks[i]), "physics_ms": 1.0, "process_ms": 1.0,
				"draw_ms": float(times_ms[i]) - 2.0, "rest_ms": 0.0, "time_scale": 1.0, "added": 0, "added_names": [],
				"objects": 0, "resources": 0, "nodes": 0, "video_mb": 0.0, "texture_mb": 0.0})
		t += int(float(times_ms[i]) * 1000.0)
	return rows


func test_the_stall_is_the_largest_frame_within_a_second_of_the_final_kill() -> void:
	# 100 frames of 50 ms (5 s), then a 900 ms frame, then 20 more of 50 ms.
	var times: Array = []
	var ticks: Array = []
	for i in 121:
		times.append(900.0 if i == 100 else 50.0)
		ticks.append(i * 2)
	var rows := _rows(times, ticks)
	var kill_us := int(rows[99]["t_us"])
	var marks := [{"frame": 99, "t_us": kill_us, "what": "kill"}, {"frame": 99, "t_us": kill_us, "what": "finished"},
			{"frame": 110, "t_us": int(rows[110]["t_us"]), "what": "kill"}]  # a kill AFTER finished is not the final one
	var summary := FrameTrace.summarize(rows, marks)
	assert_eq(int(summary["max_frame"]), 100, "the frame after the final kill")
	assert_near(float(summary["max_ms"]), 900.0, 0.01, "its time")
	assert_near(float(summary["typical_ms"]), 50.0, 0.01, "the median of the four seconds before the window")
	assert_near(float(summary["draw_ms"]), 898.0, 0.01, "and which part of the frame it was")


func test_the_match_past_load_ignores_the_loading_frames() -> void:
	var rows := _rows([15000.0, 4000.0, 60.0, 60.0, 400.0, 60.0], [-1, 6, 15, 17, 19, 21])
	var summary := FrameTrace.summarize(rows, [])
	assert_near(float(summary["match_max_ms"]), 400.0, 0.01, "the first-use hitch, not the load's compile")
	assert_eq(int(summary["match_max_tick"]), 19, "and where it was")
	assert_near(float(summary["match_median_ms"]), 60.0, 0.01, "the median says the machine kept up")
	assert_eq(int(summary["max_frame"]), -1, "no kill, no end-of-match stall reported")
