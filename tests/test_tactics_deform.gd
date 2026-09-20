extends TestCase
## Round 9, squad X2 (catalogue A8): a formation is a nominal shape plus a per-element deformation, continuous in the
## corridor width — a wedge narrows to fit a defile and re-expands after it, without dissolving, without changing
## formation, and without re-seating anybody.
##
## The falsifier A8 pre-registered is "zero slot crossings / rank inversions during defile passage". These tests
## assert that BY CONSTRUCTION rather than by counting it in a match: the deformation is a pure function of the
## corridor width, so it can be swept. Three properties, and each one is the reason a piece of the design is shaped
## the way it is:
##
##   1. HULLS STAY CLEAR at every corridor width (X1's rule, which is why the squeeze is not a bare 2x2 — a matrix
##      that squeezes a wedge's frontage to nothing stands slots 1 and 2 on top of each other).
##   2. THE DEPTH ORDER NEVER INVERTS as the corridor narrows (which is why the file's target is the shape's own
##      depth order and not the slot index — a vee has slots AHEAD of its leader).
##   3. THE FRONTAGE IS MONOTONE in the corridor width, with no snap at any width.
##
## Expectations come from `Units.PROFILES` and `DoctrineTable.SPACING_DEFAULTS`, never from metres written here, so
## CP2's resize changes no code in this file.

## **These tests turn A8 ON for their own duration, and they have to.** `TacticsFormation.DEFORM_ENABLED` ships FALSE
## because the deformation made a real traverse worse (`make squad-defile`: 0 of 5 arrived with it on against 4 of 5
## with it off). But the GEOMETRY below is still the geometry A8 will have when that seam is fixed, and it is what
## makes the invariants safe to rely on — so the suite asserts it regardless of whether the mechanism is switched on
## in the game.
##
## This was not free advice: I flipped the flag and did not re-run this file. Two of these tests **failed on builder0**
## and the rest went **vacuous** — with the flag off `fit_to_corridor` returns the identity, so a sweep that asserts
## "hulls stay clear at every corridor width" was asserting that an undeformed formation is clear, which X1 already
## guarantees. A test suite for a switched-off mechanism must switch it on, or it tests nothing and says it passed.
const SHAPES := ["column", "wedge", "vee", "line", "echelon_left", "echelon_right", "coil", "swarm", "ring",
		"rows", "block"]


## Turn A8 on for this test. There is no `setup()` hook in `TestCase` — `run_tests.gd` calls the method and then
## `teardown()` — so every test here calls this as its first line, and `teardown()` puts the flag back.
func _a8() -> void:
	TacticsFormation.DEFORM_ENABLED = true


## Restores the switch, and NOTHING ELSE -- no `super.teardown()`, deliberately.
##
## `TestCase._teardown()` is the runner's hook and it calls `teardown()` and then `free_owned()` itself, so freeing and
## draining are no longer this override's business; calling super would only run `free_owned()` twice. The reason to
## write it down rather than just delete the line: before nav sealed the drain (`49ed1fb3`), `teardown()` was the thing
## that awaited, and **a `-> void` override calling a base that awaits detaches it silently** -- the call looks correct,
## compiles, and runs, it just does not finish. That is the same family as a facing that reaches `plan` but not the
## orders: code that executes in the right place at the wrong time.
func teardown() -> void:
	TacticsFormation.DEFORM_ENABLED = false
## Corridor widths swept, in metres. From narrower than any vehicle to wider than any arena gap.
const WIDTHS: Array[float] = [5.0, 6.0, 7.0, 8.0, 10.0, 12.0, 14.0, 17.0, 20.0, 24.0, 28.0, 33.0, 40.0, 50.0, 70.0]


func _squad(faction: String, size := 5) -> Array:
	var ids := Units.roster(faction)
	var members: Array = []
	for i in size:
		var unit := String(ids[i % ids.size()])
		members.append({"name": "%s_%d" % [faction, i], "unit": unit,
				"position": Vector3(i * 3.0, 0.0, 0.0), "role": Units.role_of(unit)})
	return members


func _longest_squad(size := 5) -> Array:
	var longest := ""
	for unit_id in Units.ids():
		var hull: Array = Units.stat(unit_id, "hull_size", [0.0, 0.0, 0.0])
		var length := maxf(float(hull[0]), float(hull[2]))
		if longest == "" or length > maxf(float(Units.stat(longest, "hull_size")[0]),
				float(Units.stat(longest, "hull_size")[2])):
			longest = unit_id
	var members: Array = []
	for i in size:
		members.append({"name": "long_%d" % i, "unit": longest, "position": Vector3(i * 3.0, 0.0, 0.0),
				"role": Units.role_of(longest)})
	return members


