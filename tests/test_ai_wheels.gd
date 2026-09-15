extends TestCase
## Round-3 X2: wheeled units drive like cars (Steering.drive_toward_wheels / reverse_toward_wheels). The car below is a
## test double of combat's K3 wheels as documented on stream/combat (TankMotion.step_in_place): yaw rate = |speed| ×
## turn ÷ minimum turning radius, in the direction of `turn` in either gear; no turning at a standstill (a pure turn
## creeps along the arc); braking harder than accelerating. At CP2 these tests can drive TankMotion.predict instead.


class Car:
	var position := Vector3.ZERO
	var forward := Vector3.FORWARD
	var speed := 0.0
	var max_forward := 11.0
	var max_reverse := 5.0
	var acceleration := 9.0
	var braking := 14.0
	var radius := 7.0
	var turn_rate_deg := 100.0
	var reversed_ticks := 0

	func step(throttle: float, turn: float, delta := 1.0 / 60.0) -> void:
		if absf(throttle) < 0.5 * absf(turn):
			throttle = 0.5 * absf(turn) * (-1.0 if throttle < 0.0 or (throttle == 0.0 and speed < -0.5) else 1.0)
		var goal := throttle * (max_forward if throttle >= 0.0 else max_reverse)
		var rate := braking if absf(goal) < absf(speed) or signf(goal) != signf(speed) else acceleration
		speed = move_toward(speed, goal, rate * delta)
		var yaw := clampf(absf(speed) * turn / radius, -deg_to_rad(turn_rate_deg), deg_to_rad(turn_rate_deg))
		forward = forward.rotated(Vector3.UP, -yaw * delta)
		position += forward * speed * delta
		if speed < -0.5:
			reversed_ticks += 1


## Drive `car` at `target` with the wheel steering for up to `seconds`; returns the tick it arrived or -1.
func _drive(car: Car, target: Vector3, seconds: float, reverse := false) -> int:
	for tick in roundi(seconds * 60.0):
		var steer := Steering.reverse_toward_wheels if reverse else Steering.drive_toward_wheels
		var drive: Vector2 = steer.call(car.position, car.forward, target, 2.0, car.radius, car.speed)
		if drive == Vector2.ZERO:
			return tick
		car.step(drive.x, drive.y)
	return -1


func test_a_car_reaches_a_point_ahead_and_to_the_side() -> void:
	var car := Car.new()
	var arrived := _drive(car, Vector3(-30, 0, -40), 12.0)
	assert_true(arrived > 0, "arrives (%d ticks, ends at %s)" % [arrived, car.position])


func test_a_car_loops_round_to_a_point_far_behind() -> void:
	var car := Car.new()
	var arrived := _drive(car, Vector3(5, 0, 60), 20.0)
	print("MEASURE ai_wheels_far_behind arrived after %.1f s, reversed %.1f s" % [arrived / 60.0, car.reversed_ticks / 60.0])
	assert_true(arrived > 0, "arrives by looping round (ends at %s)" % car.position)
	assert_true(car.reversed_ticks < 60, "without backing up much when there's room (%d ticks)" % car.reversed_ticks)


func test_a_car_loops_to_a_point_close_behind() -> void:
	var car := Car.new()
	var arrived := _drive(car, Vector3(0, 0, 9), 20.0)
	print("MEASURE ai_wheels_close_behind arrived after %.1f s, reversed %.1f s" % [arrived / 60.0, car.reversed_ticks / 60.0])
	assert_true(arrived > 0 and arrived <= 60 * 8, "arrives within 8 s (%.1f s, ends at %s)" % [arrived / 60.0, car.position])


func test_a_car_backs_up_for_a_point_inside_its_turning_circle() -> void:
	# 4 m right and 1 m back: inside the right-hand 7 m turning circle, so no forward turn reaches it.
	var car := Car.new()
	var arrived := _drive(car, Vector3(4, 0, 1), 20.0)
	print("MEASURE ai_wheels_three_point arrived after %.1f s, reversed %.1f s" % [arrived / 60.0, car.reversed_ticks / 60.0])
	assert_true(arrived > 0 and arrived <= 60 * 10, "arrives within 10 s (%.1f s, ends at %s facing %s)" % [arrived / 60.0, car.position, car.forward])
	assert_true(car.reversed_ticks > 20, "backing up on the way (a three-point turn: %d ticks in reverse)" % car.reversed_ticks)


func test_a_car_backs_to_a_point_keeping_its_nose_away() -> void:
	var car := Car.new()
	var nose_away := 0
	var ticks := 0
	var target := Vector3(8, 0, 25)
	for tick in 60 * 15:
		var drive := Steering.reverse_toward_wheels(car.position, car.forward, target, 2.0, car.radius, car.speed)
		if drive == Vector2.ZERO:
			break
		car.step(drive.x, drive.y)
		ticks += 1
		if car.forward.dot(target - car.position) < 0.0:
			nose_away += 1
	var gap := Vector2(car.position.x - target.x, car.position.z - target.z).length()
	assert_true(gap <= 2.5, "backs up to the point (%.1f m off)" % gap)
	assert_true(nose_away >= ticks * 0.9, "the nose stays away from where it's going (%d of %d ticks)" % [nose_away, ticks])
