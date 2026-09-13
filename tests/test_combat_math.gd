extends TestCase
## Pure combat and driving math: armor facing, shot leading, steering.

const NORTH := Vector3(0, 0, -1)
const SOUTH := Vector3(0, 0, 1)
const EAST := Vector3(1, 0, 0)


func test_shell_from_ahead_hits_front_armor() -> void:
	# Hull faces north; the shell travels south, i.e. it came from ahead.
	assert_eq(Armor.facing(NORTH, SOUTH), Armor.Facing.FRONT, "head-on shot strikes the front")
	assert_eq(Armor.damage(34.0, NORTH, SOUTH), 17, "front armor halves damage")


func test_shell_from_behind_hits_rear_armor() -> void:
	assert_eq(Armor.facing(NORTH, NORTH), Armor.Facing.REAR, "a shell travelling the way the hull faces came from behind")
	assert_eq(Armor.damage(34.0, NORTH, NORTH), 51, "rear armor takes 1.5x damage")


func test_shell_from_the_side_hits_side_armor() -> void:
	assert_eq(Armor.facing(NORTH, EAST), Armor.Facing.SIDE, "a crossing shot strikes the side")
	assert_eq(Armor.damage(34.0, NORTH, EAST), 34, "side armor takes full damage")


func test_armor_arc_is_45_degrees() -> void:
	var shallow := SOUTH.rotated(Vector3.UP, deg_to_rad(40.0))
	var wide := SOUTH.rotated(Vector3.UP, deg_to_rad(50.0))
	assert_eq(Armor.facing(NORTH, shallow), Armor.Facing.FRONT, "40° off dead-on is still front")
	assert_eq(Armor.facing(NORTH, wide), Armor.Facing.SIDE, "50° off dead-on is side")


func test_lead_point_for_stationary_target_is_the_target() -> void:
	var lead := Ballistics.lead_point(Vector3.ZERO, Vector3(0, 0, -50), Vector3.ZERO, 70.0)
	assert_true(lead.is_equal_approx(Vector3(0, 0, -50)), "no lead needed for a still target")


func test_lead_point_intercepts_a_crossing_target() -> void:
	var target := Vector3(0, 0, -70)
	var velocity := Vector3(9, 0, 0)
	var lead := Ballistics.lead_point(Vector3.ZERO, target, velocity, 70.0)
	# Consistency: the shell's flight time to the lead point equals the target's travel time.
	var flight_time := lead.length() / 70.0
	var target_time := (lead.x - target.x) / velocity.x
	assert_near(flight_time, target_time, 1e-4, "shell and target arrive at the lead point together")
	assert_true(lead.x > 0.0, "aim ahead of a target moving east")


func test_lead_point_falls_back_when_target_outruns_shell() -> void:
	var lead := Ballistics.lead_point(Vector3.ZERO, Vector3(0, 0, -50), Vector3(0, 0, -100), 70.0)
	assert_true(lead.is_equal_approx(Vector3(0, 0, -50)), "no intercept exists, so aim at the target")


func test_steering_drives_straight_at_a_goal_ahead() -> void:
	var drive := Steering.drive_toward(Vector3.ZERO, NORTH, Vector3(0, 0, -30), 3.0)
	assert_near(drive.x, 1.0, 1e-4, "full throttle toward a distant goal straight ahead")
	assert_near(drive.y, 0.0, 1e-4, "no turning needed")


func test_steering_turns_right_toward_a_goal_on_the_right() -> void:
	var drive := Steering.drive_toward(Vector3.ZERO, NORTH, Vector3(20, 0, -20), 3.0)
	assert_true(drive.y > 0.9, "a goal 45° to the right means turning right hard (turn > 0)")
	assert_true(drive.x > 0.0, "while still driving forward")


func test_steering_turns_in_place_for_a_goal_behind() -> void:
	var drive := Steering.drive_toward(Vector3.ZERO, NORTH, Vector3(0, 0, 30), 3.0)
	assert_eq(drive.x, 0.0, "don't drive away from a goal that's behind you")
	assert_true(absf(drive.y) > 0.9, "turn around instead")


func test_steering_stops_on_arrival() -> void:
	assert_eq(Steering.drive_toward(Vector3.ZERO, NORTH, Vector3(1, 0, -1), 3.0), Vector2.ZERO,
			"inside the arrive radius the tank stops")
