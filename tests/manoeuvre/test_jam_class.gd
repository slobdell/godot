extends TestCase
## Round 41 (manoeuvre Q1): the jam census's classifier, pure (tests/manoeuvre/jam_class.gd). Forward is -Z (trip-up 2).

const JamClass := preload("res://tests/manoeuvre/jam_class.gd")


func test_a_moving_blocker_is_read_by_its_direction_against_my_way() -> void:
	assert_eq(JamClass.blocker_class(4.0, 0.0, 0.95, true), "same_way", "going my way: a slower leader")
	assert_eq(JamClass.blocker_class(4.0, 0.0, -0.9, true), "head_on", "coming at me")
	assert_eq(JamClass.blocker_class(4.0, 60.0, 0.1, true), "crossing", "across my line, even while its hull yaws")
	assert_eq(JamClass.blocker_class(1.0, 0.0, 0.5, false), "crossing", "exactly MOVING_MPS counts as moving")


func test_a_slow_blocker_is_turning_stalled_or_parked() -> void:
	assert_eq(JamClass.blocker_class(0.2, 40.0, 0.0, false), "turning", "pivoting in place, whatever its mover says")
	assert_eq(JamClass.blocker_class(0.2, -40.0, 0.0, true), "turning", "the yaw's sign is ignored")
	assert_eq(JamClass.blocker_class(0.2, 3.0, 0.0, true), "stalled", "still and under way: blocked itself")
	assert_eq(JamClass.blocker_class(0.0, 0.0, 0.0, false), "parked", "still and not under way")
	assert_eq(JamClass.CLASSES.size(), 6, "every class the table pools is named once")


func test_in_lane_is_ahead_within_length_and_width() -> void:
	var north := Vector2(0.0, -1.0)
	assert_true(JamClass.in_lane(Vector2(0.5, -6.0), north, 2.0, 12.0), "6 m ahead, 0.5 m off the line")
	assert_true(not JamClass.in_lane(Vector2(3.0, -6.0), north, 2.0, 12.0), "3 m off a 2 m lane")
	assert_true(not JamClass.in_lane(Vector2(0.0, 4.0), north, 2.0, 12.0), "behind")
	assert_true(not JamClass.in_lane(Vector2(0.0, -14.0), north, 2.0, 12.0), "beyond the lane's length")
	assert_true(JamClass.in_lane(Vector2(-7.0, 1.0), Vector2(-1.0, 0.0), 2.0, 12.0), "west lane: 7 m west, 1 m off")


func test_time_to_meet_is_the_first_touch_or_never() -> void:
	# `v_rel` is the OTHER's velocity relative to me (v_other - v_me). A friend 10 m north of me while I drive north at 5 m/s
	# and it stands still: it comes at me at (0, +5); discs of 3 m total radius touch after 7 m = 1.4 s.
	assert_near(JamClass.time_to_meet(Vector2(0.0, -10.0), Vector2(0.0, 5.0), 3.0), 1.4, 0.001, "closing along the line")
	assert_eq(JamClass.time_to_meet(Vector2(0.0, -10.0), Vector2(0.0, -5.0), 3.0), INF, "parting: never")
	assert_eq(JamClass.time_to_meet(Vector2(5.0, -10.0), Vector2(0.0, 5.0), 3.0), INF, "passing 5 m beside: never")
	assert_near(JamClass.time_to_meet(Vector2(4.0, -10.0), Vector2(0.0, 5.0), 5.0), 1.4, 0.001, "a bigger pair touches")
	assert_eq(JamClass.time_to_meet(Vector2(0.0, -10.0), Vector2.ZERO, 3.0), INF, "no relative motion: never")
	assert_eq(JamClass.time_to_meet(Vector2(0.0, -2.0), Vector2(0.0, 1.0), 3.0), 0.0, "already overlapping and closing: now")
	assert_eq(JamClass.time_to_meet(Vector2(0.0, -2.0), Vector2(0.0, -1.0), 3.0), INF, "already overlapping and parting")


func test_asker_action_in_order_of_evidence() -> void:
	assert_eq(JamClass.asker_action(60, 40, 0, 0.0, 0), "yielded", "gave way most of the episode")
	assert_eq(JamClass.asker_action(60, 10, 6, 0.0, 50), "reversed", "backed up, even if mostly still")
	assert_eq(JamClass.asker_action(60, 0, 2, 2.5, 50), "steered", "left its lane by more than STEERED_M")
	assert_eq(JamClass.asker_action(60, 0, 0, 1.0, 40), "stopped", "still most of the time, in its lane")
	assert_eq(JamClass.asker_action(60, 0, 0, 1.0, 10), "slowed", "slower, moving, in its lane")
	assert_eq(JamClass.asker_action(0, 0, 0, 0.0, 0), "none", "no ticks")


func test_yaw_helpers() -> void:
	assert_near(JamClass.yaw_of(Vector3(0.0, 0.0, -1.0)), PI, 0.0001, "facing north (-Z) is yaw pi, by atan2's convention")
	assert_near(JamClass.yaw_of(Vector3(1.0, 0.0, 0.0)), PI / 2.0, 0.0001, "facing east")
	assert_near(JamClass.yaw_rate_dps(0.0, deg_to_rad(30.0), 0.1), 300.0, 0.01, "30 deg in 0.1 s")
	assert_near(JamClass.yaw_rate_dps(deg_to_rad(170.0), deg_to_rad(-170.0), 1.0), 20.0, 0.01, "the short way round the seam")
	assert_eq(JamClass.yaw_rate_dps(0.0, 1.0, 0.0), 0.0, "no time: no rate")
