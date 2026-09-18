extends TestCase
## N6 (nav X6, round 6): the house regulator. No derivative kick on a setpoint jump, anti-windup, deterministic.

const DT := 1.0 / 30.0


func test_proportional_alone() -> void:
	var pid := Pid.new({"kp": 0.5, "ki": 0.0, "kd": 0.0, "output_limit": 10.0})
	assert_near(pid.step(4.0, 1.0, DT), 1.5, 0.0001, "kp times the error")


func test_no_derivative_kick_when_the_setpoint_jumps() -> void:
	var pid := Pid.new({"kp": 0.0, "ki": 0.0, "kd": 1.0, "output_limit": 100.0})
	pid.step(0.0, 2.0, DT)
	assert_near(pid.step(50.0, 2.0, DT), 0.0, 0.0001, "the measurement didn't move, so D is zero however far the setpoint jumped")
	assert_near(pid.step(50.0, 2.5, DT), -15.0, 0.0001, "D opposes the measurement's own motion (0.5 m in a tick)")


func test_integral_is_clamped_and_does_not_wind_up_while_saturated() -> void:
	var pid := Pid.new({"kp": 1.0, "ki": 1.0, "kd": 0.0, "integral_limit": 2.0, "output_limit": 1.0})
	for tick in 300:
		pid.step(10.0, 0.0, DT)  # a wall: the error never shrinks, the output sits at its limit
	assert_near(pid.integral, 0.0, 0.0001, "saturated the same way as the error: the integral never charges")
	var free := Pid.new({"kp": 0.0, "ki": 1.0, "kd": 0.0, "integral_limit": 2.0, "output_limit": 100.0})
	for tick in 300:
		free.step(10.0, 0.0, DT)
	assert_near(free.integral, 2.0, 0.0001, "and when it does integrate, it stops at the clamp")


func test_regulates_a_lagging_plant_to_the_setpoint() -> void:
	# A point mass with an acceleration limit (like a hull) closing on a setpoint: settles without running away.
	var pid := Pid.new({"kp": 1.2, "ki": 0.05, "kd": 1.4, "integral_limit": 3.0, "output_limit": 8.0})
	var position := 0.0
	var speed := 0.0
	for tick in 30 * 12:
		var wanted := pid.step(20.0, position, DT)
		speed = move_toward(speed, wanted, 10.0 * DT)
		position += speed * DT
	assert_near(position, 20.0, 0.3, "within 30 cm after 12 s (at %.2f)" % position)


func test_reset_forgets() -> void:
	var pid := Pid.new({"kp": 0.0, "ki": 1.0, "kd": 1.0, "integral_limit": 5.0, "output_limit": 100.0})
	pid.step(1.0, 0.0, DT)
	pid.step(1.0, 0.5, DT)
	pid.reset()
	assert_near(pid.integral, 0.0, 0.0001, "integral cleared")
	assert_near(pid.step(0.0, 7.0, DT), -7.0 * DT, 0.0001, "and no derivative from before the reset")
