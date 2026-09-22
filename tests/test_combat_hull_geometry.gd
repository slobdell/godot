extends TestCase
## Round 9: a hull is an oriented box, not a disc.
##
## Three consumers modelled one as a circle of radius `Vector2(width, length).length() / 2` -- `Match`'s
## friendly-fire risk, `Match.incoming_projectiles` (whose docstring said "within the hull's half-diagonal") and
## squad's `IncomingFire`, which cached that radius per unit id and used it on BOTH axes. For a War Rig
## (3.32 x 14.00 m) the disc is 7.19 m against a real half-width of 1.66 m.
##
## THE ERROR IS NOT A CONSTANT, which is the part that makes it a candidate mechanism rather than a rounding
## complaint: abeam it is 4.3x, end-on the disc is 7.19 m against a true 7.00 m and is nearly exact. So the AI does
## not refuse every shot -- it refuses the ones ACROSS a rig, which is exactly the shot a gang pack travelling with a
## rig in the middle wants to take. Whether that is the lead's unexplained `gangs vs law` 9/20 -> 0/20 is UNTESTED
## until the series says so, and these tests do not claim it.

const RIG := "gang_tank"  # 3.32 x 14.00 m
const NORTH := Vector3(0, 0, -1)
const EAST := Vector3(1, 0, 0)


func _rig() -> Array:
	return Units.stat(RIG, "hull_size")


## The DISC is the default until the series says otherwise, so every test of the box has to select it -- which is
## itself worth asserting, because a test that silently measured the default would be testing the geometry it was
## written to replace and saying nothing about it.
func _use_the_box() -> void:
	assert_eq(Units.apply_tuning("match.hull_disc=0"), "", "the box arm is selectable")
	assert_true(Units.hull_reach_along(_rig(), NORTH, EAST) < 2.0, "and selected (abeam reach is the half-width)")


## Restored on EVERY exit, including a failing one: `Units.tuning` is a static and a test that dies holding the box
## would hand the default to whatever runs next -- the leak-into-the-next-test shape that cost this round two shards.
## Reaches the base, for the same reason as its siblings: owning nothing today is not a property that stays true.
func teardown() -> void:
	Units.tuning.erase("hull_disc")
	await super.teardown()


## The orchestrator's two cases, hand-computed from `hull_size` and depending on no series: a shell passing 3 m
## beside a War Rig's flank is not a friendly-fire risk; one passing 1 m is. Half-width is 1.66 m.
func test_a_shell_three_metres_off_a_rigs_flank_is_clear_and_one_metre_is_not() -> void:
	_use_the_box()
	var rig := _rig()
	# The rig faces north; the shot runs north past its flank, offset east by the stated distance.
	for pair in [[3.0, true], [1.0, false]]:
		var offset: float = pair[0]
		var line_origin := Vector3(offset, 0, 60)
		var gap := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, line_origin, NORTH)
		print("MEASURE hull_box shell %.1f m off the rig's flank: gap %.2f m (half-width %.2f)" % [
				offset, gap, float(rig[0]) * 0.5])
		if bool(pair[1]):
			assert_true(gap > 0.0, "%.1f m clears a %.2f m half-width (gap %.2f)" % [offset, float(rig[0]) * 0.5, gap])
		else:
			assert_eq(gap, 0.0, "%.1f m is inside a %.2f m half-width, so the line crosses the hull" % [
					offset, float(rig[0]) * 0.5])


