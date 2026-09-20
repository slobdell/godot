extends TestCase
## Round 9, squad X1: a formation's slot pitch is a function of the MEMBERS' HULLS, not only of the doctrine's
## tactical spacing. `DoctrineTable.SPACING_DEFAULTS` is open 14 / lanes 11 / dense 8 m, and a 14 m War Rig at
## 8 m "dense" spacing stands inside the rig in front of it. The scale stream's resize (CP2) grows the
## mid-roster 1.5-2x, so this is the floor that keeps every formation clear of itself afterwards.
##
## Every expectation below is derived from `Units.PROFILES` (lesson 3), so CP2 changes no code here and these
## tests keep passing on the resized roster BY CONSTRUCTION. Nothing is written in metres.
##
## The clearance rule is the SEPARATING AXIS, not centre distance: two hull boxes standing along the same
## heading are clear when either axis separates them — side by side needs width, nose to tail needs length — so a
## pair's clearance is the larger of its two axis gaps. `TacticsFormation.closest_boxes` is that measurement.

## Shapes that lay out a squad: the doctrine formations plus the group shapes a player's order can produce.
const SHAPES := ["column", "wedge", "vee", "line", "echelon_left", "echelon_right", "herringbone", "coil",
		"swarm", "ring", "rows", "block", "single"]


## A five-vehicle squad from `faction`'s own catalogue (the size C2's army JSON caps a squad at).
func _squad_of(faction: String, size := 5) -> Array:
	var ids := Units.roster(faction)
	var members: Array = []
	for i in size:
		var unit := String(ids[i % ids.size()])
		members.append({"name": "%s_%d" % [faction, i], "unit": unit,
				"position": Vector3(i * 3.0, 0.0, 0.0), "role": Units.role_of(unit)})
	return members


## The longest and the widest hull in the whole catalogue, as one squad: the worst case any spacing must survive.
func _biggest_squad(size := 5) -> Array:
	var longest := ""
	var widest := ""
	for unit_id in Units.ids():
		var hull: Array = Units.stat(unit_id, "hull_size", [0.0, 0.0, 0.0])
		if longest == "" or maxf(float(hull[0]), float(hull[2])) \
				> maxf(float(Units.stat(longest, "hull_size")[0]), float(Units.stat(longest, "hull_size")[2])):
			longest = unit_id
		if widest == "" or minf(float(hull[0]), float(hull[2])) \
				> minf(float(Units.stat(widest, "hull_size")[0]), float(Units.stat(widest, "hull_size")[2])):
			widest = unit_id
	var members: Array = []
	for i in size:
		var unit := longest if i % 2 == 0 else widest
		members.append({"name": "big_%d" % i, "unit": unit, "position": Vector3(i * 3.0, 0.0, 0.0),
				"role": Units.role_of(unit)})
	return members


func test_the_hull_floor_is_the_widest_width_and_the_longest_length() -> void:
	for faction in Units.FACTIONS:
		var members := _squad_of(faction)
		var widest := 0.0
		var longest := 0.0
		for member: Dictionary in members:
			var hull: Array = Units.stat(String(member["unit"]), "hull_size")
			widest = maxf(widest, minf(float(hull[0]), float(hull[2])))
			longest = maxf(longest, maxf(float(hull[0]), float(hull[2])))
		var floor_v := TacticsFormation.hull_floor(members)
		assert_near(floor_v.x, widest + TacticsFormation.HULL_CLEAR_M, 0.001,
				"%s: across the heading a slot is the widest hull plus clear ground" % faction)
		assert_near(floor_v.y, longest + TacticsFormation.HULL_CLEAR_M, 0.001,
				"%s: along the heading it is the longest hull plus clear ground" % faction)
		assert_true(floor_v.y > floor_v.x, "%s: vehicles are longer than they are wide, so the floor is anisotropic"
				% faction)