func _fit(members: Array, shape: String, width: float, spacing := -1.0) -> Dictionary:
	var pitch := spacing if spacing > 0.0 else float(DoctrineTable.SPACING_DEFAULTS["open"])
	return TacticsFormation.fit_to_corridor(members, shape, members.size(), pitch, width)


func test_an_unknown_corridor_is_the_identity() -> void:
	# A formation must never be worse than today for the lack of a number: with no corridor measured the
	# deformation is X1's pitch and nothing else, on the same code path, so the sim hash cannot move for it.
	_a8()
	var members := _squad("gangs")
	var spacing := float(DoctrineTable.SPACING_DEFAULTS["open"])
	for width in [INF, 0.0, -1.0]:
		var fit := TacticsFormation.fit_to_corridor(members, "wedge", members.size(), spacing, width)
		assert_eq(fit["pitch"], TacticsFormation.pitch(members, spacing),
				"corridor %s: the pitch is X1's, untouched" % width)
		assert_near(float(fit["file"]), 0.0, 0.0001, "corridor %s: no morph" % width)
	for shape in SHAPES:
		var fit := TacticsFormation.fit_to_corridor(members, shape, members.size(), spacing, INF)
		assert_eq(TacticsFormation.offsets_deformed(shape, members.size(), fit),
				TacticsFormation.offsets_at(shape, members.size(), TacticsFormation.pitch(members, spacing)),
				"%s: an unmeasured corridor lays exactly the slots X1 lays" % shape)


func test_a_wide_corridor_deforms_nothing() -> void:
	_a8()
	var members := _longest_squad()
	var spacing := float(DoctrineTable.SPACING_DEFAULTS["open"])
	for shape in SHAPES:
		# Wider than the shape's own frontage plus its hulls and margins: there is nothing to deform for.
		var natural := TacticsFormation.frontage(shape, members.size(),
				TacticsFormation.pitch(members, spacing).x)
		var fit := _fit(members, shape, natural + TacticsFormation.hull_extent(members).x + 10.0)
		assert_near(float(fit["file"]), 0.0, 0.0001, "%s: a corridor wider than the shape leaves it alone" % shape)
		assert_true(bool(fit["fits"]), "%s: and it fits" % shape)


func test_hulls_stay_clear_at_every_corridor_width() -> void:
	_a8()
	var clear := TacticsFormation.HULL_CLEAR_M
	var squads := {"longest": _longest_squad()}
	for faction in Units.FACTIONS:
		squads[faction] = _squad(faction)
	for label: String in squads:
		var members: Array = squads[label]
		var hull := TacticsFormation.hull_extent(members)
		for terrain: String in DoctrineTable.SPACING_DEFAULTS:
			for shape in SHAPES:
				for width in WIDTHS:
					var fit := _fit(members, shape, width, float(DoctrineTable.SPACING_DEFAULTS[terrain]))
					var slots := TacticsFormation.offsets_deformed(shape, members.size(), fit)
					var closest := INF
					for i in slots.size():
						for j in range(i + 1, slots.size()):
							var apart: Vector2 = (slots[i] - slots[j]).abs()
							closest = minf(closest, maxf(apart.x - hull.x, apart.y - hull.y))
					assert_true(closest >= clear - 0.01,
							"%s %s in %s m of %s corridor: closest hulls %.2f m apart, needs %.2f" \
							% [label, shape, width, terrain, closest, clear])


func test_the_depth_order_never_inverts_as_the_corridor_narrows() -> void:
	# The falsifier: zero rank inversions during defile passage. Slot i keeps its index throughout (the deformation
	# does not re-seat), so an inversion can only be geometric — two slots swapping places along the heading.
	_a8()
	var members := _longest_squad()
	for shape in SHAPES:
		var nominal := TacticsFormation.group_offsets(shape, members.size(), 1.0)
		for width in WIDTHS:
			var fit := _fit(members, shape, width)
			var slots := TacticsFormation.offsets_deformed(shape, members.size(), fit)
			for i in slots.size():
				for j in range(i + 1, slots.size()):
					var was: float = nominal[i].y - nominal[j].y
					var now: float = slots[i].y - slots[j].y
					if absf(was) < 1e-6:
						continue  # the same depth to start with: any order is the order it had
					assert_true(was * now >= -1e-6,
							"%s at %s m: slots %d and %d swapped places along the heading (%.2f -> %.2f)" \
							% [shape, width, i, j, was, now])


