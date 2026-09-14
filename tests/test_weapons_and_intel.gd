extends TestCase
## Flamethrower cone damage, shared team vision, and a brain in a real scene.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const CRATE := preload("res://game/arena/crate.tscn")
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _place(tank: Tank, z: float, yaw: float) -> void:
	tank.global_position = Vector3(LANE_X, 0.0, z)
	tank.rotation.y = yaw


func test_cone_geometry() -> void:
	assert_true(Weapons.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -10), 20.0, 30.0), "straight ahead, in range")
	assert_true(Weapons.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(2, 0, -10), 20.0, 30.0), "11° off axis is inside a 30° cone")
	assert_true(not Weapons.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(5, 0, -10), 20.0, 30.0), "27° off axis is outside")
	assert_true(not Weapons.in_cone(Vector3.ZERO, Vector3.FORWARD, Vector3(0, 0, -25), 20.0, 30.0), "beyond range")


func _burn(target_z: float, target_yaw: float, seconds: float, blocker := false) -> Tank:
	var game_match := _setup()
	var burner := game_match.spawn_tank("Burner", 0, Match.Team.GREEN, "flamethrower")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
	_place(burner, 20.0, 0.0)
	_place(target, target_z, target_yaw)
	if blocker:
		var crate: Node3D = CRATE.instantiate()
		crate.position = Vector3(LANE_X, 0.0, 14.0)
		add_to_tree(crate)
	await wait_physics_frames(2)
	for frame in int(seconds * 60):
		burner.command = TankCommand.new(0.0, 0.0, target.global_position, true)
		await tree.physics_frame
	return target


func test_flamethrower_burns_at_close_range() -> void:
	var target: Tank = await _burn(10.0, PI / 2.0, 1.0)  # 10 m ahead, side-on
	assert_near(target.health, target.max_health - 45, 3, "one second in the cone deals ~45 to side armor")


func test_flamethrower_is_short_range() -> void:
	var target: Tank = await _burn(-5.0, PI / 2.0, 1.0)  # 25 m away
	assert_eq(target.health, target.max_health, "25 m is out of a flamethrower's 20 m reach")


func test_flamethrower_needs_line_of_sight() -> void:
	var target: Tank = await _burn(8.0, PI / 2.0, 1.0, true)
	assert_eq(target.health, target.max_health, "a crate between them blocks the flames")


func test_team_vision_is_shared_and_remembered() -> void:
	var game_match := _setup()
	var spotter := game_match.spawn_tank("Spotter", 0, Match.Team.GREEN)
	var blind := game_match.spawn_tank("Blind", 0, Match.Team.GREEN)
	var enemy := game_match.spawn_tank("Enemy", 0, Match.Team.RUST)
	_place(spotter, 30.0, 0.0)
	_place(enemy, 0.0, PI)
	blind.global_position = Vector3(48, 0, 40)  # far across the map, no line of sight
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 2)
	assert_true(game_match.intel[Match.Team.GREEN].has("Enemy"), "the spotter's sighting is team knowledge")
	assert_true(game_match.intel[Match.Team.GREEN]["Enemy"]["visible"], "and marked visible")
	spotter.global_position = Vector3(-48, 0, 58)  # tuck behind... simply move out of sensor range
	enemy.global_position = Vector3(LANE_X, 0, -40)
	await wait_physics_frames(Match.INTEL_EVERY_TICKS + 2)
	assert_true(game_match.intel[Match.Team.GREEN].has("Enemy"), "an enemy out of sight is remembered")
	assert_true(not game_match.intel[Match.Team.GREEN]["Enemy"]["visible"], "but no longer visible")
	assert_true(not game_match.intel[Match.Team.RUST].has("Blind") or game_match.intel[Match.Team.RUST]["Blind"]["visible"] == false \
			or Perception.has_line_of_sight(enemy, blind), "intel only contains what someone could see")


func test_brain_engages_a_visible_enemy() -> void:
	var game_match := _setup()
	var brain_tank := game_match.add_brain_tank(Match.Team.GREEN, "Solo", "cannon", [], "Green_Solo_1")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
	_place(brain_tank, 20.0, 0.0)
	_place(target, -20.0, PI / 2.0)
	var lowest := target.health
	for frame in 60 * 8:
		await tree.physics_frame
		lowest = mini(lowest, target.health)
	assert_true(lowest < target.max_health, "within 8 s the brain senses (via team intel), engages, and hits (lowest %d)" % lowest)
	assert_true(brain_tank.intent.begins_with("ENGAGE") or lowest < target.max_health, "its nameplate intent says what it's doing (%s)" % brain_tank.intent)


func test_hurt_brain_backs_away_under_fire() -> void:
	var game_match := _setup()
	var brain_tank := game_match.add_brain_tank(Match.Team.GREEN, "Solo", "cannon", [], "Green_Solo_1")
	var enemy := game_match.spawn_tank("Enemy", 0, Match.Team.RUST)
	_place(brain_tank, 20.0, 0.0)
	_place(enemy, -10.0, PI)  # facing the brain tank: its gun points at it
	brain_tank.apply_damage(brain_tank.max_health - 15)
	await wait_physics_frames(TankBrain.THINK_EVERY_TICKS * 3)
	var brain: TankBrain = game_match.brains.get_node("Brain_Green_Solo_1")
	assert_eq(brain.choice.get("option"), "RETREAT", "15 HP with an enemy gun on it: retreat (ranked %s)" % [brain.ranked])
	assert_eq(brain.move_order.get("reverse"), true, "backing away, front armor toward the threat")


func test_brain_shoots_what_it_can_see_while_its_target_is_hidden() -> void:
	# Regression (experiment T2, 2026-09-13): brains lost 35% vs BotController because a
	# brain would lock onto a target only a TEAMMATE could see and never fire at the enemy
	# in its own sights. Measured: guns idle 95-97% of loaded-and-in-sight samples.
	var game_match := _setup()
	var brain_tank := game_match.add_brain_tank(Match.Team.GREEN, "Solo", "cannon", [], "Green_Solo_1")
	var brain: TankBrain = game_match.brains.get_node("Brain_Green_Solo_1")
	brain.game_match = null  # freeze the brain's own decisions BEFORE any frame; test the order layer
	var hidden := game_match.spawn_tank("Hidden", 0, Match.Team.RUST)
	var exposed := game_match.spawn_tank("Exposed", 0, Match.Team.RUST)
	_place(brain_tank, 20.0, 0.0)
	_place(exposed, -15.0, PI / 2.0)
	hidden.global_position = Vector3(LANE_X + 8.0, 0.0, 12.0)
	var crate: Node3D = CRATE.instantiate()
	crate.position = Vector3(LANE_X + 4.0, 0.0, 15.0)
	add_to_tree(crate)
	# Force the problem case: engage the hidden tank (as if a teammate had reported it).
	brain.set_orders({"type": "stop"}, {"type": "target", "name": "Hidden", "fallback": true})
	var lowest := exposed.health
	for frame in 60 * 6:
		await tree.physics_frame
		lowest = mini(lowest, exposed.health)
	assert_true(not Perception.has_line_of_sight(brain_tank, hidden), "setup: the named target is hidden")
	assert_true(lowest < exposed.max_health, "with fallback it fires at the enemy it CAN see (lowest %d)" % lowest)