func test_the_pitch_is_the_doctrine_spacing_until_the_hulls_need_more() -> void:
	var members := _biggest_squad()
	var floor_v := TacticsFormation.hull_floor(members)
	# Above every floor the doctrine number is untouched: the hull floor is a floor, not a replacement.
	var roomy := TacticsFormation.pitch(members, floor_v.y + 10.0)
	assert_near(roomy.x, floor_v.y + 10.0, 0.001, "a spacing above both floors is used as given, across")
	assert_near(roomy.y, floor_v.y + 10.0, 0.001, "and along")
	# Below them each axis is floored on its own: the "dense" doctrine spacing must not stack hulls nose to tail.
	var dense := TacticsFormation.pitch(members, DoctrineTable.SPACING_DEFAULTS["dense"])
	assert_true(dense.y >= floor_v.y - 0.001, "dense spacing is raised to the hull floor along the heading")
	assert_near(dense.x, maxf(float(DoctrineTable.SPACING_DEFAULTS["dense"]), floor_v.x), 0.001,
			"and across it to the width floor, each axis on its own")
	for terrain: String in DoctrineTable.SPACING_DEFAULTS:
		var pitch := TacticsFormation.pitch(members, float(DoctrineTable.SPACING_DEFAULTS[terrain]))
		assert_true(pitch.x >= float(DoctrineTable.SPACING_DEFAULTS[terrain]) - 0.001,
				"%s: the tactical spacing is never reduced across the heading" % terrain)
		assert_true(pitch.y >= float(DoctrineTable.SPACING_DEFAULTS[terrain]) - 0.001,
				"%s: nor along it" % terrain)


func test_no_shipped_formation_stands_a_squads_hulls_inside_each_other() -> void:
	var clear := TacticsFormation.HULL_CLEAR_M
	var squads := {"biggest": _biggest_squad()}
	for faction in Units.FACTIONS:
		squads[faction] = _squad_of(faction)
	for label: String in squads:
		var members: Array = squads[label]
		for terrain: String in DoctrineTable.SPACING_DEFAULTS:
			var spacing := float(DoctrineTable.SPACING_DEFAULTS[terrain])
			for shape in SHAPES:
				var gap := TacticsFormation.closest_boxes(members, shape, spacing)
				assert_true(gap >= clear - 0.001,
						"%s in %s on %s terrain: closest hull boxes %.2f m apart, needs %.2f" \
						% [label, shape, terrain, gap, clear])


func test_a_squad_bigger_than_a_platoon_is_clear_too() -> void:
	# A group order can place any number of vehicles (TacticsFormation.auto sends more than a platoon into rows).
	for size in [2, 3, 8, 17, 30]:
		var members := _biggest_squad(size)
		for shape in ["rows", "block", "line", "column", "wedge"]:
			var gap := TacticsFormation.closest_boxes(members, shape, DoctrineTable.SPACING_DEFAULTS["dense"])
			assert_true(gap >= TacticsFormation.HULL_CLEAR_M - 0.001,
					"%d of the biggest hulls in %s: %.2f m between the closest boxes" % [size, shape, gap])


func test_a_formation_of_small_hulls_is_laid_out_exactly_as_before() -> void:
	# The floor must not move the shapes it was not needed for: the sim baseline only fields `tank` hulls, and
	# X1 is pre-registered not to move it. Anything whose hull floor sits under the doctrine spacing is untouched.
	var members := _squad_of("condemned")
	var small: Array = []
	for member: Dictionary in members:
		small.append({"name": member["name"], "unit": "tank", "position": member["position"], "role": "tank"})
	var spacing := float(DoctrineTable.SPACING_DEFAULTS["open"])
	var floor_v := TacticsFormation.hull_floor(small)
	assert_true(floor_v.x < spacing and floor_v.y < spacing, "a tank's hull floor sits under the open spacing")
	for shape in SHAPES:
		var before := TacticsFormation.group_offsets(shape, small.size(), spacing)
		var after := TacticsFormation.offsets_at(shape, small.size(), TacticsFormation.pitch(small, spacing))
		assert_eq(after, before, "%s: an unfloored pitch lays the same slots as the scalar spacing did" % shape)


func test_the_anisotropic_pitch_scales_the_shape_and_nothing_else() -> void:
	# The per-axis pitch is the shape at the along-axis pitch with the across axis scaled: the degenerate diagonal
	# 2x2 that X2's affine transform generalises. It is exact because every shape is linear in its spacing.
	var pitch := Vector2(10.0, 20.0)
	for shape in SHAPES:
		var unit_shape := TacticsFormation.group_offsets(shape, 5, 1.0)
		var scaled := TacticsFormation.offsets_at(shape, 5, pitch)
		assert_eq(scaled.size(), unit_shape.size(), "%s: a per-axis pitch keeps the slot count" % shape)
		for i in unit_shape.size():
			assert_near(scaled[i].x, unit_shape[i].x * pitch.x, 0.001,
					"%s slot %d: across the heading it is scaled by the across pitch" % [shape, i])
			assert_near(scaled[i].y, unit_shape[i].y * pitch.y, 0.001,
					"%s slot %d: along it, by the along pitch" % [shape, i])


