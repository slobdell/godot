extends "res://tests/tactics/cpu_hold_case.gd"
## Round 31 (C31.9 / R31.9): split from one slow file; what its tests share is in cpu_hold_case.gd.


func test_the_cpu_ahead_on_points_holds_its_depot_and_springs_the_bay_ambush() -> void:
	var off: Dictionary = await _stage(false)
	var on: Dictionary = await _stage(true)
	print("MEASURE cpu_hold parade: attack (round 18) %s | hold %s" % [off, on])
	assert_true(float(on["took_s"]) >= 0.0, "the CPU takes an ambush (%s)" % on)
	assert_true(float(on["sprung_s"]) >= 0.0, "and springs it (%s)" % on)
	assert_true(absf(float(on["x_at_spring"])) > BAY_X, "from a bay, off the floor (%s)" % on)
	assert_true(int(on["rust_at_depot_20s"]) > 0, "the rest of the line holds the depot (%s)" % on)
	assert_true(not (float(off["sprung_s"]) >= 0.0 and absf(float(off["x_at_spring"])) > BAY_X),
			"control: attacking, the CPU never springs one from a bay (%s)" % off)
