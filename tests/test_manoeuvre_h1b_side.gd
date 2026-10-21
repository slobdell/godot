extends "res://tests/manoeuvre/h1b_side_stage.gd"
## Round 36, manoeuvre S2a (`--nav-off=h1bside` flips H1B_SIDE_DEFAULT): **a crew H1-looping on a friend that will not give
## way goes round it, or stands.** X4b: 10 of 17 crews left behind and still re-rammed a parked friend every ~7 s to the judge.
## Bar S2a's deciding lines; the stage: tests/manoeuvre/h1b_side_stage.gd (the friend's controller is off: it never answers).

const PAST_BY_S := 20.0
const BASE_FIRES := 3


## (a) A friend closes one side: the far loop goes round on the other and gets past; base re-rams.
func test_room_on_one_side_goes_round() -> void:
	var now := await far_loop(true, false, "left")
	var base := await far_loop(false, false, "left")
	report("room on one side", now, base)
	assert_true(base["fires"] >= BASE_FIRES and base["past_at"] < 0.0, "premise: base re-rams (%d fires at %s) and never gets past" % [base["fires"], base["fire_times"]])
	assert_true(int(base["far"]) >= 1, "premise: base's loop is H1b's FAR case (%d far loops)" % base["far"])
	assert_true(now["past_at"] >= 0.0 and now["past_at"] <= PAST_BY_S, "h1bside: past the friend within %.0f s (%.1f s)" % [PAST_BY_S, now["past_at"]])
	assert_eq(int(now["steps"]), 1, "one side step")
	assert_eq(int(now["fires_after_far"]), 0, "and no fire after it")


## (b) A one-hull street (parked friends abreast on both sides): the far loop stands instead of re-ramming.
func test_a_one_hull_street_stands() -> void:
	var now := await far_loop(true, false, "both")
	var base := await far_loop(false, false, "both")
	report("one-hull street", now, base)
	assert_true(base["fires"] >= BASE_FIRES, "premise: base re-rams (%d fires at %s)" % [base["fires"], base["fire_times"]])
	assert_true(now["first_far"] >= 0.0, "the far loop is reached (%.1f s)" % now["first_far"])
	assert_eq(int(now["stands"]), 1, "it stands (no side clear)")
	assert_eq(int(now["fires_after_far"]), 0, "no escape fire after its first far loop (fires at %s)" % [now["fire_times"]])
	assert_true(now["late_moved_m"] < 0.5 and int(now["pressing_late"]) == 0, "still in the last %.0f s (moved %.2f m, pressing %d ticks)" % [STILL_SECONDS, now["late_moved_m"], now["pressing_late"]])


## The native drive (the tree's default arm) does what GDScript does on both stages.
func test_the_native_path_matches_gdscript_in_the_default_arm() -> void:
	if not NativeBridge.available:
		print("SKIP h1b_side native: no native library")
		return
	for walls in ["left", "both"]:
		var native := await far_loop(native_arm(), true, walls)
		var script := await far_loop(native_arm(), false, walls)
		report("native default arm (%s) %s" % ["ON" if native_arm() else "base", walls], native, script)
		assert_eq(native["fire_times"], script["fire_times"], "%s: the same fires" % walls)
		assert_eq(native["past_at"], script["past_at"], "%s: the same pass" % walls)
		var gap := Vector2(float(native["at"][0]) - float(script["at"][0]), float(native["at"][1]) - float(script["at"][1])).length()
		assert_true(gap <= 0.05, "%s: the same end position (%.3f m apart)" % [walls, gap])


## (c, R36.27) Beside water: a side point never leaves the hull's own bank or lands on a bridge deck, on either path.
## "bank": the friend's water side a metre off the Locks' canal rim, the goal a little towards the water (the water side is the
## nearer point): the rule must refuse it and go round on the land side. "mouth": the friend at the central bridge's north
## mouth with a second friend abreast on its land side. The rim is cut at a bridge, so the open deck mouth is room: both arms
## drive round over it with no H1 fire (measured, builder0 light, 2026-10-21), and the side rule never arises. That line is
## pinned as ON = base, so a change that starts sending crews onto a deck from here shows.
func _assert_on_its_bank(label: String, run: Dictionary) -> void:
	for p: Array in run["side_points"]:
		assert_true(float(p[1]) > CANAL_HALF_M, "%s: side point %s on the hull's own (north) bank" % [label, p])
		assert_true(not (absf(float(p[0])) <= DECK_HALF_X and absf(float(p[1])) <= DECK_HALF_Z), "%s: side point %s off the deck" % [label, p])
	assert_true(float(run["min_z"]) > CANAL_HALF_M, "%s: the hull never entered the canal (least z %.2f)" % [label, run["min_z"]])


func test_beside_the_canal_the_side_point_stays_on_its_bank() -> void:
	var paths := [false, true] if NativeBridge.available else [false]
	for native: bool in paths:
		var label := "native" if native else "GDScript"
		var now := await far_loop(true, native, "bank")
		var base := await far_loop(false, false, "bank")
		report("bank %s" % label, now, base)
		assert_true(int(base["fires"]) >= BASE_FIRES and base["past_at"] < 0.0, "premise: base re-rams beside the canal (%d fires)" % base["fires"])
		assert_eq(int(now["steps"]), 1, "bank %s: one side step (the water side refused, the land side taken)" % label)
		_assert_on_its_bank("bank " + label, now)
		assert_true(now["past_at"] >= 0.0 and now["past_at"] <= PAST_BY_S, "bank %s: past the friend within %.0f s (%.1f s)" % [label, PAST_BY_S, now["past_at"]])
		var mouth := await far_loop(true, native, "mouth")
		var mouth_base := await far_loop(false, false, "mouth")
		report("mouth %s" % label, mouth, mouth_base)
		assert_eq(int(mouth["steps"]) + int(mouth["stands"]), 0, "mouth %s: the deck mouth is room, the side rule never arises" % label)
		assert_eq(mouth["at"], mouth_base["at"], "mouth %s: ON drives as base" % label)
		_assert_on_its_bank("mouth " + label, mouth)
