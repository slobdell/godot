extends TestCase
## Pure movement math: no scene tree needed.


func test_throttle_accelerates_toward_forward_cap() -> void:
	var speed := TankMotion.next_speed(0.0, 1.0, 9.0, 4.0, 14.0, 0.1)
	assert_near(speed, 1.4, 1e-5, "one 0.1 s tick at 14 m/s² adds 1.4 m/s")
	for i in 100:
		speed = TankMotion.next_speed(speed, 1.0, 9.0, 4.0, 14.0, 0.1)
	assert_near(speed, 9.0, 1e-5, "speed settles at max_forward, never beyond")


func test_reverse_uses_lower_cap() -> void:
	var speed := 0.0
	for i in 100:
		speed = TankMotion.next_speed(speed, -1.0, 9.0, 4.0, 14.0, 0.1)
	assert_near(speed, -4.0, 1e-5, "full reverse settles at -max_reverse")


func test_zero_throttle_brakes_to_stop() -> void:
	var speed := 9.0
	for i in 100:
		speed = TankMotion.next_speed(speed, 0.0, 9.0, 4.0, 14.0, 0.1)
	assert_near(speed, 0.0, 1e-5, "releasing throttle brings the tank to rest")


func test_yaw_toward_straight_ahead_is_zero() -> void:
	assert_near(TankMotion.yaw_toward(Vector3(0, 0, -10)), 0.0, 1e-5, "forward is -Z")


func test_yaw_toward_right_is_negative() -> void:
	# Positive rotation about +Y turns counter-clockwise seen from above, i.e. left.
	assert_near(TankMotion.yaw_toward(Vector3(10, 0, 0)), -PI / 2.0, 1e-5,
			"a target on the right (+X) needs yaw -90°")


func test_step_yaw_takes_short_way_across_pi() -> void:
	var result := TankMotion.step_yaw(3.0, -3.0, 1.0, 0.1)
	assert_near(angle_difference(3.0, result), 0.1, 1e-5,
			"from +3.0 rad to -3.0 rad the short way is forward through ±PI")
