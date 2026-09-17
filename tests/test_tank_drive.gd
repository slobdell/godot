extends TestCase
## Integration: the real arena + tank scenes, stepped through real physics frames.
## Proves a TankCommand actually moves a Tank (the controller seam works).

const ARENA := preload("res://game/arena/arena.tscn")
const TANK := preload("res://game/tank/tank.tscn")


## An open lane on the west side of the arena, clear of obstacles for ~15 m each way.
const LANE := Vector3(-100, 0, 0)


func _spawn_tank() -> Tank:
	add_to_tree(ARENA.instantiate())
	var tank: Tank = TANK.instantiate()
	tank.position = LANE
	add_to_tree(tank)
	return tank


func test_full_throttle_drives_forward() -> void:
	var tank := _spawn_tank()
	tank.command = TankCommand.new(1.0, 0.0, LANE + Vector3(0, 0, -50))
	await wait_physics_frames(SimClock.TICK_RATE)
	assert_true(tank.global_position.z < LANE.z - 4.0,
			"1 s at full throttle moves >4 m along -Z (got z=%.2f)" % tank.global_position.z)
	assert_near(tank.global_position.x, LANE.x, 0.05, "driving straight does not drift sideways")
	assert_near(tank.global_position.y, 0.0, 0.1, "tank rests on the ground, not falling through")


func test_turn_input_rotates_hull() -> void:
	var tank := _spawn_tank()
	tank.command = TankCommand.new(0.0, 1.0, LANE + Vector3(0, 0, -10))
	await wait_physics_frames(30)
	assert_true(tank.rotation.y < -0.3, "turning right yaws the hull clockwise (negative)")


func test_turret_tracks_aim_point() -> void:
	var tank := _spawn_tank()
	tank.command = TankCommand.new(0.0, 0.0, LANE + Vector3(20, 0, 0))
	await wait_physics_frames(120)
	assert_near(tank.turret.rotation.y, -PI / 2.0, 0.05, "turret swings to face a target on the right")
	assert_near(tank.rotation.y, 0.0, 1e-4, "aiming the turret does not turn the hull")
