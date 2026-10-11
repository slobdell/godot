extends TestCase
## Round 26 (traffic, manoeuvre's C26.5 relay): a wheeled hull's hard forward turn is never asked for less than the plant's
## creep line (TankMotion.WHEEL_CREEP_THROTTLE x |turn|): under it the plant shuffles the hull in 0.5 s legs instead of
## rolling it round the arc. Pure (Steering), forward is -Z.

const RADIUS := 6.0


func test_a_full_lock_turn_near_the_goal_clears_the_creep_line() -> void:
	Traffic.set_off("creep", false)
	# Facing -Z, the point 4 m away and well off to the right: full lock, little route left.
	var drive := Steering.drive_toward_wheels(Vector3.ZERO, Vector3(0, 0, -1), Vector3(12.0, 0.0, -6.0), 0.5, RADIUS, 2.0,
			3.0)
	assert_near(absf(drive.y), 1.0, 0.001, "full lock (%s)" % drive)
	assert_true(drive.x >= TankMotion.WHEEL_CREEP_THROTTLE * absf(drive.y) + Steering.CREEP_MARGIN - 0.0001,
			"the throttle clears the plant's creep line, so the hull rolls round the arc (%s)" % drive)


func test_switched_off_the_old_floor_sits_under_the_creep_line() -> void:
	Traffic.set_off("creep", true)
	var drive := Steering.drive_toward_wheels(Vector3.ZERO, Vector3(0, 0, -1), Vector3(12.0, 0.0, -6.0), 0.5, RADIUS, 2.0,
			3.0)
	assert_true(drive.x < TankMotion.WHEEL_CREEP_THROTTLE * absf(drive.y),
			"--traffic-off=creep: the measured bug, a creep at full lock (%s)" % drive)
	Traffic.set_off("creep", false)


func test_a_gentle_turn_and_the_three_point_turn_are_unchanged() -> void:
	Traffic.set_off("creep", false)
	var gentle := Steering.drive_toward_wheels(Vector3.ZERO, Vector3(0, 0, -1), Vector3(1.0, 0.0, -30.0), 0.5, RADIUS, 8.0)
	Traffic.set_off("creep", true)
	var gentle_old := Steering.drive_toward_wheels(Vector3.ZERO, Vector3(0, 0, -1), Vector3(1.0, 0.0, -30.0), 0.5, RADIUS, 8.0)
	assert_eq(gentle, gentle_old, "a gentle turn already clears the line: nothing changes")
	# A point inside the turning circle: the back-up leg (0.6 reverse at full lock) is above the line either way.
	Traffic.set_off("creep", false)
	var back := Steering.drive_toward_wheels(Vector3.ZERO, Vector3(0, 0, -1), Vector3(3.0, 0.0, -1.0), 0.5, RADIUS, 0.0)
	assert_true(back.x < 0.0 and absf(back.x) >= TankMotion.WHEEL_CREEP_THROTTLE * absf(back.y),
			"the three-point turn's reverse leg is untouched (%s)" % back)
	Traffic.set_off("creep", false)
