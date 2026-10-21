extends TestCase
## Round 36 (orders O1, C36.4): the herringbone-across-a-lane lab stage (tests/control/herringbone_lane_stage.gd) stays a
## workload: from s1's fixed snapshot the Sirens get in, and Hunters2 arrives and deploys into its halt while the Sirens are
## still on their street. One cell, in a fresh process (R33.14: a match leaves the physics world different for the next).
## Its numbers (the jam, X3b's bar) are read by `make herringbone-lab`, not asserted here: they are a machine's.

const CHILD_TIMEOUT_S := "300"


func _cell(flags: Array) -> Dictionary:
	var out: Array = []
	var code := OS.execute("timeout", [CHILD_TIMEOUT_S, OS.get_executable_path(), "--headless", "--fixed-fps",
			str(SimClock.TICK_RATE), "--path", ProjectSettings.globalize_path("res://"), "--script",
			"res://tests/control/herringbone_lane_probe.gd", "--", "--lead=-10", "--seconds=40"] + flags, out, true)
	var text := "\n".join(PackedStringArray(out.map(func(line: Variant) -> String: return str(line))))
	assert_true(code == 0, "the child finished inside %ss (exit %d)" % [CHILD_TIMEOUT_S, code])
	for line in text.split("\n"):
		if line.begins_with("HERRINGBONE_LAB "):
			var parsed: Variant = JSON.parse_string(line.trim_prefix("HERRINGBONE_LAB "))
			if parsed is Dictionary:
				return parsed
	assert_true(false, "the child printed its line: %s" % text.substr(0, 400))
	return {"sirens_s": -1.0, "hunters2_s": -1.0, "deployed_s": -1.0}


func test_the_stage_deploys_hunters2_while_the_sirens_drive_through() -> void:
	var off := _cell([])
	print("MEASURE herringbone lab lead -10: %s" % off)
	assert_true(float(off["hunters2_s"]) >= 0.0 and float(off["deployed_s"]) >= float(off["hunters2_s"]),
			"Hunters2 arrives, then deploys: %s" % off)
	assert_true(float(off["deployed_s"]) < float(off["sirens_s"]), "it deploys before the Sirens are in (they pass it): %s" % off)
	assert_true(float(off["sirens_s"]) > 0.0, "the Sirens get in: %s" % off)
