extends "res://tests/tactics/facing_tasks_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in facing_tasks_case.gd.


func test_an_ambush_faces_the_way_he_drew() -> void:
	# Round 27 (B5): and its guns, laid on their sectors while it holds its fire.
	await _run(43, {"verb": "ambush", "to": [LANE_X + 40.0, 0.0], "facing": [1.0, 0.0]}, 35, "ambush", true)


func test_an_attack_move_arrives_facing_the_way_he_drew() -> void:
	await _run(44, {"verb": "move", "to": [LANE_X, 0.0], "facing": [1.0, 0.0]}, 30, "attack-move")
