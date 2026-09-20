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


func teardown() -> void:
	Units.tuning.erase("hull_disc")


## The orchestrator's two cases, hand-computed from `hull_size` and depending on no series: a shell passing 3 m
## beside a War Rig's flank is not a friendly-fire risk; one passing 1 m is. Half-width is 1.66 m.
func test_a_shell_three_metres_off_a_rigs_flank_is_clear_and_one_metre_is_not() -> void:
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
func test_the_disc_arm_is_selectable_and_gates_both_axes() -> void:
	var rig := _rig()
	var box_abeam := Units.hull_reach_along(rig, NORTH, EAST)
	var box_gap := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	assert_eq(Units.apply_tuning("match.hull_disc=1"), "", "the disc arm is selectable")
	var disc_abeam := Units.hull_reach_along(rig, NORTH, EAST)
	var disc_gap := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	print("MEASURE hull_box_arm abeam reach %.2f -> %.2f; 3 m flank gap %.2f -> %.2f" % [
			box_abeam, disc_abeam, box_gap, disc_gap])
	assert_true(disc_abeam > box_abeam * 4.0, "the knob restores the disc on the longitudinal axis (squad's)")
	assert_true(box_gap > 0.0 and disc_gap == 0.0,
			"and on the lateral one: a shell 3 m off the flank is clear as a box and a risk as a disc")
	Units.tuning.erase("hull_disc")


## Rotating the hull rotates the box with it: the disc cannot express this and that is the whole point.
func test_the_box_turns_with_the_hull() -> void:
	var rig := _rig()
	# The same shot, against a rig facing along it and across it.
	var across := Units.hull_distance_to_line(rig, NORTH, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	var along := Units.hull_distance_to_line(rig, EAST, Vector3.ZERO, Vector3(3.0, 0, 60), NORTH)
	print("MEASURE hull_box same shot, rig abeam: gap %.2f m; rig end-on: gap %.2f m" % [across, along])
	assert_true(across > 0.0, "3 m off the flank of a 3.32 m-wide hull clears it")
	assert_eq(along, 0.0, "but the same 3 m is inside a 14 m hull pointed along the shot")
