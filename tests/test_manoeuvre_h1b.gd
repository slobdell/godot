extends "res://tests/manoeuvre/h1b_stage.gd"
## Round 32, manoeuvre H1b (C32.2, `--nav-off=h1b` = ON, opt-in until judged): **the ask that never frees.** H1 asks
## the friend that pins it, backs off straight and drives the route again. A squadmate parked at its own slot never
## moves for that ask, so the pinned hull looped (Terminus rigs seed 31: Green_S0_4 on Green_S0_2, ask, back 2-3 m,
## drive back in about every 21 s, asks 29, backs 29). H1b: after H1B_ASKS failed asks on the SAME unmoved friend, a
## hull whose goal is within H1B_SETTLE_MAX_M settles where it stands (the goal re-grounded through the repair channel
## the brain completes on) and never re-drives into it.
##
## The stage: tests/manoeuvre/h1b_stage.gd (the no-loop IFV guard is test_manoeuvre_h1b_guard.gd).


## Seed 31's shape: a War Rig sent to a slot a parked squadmate sits on. Base loops (the defect); H1b settles after two
## failed asks and never fires again.
func test_a_war_rig_behind_a_parked_squadmate_settles_instead_of_looping() -> void:
	var now := await _parked(true, "gang_tank", 18.0, -3.0)
	var base := await _parked(false, "gang_tank", 18.0, -3.0)
	_report("gang_tank on a parked squadmate", now, base)
	assert_true(base["fires"] > Movement.H1B_ASKS + 1, "setup: base loops on the parked friend (%d fires at %s)" % [base["fires"], base["fire_times"]])
	assert_true(now["fires"] <= Movement.H1B_ASKS + 1, "H1b: at most %d fires, then it stops (%d at %s)" % [Movement.H1B_ASKS + 1, now["fires"], now["fire_times"]])
	assert_true(now["repaired"] and now["phase"] == "arrived", "it settled where it stands, the order completable (phase %s, repaired %s)" % [now["phase"], now["repaired"]])
	assert_true(now["late_moved_m"] < 0.5 and now["pressing_late"] == 0, "and sits still (moved %.2f m, pressing %d ticks in the last %.0f s)" % [now["late_moved_m"], now["pressing_late"], STILL_SECONDS])
	assert_eq(int((now["h1b"] as Dictionary)["settles"]), 1, "one settle")
	assert_eq(int((now["h1b"] as Dictionary)["loops"]), 0, "and no loop left (base: %d)" % int((base["h1b"] as Dictionary)["loops"]))


## Switched off, H1b never acts (round 31's escape bit for bit); its bookkeeping still counts the loops, which is the
## base arm's number for the bar.
func test_switched_off_h1b_never_acts_and_counts_the_loops() -> void:
	var base := await _parked(false, "gang_tank", 18.0, -3.0)
	var counts: Dictionary = base["h1b"]
	assert_eq(int(counts["settles"]) + int(counts["far"]), 0, "H1b never acts with the switch off (%s)" % counts)
	# Fire 1 starts the count, fires 2 and 3 are the two failed asks; from fire 3 on (where H1b would settle) each is a loop.
	assert_eq(int(counts["loops"]), int(base["fires"]) - Movement.H1B_ASKS,
			"every fire from the second failed ask on is a loop (%s, fires %d)" % [counts, base["fires"]])
	assert_true(not base["repaired"], "nothing re-grounded the goal")
