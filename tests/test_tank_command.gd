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
