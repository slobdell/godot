extends TestCase
## The arena bakes a navigation mesh; move_to follows it around obstacles.
## Reproduces playtest #1's deadlock: a bot pinned against CoverNorth (x 19..37,
## z -60.75..-59.25 since the arena doubled) trying to reach a tank directly behind it.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")


func _setup() -> Array:
	# Wait for THIS arena's navmesh, not any navmesh (lesson 87): Pathing.is_ready() is true for the previous test's
	# regions for a frame or two, and a path planned on them runs straight through this arena's walls. squad caught it
	# (round 7): this file failed after test_movement and passed alone.
	var arena := await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return [arena, game_match]


func test_path_goes_around_a_wall() -> void:
	var setup: Array = await _setup()
	var arena: Node3D = setup[0]
	var from := Vector3(28, 0, -50)  # south of CoverNorth
	var to := Vector3(28, 0, -70)    # directly north of it
	var path := Pathing.find_path(arena, from, to)
	assert_true(path.size() >= 3, "a wall in the way needs intermediate waypoints (got %d points)" % path.size())
	var detours := false
	for point in path:
		if point.x < 19.0 - 1.0 or point.x > 37.0 + 1.0:
			detours = true
	assert_true(detours, "the path swings past an end of the 18 m wall")
	if path.size() > 0:
		assert_true(path[path.size() - 1].distance_to(to) < 1.5, "and ends at the goal")


func test_bot_reaches_target_hidden_behind_wall() -> void:
	var setup: Array = await _setup()
	var game_match: Match = setup[1]
	var target := game_match.spawn_tank("Target", 0, Match.Team.GREEN)
	var bot := game_match.add_bot()
	target.global_position = Vector3(28, 0, -72)
	target.rotation.y = PI / 2.0
	bot.global_position = Vector3(28, 0, -48)
	bot.rotation.y = 0.0  # facing north, straight at the wall
	await wait_physics_frames(2)
	assert_true(not Perception.has_line_of_sight(bot, target), "setup: the wall hides the target")
	var lowest_health := target.health
	for frame in SimClock.TICK_RATE * 20:
		await tree.physics_frame
		lowest_health = mini(lowest_health, target.health)
		if lowest_health < target.max_health:
			break
	assert_true(lowest_health < target.max_health, "within 20 s the bot paths around the wall and hits (lowest health %d, bot at %s)" % [
			lowest_health, bot.global_position])


func test_navigation_is_point_symmetric() -> void:
	# Fairness guard: the same trip rotated 180° must be exactly as long. A plain bake
	# failed this by up to 4.4 m and the south base won 64% of 140 bot matches
	# (see arena.gd and squad_ai_design.md "Fairness").
	var setup: Array = await _setup()
	var arena: Node3D = setup[0]
	var trips := [[Vector3(0, 0, 42), Vector3(0, 0, -42)], [Vector3(12, 0, 42), Vector3(-12, 0, -12)],
			[Vector3(-24, 0, 42), Vector3(10, 0, -20)], [Vector3(14, 0, -24), Vector3(14, 0, -36)]]
	for trip in trips:
		var from: Vector3 = trip[0]
		var to: Vector3 = trip[1]
		var forward_length := _path_length(Pathing.find_path(arena, from, to))
		var mirrored_length := _path_length(Pathing.find_path(arena, -from, -to))
		assert_true(forward_length > 0.0, "trip %s -> %s has a path" % [from, to])
		assert_near(forward_length, mirrored_length, 0.05,
				"trip %s -> %s is as long as its 180° mirror" % [from, to])


func _path_length(path: PackedVector3Array) -> float:
	var total := 0.0
	for i in path.size() - 1:
		total += path[i].distance_to(path[i + 1])
	return total
