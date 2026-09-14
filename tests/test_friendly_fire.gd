extends TestCase
## Rules R4: friendly fire is on (the lead). Shells, beams, and bursts hurt teammates; the match records it, the
## announcer calls it out, and Match.friendlies_in_line_of_fire (contract C4) tells the AI who a shot endangers.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _at(tank: Tank, x: float, z: float, yaw := 0.0) -> Tank:
	tank.global_position = Vector3(LANE_X + x, 0.0, z)
	tank.rotation.y = yaw
	return tank


func _names(tanks: Array[Tank]) -> Array:
	return tanks.map(func(tank: Tank) -> String: return String(tank.name))


func test_a_laser_through_a_teammate_hurts_it_and_scores_nothing() -> void:
	var game_match := _setup()
	var lancer := _at(game_match.spawn_tank("Green_Lance_1", 0, Match.Team.GREEN, "lancer"), 0.0, 30.0)
	var friend := _at(game_match.spawn_tank("Green_Guns_1", 0, Match.Team.GREEN, "tank"), 0.0, 10.0, PI / 2.0)
	var enemy := _at(game_match.spawn_tank("Rust_Guns_1", 0, Match.Team.RUST, "tank"), 0.0, -20.0)
	await wait_physics_frames(2)
	for tick in 60 * 2:
		lancer.command = TankCommand.new(0.0, 0.0, enemy.global_position, true)
		await tree.physics_frame
	assert_true(friend.health + friend.shield < friend.max_health + friend.max_shield, "the teammate in the beam's path takes the pulses")
	assert_eq(enemy.health + int(enemy.shield), enemy.max_health + int(enemy.max_shield), "the enemy behind it is shielded by it")
	assert_true(game_match.stats["friendly_damage"][Match.Team.GREEN] > 0.0, "friendly damage is recorded for the shooter's team")
	assert_eq(game_match.stats["damage"][Match.Team.GREEN], 0, "and isn't counted as damage to the enemy")


func test_a_friendly_kill_scores_nothing_and_is_announced() -> void:
	var game_match := _setup()
	var doctrine := {"name": "Us", "squads": [{"name": "Alpha", "units": [{"unit": "tank"}, {"unit": "tank"}]}]}
	assert_eq(game_match.load_doctrine(Match.Team.GREEN, doctrine), "", "setup: doctrine")
	var announcer := MatchAnnouncer.new()
	announcer.game_match = game_match
	game_match.add_child(announcer)
	var messages: Array = []
	announcer.announced.connect(func(text: String, _severity: int) -> void: messages.append(text))
	var victim := game_match.tanks.get_node("Green_Alpha_2") as Tank
	await wait_physics_frames(2)
	game_match._land_hit(victim, 10.0, Weapons.profile("cannon"), Vector3.FORWARD, Match.Team.GREEN, "Green_Alpha_1", "", true)
	assert_true(messages.has("Friendly fire: Alpha 1 hit Alpha 2"), "a friendly hit is called out: %s" % [messages])
	game_match._land_hit(victim, 10.0, Weapons.profile("cannon"), Vector3.FORWARD, Match.Team.GREEN, "Green_Alpha_1", "", true)
	assert_eq(messages.filter(func(m: String) -> bool: return m.begins_with("Friendly fire")).size(), 1, "but not every hit")
	victim.shield = 0.0
	game_match._land_hit(victim, 5000.0, Weapons.profile("cannon"), Vector3.FORWARD, Match.Team.GREEN, "Green_Alpha_1", "", true)
	assert_true(not victim.is_alive(), "setup: the teammate is destroyed")
	assert_eq(game_match.score_green, 0, "killing a teammate scores nothing")
	assert_eq(game_match.stats["friendly_kills"][Match.Team.GREEN], 1, "it's counted as a friendly kill")
	assert_true(messages.any(func(m: String) -> bool: return m.contains("to friendly fire from Alpha 1")), "the loss names the shooter: %s" % [messages])


