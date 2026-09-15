extends TestCase
## Round 3 combat X5: artillery deploys before firing (game_design.md "Artillery deploys before firing"). Stopping
## lowers the outriggers over deploy_seconds; only a fully deployed battery fires; any drive order packs it up over
## pack_seconds before it can move. The hull, turret, and weapon visuals get set_deployed(ratio 0..1).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const LANE_X := -100.0


func _battery() -> Array:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	game_match.seed_spawns(2, 0.0)
	var gun := game_match.spawn_tank("Gun", 0, Match.Team.GREEN, "artillery")
	gun.global_position = Vector3(LANE_X, 0.0, 60.0)
	var shots := [0]
	game_match.weapon_fired.connect(func(_event: Dictionary) -> void: shots[0] += 1)
	return [game_match, gun, shots]


func test_only_artillery_deploys() -> void:
	for unit_id: String in Units.PROFILES:
		var deploys := float(Units.stat(unit_id, "deploy_seconds", 0.0)) > 0.0
		assert_eq(deploys, unit_id == "artillery", "%s %s" % [unit_id, "deploys" if deploys else "fires on the move"])
	assert_true(float(Units.stat("artillery", "pack_seconds", 0.0)) > 0.0, "and packs up again")


func test_a_battery_fires_only_once_its_legs_are_down() -> void:
	var setup := _battery()
	var gun: Tank = setup[1]
	var shots: Array = setup[2]
	await wait_physics_frames(2)
	var deploy_ticks := roundi(float(Units.stat("artillery", "deploy_seconds")) * 60.0)
	var aim := gun.global_position + Vector3(0.0, 0.0, -90.0)
	var ratios: Array = []
	for tick in deploy_ticks + Tank.DEPLOY_SETTLE_TICKS - 5:  # the 2 setup ticks already count as standing still
		gun.command = TankCommand.new(0.0, 0.0, aim, true)
		await tree.physics_frame
		ratios.append(gun.deploy_ratio)
	assert_eq(shots[0], 0, "no round while the outriggers are still coming down")
	assert_true(not gun.is_deployed(), "not deployed yet (%.2f)" % gun.deploy_ratio)
	var monotonic := true
	for i in range(1, ratios.size()):
		monotonic = monotonic and float(ratios[i]) >= float(ratios[i - 1])
	assert_true(monotonic and float(ratios[-1]) > 0.8, "the ratio climbs toward 1 (%.2f)" % ratios[-1])
	for tick in 10:
		gun.command = TankCommand.new(0.0, 0.0, aim, true)
		await tree.physics_frame
	assert_true(gun.is_deployed(), "deployed")
	assert_eq(shots[0], 1, "then the first round goes")


func test_a_deployed_battery_packs_up_before_it_drives() -> void:
	var setup := _battery()
	var gun: Tank = setup[1]
	var shots: Array = setup[2]
	await wait_physics_frames(2)
	for tick in 60 * 4:
		gun.command = TankCommand.new(0.0, 0.0, gun.global_position + Vector3(0.0, 0.0, -90.0), false)
		await tree.physics_frame
	assert_true(gun.is_deployed(), "setup: dug in")
	var start := gun.global_position
	var pack_ticks := roundi(float(Units.stat("artillery", "pack_seconds")) * 60.0)
	for tick in pack_ticks - 2:
		gun.command = TankCommand.new(1.0, 0.0, gun.global_position + Vector3(0.0, 0.0, -90.0), true)
		await tree.physics_frame
	assert_true(gun.global_position.distance_to(start) < 0.05, "it doesn't move while packing (%.2f m)" % gun.global_position.distance_to(start))
	assert_eq(shots[0], 0, "and can't fire while its legs come up")
	for tick in 60:
		gun.command = TankCommand.new(1.0, 0.0, gun.global_position + Vector3(0.0, 0.0, -90.0), false)
		await tree.physics_frame
	assert_near(gun.deploy_ratio, 0.0, 0.0001, "packed")
	assert_true(gun.global_position.distance_to(start) > 1.0, "then it drives off")


func test_a_brief_pause_does_not_start_deploying() -> void:
	var setup := _battery()
	var gun: Tank = setup[1]
	await wait_physics_frames(2)
	for tick in 90:
		var moving := tick % 20 < 20 - (Tank.DEPLOY_SETTLE_TICKS - 3)
		gun.command = TankCommand.new(1.0 if moving else 0.0, 0.0, Vector3.ZERO, false)
		await tree.physics_frame
	assert_near(gun.deploy_ratio, 0.0, 0.0001, "stop-and-go never lowers the legs")


func test_other_units_fire_on_the_move() -> void:
	add_to_tree(ARENA.instantiate())
	var game_match: Match = add_to_tree(MATCH.instantiate())
	var tank := game_match.spawn_tank("Tank", 0, Match.Team.GREEN, "tank")
	tank.global_position = Vector3(LANE_X, 0.0, 60.0)
	var shots := [0]
	game_match.weapon_fired.connect(func(_event: Dictionary) -> void: shots[0] += 1)
	await wait_physics_frames(2)
	for tick in 10:
		tank.command = TankCommand.new(1.0, 0.0, tank.global_position + Vector3(0.0, 1.0, -60.0), true)
		await tree.physics_frame
	assert_eq(shots[0], 1, "a tank fires while driving")
	assert_true(tank.is_deployed(), "units that don't deploy always count as ready")
