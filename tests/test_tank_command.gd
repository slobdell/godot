extends TestCase


func test_sanitized_clamps_axes() -> void:
	var cmd := TankCommand.new(3.0, -7.0, Vector3(1, 2, 3), true).sanitized()
	assert_eq(cmd.throttle, 1.0, "throttle clamps to 1")
	assert_eq(cmd.turn, -1.0, "turn clamps to -1")
	assert_eq(cmd.aim_point, Vector3(1, 2, 3), "aim point passes through")
	assert_true(cmd.fire, "fire passes through")


func test_sanitized_returns_a_copy() -> void:
	var original := TankCommand.new(5.0)
	original.sanitized()
	assert_eq(original.throttle, 5.0, "the controller's command object is not mutated")


func test_sanitized_zeroes_non_finite_values() -> void:
	var cmd := TankCommand.new(NAN, INF, Vector3(NAN, 0, 0)).sanitized()
	assert_eq(cmd.throttle, 0.0, "NaN throttle becomes 0, not NaN (clampf would pass NaN through)")
	assert_eq(cmd.turn, 0.0, "infinite turn becomes 0")
	assert_eq(cmd.aim_point, Vector3.ZERO, "non-finite aim point becomes the origin")
