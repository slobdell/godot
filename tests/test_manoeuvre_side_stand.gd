extends "res://tests/manoeuvre/h1b_side_stage.gd"
## Round 37, manoeuvre M1 (`--nav-off=sidestand` flips SIDE_STAND_DEFAULT): **a crew does not step aside again and again into the
## same friend.** R36.31: Rust_Eyes_3 (locks-6550) picked 9 side points on one parked artillery seen at an angle, ~3 s apart, for
## 1.0 m of net motion: the drive to the side point clips the long friend's corner. Bar M1's deciding lines (workstreams.md
## *Bars (round 37)*); the stage: tests/manoeuvre/h1b_side_stage.gd, walls "eyes3:<yaw deg>" (the trace's own spot on the Locks,
## the artillery's yaw the parameter: its axis 45-55 deg off the scout's lane at 135-125).
##
## Measured (GDScript, laptop, 2026-10-21): yaw 125, 130 and 135 loop in base (4 side points within 0.5 m of each other, all
## beside the corner, 9-10 fires in 30 s); 140 takes one step and gets past in both arms; 110-115 and 145 never reach the rule.

const LOOPING := ["eyes3:125", "eyes3:130", "eyes3:135"]
const ONE_STEP := "eyes3:140"
const BASE_STEPS := 3


## The deciding line: where base steps aside again and again, ON takes one step, then stands without another fire.
func test_a_long_friend_at_an_angle_gets_one_side_step_then_a_stand() -> void:
	for walls: String in LOOPING:
		var now := await far_loop(true, false, walls, false, "sidestand")
		var base := await far_loop(false, false, walls, false, "sidestand")
		report("angled " + walls, now, base)
		assert_true(int(base["steps"]) >= BASE_STEPS and int(base["repeats"]) >= BASE_STEPS - 1 and base["past_at"] < 0.0,
				"%s premise: base steps aside again and again (%d steps, %d repeats) and never gets past" % [walls, base["steps"], base["repeats"]])
		assert_eq(int(now["steps"]), 1, "%s: one side step" % walls)
		assert_eq(int(now["restands"]), 1, "%s: then a stand on the same unmoved friend" % walls)
		var fires: Array = now["fire_times"]
		assert_eq((base["fire_times"] as Array).slice(0, fires.size()), fires, "%s: inert up to the stand (the stand's fire is the last)" % walls)
		assert_true(now["late_moved_m"] < 0.5 and int(now["pressing_late"]) == 0,
				"%s: still after it (moved %.2f m, pressing %d ticks in the last %.0f s)" % [walls, now["late_moved_m"], now["pressing_late"], STILL_SECONDS])


## Guard: where one side step gets the crew past, nothing changes.
func test_one_side_step_that_works_is_unchanged() -> void:
	var now := await far_loop(true, false, ONE_STEP, false, "sidestand")
	var base := await far_loop(false, false, ONE_STEP, false, "sidestand")
	report("angled " + ONE_STEP, now, base)
	assert_true(base["past_at"] >= 0.0 and int(base["steps"]) == 1, "premise: one step gets base past (%d steps, past at %.1f s)" % [base["steps"], base["past_at"]])
	assert_eq(int(now["restands"]), 0, "no stand")
	assert_eq(now["fire_times"], base["fire_times"], "the same fires")
	assert_eq(now["at"], base["at"], "the same end position")


## Both paths: the native drive reads `_side_stand` / `_side_to` that the GDScript callback sets; it matches GDScript in both arms.
func test_the_native_path_matches_gdscript_in_both_arms() -> void:
	if not NativeBridge.available:
		print("SKIP side_stand native: no native library")
		return
	for on: bool in [true, false]:
		for walls: String in ["eyes3:135", ONE_STEP]:
			var native := await far_loop(on, true, walls, false, "sidestand")
			var script := await far_loop(on, false, walls, false, "sidestand")
			report("native %s %s" % ["ON" if on else "base", walls], native, script)
			assert_eq(native["fire_times"], script["fire_times"], "%s %s: the same fires" % [on, walls])
			assert_eq(native["restands"], script["restands"], "%s %s: the same stands" % [on, walls])
			var gap := Vector2(float(native["at"][0]) - float(script["at"][0]), float(native["at"][1]) - float(script["at"][1])).length()
			assert_true(gap <= 0.05, "%s %s: the same end position (%.3f m apart)" % [on, walls, gap])