func test_direct_fire_line_finds_teammates_in_the_corridor() -> void:
	var game_match := _setup()
	var shooter := _at(game_match.spawn_tank("Shooter", 0, Match.Team.GREEN, "tank"), 0.0, 40.0)
	var in_line := _at(game_match.spawn_tank("InLine", 0, Match.Team.GREEN, "ifv"), 0.5, 10.0)
	var beside := _at(game_match.spawn_tank("Beside", 0, Match.Team.GREEN, "tank"), 12.0, 10.0)
	var behind := _at(game_match.spawn_tank("Behind", 0, Match.Team.GREEN, "tank"), 0.0, 60.0)
	var past := _at(game_match.spawn_tank("PastTarget", 0, Match.Team.GREEN, "tank"), 0.0, -20.0)
	var far_past := _at(game_match.spawn_tank("FarPast", 0, Match.Team.GREEN, "tank"), 0.0, -55.0)
	var enemy := _at(game_match.spawn_tank("Enemy", 0, Match.Team.RUST, "tank"), 0.0, -30.0)
	await wait_physics_frames(2)
	var aim := Vector3(LANE_X, 0.0, -10.0)  # 50 m ahead
	var names := _names(game_match.friendlies_in_line_of_fire(shooter, aim))
	assert_eq(names, ["InLine", "PastTarget"], "in front of the gun, and just past the aim point, nearest first (got %s)" % [names])
	assert_true(not names.has("Beside") and not names.has("Behind") and not names.has("FarPast"),
			"not beside the corridor, not behind the gun, not far past the target")
	assert_true(not names.has(String(enemy.name)) and not names.has("Shooter"), "never enemies or the shooter")
	in_line.apply_damage(100000)
	await wait_physics_frames(1)
	assert_eq(_names(game_match.friendlies_in_line_of_fire(shooter, aim)), ["PastTarget"], "wrecks don't count")
	for tank: Tank in [beside, behind, far_past]:
		assert_true(tank.is_alive(), "setup: %s alive" % tank.name)


func test_splash_and_flame_lines() -> void:
	var game_match := _setup()
	var battery := _at(game_match.spawn_tank("Battery", 0, Match.Team.GREEN, "artillery"), 0.0, 90.0)
	var near_burst := _at(game_match.spawn_tank("NearBurst", 0, Match.Team.GREEN, "tank"), 6.0, 0.0)
	var clear := _at(game_match.spawn_tank("Clear", 0, Match.Team.GREEN, "tank"), 40.0, 0.0)
	var under_arc := _at(game_match.spawn_tank("UnderTheArc", 0, Match.Team.GREEN, "tank"), 0.0, 45.0)
	await wait_physics_frames(2)
	var names := _names(game_match.friendlies_in_line_of_fire(battery, Vector3(LANE_X, 0.0, 0.0)))
	assert_eq(names, ["NearBurst"], "a mortar endangers teammates near where it lands, not under its arc (got %s)" % [names])
	var burner := _at(game_match.spawn_tank("Burner", 0, Match.Team.RUST, "tank"), 60.0, 0.0)
	burner.set_weapon("flamethrower")
	var in_flame := _at(game_match.spawn_tank("InFlame", 0, Match.Team.RUST, "tank"), 60.0, -12.0)
	var out_of_flame := _at(game_match.spawn_tank("OutOfFlame", 0, Match.Team.RUST, "tank"), 75.0, -12.0)
	await wait_physics_frames(2)
	assert_eq(_names(game_match.friendlies_in_line_of_fire(burner, Vector3(LANE_X + 60.0, 0.0, -30.0))), ["InFlame"],
			"a flamethrower endangers teammates inside its cone")
	for tank: Tank in [clear, under_arc, out_of_flame]:
		assert_true(tank.is_alive(), "setup: %s alive" % tank.name)
