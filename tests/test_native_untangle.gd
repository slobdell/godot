extends TestCase
## Round 45 (native N2b, R45.3): SelectionSquads.untangle_whole natively (NativeUntangle -> untangle_native.cpp) against its
## LIVE GDScript body (BrainSwitches.native_untangle off), bit for bit (var_to_bytes of the places, the return and both
## counters), on tests/test_untangle_whole_memo.gd's knots (random and crowded: shared ends, collinear drives) at 2-7 squads,
## with each optional reading (leads + arc, misplaced), a loose block's extra anchor past the squads, and a squad with no crews.
## (The memo test itself compares the function, native when present, to the round-43 reference: the second guard.)

const Memo := preload("res://tests/test_untangle_whole_memo.gd")
const TRIALS := 1200


static func _run(knot: Dictionary, leads: Array, arc: Callable, misplaced: Callable, native: bool) -> PackedByteArray:
	BrainSwitches.native_untangle = native
	var anchors: Array[Vector3] = (knot["anchors"] as Array[Vector3]).duplicate()
	var still := SelectionSquads.whole_still_crossed
	var swapped := SelectionSquads.swapped_whole
	var position := func(n: String) -> Vector3: return knot["positions"][n]
	var moved := SelectionSquads.untangle_whole(knot["squads"], anchors, position, leads, arc, misplaced)
	return var_to_bytes([anchors, moved, SelectionSquads.whole_still_crossed - still, SelectionSquads.swapped_whole - swapped])


func test_native_untangle_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the untangle equality is not exercised in this run")
		return
	var was := BrainSwitches.native_untangle
	var rng := RandomNumberGenerator.new()
	rng.seed = 4503
	var mismatches := 0
	var moved_any := 0
	var first := ""
	for trial in TRIALS:
		var squads_n := 2 + trial % 6  # 2..7
		var knot: Dictionary = Memo._knot(rng, squads_n, trial % 3 == 0)
		if trial % 10 == 4:
			(knot["squads"] as Array)[0]["units"] = []  # a squad with no crews left
		if trial % 5 == 2:
			(knot["anchors"] as Array[Vector3]).append(Vector3(rng.randf_range(-60.0, 60.0), 0.0, rng.randf_range(-60.0, 60.0)))
		var leads: Array = []
		var arc := Callable()
		var misplaced := Callable()
		if trial % 4 == 1 or trial % 4 == 3:
			for i in squads_n:
				leads.append(snappedf(rng.randf_range(0.0, 80.0), 5.0 if trial % 8 == 1 else 0.001))
			arc = func(p: Vector3) -> float: return snappedf(p.length(), 5.0)
		if trial % 4 >= 2:
			var side := rng.randf_range(-1.0, 1.0)
			misplaced = func(i: int, p: Vector3) -> bool: return (i % 2 == 0) != (p.x > side * 30.0)
		var live := _run(knot, leads, arc, misplaced, false)
		var native := _run(knot, leads, arc, misplaced, true)
		moved_any += int(bytes_to_var(live)[1] > 0)
		if live != native:
			mismatches += 1
			if first == "":
				first = "trial %d (%d squads): live %s native %s" % [trial, squads_n, bytes_to_var(live), bytes_to_var(native)]
	BrainSwitches.native_untangle = was
	print("MEASURE native_untangle compared=%d mismatches=%d moved=%d" % [TRIALS, mismatches, moved_any])
	assert_eq(mismatches, 0, "native untangle_whole = the GDScript on every knot (%d); first: %s" % [TRIALS, first])
	assert_true(moved_any > 200, "the comparison exercised re-dealt places (%d of %d knots moved)" % [moved_any, TRIALS])