func test_place_reports_the_pitch_it_resolved_to() -> void:
	# control's readout and the coherence probe both need the number the slots were actually laid at, not the
	# doctrine number they asked for.
	var members := _biggest_squad()
	var spacing := float(DoctrineTable.SPACING_DEFAULTS["dense"])
	var placed := TacticsFormation.place(members, "column", Vector3.ZERO, Vector3.FORWARD, spacing)
	var pitch := TacticsFormation.pitch(members, spacing)
	assert_eq(placed.size(), members.size(), "every member is placed")
	var deepest := 0.0
	for entry in placed:
		deepest = maxf(deepest, absf((entry["offset"] as Vector2).y))
	assert_near(deepest, pitch.y * (members.size() - 1) * 0.5, 0.01,
			"a column of the biggest hulls is laid out at the hull pitch, not the dense doctrine spacing")
	for entry in placed:
		assert_eq(entry["pitch"], pitch, "each slot carries the pitch it was laid at")


func test_the_slot_leash_is_one_formation_spacing_whatever_the_hulls_are() -> void:
	# A unit fighting from its formation slot manoeuvres inside ONE formation spacing of it
	# (TankBrain.SLOT_LEASH's own comment). Round 9 makes that a real number: a squad of 14 m rigs is laid out at a
	# 16 m pitch, so a flat 14 m leash is tighter than the formation the crews are standing in -- and nav bounds
	# a held unit's dodges by exactly this number (its A7 priority table, level 0).
	assert_near(TankBrain.slot_leash(null), TankBrain.SLOT_LEASH, 0.001,
			"an element that publishes no pitch leaves the constant alone")
	assert_near(TankBrain.slot_leash({}), TankBrain.SLOT_LEASH, 0.001, "and so does one with no pitch key")
	var small := TacticsFormation.pitch([{"name": "a", "unit": "tank"}], DoctrineTable.SPACING_DEFAULTS["open"])
	assert_near(TankBrain.slot_leash({"pitch": small}), TankBrain.SLOT_LEASH, 0.001,
			"a squad whose hulls fit inside the doctrine spacing keeps exactly today's leash")
	var big := TacticsFormation.pitch(_biggest_squad(), DoctrineTable.SPACING_DEFAULTS["open"])
	assert_true(TankBrain.slot_leash({"pitch": big}) >= maxf(big.x, big.y) - 0.001,
			"a squad spaced by its hulls is leashed to that spacing, not to less")
	assert_true(TankBrain.slot_leash({"pitch": big}) >= TankBrain.SLOT_LEASH,
			"the leash never gets tighter than it was")


func test_an_unknown_unit_is_laid_out_as_the_catalogue_default_and_says_so() -> void:
	# `ArmyLayout._hull` had two SILENT pre-CP2 fallbacks. The reachable one returned `Vector2(2.6, 4.0)` for an id with
	# no profile; the other passed `[2.6, 1.8, 4.0]` to `Units.stat`, which was stale and DEAD because `stat` ends in
	# `PROFILES[unit_id].get(key, fallback)` and indexing an unknown id raises before the fallback is consulted (nav).
	#
	# The magnitude is why this is not tidying: `tank`'s live hull is `[2.40, 2.40, 8.62]`, so the literal understated
	# the default LENGTH by 4.6 m -- less than half. A deploy layout built on it pitches slots for a 4 m vehicle and
	# stands 8.6 m vehicles in them, nose into tail, which is exactly what X1 exists to prevent.
	#
	# `expect_warning` is the non-vacuity guard for free: declaring it and getting none fails this test too, so the
	# branch cannot go quiet without saying so.
	expect_warning("no unit profile for 'no_such_unit_id'")
	var laid := ArmyLayout._hull("no_such_unit_id")
	var live: Array = Units.stat(Units.DEFAULT, "hull_size")
	var want := Vector2(minf(float(live[0]), float(live[2])), maxf(float(live[0]), float(live[2])))
	assert_true(laid.is_equal_approx(want),
			"an unreadable unit is laid out as the catalogue's live '%s' (%s), not a literal (%s)" \
			% [Units.DEFAULT, want, laid])
	assert_true(not laid.is_equal_approx(Vector2(2.6, 4.0)),
			"and specifically not the pre-CP2 2.6 x 4.0, which is 4.6 m short of the default's length")

