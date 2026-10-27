extends TestCase
## Round 42 (camera K4.1): the look census's pure parts: which way a point lies from the view, facing the wall, a round
## fired at the selection, and a swinging yaw.


func test_bearing_is_zero_ahead_positive_left_and_180_behind() -> void:
	var from := Vector3(0, 0, 50)
	# yaw 0 looks north (-Z); positive yaw turns left (trip-up 2).
	assert_near(CameraLook.bearing(0.0, from, Vector3(0, 0, 0)), 0.0, 0.01, "straight up the screen")
	assert_near(CameraLook.bearing(0.0, from, Vector3(-30, 0, 50)), 90.0, 0.01, "west is to the left of a north view")
	assert_near(CameraLook.bearing(0.0, from, Vector3(30, 0, 50)), -90.0, 0.01, "east is to the right")
	assert_near(absf(CameraLook.bearing(0.0, from, Vector3(0, 0, 90))), 180.0, 0.01, "south is behind")
	assert_near(CameraLook.bearing(deg_to_rad(-90.0), from, Vector3(30, 0, 50)), 0.0, 0.01, "a view turned east has the east ahead")


func test_facing_the_wall_needs_the_middle_behind_and_some_distance() -> void:
	var middle := Vector3.ZERO
	var near_edge := Vector3(0, 0, 120)  # his own edge, south
	assert_true(CameraLook.facing_wall(PI, near_edge, middle), "looking south from the south edge: the audience")
	assert_true(not CameraLook.facing_wall(0.0, near_edge, middle), "looking north from there: the war")
	assert_true(not CameraLook.facing_wall(PI, Vector3(0, 0, 10), middle), "near the middle every way is toward it")


func test_a_round_counts_as_at_us_only_when_its_line_passes_near_inside_its_range() -> void:
	var muzzle := Vector3(40, 1, 0)
	var west := Vector3(-1, 0, 0)
	assert_true(DangerFeed.passes_near(muzzle, west, 80.0, Vector3(0, 0, 3), 6.0), "3 m off the line, 40 m out: at us")
	assert_true(not DangerFeed.passes_near(muzzle, west, 80.0, Vector3(0, 0, 9), 6.0), "9 m off: at someone else")
	assert_true(not DangerFeed.passes_near(muzzle, -west, 80.0, Vector3(0, 0, 0), 6.0), "fired away from us")
	assert_true(not DangerFeed.passes_near(muzzle, west, 20.0, Vector3(0, 0, 0), 6.0), "beyond its range")
	assert_true(DangerFeed.passes_near(muzzle, Vector3(-1, 0.3, 0), 0.0, Vector3(0, 0, 0), 6.0), "a lobbed round reads flat")


func test_a_yaw_that_swings_back_counts_reversals_and_a_steady_turn_does_not() -> void:
	var look := CameraLook.new()
	for deg in range(0, 90, 2):
		look._count_reversal(float(deg))
	assert_eq(look._reversals, 0, "one steady 90 deg turn")
	for deg in [88.0, 86.0, 84.0, 82.0, 80.0, 78.0]:
		look._count_reversal(deg)
	assert_eq(look._reversals, 1, "turned back 12 deg: one reversal")
	for deg in [79.0, 81.0, 79.0, 81.0, 79.0]:
		look._count_reversal(deg)
	assert_eq(look._reversals, 1, "a 2 deg wobble is not a swing")
	look._count_reversal(170.0)
	look._count_reversal(-170.0)  # across the seam: a 20 deg turn the same way
	assert_eq(look._reversals, 2, "the turn back to the left after going right is the second; the seam is not")
	look.free()
