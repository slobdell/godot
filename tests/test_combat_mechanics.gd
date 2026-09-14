extends TestCase
## Rules R2: the mechanics that make counters real, with no damage table: penetration vs armor facing, fixed
## mounts that aim with the hull, turret tracking, per-weapon shell range, and artillery that needs team sight.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## Open lane on the west side of the arena.
const LANE_X := -100.0


func _setup() -> Match:
	var arena := add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.set_meta("arena", arena)
	return game_match


## Free one round's match and arena inside a test that runs several.
func _dispose(game_match: Match) -> void:
	(game_match.get_meta("arena") as Node).queue_free()
	game_match.queue_free()
	await wait_physics_frames(2)


func _unshielded(tank: Tank) -> void:
	tank.max_shield = 0.0
	tank.shield = 0.0


# ---- Penetration vs armor facing ----------------------------------------------------------

func test_the_cannon_against_a_tank_keeps_round_ones_armor_table() -> void:
	var cannon := Weapons.profile("cannon")
	assert_near(Match.armor_multiplier(cannon, "tank", "front"), 0.5, 0.001, "front armor halves a cannon shell")
	assert_near(Match.armor_multiplier(cannon, "tank", "side"), 1.0, 0.001, "the side takes it in full")
	assert_near(Match.armor_multiplier(cannon, "tank", "rear"), 1.5, 0.001, "the rear takes half again")


func test_light_guns_barely_scratch_heavy_fronts() -> void:
	for weapon_id in ["machine_gun", "autocannon"]:
		var multiplier := Match.armor_multiplier(Weapons.profile(weapon_id), "tank", "front")
		assert_true(multiplier <= 0.1, "a %s against a tank's front does almost nothing (x%.2f)" % [weapon_id, multiplier])
	assert_true(Match.armor_multiplier(Weapons.profile("autocannon"), "scout", "side") >= 1.0,
			"but the autocannon shreds a scout's side")
	assert_true(Match.armor_multiplier(Weapons.profile("autocannon"), "scout", "front")
			> 5.0 * Match.armor_multiplier(Weapons.profile("autocannon"), "tank", "front"), "and a scout's front")


func test_everything_hurts_from_behind() -> void:
	for weapon_id: String in Weapons.PROFILES:
		var weapon := Weapons.profile(weapon_id)
		for unit_id: String in Units.PROFILES:
			var front := Match.armor_multiplier(weapon, unit_id, "front")
			var rear := Match.armor_multiplier(weapon, unit_id, "rear")
			assert_true(rear >= front, "%s into a %s's rear hurts at least as much as the front (%.2f vs %.2f)" % [weapon_id, unit_id, rear, front])
			assert_true(rear >= 0.4, "%s from behind always hurts a %s (x%.2f)" % [weapon_id, unit_id, rear])


func test_penetration_math_edges() -> void:
	assert_eq(Armor.penetration_multiplier(0.0, 5.0), Armor.PENETRATION_FLOOR, "no penetration scratches")
	assert_eq(Armor.penetration_multiplier(5.0, 0.0), Armor.PENETRATION_CAP, "no armor is a weak spot")
	assert_near(Armor.penetration_multiplier(8.0, 4.0) - Armor.penetration_multiplier(4.0, 4.0), 0.5, 0.001,
			"doubling penetration adds half the damage back")


