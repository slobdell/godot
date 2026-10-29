extends TestCase
## Round 45 (native N2, C45.4): RtsControls.gate_width_edge_on natively (NativeGateWidth -> gate_width_native.cpp) against the LIVE
## GDScript gate_width with the column lay's own Callables (drive_on(ground), crosses_or_edge(crosses_on(ground))), bit for
## bit (var_to_bytes), on arenas with bridge decks (crossing), drops and water (gorge, locks) and a city (terminus): seeded
## clicks across each arena and past its edge, every heading, both scans the callers use and both post spans, and clicks ON a
## deck (crosses_on's early "no"). A comparison that only ever reads open ground proves nothing, so the deciding branches are
## counted and must each be taken: a side cut by a deck, by the arena's edge, by a long way round, and read past a post.

const CLICKS := 90
const ARENAS: Array[String] = ["crossing", "gorge", "locks", "terminus"]


static func _bytes(value: Variant) -> PackedByteArray:
	return var_to_bytes(value)


func test_native_gate_width_is_the_live_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the gate_width equality is not exercised in this run")
		return
	assert_true(NativePathing.configure(), "the native gate rides on Pathing's configured wrappers")
	var was := BrainSwitches.native_gate_width
	var rng := RandomNumberGenerator.new()
	rng.seed = 4502
	var compared := 0
	var mismatches := 0
	var first := ""
	var branches := {"deck": 0, "edge": 0, "detour": 0, "posts": 0, "click_on_deck": 0, "full": 0}
	for arena_name in ARENAS:
		var arena := await ArenaFixture.build(self, arena_name)
		var drive := SelectionSquads.drive_on(arena)
		var crosses_raw := SelectionSquads.crosses_on(arena)
		var crosses := SelectionSquads.crosses_or_edge(crosses_raw)
		var decks := SlotGround.deck_boxes()
		var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE))
		for n in CLICKS:
			var click := Vector3(rng.randf_range(-half * 1.05, half * 1.05), rng.randf_range(-1.0, 2.0) if n % 7 == 0 else 0.0,
					rng.randf_range(-half * 1.05, half * 1.05))
			# a click ON a deck now and then (crosses_on answers "no" from a deck without reading a path)
			if n % 9 == 0 and not decks.is_empty():
				var box: Array = decks[rng.randi_range(0, decks.size() - 1)]
				click = Vector3(lerpf(float(box[0]), float(box[2]), rng.randf()), 0.0, lerpf(float(box[1]), float(box[3]), rng.randf()))
			var heading := rng.randf_range(0.0, TAU)
			var across := Vector3(cos(heading), 0.0, sin(heading))
			var scan: float = [SelectionSquads.GROUP_SCAN_M, RtsControls.GATE_SCAN_M][n % 2]
			var posts: float = [0.0, RtsControls.POST_SPAN_M][(n / 2) % 2]
			BrainSwitches.native_gate_width = false
			var live := RtsControls.gate_width_edge_on(arena, click, across, drive, crosses, scan, posts)
			var reference := RtsControls.gate_width(click, across, drive, crosses, scan, posts)
			BrainSwitches.native_gate_width = true
			var native := RtsControls.gate_width_edge_on(arena, click, across, drive, crosses, scan, posts)
			compared += 1
			if _bytes(live) != _bytes(reference) or _bytes(live) != _bytes(native):
				mismatches += 1
				if first == "":
					first = "%s click %s across %s scan %.0f posts %.0f: live %s native %s" % [arena_name, click, across, scan,
							posts, live, native]
			_count(branches, live, click, across, scan, posts, drive, crosses, crosses_raw)
		arena.free()
	BrainSwitches.native_gate_width = was
	print("MEASURE native_gate_width compared=%d mismatches=%d branches=%s" % [compared, mismatches, branches])
	assert_eq(mismatches, 0, "native gate_width = the GDScript on every click (%d compared); first: %s" % [compared, first])
	for branch: String in branches:
		assert_true(int(branches[branch]) > 0, "the comparison took the '%s' branch at least once (%s)" % [branch, branches])


## Which rule ended each side (read once more with the GDScript Callables, after the comparison).
static func _count(branches: Dictionary, sides: Array[float], click: Vector3, across: Vector3, scan: float, posts: float,
		drive: Callable, crosses: Callable, crosses_raw: Callable) -> void:
	var flat_click := Vector3(click.x, 0.0, click.z)
	if SlotGround.near_deck(flat_click, 0.0):
		branches["click_on_deck"] += 1
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var reach := sides[i]
		if reach >= scan - 0.01:
			branches["full"] += 1
			continue
		# the first step past the reach that the scan stopped at or skipped
		var k := int(round(reach / RtsControls.GATE_STEP_M)) + 1
		while k * RtsControls.GATE_STEP_M <= scan + 0.001:
			var d := k * RtsControls.GATE_STEP_M
			var p := flat_click + across * (side * d)
			if bool(crosses.call(flat_click, p)):
				branches["deck" if bool(crosses_raw.call(flat_click, p)) else "edge"] += 1
				break
			var by_ground := float(drive.call(flat_click, p))
			if by_ground < 0.0 or by_ground > RtsControls.GATE_DETOUR * d + 1.0:
				if d - reach > posts:
					branches["detour"] += 1
					break
				if posts > 0.0:
					branches["posts"] += 1
			k += 1