## The disc's error, stated as the two numbers that bound it: abeam it is more than four times the truth, end-on it
## is nearly exact. A test that only checked one angle would report a constant factor and miss the mechanism.
func test_the_discs_error_is_a_function_of_the_angle_not_a_constant() -> void:
	_use_the_box()
	var rig := _rig()
	var disc := Vector2(float(rig[0]), float(rig[2])).length() / 2.0
	var abeam := Units.hull_reach_along(rig, NORTH, EAST)     # across the hull: the half-WIDTH
	var end_on := Units.hull_reach_along(rig, NORTH, NORTH)   # along the hull: the half-LENGTH
	print("MEASURE hull_box disc %.2f m; true reach abeam %.2f (x%.1f), end-on %.2f (x%.2f)" % [
			disc, abeam, disc / abeam, end_on, disc / end_on])
	assert_near(abeam, float(rig[0]) * 0.5, 0.001, "abeam, the hull reaches its half-width")
	assert_near(end_on, float(rig[2]) * 0.5, 0.001, "end-on, its half-length")
	assert_true(disc / abeam > 4.0, "the disc is over 4x the truth abeam (%.1fx)" % (disc / abeam))
	assert_true(disc / end_on < 1.1, "and within 10%% of it end-on (%.2fx)" % (disc / end_on))


## The arm has to be distinguishable or the series measures one build twice (lesson 117): the SAME query must return
## the box under the default and the disc under the knob, and the knob gates BOTH axes because squad's longitudinal
## test goes through `hull_reach_along` too.
func test_the_box_arm_is_selectable_and_gates_both_axes() -> void:
	var rig := _rig()
	# The DEFAULT is the disc; the knob selects the box. Both are read here so the arms are shown to differ.
	var disc_abeam := Units.hull_reach_along(rig, NORTH, EAST)
	var disc_gap := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	_use_the_box()
	var box_abeam := Units.hull_reach_along(rig, NORTH, EAST)
	var box_gap := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	print("MEASURE hull_box_arm default disc -> knob box: abeam reach %.2f -> %.2f; 3 m flank gap %.2f -> %.2f" % [
			disc_abeam, box_abeam, disc_gap, box_gap])
	assert_true(disc_abeam > box_abeam * 4.0, "the knob selects the box on the longitudinal axis (squad's)")
	assert_true(box_gap > 0.0 and disc_gap == 0.0,
			"and on the lateral one: a shell 3 m off the flank is clear as a box and a risk as a disc")
	Units.tuning.erase("hull_disc")


## Rotating the hull rotates the box with it: the disc cannot express this and that is the whole point.
func test_the_box_turns_with_the_hull() -> void:
	_use_the_box()
	var rig := _rig()
	# The same shot, against a rig facing along it and across it.
	var across := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	var along := Units.hull_distance_to_line(rig, EAST, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	print("MEASURE hull_box same shot, rig abeam: gap %.2f m; rig end-on: gap %.2f m" % [across, along])
	assert_true(across > 0.0, "3 m off the flank of a 3.32 m-wide hull clears it")
	assert_eq(along, 0.0, "but the same 3 m is inside a 14 m hull pointed along the shot")


## squad's guard, and it is here rather than in a comment because "did we migrate all three?" is otherwise answered
## from memory at the moment someone is keen to see a number. The series that tests the disc-vs-box mechanism is only
## readable if EVERY consumer flips with the flag: a site still computing its own radius ignores the knob entirely,
## so a half-migrated tree measures a hull that is a box for one question and a disc for another, and the result
## looks clean while meaning nothing.
func test_no_consumer_computes_a_hull_radius_of_its_own() -> void:
	for path in ["res://game/match/match.gd", "res://game/ai/incoming_fire.gd"]:
		var text := FileAccess.get_file_as_string(path)
		assert_true(not text.is_empty(), "read %s" % path)
		for line in text.split("\n"):
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("##"):
				continue  # the notes explaining the migration name the old expression on purpose
			assert_true(not code.contains("hull_size\")).length()") and not code.contains("size[2])).length()"),
					"%s still derives a hull radius itself instead of calling Units.hull_reach_of: %s" % [path, code])


## The cached-pair entry points must agree with the ones that take `hull_size`, or squad's per-tick path and mine
## would answer the same question differently -- which is the two-implementations failure the helper exists to avoid.
func test_the_cached_pair_agrees_with_the_hull_size_form() -> void:
	_use_the_box()
	var rig := _rig()
	var half := Units.hull_half_extents(rig)
	for degrees in [0.0, 23.0, 45.0, 90.0, 137.0, 180.0]:
		var axis := Vector3(sin(deg_to_rad(degrees)), 0.0, -cos(deg_to_rad(degrees)))
		assert_near(Units.hull_reach_of(half, NORTH, axis), Units.hull_reach_along(rig, NORTH, axis), 1e-6,
				"reach agrees at %.0f deg" % degrees)
		assert_near(Units.hull_distance_of(half, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), axis),
				Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), axis), 1e-6,
				"distance agrees at %.0f deg" % degrees)
	Units.tuning.erase("hull_disc")  # back to the default disc
	assert_near(Units.hull_reach_of(half, NORTH, EAST), Units.hull_reach_along(rig, NORTH, EAST), 1e-6,
			"the disc is half.length(), which is Vector2(w, l).length() / 2 -- the same number by either route")
	Units.tuning.erase("hull_disc")


