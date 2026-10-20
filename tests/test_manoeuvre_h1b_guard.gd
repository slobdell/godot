extends "res://tests/manoeuvre/h1b_stage.gd"
## Round 32 (manoeuvre H1b, C32.2): **no loop, nothing to do.** An IFV short of a parked squadmate is held still by
## avoidance (phase blocked, never pressing, the stall rule never fires: 0 fires in both arms over 40 s, builder0,
## 373de208), so H1b never acts and the hull does what base does. Split from test_manoeuvre_h1b.gd (C32.8).

const GUARD_SECONDS := 20.0


func test_an_ifv_held_off_a_parked_squadmate_is_left_alone() -> void:
	var now := await _parked(true, "ifv", 11.0, -1.0, GUARD_SECONDS)
	var base := await _parked(false, "ifv", 11.0, -1.0, GUARD_SECONDS)
	_report("ifv held off a parked squadmate", now, base)
	assert_eq(base["fires"], 0, "setup: avoidance holds the IFV off, no escape fires at base")
	assert_eq(now["fires"], 0, "none with H1b either")
	assert_eq(int((now["h1b"] as Dictionary)["settles"]), 0, "H1b never settles a hull that is not looping")
	assert_eq(now["phase"], base["phase"], "the same phase as base (%s)" % now["phase"])
	assert_true(absf(float(now["gap_to_goal"]) - float(base["gap_to_goal"])) < 0.05, "the same place (%.2f v %.2f m)" % [now["gap_to_goal"], base["gap_to_goal"]])


## Round 35 (manoeuvre W1c): the same IFV with the stall gate reading the drive's intent against the squadmate it is held off:
## the stall is seen through avoidance's crawl and H1's escape fires (the asker's half of W1c; the parked squadmate's answer is
## traffic's T9).
func test_with_the_stall_intent_the_held_ifv_escapes() -> void:
	var w1c := await _parked(false, "ifv", 11.0, -1.0, GUARD_SECONDS, true)
	var base := await _parked(false, "ifv", 11.0, -1.0, GUARD_SECONDS)
	_report("ifv held off a parked squadmate, W1c ON", w1c, base)
	assert_true(int(w1c["fires"]) > 0, "W1c: H1's escape fires (%d; base %d)" % [w1c["fires"], base["fires"]])