func test_the_frontage_narrows_with_the_corridor_and_never_snaps() -> void:
	_a8()
	var members := _longest_squad()
	for shape in SHAPES:
		var last := -1.0
		var steps: Array = []
		for width in WIDTHS:
			var fit := _fit(members, shape, width)
			var slots := TacticsFormation.offsets_deformed(shape, members.size(), fit)
			var low := INF
			var high := -INF
			for slot in slots:
				low = minf(low, slot.x)
				high = maxf(high, slot.x)
			var frontage: float = high - low
			assert_true(frontage >= last - 0.01,
					"%s: a wider corridor is never a narrower formation (%s m gave %.1f after %.1f)" \
					% [shape, width, frontage, last])
			steps.append(frontage)
			last = frontage
		# No snap: no single metre of corridor may change the frontage by more than the corridor changed by, scaled
		# by how much frontage a metre of corridor buys at all (the shape's natural frontage over the widths swept).
		for i in range(1, steps.size()):
			var grew: float = float(steps[i]) - float(steps[i - 1])
			var room: float = WIDTHS[i] - WIDTHS[i - 1]
			assert_true(grew <= room * 6.0 + 0.01,
					"%s: the frontage jumped %.1f m for %.1f m of corridor between %s and %s" \
					% [shape, grew, room, WIDTHS[i - 1], WIDTHS[i]])


func test_a_wedge_files_through_a_defile_and_re_expands_after_it() -> void:
	# The behaviour A8 is for, stated as the lead would see it: the same five vehicles, the same formation, the same
	# seating -- a wedge in the open, a file in the gap, a wedge again on the far side.
	_a8()
	var members := _longest_squad()
	var spacing := float(DoctrineTable.SPACING_DEFAULTS["open"])
	var open_fit := TacticsFormation.fit_to_corridor(members, "wedge", members.size(), spacing, INF)
	var tight_fit := _fit(members, "wedge", 10.0)
	var again := TacticsFormation.fit_to_corridor(members, "wedge", members.size(), spacing, INF)
	var open_slots := TacticsFormation.offsets_deformed("wedge", members.size(), open_fit)
	var tight_slots := TacticsFormation.offsets_deformed("wedge", members.size(), tight_fit)
	assert_true(float(tight_fit["file"]) > 0.9, "a 10 m gap files the wedge (file %.2f)" % tight_fit["file"])
	assert_true(TacticsFormation._extent(tight_slots, true) < TacticsFormation._extent(open_slots, true) * 0.35,
			"and it is far narrower going through than it was in the open")
	assert_true(TacticsFormation._extent(tight_slots, false) > TacticsFormation._extent(open_slots, false),
			"the dispersion it gives up sideways it takes back in depth")
	assert_eq(TacticsFormation.offsets_deformed("wedge", members.size(), again), open_slots,
			"and the far side of the defile is exactly the wedge it started as")
	# Seating is a function of the slots, not of the deformation: every slot index is still present exactly once.
	var seen := {}
	for i in tight_slots.size():
		seen[i] = true
	assert_eq(seen.size(), open_slots.size(), "the same slots, deformed -- none dissolved, none added")


func test_a_formation_that_cannot_fit_says_so_instead_of_stacking_hulls() -> void:
	# A corridor narrower than one hull plus its clearance cannot hold the formation at all. The honest answer is
	# "it does not fit", which is information the element can act on; overlapping the hulls to make the number look
	# right is the failure X1 exists to prevent.
	_a8()
	var members := _longest_squad()
	var hull := TacticsFormation.hull_extent(members)
	var fit := _fit(members, "wedge", hull.x)
	assert_true(not bool(fit["fits"]), "a corridor no wider than one hull does not fit a five-vehicle wedge")
	var slots := TacticsFormation.offsets_deformed("wedge", members.size(), fit)
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			var apart: Vector2 = (slots[i] - slots[j]).abs()
			assert_true(maxf(apart.x - hull.x, apart.y - hull.y) >= TacticsFormation.HULL_CLEAR_M - 0.01,
					"and its hulls are still clear of each other (%d, %d)" % [i, j])
