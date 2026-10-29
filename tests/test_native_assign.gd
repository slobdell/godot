extends TestCase
## Round 45 (native, R45.16): SelectionSquads._assign natively (NativeAssign -> assign_native.cpp) against its LIVE GDScript
## (BrainSwitches.native_assign off), bit for bit, on random and crowded point sets (0-6 squads; more slots than squads; slots on a
## coarse grid so totals tie and the first-best rule decides; duplicate points). Past SEARCH_LIMIT the seam steps aside (least_total).

const TRIALS := 3000


static func _points(rng: RandomNumberGenerator, n: int, grid: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in n:
		var p := Vector3(rng.randf_range(-80.0, 80.0), rng.randf_range(-1.0, 1.0) if i % 3 == 0 else 0.0, rng.randf_range(-80.0, 80.0))
		if grid > 0.0:
			p = Vector3(snappedf(p.x, grid), 0.0, snappedf(p.z, grid))
		out.append(p)
	return out


func test_native_assign_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the assign equality is not exercised in this run")
		return
	var was := BrainSwitches.native_assign
	var rng := RandomNumberGenerator.new()
	rng.seed = 4516
	var mismatches := 0
	var moved := 0
	var first := ""
	for trial in TRIALS:
		var n := trial % (SelectionSquads.SEARCH_LIMIT + 1)  # 0..6
		var grid := 20.0 if trial % 3 == 0 else 0.0
		var centers := _points(rng, n, grid)
		var slots := _points(rng, n + (1 if trial % 4 == 1 else 0) + (2 if trial % 8 == 5 else 0), grid)
		if trial % 11 == 7 and n >= 2:
			slots[1] = slots[0]  # two seats on one point
		BrainSwitches.native_assign = false
		var live := SelectionSquads._assign(centers, slots)
		BrainSwitches.native_assign = true
		var native := SelectionSquads._assign(centers, slots)
		for k in live.size():
			if live[k] != k:
				moved += 1
				break
		if var_to_bytes(live) != var_to_bytes(native):
			mismatches += 1
			if first == "":
				first = "trial %d n %d: live %s native %s" % [trial, n, live, native]
	BrainSwitches.native_assign = was
	print("MEASURE native_assign compared=%d mismatches=%d moved=%d" % [TRIALS, mismatches, moved])
	assert_eq(mismatches, 0, "native _assign = the GDScript on every set (%d); first: %s" % [TRIALS, first])
	assert_true(moved > 1000, "the comparison exercised non-identity assignments (%d of %d)" % [moved, TRIALS])
