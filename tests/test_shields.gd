extends TestCase
## G6: Halo-style shields over hull health. The shield absorbs first (evenly, no facing), recharges
## after a quiet spell; the hull only mends at base.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func test_the_shield_split_is_pure_math() -> void:
	assert_eq(Armor.split_shield(34.0, 150.0, 0.8, 1.5), Vector2(27.2, 0.0), "a full shield takes the whole hit (x0.8), the rear armor nothing")
	var split := Armor.split_shield(34.0, 13.6, 0.8, 1.0)
	assert_near(split.x, 13.6, 0.001, "a thin shield absorbs what it has")
	assert_near(split.y, 17.0, 0.001, "and half the shell (the half it couldn't absorb) reaches the hull")
	assert_eq(Armor.split_shield(34.0, 0.0, 0.8, 0.5), Vector2(0.0, 17.0), "no shield: straight to the armor")


func _shot(target_shield: float, weapon_id := "cannon") -> Tank:
	var game_match := _setup()
	var shooter := game_match.spawn_tank("Shooter", 0, Match.Team.GREEN, weapon_id)
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
	shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
	target.global_position = Vector3(LANE_X, 0.0, 5.0)
	target.rotation.y = PI / 2.0  # side-on
	target.shield = target_shield
	target.ticks_since_hit = 0  # as if just hit: no recharge during the test
	await wait_physics_frames(2)
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, true)
	await wait_physics_frames(1)
	shooter.command = TankCommand.new(0.0, 0.0, target.global_position, false)
	await wait_physics_frames(20)
	return target


func test_a_full_shield_absorbs_a_shell() -> void:
	var target: Tank = await _shot(150.0)
	assert_eq(target.health, target.max_health, "the hull is untouched")
	assert_near(target.shield, 150.0 - 34.0 * 0.8, 0.01, "the shield took 34 x 0.8, from the side or any side")


func test_what_the_shield_cannot_absorb_reaches_the_hull() -> void:
	var target: Tank = await _shot(13.6)
	assert_near(target.shield, 0.0, 0.001, "the shield breaks")
	assert_eq(target.health, target.max_health - 17, "half the shell gets through to the side armor")


func test_lasers_strip_shields_faster() -> void:
	var cannon: float = Weapons.profile("cannon")["shield_multiplier"]
	var laser: float = Weapons.profile("laser")["shield_multiplier"]
	assert_true(laser > 1.0 and cannon < 1.0, "energy weapons are anti-shield, shells are hull breakers (%s vs %s)" % [laser, cannon])
	var target: Tank = await _shot(150.0, "laser")
	assert_near(target.shield, 150.0 - float(Weapons.profile("laser")["damage"]) * laser, 0.01, "one pulse x %.1f against the shield" % laser)


func test_the_shield_recharges_after_a_quiet_spell() -> void:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Tank", 0, Match.Team.GREEN)
	tank.global_position = Vector3(LANE_X, 0.0, 20.0)
	await wait_physics_frames(2)
	tank.take_hit(1000.0, 1.0, 0.0)  # shield gone, armor multiplier 0: the hull is untouched
	assert_eq(tank.shield, 0.0, "setup: shield broken")
	await wait_physics_frames(roundi(tank.shield_recharge_delay * 60.0) - 10)
	assert_eq(tank.shield, 0.0, "nothing comes back during the delay")
	tank.take_hit(1.0, 1.0, 0.0)  # a new hit restarts the delay
	await wait_physics_frames(roundi(tank.shield_recharge_delay * 60.0) - 10)
	assert_eq(tank.shield, 0.0, "a hit during the delay restarts it")
	await wait_physics_frames(10 + 60)
	assert_near(tank.shield, tank.shield_recharge_rate, 2.0, "then it refills at %.0f per second" % tank.shield_recharge_rate)
	await wait_physics_frames(roundi(tank.max_shield / tank.shield_recharge_rate * 60.0))
	assert_eq(tank.shield, tank.max_shield, "all the way to full")
	assert_eq(tank.sync_shield, roundi(tank.max_shield), "and replicates")


