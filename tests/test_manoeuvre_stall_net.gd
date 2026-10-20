extends "res://tests/manoeuvre/stall_net_stage.gd"
## Round 36, manoeuvre S1 (C36.3, `--nav-off=stallnet` flips STALL_NET_DEFAULT): **a hull wedged between two friends gets
## out.** X1(d): wedged at full throttle in a gap narrower than itself, the contact pops one fast tick about once a second
## and today's stall rule zeroes its clock on that tick, so H1's escape never starts (law-716 Green_Guns_7 rocked ~50 s).
## Stallnet resets the clock only on NET motion (> STUCK_NET_M from where it started). The bar's DECIDING line: in the
## pinch stage ON fires an escape within FIRE_BY_S of wedging; base never does in SECONDS (the pinned premise), on both
## paths (the native drive runs only the tree's default arm: see `native_arm`).
##
## The stage: tests/manoeuvre/stall_net_stage.gd (the wedge is physical, the traced pop is injected).


func test_a_wedged_hull_whose_contact_pops_escapes_with_stallnet() -> void:
	var now := await pinch(true, false)
	var base := await pinch(false, false)
	report("gdscript", now, base)
	assert_true(now["wedged_at"] >= 0.0 and base["wedged_at"] >= 0.0, "setup: the hull wedges (ON %.2f s, base %.2f s)" % [now["wedged_at"], base["wedged_at"]])
	assert_true((base["blockers"] as Dictionary).keys().any(func(k: String) -> bool: return k.begins_with("Green_Hunters")),
			"setup: the honest path names a parked friend as the pin (%s)" % [base["blockers"]])
	assert_true(base["pops"] >= 10, "setup: the traced pop recurs while it presses (%d)" % base["pops"])
	assert_eq(int(base["fires"]), 0, "premise: today's rule never fires in %.0f s (first fire %.2f s after wedging, max clock %.2f)" % [SECONDS, base["fire_after"], base["max_clock"]])
	assert_true(now["fire_after"] >= 0.0 and now["fire_after"] <= FIRE_BY_S, "stallnet: an escape within %.0f s of wedging (%.2f s)" % [FIRE_BY_S, now["fire_after"]])
	assert_true(int(now["fires_hull"]) >= 1, "the escape is H1's against the friend (hull fires %d)" % now["fires_hull"])
	assert_true(int(now["holds"]) > 0, "the arm counter moves (holds %d)" % now["holds"])


## Without the pop, the wedge is today's: both arms fire at the same tick (stallnet changes only the fast-tick reset).
func test_without_the_pop_both_arms_fire_alike() -> void:
	var now := await pinch(true, false, 0)
	var base := await pinch(false, false, 0)
	report("gdscript no pop", now, base)
	assert_true(base["fire_after"] >= 0.0, "today's rule fires on a clean wedge (%.2f s)" % base["fire_after"])
	assert_eq(now["first_fire"], base["first_fire"], "the same first fire")
	assert_eq(int(now["fires"]), int(base["fires"]), "and the same fires in %.0f s" % SECONDS)


## The native drive (the tree's default arm) reads what GDScript reads, tick for tick on this stage.
func test_the_native_path_matches_gdscript_in_the_default_arm() -> void:
	if not NativeBridge.available:
		print("SKIP stall_net native: no native library")
		return
	var native := await pinch(native_arm(), true)
	var script := await pinch(native_arm(), false)
	report("native default arm (%s)" % ("ON" if native_arm() else "base"), native, script)
	assert_eq(native["first_fire"], script["first_fire"], "first fire")
	assert_eq(int(native["fires"]), int(script["fires"]), "fires")
	assert_eq(int(native["holds"]), int(script["holds"]), "holds (the counter)")