func test_an_ifv_cannot_crack_a_tank_front_in_a_real_fight() -> void:
	var game_match := _setup()
	var ifv := game_match.spawn_tank("Ifv", 0, Match.Team.GREEN, "ifv")
	var tank := game_match.spawn_tank("Tank", 0, Match.Team.RUST, "tank")
	var scout := game_match.spawn_tank("Scout", 0, Match.Team.RUST, "scout")
	ifv.global_position = Vector3(LANE_X, 0.0, 20.0)
	tank.global_position = Vector3(LANE_X, 0.0, -10.0)
	tank.rotation.y = PI  # facing the IFV
	scout.global_position = Vector3(LANE_X + 30.0, 0.0, -10.0)
	scout.rotation.y = PI / 2.0  # showing its side
	_unshielded(tank)
	_unshielded(scout)
	await wait_physics_frames(2)
	for target: Tank in [tank, scout]:
		for tick in 60 * 3:
			ifv.command = TankCommand.new(0.0, 0.0, target.global_position, true)
			tank.command = TankCommand.new()
			scout.command = TankCommand.new()
			await tree.physics_frame
	assert_true(tank.max_health - tank.health <= 10, "3 s of autocannon on a tank's front: %d damage" % (tank.max_health - tank.health))
	var scout_damage := scout.max_health - scout.health
	assert_true(scout_damage >= 30 and scout_damage >= 4 * (tank.max_health - tank.health),
			"3 s on a scout's side (42 m, some rounds miss): %d damage, several times the tank's" % scout_damage)


# ---- Fixed mounts ---------------------------------------------------------------------------

func test_a_fixed_gun_swings_only_inside_its_arc() -> void:
	var game_match := _setup()
	var scout := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
	var tank := game_match.spawn_tank("Tank", 0, Match.Team.GREEN, "tank")
	scout.global_position = Vector3(LANE_X, 0.0, 20.0)
	tank.global_position = Vector3(LANE_X + 20.0, 0.0, 20.0)
	await wait_physics_frames(2)
	var right_of_scout := scout.global_position + Vector3(30.0, 0.0, 0.0)
	var right_of_tank := tank.global_position + Vector3(30.0, 0.0, 0.0)
	for tick in 60 * 3:
		scout.command = TankCommand.new(0.0, 0.0, right_of_scout, false)
		tank.command = TankCommand.new(0.0, 0.0, right_of_tank, false)
		await tree.physics_frame
	assert_eq(scout.mount, "fixed", "setup: the scout's gun is fixed")
	assert_near(absf(rad_to_deg(scout.turret.rotation.y)), scout.fire_arc_deg / 2.0, 0.5,
			"asked to aim 90° right, the hood gun stops at the edge of its %.0f° arc" % scout.fire_arc_deg)
	assert_near(rad_to_deg(tank.turret.rotation.y), -90.0, 1.0, "a turret swings all the way")
	assert_true(not scout.can_bear_on(right_of_scout), "the scout can't bear on a target beside it")
	assert_true(scout.can_bear_on(scout.global_position + Vector3(0.0, 0.0, -30.0)), "but can on one ahead")
	assert_true(tank.can_bear_on(right_of_tank), "a turret bears on anything")


func test_a_scout_only_hits_what_it_points_at() -> void:
	var hits_on := func(offset: Vector3) -> int:
		var game_match := _setup()
		var scout := game_match.spawn_tank("Scout", 0, Match.Team.GREEN, "scout")
		var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
		scout.global_position = Vector3(LANE_X, 0.0, 20.0)
		target.global_position = scout.global_position + offset
		await wait_physics_frames(2)
		for tick in 60 * 2:
			scout.command = TankCommand.new(0.0, 0.0, target.global_position, true)
			target.command = TankCommand.new()
			await tree.physics_frame
		var hits: int = game_match.stats["hits"][Match.Team.GREEN]
		await _dispose(game_match)
		return hits
	var ahead: int = await hits_on.call(Vector3(0.0, 0.0, -25.0))
	var beside: int = await hits_on.call(Vector3(18.0, 0.0, -18.0))  # 45° off the nose
	assert_true(ahead >= 5, "a target dead ahead gets hit (%d hits)" % ahead)
	assert_eq(beside, 0, "a target 45° off the nose is never hit: the hull must turn")


# ---- Turret tracking ------------------------------------------------------------------------

