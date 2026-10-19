extends TestCase
## Round 28 (native N6.4): Pathing.is_ready / query / find_path natively (NativePathing -> pathing_native.cpp) against
## the LIVE GDScript on a baked Sumps: seeded from/to pairs across the arena and beyond it (goals off the mesh, in the
## air, below it), each wrapper both ways, bit for bit (var_to_bytes), under every combination of the switches the
## wrappers read (BrainSwitches.ready_memo, native_nav) and with Pathing.enabled off.

const PAIRS := 300


static func _bytes(value: Variant) -> PackedByteArray:
	return var_to_bytes(value)


func test_pathing_wrappers_are_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the pathing equality is not exercised in this run")
		return
	assert_true(NativePathing.configure(), "the native wrappers take the live Pathing")
	var arena := await ArenaFixture.build(self, "sumps")
	var was_pathing := BrainSwitches.native_pathing
	var was_memo := BrainSwitches.ready_memo
	var was_nav := BrainSwitches.native_nav
	var was_enabled := Pathing.enabled
	var rng := RandomNumberGenerator.new()
	rng.seed = 2830
	var compared := 0
	var mismatches := 0
	var first := ""
	var reachable := 0
	var unreachable := 0
	for combo in 5:
		BrainSwitches.ready_memo = combo % 2 == 0
		BrainSwitches.native_nav = combo < 2
		Pathing.enabled = combo != 4
		for n in PAIRS / 5:
			var from := Vector3(rng.randf_range(-150.0, 150.0), 0.0, rng.randf_range(-150.0, 150.0))
			var to := Vector3(rng.randf_range(-190.0, 190.0), rng.randf_range(-2.0, 4.0) if n % 4 == 0 else 0.0,
					rng.randf_range(-190.0, 190.0))
			BrainSwitches.native_pathing = false
			var live := [Pathing.is_ready(arena), Pathing.query(arena, from, to), Pathing.find_path(arena, from, to),
					Pathing._ready_answer, Pathing._ready_iteration]
			BrainSwitches.native_pathing = true
			var native := [Pathing.is_ready(arena), Pathing.query(arena, from, to), Pathing.find_path(arena, from, to),
					Pathing._ready_answer, Pathing._ready_iteration]
			compared += 1
			if _bytes(live) != _bytes(native):
				mismatches += 1
				if first == "":
					first = "combo %d %s -> %s: live %s native %s" % [combo, from, to, live, native]
			if live[1]["reachable"]:
				reachable += 1
			elif live[1]["ready"]:
				unreachable += 1
	# The memo's first fill natively: a stale memo (another map) refilled the same way.
	BrainSwitches.ready_memo = true
	Pathing.enabled = true
	Pathing._ready_map = RID()
	BrainSwitches.native_pathing = true
	var native_fill := [Pathing.is_ready(arena), Pathing._ready_map, Pathing._ready_iteration, Pathing._ready_answer]
	Pathing._ready_map = RID()
	BrainSwitches.native_pathing = false
	var live_fill := [Pathing.is_ready(arena), Pathing._ready_map, Pathing._ready_iteration, Pathing._ready_answer]
	if live_fill != native_fill:
		mismatches += 1
		if first == "":
			first = "memo fill: live %s native %s" % [live_fill, native_fill]
	BrainSwitches.native_pathing = was_pathing
	BrainSwitches.ready_memo = was_memo
	BrainSwitches.native_nav = was_nav
	Pathing.enabled = was_enabled
	print("native pathing: %d pairs (%d reachable, %d not), %d mismatches" % [compared, reachable, unreachable, mismatches])
	assert_eq(mismatches, 0, "the native pathing wrappers are the live GDScript: %s" % first)
	assert_true(reachable >= 50, "a real sample (%d reachable, %d not)" % [reachable, unreachable])