func test_the_hull_only_mends_at_base() -> void:
	var game_match := _setup()
	var home := game_match.spawn_tank("Home", 0, Match.Team.GREEN)
	var field := game_match.spawn_tank("Field", 0, Match.Team.GREEN)
	home.global_position = Match.resupply_center(Match.Team.GREEN) + Vector3(-8, 0, 0)
	field.global_position = Vector3(LANE_X, 0.0, 0.0)
	await wait_physics_frames(2)
	for tank in [home, field]:
		tank.shield = 0.0
		tank.take_hit(100.0, 1.0, 1.0)
	var worn := home.health
	await wait_physics_frames(roundi(home.shield_recharge_delay * 60.0) + 60 * 2 + Match.INTEL_EVERY_TICKS)
	assert_eq(field.health, worn, "out in the field the hull stays damaged")
	assert_true(home.health > worn and home.health <= worn + roundi(Match.REPAIR_HP_PER_SECOND * 2.0) + 1,
			"at base it mends slowly once the shooting stops (%d -> %d)" % [worn, home.health])


func _brain_situation(health: int, shield: float, overrides: Dictionary = {}) -> Dictionary:
	var s := {
		"tick": 1000,
		"self": {"name": "Green_A_1", "team": 0, "position": Vector3.ZERO, "forward": Vector3.FORWARD,
				"health": health, "max_health": 300, "shield": shield, "max_shield": 150.0,
				"weapon": Weapons.profile("cannon")},
		"directives": Directives.resolve([]),
		"contacts": [{"name": "Rust_A_1", "position": Vector3(0, 0, -40), "velocity": Vector3.ZERO, "forward": Vector3.BACK,
				"health": 300, "shield": 150, "weapon": "cannon", "visible": true, "age": 0, "exposed_face": "front",
				"facing_ally": false, "aiming_at_me": true}],
		"allies": [], "objective": null, "objective_radius": 0.0, "squad_center": null,
		"cover": [Vector3(10, 0, 5)], "rally": Vector3(0, 0, 90), "enemy_base": Vector3(0, 0, -90),
		"memory_ticks": Match.CONTACT_MEMORY_TICKS,
	}
	s.merge(overrides, true)
	return s


func test_with_its_shield_down_a_worn_tank_ducks_out_to_recharge() -> void:
	var fresh := TankBrain.label(TankBrain.decide(_brain_situation(200, 150.0), {})["choice"])
	assert_eq(fresh, "ENGAGE Rust_A_1", "shield up at 2/3 hull: keep fighting")
	var broken := TankBrain.label(TankBrain.decide(_brain_situation(200, 0.0), {})["choice"])
	assert_eq(broken, "RECHARGE", "same hull, shield down, a gun on it: break contact and let the shield come back")
	var s := _brain_situation(200, 60.0)
	assert_eq(TankBrain.label(TankBrain.decide(s, {"option": "RECHARGE", "target": "", "since": 990})["choice"]), "RECHARGE",
			"a recharging tank keeps ducking until the shield is mostly back")
	s["self"]["shield"] = 120.0
	assert_eq(TankBrain.label(TankBrain.decide(s, {"option": "RECHARGE", "target": "", "since": 0})["choice"]), "ENGAGE Rust_A_1",
			"then it comes back to the fight")


func test_a_worn_tank_goes_home_to_mend_and_waits_there() -> void:
	var quiet := {"contacts": [], "cover": []}
	var hurt_in_field := TankBrain.label(TankBrain.decide(_brain_situation(80, 150.0, quiet), {})["choice"])
	assert_eq(hurt_in_field, "RESUPPLY", "badly hurt with nobody around: go home to mend")
	var s := _brain_situation(200, 150.0, quiet)
	s["self"]["in_resupply_zone"] = true
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "RESUPPLY", "at base and worn: stay until mended")
	s["self"]["health"] = 290
	assert_eq(TankBrain.label(TankBrain.decide(s, {})["choice"]), "ADVANCE", "mended: back to the fight")
