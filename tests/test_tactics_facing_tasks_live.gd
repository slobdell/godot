extends "res://tests/tactics/facing_tasks_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in facing_tasks_case.gd.


func test_a_screen_faces_the_way_he_drew() -> void:
	await _run(41, {"verb": "screen", "to": [LANE_X, 0.0], "facing": [1.0, 0.0]}, 30, "screen")


func test_support_by_fire_faces_the_way_he_drew() -> void:
	await _run(42, {"verb": "support_by_fire", "to": [LANE_X + 40.0, 0.0], "facing": [1.0, 0.0]}, 35,
			"support by fire")
