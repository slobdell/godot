extends DriveTwinCase
## Round 43 (native N3, the twin manoeuvre asked for; C43.4): with `--traffic-on=parkaside` (Movement._park_aside, Bar S v2)
## the native drive is the live GDScript drive while seats lie under parked friends: the memo and the cheap exits natively
## (drive_native.cpp park_aside), the decision called back. Three hulls park on their own spots on the Sumps; nine others are
## re-aimed every 40 frames at a point inside a parked friend's disc (most) or just outside it, from within the 30 m reach.
## Every driving mover is driven both ways from one snapshot each frame (DriveTwinCase._compare_tick; MoverState carries
## Manoeuvre's aside memo, so the second arm starts with the first arm's memo as it was).

const PARKED := [0, 2, 4]
const FIGHT_FRAMES := 240


func test_the_seat_aside_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_the_seat_aside_is_the_live_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	if NativeExpect.absent(self):
		print("native: absent, the parkaside equality is not exercised in this run")
		return
	var was := Traffic.off("parkaside")
	Traffic.set_off("parkaside", false)
	MoverState.world_reset()
	_man_reset()
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for i in UNITS.size():
		var tank := game_match.spawn_tank("Aside%02d" % i, 0, Match.Team.GREEN, UNITS[i])
		tank.place(Vector3(-30.0 + 6.0 * (i % 6), 0.0, -10.0 + 7.0 * (i / 6)), tank.rotation.y)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
	assert_true(MoverState.capture(movers[0]).has("static:Manoeuvre._aside"), "the snapshot carries Manoeuvre's aside memo")
	for p: int in PARKED:  # parked: ordered onto their own spot, so they arrive and stand still
		var at := controllers[p].tank.global_position
		controllers[p].set_orders({"type": "move_to", "x": at.x, "z": at.z}, null)
	var moved_before := Movement.parkaside_moved
	var drives := 0
	var mismatches := 0
	var first := ""
	var under := 0
	for frame in FIGHT_FRAMES:
		if frame % 40 == 10:
			for i in controllers.size():
				if PARKED.has(i):
					continue
				var friend: Tank = controllers[PARKED[rng.randi_range(0, PARKED.size() - 1)]].tank
				var angle := rng.randf_range(0.0, TAU)
				var reach := rng.randf_range(0.0, 3.0) if rng.randf() < 0.75 else rng.randf_range(9.0, 11.0)
				var goal := friend.global_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
				var order := {"type": "move_to", "x": goal.x, "z": goal.z}
				if movers[i].wheel_radius() > 0.0 and rng.randf() < 0.4:
					order["facing"] = [cos(angle), sin(angle)]
				if rng.randf() < 0.1:
					order["direct"] = true
				under += 1 if reach < 3.0 else 0
				controllers[i].set_orders(order, null)
		await wait_physics_frames(1)
		var result := _compare_tick(movers, controllers, frame)
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
	var moved := Movement.parkaside_moved - moved_before
	Traffic.set_off("parkaside", was)
	print("native drive parkaside: %d drives, %d seats moved aside (the fight's own drives), %d goals aimed under a friend, %d mismatches"
			% [drives, moved, under, mismatches])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive with parkaside ON: %s" % first)
	assert_true(drives >= 1500, "a real sample (%d drives)" % drives)
	assert_true(moved >= 5, "seats were moved aside, so the memo and the callback were both exercised (%d)" % moved)
