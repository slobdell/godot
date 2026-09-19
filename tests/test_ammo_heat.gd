extends TestCase
## G7: finite ammunition with a base resupply zone, the laser (hitscan, heat), and the heat cap. Rules R8 made
## direct-fire guns unlimited (only the mortar has a load), so the ammo mechanics are tested on a tank given a load.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0


func _setup() -> Match:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	return game_match


func _hold_trigger(tank: Tank, at: Vector3, ticks: int) -> void:
	for i in ticks:
		tank.command = TankCommand.new(0.0, 0.0, at, true)
		await tree.physics_frame


func test_a_cannon_runs_out_of_shells() -> void:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Gunner", 0, Match.Team.GREEN)
	tank.global_position = Vector3(LANE_X, 0.0, 20.0)
	await wait_physics_frames(2)
	assert_eq(tank.ammo, -1, "R8: a cannon never runs out")
	assert_eq(Weapons.max_ammo(Weapons.profile("mortar")), 24, "the mortar still carries a load")
	tank.max_ammo = 45  # the mechanism, on a weapon given a load
	tank.ammo = 2
	await _hold_trigger(tank, Vector3(LANE_X, 0.0, -40.0), SimClock.TICK_RATE * 8)  # three reloads' worth of trigger
	assert_eq(game_match.stats["shots"][Match.Team.GREEN], 2, "two shells, two shots, then the gun is dry")
	assert_eq(tank.sync_ammo, 0, "the replicated count shows empty")
	assert_true(not tank.ready_to_fire(), "an empty gun is not ready to fire")


func test_the_base_resupplies_shells_slowly_and_only_at_base() -> void:
	var game_match := _setup()
	var home := game_match.spawn_tank("Home", 0, Match.Team.GREEN)
	var away := game_match.spawn_tank("Away", 0, Match.Team.GREEN)
	home.global_position = Match.resupply_center(Match.Team.GREEN) + Vector3(10, 0, 0)
	away.global_position = Vector3(LANE_X, 0.0, 0.0)
	await wait_physics_frames(2)
	for tank: Tank in [home, away]:
		tank.max_ammo = 45
		tank.ammo = 0
	await wait_physics_frames(roundi(Match.RESUPPLY_SECONDS_PER_SHELL * float(SimClock.TICK_RATE) * 2.0) + Match.INTEL_EVERY_TICKS)
	assert_eq(home.ammo, 2, "at base: one shell every %.1f s" % Match.RESUPPLY_SECONDS_PER_SHELL)
	assert_eq(away.ammo, 0, "away from base: nothing")


func test_the_laser_hits_instantly_and_never_runs_out() -> void:
	var game_match := _setup()
	var shooter := game_match.spawn_tank("Laser", 0, Match.Team.GREEN, "lancer")
	var target := game_match.spawn_tank("Target", 0, Match.Team.RUST)
	shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
	target.global_position = Vector3(LANE_X, 0.0, -10.0)  # 30 m ahead
	target.rotation.y = PI / 2.0  # side-on
	target.max_shield = 0.0
	target.shield = 0.0  # hull math here; lasers against shields: test_shields.gd
	await wait_physics_frames(2)
	assert_eq(shooter.ammo, -1, "lasers carry no ammo")
	await _hold_trigger(shooter, target.global_position, 70)
	var pulse := float(Weapons.profile("laser")["damage"]) * Match.armor_multiplier(Weapons.profile("laser"), target.unit_id, "side")
	var lost := target.max_health - target.health
	assert_true(lost >= pulse * 2, "pulses land with no travel time (%d damage in ~1 s)" % lost)
	var pulses := roundi(lost / pulse)
	assert_true(absf(lost - pulses * pulse) < 1.0, "each side-on pulse does %.1f through the side armor (%d = %d pulses)" % [pulse, lost, pulses])
	assert_true(shooter.heat > 0.0, "and every pulse heats the tank (heat %.1f)" % shooter.heat)


func test_a_shot_that_would_overheat_is_refused_until_the_tank_cools() -> void:
	var game_match := _setup()
	var shooter := game_match.spawn_tank("Laser", 0, Match.Team.GREEN, "lancer")
	shooter.global_position = Vector3(LANE_X, 0.0, 20.0)
	await wait_physics_frames(2)
	var per_shot := float(Weapons.profile("laser")["heat_per_shot"])
	shooter.heat = shooter.heat_capacity - per_shot + 2.0  # 2 over what one more pulse allows
	var first_shot := -1
	for i in SimClock.TICK_RATE:
		shooter.command = TankCommand.new(0.0, 0.0, Vector3(LANE_X, 0.0, -40.0), true)
		await tree.physics_frame
		assert_true(shooter.heat <= shooter.heat_capacity + 0.01, "a tank can never go past its heat capacity (%.1f)" % shooter.heat)
		if first_shot < 0 and game_match.stats["shots"][Match.Team.GREEN] > 0:
			first_shot = i
	var cooling_ticks := ceili(2.0 / shooter.heat_dissipation * float(SimClock.TICK_RATE))
	assert_true(first_shot >= cooling_ticks - 1, "the trigger is refused until 2 heat dissipates (~%d ticks; fired at %d)" % [cooling_ticks, first_shot])
	assert_true(first_shot >= 0 and first_shot <= cooling_ticks + 3, "then it fires straight away (tick %d)" % first_shot)


func test_heat_dissipates_over_time() -> void:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Cooling", 0, Match.Team.GREEN, "lancer")
	tank.global_position = Vector3(LANE_X, 0.0, 20.0)
	await wait_physics_frames(2)
	tank.heat = 60.0
	await wait_physics_frames(SimClock.TICK_RATE)
	assert_near(tank.heat, 60.0 - tank.heat_dissipation, 0.5, "one second sheds heat_dissipation heat")
	assert_near(tank.sync_heat, tank.heat / tank.heat_capacity, 0.011, "heat replicates as a 0..1 ratio")


func test_low_on_shells_it_skips_long_shots() -> void:
	var game_match := _setup()
	var tank := game_match.spawn_tank("Frugal", 0, Match.Team.GREEN)
	var far := game_match.spawn_tank("Far", 0, Match.Team.RUST)
	tank.global_position = Vector3(LANE_X, 0.0, 30.0)
	far.global_position = Vector3(LANE_X, 0.0, -30.0)  # 60 m: in range, outside the 45 m preferred range
	tank.max_ammo = 30  # R8: guns are unlimited; give this one a load to test the discipline
	tank.ammo = 5  # 17% of a load
	var orders := OrderController.new()
	orders.tank = tank
	orders.tanks_root = game_match.tanks
	add_to_tree(orders)
	# N5 (round 6): the target is DESIGNATED by name, which is the one thing that overrides the engagement envelope's
	# fire discipline. Without that this test would pass on discipline alone (a 45 m band and a 45 m preferred range
	# are the same number now) and would stop saying anything about ammo.
	orders.set_orders({"type": "stop"}, {"type": "target", "name": "Far"})
	await wait_physics_frames(SimClock.TICK_RATE * 4)
	assert_eq(game_match.stats["shots"][Match.Team.GREEN], 0, "with 5 shells left it holds fire at 60 m")
	far.global_position = Vector3(LANE_X, 0.0, -5.0)  # 35 m
	await wait_physics_frames(SimClock.TICK_RATE * 3)
	assert_true(game_match.stats["shots"][Match.Team.GREEN] > 0, "and shoots once the target is inside 45 m")