## nav, round 9: `Units.stat(unit_id, key, fallback)` ended in `PROFILES[unit_id].get(key, fallback)`, so an unknown
## id raised on the INDEX and the fallback was **unreachable by construction**. Every call site passing a fallback
## for a possibly-unknown id read as protection that did not exist -- which is how the pre-CP2 literals scale found
## managed to be stale AND dead at once. The guard is only worth having if it can be driven, so it is driven here:
## both the given-fallback branch and the no-fallback branch, with the error declared (round 10: an error, not a
## warning) so a guard that stops erroring fails this test rather than passing it quietly.
func test_an_unknown_unit_id_returns_the_fallback_instead_of_raising() -> void:
	expect_error("Units.stat: no unit 'no_such_unit'*")
	expect_error("Units.stat: no unit 'no_such_unit'*")
	var given: Variant = Units.stat("no_such_unit", "hull_size", [1.0, 1.0, 1.0])
	assert_eq(given, [1.0, 1.0, 1.0], "the fallback the caller wrote is the one it gets")
	# No fallback: DEFAULT's value, which is a unit that exists, rather than a null that fails somewhere else later.
	var defaulted: Variant = Units.stat("no_such_unit", "hull_size")
	assert_eq(defaulted, Units.stat(Units.DEFAULT, "hull_size"),
			"with no fallback given, %s's value stands in (%s)" % [Units.DEFAULT, defaulted])
	# And a KNOWN id is untouched by the guard, which is the half that would be easy to break silently.
	assert_eq(Units.stat(RIG, "hull_size"), _rig(), "a known id still reads its own profile")


## Round 10 (combat, research row C8(a)): every aim, line-of-fire and exposure computation treats a hull's ORIGIN as the
## centre of its box in plan (`gunnery.gd` aims at `target.global_position`; `Ballistics.aim_error` is planar; the disc
## and box reaches are centred there). That is only true while the collider sits on the origin in x and z. R5 moves the
## turret, not the hull, so nothing should move it; this makes an offset collider fail by name instead of quietly
## shifting every unit's exposure.
func test_every_hull_collider_is_centred_on_its_origin_in_plan() -> void:
	add_to_tree(preload("res://game/arena/arena.tscn").instantiate())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	var ids: Array = Units.PROFILES.keys()
	ids.sort()
	var checked := 0
	for index in ids.size():
		var unit_id := String(ids[index])
		var tank := game_match.spawn_tank("Green_Centre_%d" % index, index, Match.Team.GREEN, unit_id)
		var collider := tank.get_node("Collision") as CollisionShape3D
		var size: Array = Units.stat(unit_id, "hull_size")
		assert_near(collider.position.x, 0.0, 1e-6, "%s: the collider's centre is on the origin across (x)" % unit_id)
		assert_near(collider.position.z, 0.0, 1e-6, "%s: the collider's centre is on the origin along (z)" % unit_id)
		assert_near((collider.shape as BoxShape3D).size.z, float(size[2]), 1e-6, "%s: and it is the profile's box" % unit_id)
		checked += 1
	assert_eq(checked, ids.size(), "every profile was spawned and checked (%d)" % checked)