## The worst aim error (degrees) while a target crosses 10 m in front of a stationary `unit_id` at scout speed.
func _worst_tracking_error(unit_id: String) -> float:
	var game_match := _setup()
	var gunner := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN, unit_id)
	var runner := game_match.spawn_tank("Runner", 0, Match.Team.RUST, "scout")
	gunner.global_position = Vector3(LANE_X, 0.0, 20.0)
	var start := Vector3(LANE_X - 14.0, 0.0, 10.0)
	runner.global_position = start
	for tick in 60 * 2:  # line up on the start point first
		gunner.command = TankCommand.new(0.0, 0.0, runner.global_position, false)
		await tree.physics_frame
	var worst := 0.0
	var speed := float(Units.profile("scout")["max_forward_speed"])
	for tick in 120:  # 2 s: 28 m across the nose, closest at 1 s
		runner.global_position = start + Vector3(speed * tick / 60.0, 0.0, 0.0)
		gunner.command = TankCommand.new(0.0, 0.0, runner.global_position, false)
		await tree.physics_frame
		worst = maxf(worst, rad_to_deg(Ballistics.aim_error(gunner.turret.global_position, gunner.turret_forward(), runner.global_position)))
	await _dispose(game_match)
	return worst


func test_a_slow_tank_turret_loses_a_close_scout_that_an_ifv_tracks() -> void:
	var tank_error := await _worst_tracking_error("tank")
	var ifv_error := await _worst_tracking_error("ifv")
	var cannon_tolerance := float(Weapons.profile("cannon")["aim_tolerance_deg"])
	assert_true(tank_error > cannon_tolerance * 3.0, "the tank's turret falls %.0f° behind a scout crossing at 10 m" % tank_error)
	assert_true(ifv_error <= float(Weapons.profile("autocannon")["aim_tolerance_deg"]),
			"the IFV's fast turret stays on it (worst %.1f°)" % ifv_error)


# ---- Per-weapon range -----------------------------------------------------------------------

func test_autocannon_rounds_fall_short_past_its_range() -> void:
	var damage_at := func(distance: float) -> int:
		var game_match := _setup()
		var ifv := game_match.spawn_tank("Ifv", 0, Match.Team.GREEN, "ifv")
		var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
		ifv.global_position = Vector3(LANE_X, 0.0, 40.0)
		target.global_position = Vector3(LANE_X, 0.0, 40.0 - distance)
		target.rotation.y = PI / 2.0
		_unshielded(target)
		await wait_physics_frames(2)
		for tick in 60 * 3:
			ifv.command = TankCommand.new(0.0, 0.0, target.global_position, true)
			target.command = TankCommand.new()
			await tree.physics_frame
		var lost := target.max_health - target.health
		await _dispose(game_match)
		return lost
	var in_range: int = await damage_at.call(50.0)
	var out_of_range: int = await damage_at.call(float(Weapons.profile("autocannon")["range"]) + Shell.RANGE_MARGIN + 6.0)
	assert_true(in_range > 0, "50 m: inside the autocannon's range, rounds land (%d damage)" % in_range)
	assert_eq(out_of_range, 0, "past its range the rounds burn out before arriving")


# ---- Artillery needs team sight ---------------------------------------------------------------

func test_unspotted_artillery_fire_scatters_wide() -> void:
	var mortar := Weapons.profile("mortar")
	assert_near(Match.arc_scatter(mortar, 100.0, false), Match.arc_scatter(mortar, 100.0, true) * Match.BLIND_SCATTER_FACTOR, 0.001,
			"a blind round scatters %.0fx wider" % Match.BLIND_SCATTER_FACTOR)
	var game_match := _setup()
	var spotter := game_match.spawn_tank("Eyes", 0, Match.Team.GREEN, "scout")
	spotter.global_position = Vector3(LANE_X, 0.0, 40.0)
	await wait_physics_frames(2)
	assert_true(game_match.is_point_spotted(Match.Team.GREEN, Vector3(LANE_X, 0.0, -40.0)), "80 m from a scout (110 m sight): spotted")
	assert_true(not game_match.is_point_spotted(Match.Team.GREEN, Vector3(LANE_X, 0.0, -100.0)), "140 m away: blind")
	assert_true(not game_match.is_point_spotted(Match.Team.RUST, Vector3(LANE_X, 0.0, -40.0)), "the other team doesn't share the view")
