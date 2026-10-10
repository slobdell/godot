extends TestCase
## Round 25/26 (native N7, `native_weapon`): Gunnery's aim solution (`Gunnery._aim_solution`: the lead, the Difficulty
## wander, the distance and the aim error) natively (NativeWeapon.aim -> TankNative.weapon_aim) gives the LIVE
## GDScript's answer BIT FOR BIT on every pose: every unit (each weapon kind and round speed), random hulls, turret
## yaws and target velocities (still, slow, faster than the round), random ticks, both difficulties' wander, with a
## brain that has a match (the wander applies) and a plain controller (it does not). The GDScript is asked through the
## real Gunnery each time, so an edit to Ballistics, Difficulty or the aim block the C++ does not follow fails here
## (N2b's pattern; C25.2: a behaviour change lands in both).

const MATCH := preload("res://game/match/match.tscn")
const POSES := 600


func _same(live: Array, native: Array) -> bool:
	return (live[0] as Vector3) == (native[0] as Vector3) and float(live[1]) == float(native[1]) \
			and float(live[2]) == float(native[2])


func test_the_aim_solution_is_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the aim solution's equality is not exercised in this run")
		return
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var units: Array = Units.ids()
	var gunners: Array[Gunnery] = []
	var targets: Array[Tank] = []
	for i in units.size():
		var shooter := game_match.spawn_tank("Aim%02d" % i, 0, Match.Team.GREEN if i % 2 == 0 else Match.Team.RUST,
				String(units[i]))
		var target := game_match.spawn_tank("Mark%02d" % i, 0, Match.Team.RUST if i % 2 == 0 else Match.Team.GREEN,
				String(units[(i + 3) % units.size()]))
		# Half the gunners sit in a brain with the match (the Difficulty wander applies), half in a plain controller.
		var orders: OrderController = TankBrain.new() if i % 2 == 0 else OrderController.new()
		orders.name = "AimOrders%02d" % i
		orders.tank = shooter
		orders.tanks_root = game_match.tanks
		if orders is TankBrain:
			(orders as TankBrain).game_match = game_match
		add_to_tree(orders)
		gunners.append(orders.gunnery)
		targets.append(target)
	await wait_physics_frames(2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2526
	var saved_switch := BrainSwitches.native_weapon
	var saved_tick := game_match.tick
	Difficulty.reset()
	Difficulty.use(Match.Team.GREEN, "easy")  # 2 m of wander on one side, none on the other
	var mismatches := 0
	var first := ""
	var wandered := 0
	var led := 0
	for n in POSES:
		var index := n % gunners.size()
		var gunnery := gunners[index]
		var shooter := gunnery.tank
		var target := targets[index]
		shooter.global_position = Vector3(rng.randf_range(-150.0, 150.0), rng.randf_range(0.0, 3.0), rng.randf_range(-150.0, 150.0))
		shooter.turret.rotation.y = rng.randf_range(-PI, PI)
		shooter.rotation.y = rng.randf_range(-PI, PI)
		var range_now := rng.randf_range(0.0, 160.0) if n % 17 != 0 else 0.0  # sometimes on top of it
		var bearing := rng.randf_range(-PI, PI)
		target.global_position = shooter.global_position + Vector3(cos(bearing) * range_now, rng.randf_range(-2.0, 2.0),
				sin(bearing) * range_now)
		var speed: float = [0.0, rng.randf_range(0.5, 12.0), rng.randf_range(40.0, 140.0)][n % 3]
		var heading := rng.randf_range(-PI, PI)
		target.estimated_velocity = Vector3(cos(heading) * speed, rng.randf_range(-0.5, 0.5), sin(heading) * speed)
		game_match.tick = rng.randi_range(0, 20000)
		var muzzle := shooter.turret.global_position
		BrainSwitches.native_weapon = false
		var live := gunnery._aim_solution(target, muzzle)
		BrainSwitches.native_weapon = true
		var native := gunnery._aim_solution(target, muzzle)
		if gunnery.ctl is TankBrain and shooter.team == Match.Team.GREEN:
			wandered += 1
		if shooter.weapon["kind"] == Weapons.Kind.PROJECTILE and speed > 0.0:
			led += 1
		if not _same(live, native):
			mismatches += 1
			if first == "":
				first = "pose %d %s v %s: live %s native %s" % [n, shooter.unit_id, target.unit_id, live, native]
	BrainSwitches.native_weapon = saved_switch
	game_match.tick = saved_tick
	Difficulty.reset()
	print("NATIVE_WEAPON aim: %d poses, %d with wander, %d led, %d mismatches" % [POSES, wandered, led, mismatches])
	assert_true(wandered > 50 and led > 50, "the wander and the lead are both exercised (%d, %d)" % [wandered, led])
	assert_eq(mismatches, 0, "the aim solution equals the live GDScript (%s)" % first)


func test_the_switch_is_off_by_default() -> void:
	assert_true(not BrainSwitches.native_weapon, "native_weapon ships OFF until the N7 bundle is priced on the laptop")
