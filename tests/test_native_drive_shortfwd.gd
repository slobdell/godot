extends DriveTwinCase
## Round 46 (native N2, the twin manoeuvre asked for; C46.4): with `--traffic-on=shortfwd` (Movement's M5: his short move to a
## wheeled crew inside its turning circle drives FORWARD) the native drive is the live GDScript drive. The rule needs a
## TankBrain whose `_his_order` is set, so the crews are TankBrains that do not think (ShortBrain: the test gives the orders,
## his and not his); the wheeled ones are re-aimed every 30 frames at points inside three turning circles, near and far off
## the nose, by the Sumps' walls and in the open. Every driving mover is driven both ways from one snapshot each frame
## (DriveTwinCase._compare_tick).

const WHEELED: Array[String] = ["ifv", "scout", "gang_tank", "ifv", "scout", "gang_tank", "ifv", "scout"]
const FIGHT_FRAMES := 300


class ShortBrain extends TankBrain:
	func _physics_process(delta: float) -> void:
		if tank == null or not is_instance_valid(tank):
			return
		tank.command = compute_command(delta)


func test_his_short_move_forward_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_his_short_move_forward_is_the_live_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	if NativeExpect.absent(self):
		print("native: absent, the shortfwd equality is not exercised in this run")
		return
	var was := Traffic.off("shortfwd")
	Traffic.set_off("shortfwd", false)
	MoverState.world_reset()
	_man_reset()
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4646
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for i in WHEELED.size():
		var tank := game_match.spawn_tank("Short%02d" % i, 0, Match.Team.GREEN, WHEELED[i])
		tank.place(Vector3(-36.0 + 9.0 * (i % 4), 0.0, -14.0 + 12.0 * (i / 4)), rng.randf_range(0.0, TAU))
		var brain := ShortBrain.new()
		brain.tank = tank
		brain.tanks_root = game_match.tanks
		add_to_tree(brain)
		controllers.append(brain)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
	var ticks_before := Movement.shortfwd_ticks
	var drives := 0
	var mismatches := 0
	var first := ""
	var his_short := 0
	for frame in FIGHT_FRAMES:
		if frame % 30 == 5:
			for i in controllers.size():
				var brain := controllers[i] as ShortBrain
				var tank := brain.tank
				var radius := movers[i].wheel_radius()
				var fwd := Vector3(-tank.global_basis.z.x, 0.0, -tank.global_basis.z.z).normalized()
				var off := deg_to_rad(rng.randf_range(-130.0, 130.0))
				var reach := rng.randf_range(1.0, 3.4) * radius
				var goal := tank.global_position + fwd.rotated(Vector3.UP, off) * reach
				brain._his_order = rng.randf() < 0.8
				var order := {"type": "move_to", "x": goal.x, "z": goal.z}
				if rng.randf() < 0.08:
					order["direct"] = true
				elif rng.randf() < 0.08:
					order["reverse"] = true
				if brain._his_order and absf(rad_to_deg(off)) <= 100.0 and reach <= 3.0 * radius:
					his_short += 1
				brain.set_orders(order, null)
		await wait_physics_frames(1)
		var result := _compare_tick(movers, controllers, frame)
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
	var forward_ticks := Movement.shortfwd_ticks - ticks_before
	Traffic.set_off("shortfwd", was)
	print("native drive shortfwd: %d drives, %d his short moves given, %d forward-arc ticks (the fight's own drives), %d mismatches"
			% [drives, his_short, forward_ticks, mismatches])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive with shortfwd ON: %s" % first)
	assert_true(drives >= 1000, "a real sample (%d drives)" % drives)
	assert_true(forward_ticks >= 20, "the forward arc replaced the circle rule's reverse, so the rule was exercised (%d)" % forward_ticks)
