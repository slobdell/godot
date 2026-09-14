extends TestCase
## Integration: real Match + Arena + tanks + shells, stepped through real physics.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const CRATE := preload("res://game/arena/crate.tscn")
## Open lane on the west side of the arena.
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.respawn_seconds = 1.0
	return game_match


func _place(tank: Tank, z: float, yaw: float) -> void:
	tank.global_position = Vector3(LANE_X, 0.0, z)
	tank.rotation.y = yaw


## Shooter south of the target, both in the lane, one shot fired north.
func _duel(target_yaw: float, target_team: int = Match.Team.RUST) -> Array:
	var game_match := _setup()
	var shooter := game_match.spawn_tank("Shooter", 0, Match.Team.GREEN)
	var target := game_match.spawn_tank("Target", 0, target_team)
	_place(shooter, 20.0, 0.0)
	_place(target, 5.0, target_yaw)
	await wait_physics_frames(2)
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, true)
	await wait_physics_frames(1)
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, false)
	await wait_physics_frames(30)
	return [game_match, shooter, target]


func test_rear_shot_does_rear_damage() -> void:
	var result: Array = await _duel(0.0)  # target faces north, away from the shooter
	assert_eq(result[2].health, result[2].max_health - 51, "a shot into the rear armor deals 1.5x of 34")


func test_front_shot_does_front_damage() -> void:
	var result: Array = await _duel(PI)  # target faces south, toward the shooter
	assert_eq(result[2].health, result[2].max_health - 17, "a shot into the front armor deals half of 34")


func test_side_shot_does_side_damage() -> void:
	var result: Array = await _duel(PI / 2.0)
	assert_eq(result[2].health, result[2].max_health - 34, "a shot into the side armor deals full damage")


func test_no_friendly_fire() -> void:
	var result: Array = await _duel(0.0, Match.Team.GREEN)
	assert_eq(result[2].health, result[2].max_health, "shells don't damage teammates")


func test_wall_blocks_shell() -> void:
	var game_match := _setup()
	var crate: Node3D = CRATE.instantiate()
	crate.position = Vector3(LANE_X, 0.0, 12.0)
	add_to_tree(crate)
	var shooter := game_match.spawn_tank("Shooter", 0, Match.Team.GREEN)
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
	_place(shooter, 20.0, 0.0)
	_place(target, 5.0, 0.0)
	await wait_physics_frames(2)
	assert_true(not Perception.has_line_of_sight(shooter, target), "the crate blocks line of sight")
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, true)
	await wait_physics_frames(1)
	shooter.command = TankCommand.new()
	await wait_physics_frames(30)
	assert_eq(target.health, target.max_health, "the crate absorbs the shell")


func test_kill_scores_and_respawns() -> void:
	var game_match := _setup()
	game_match.respawn_seconds = 1.0  # must outlast the shell's flight so we can observe "dead"
	var shooter := game_match.spawn_tank("Shooter", 0, Match.Team.GREEN)
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
	_place(shooter, 20.0, 0.0)
	_place(target, 5.0, 0.0)
	await wait_physics_frames(2)
	assert_true(Perception.has_line_of_sight(shooter, target), "open lane: clear line of sight")
	target.health = 10
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, true)
	await wait_physics_frames(1)
	shooter.command = TankCommand.new()
	await wait_physics_frames(30)
	assert_true(not target.is_alive(), "the hit destroys a tank on 10 HP")
	assert_eq(game_match.score_green, 1, "the kill scores for Green")
	await tree.create_timer(1.2).timeout
	await wait_physics_frames(2)
	assert_true(target.is_alive(), "the tank respawns after respawn_seconds")
	assert_eq(target.health, target.max_health, "with full health")
	assert_true(target.global_position.distance_to(Match.spawn_position(Match.Team.RUST, target.slot)) < 1.0,
			"at its team's spawn slot")


func test_bot_engages_a_visible_enemy() -> void:
	var game_match := _setup()
	var target := game_match.spawn_tank("Target", 0, Match.Team.GREEN)
	var bot := game_match.add_bot()
	assert_eq(bot.team, Match.Team.RUST, "the bot joins the smaller team")
	_place(target, 15.0, PI / 2.0)
	_place(bot, -15.0, PI)
	# Track the lowest health seen: a lethal bot can kill AND the target can respawn
	# at full health before the check (this exact false failure happened once).
	var lowest_health := target.health
	for frame in 60 * 5:
		await tree.physics_frame
		lowest_health = mini(lowest_health, target.health)
	assert_true(lowest_health < target.max_health, "within 5 s the bot turns its turret, leads, and hits (lowest health %d)" % lowest_health)
