extends TestCase
## Round 24 (native, N3c): `Movement.drive` as one native call (NativeDrive -> TankNative.drive, drive_native.cpp)
## against the LIVE GDScript drive, from the same state. Twelve hulls of seven units (tracked and wheeled) are driven
## round the Sumps by their own controllers with orders that use every input drive reads (plain, a facing for the
## wheeled gate, paced, a slower speed, an arrive radius, reverse, direct), re-ordered every few seconds. After every
## physics frame each driving mover is driven twice from one snapshot of EVERY mover (drive can ask another to give
## way): once by `Movement.drive` (GDScript), once natively; the command and every member and static of every mover
## (MoverState: movement.gd's own `static var` lines, the station PID's members) must be equal bit for bit. Then all
## movers go back to the snapshot, so the fight goes on exactly as the game drives it.

const MATCH := preload("res://game/match/match.tscn")
const UNITS: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv",
		"gang_tank", "scout", "tank"]
const FRAMES := 180


func _capture_all(movers: Array[Movement]) -> Array:
	var states := []
	for mover in movers:
		states.append(MoverState.capture(mover))
	return states


func _restore_all(movers: Array[Movement], states: Array) -> void:
	for i in movers.size():
		MoverState.restore(movers[i], states[i])


func _order(rng: RandomNumberGenerator, wheeled: bool) -> Dictionary:
	var order := {"type": "move_to", "x": rng.randf_range(-120.0, 120.0), "z": rng.randf_range(-120.0, 120.0)}
	if wheeled and rng.randf() < 0.6:
		# The arrival gate (_approach_gate): a facing, sometimes degenerate, on goals near and far.
		var angle := rng.randf_range(0.0, TAU)
		order["facing"] = [cos(angle), sin(angle)] if rng.randf() < 0.9 else [0.0, 0.0]
		if rng.randf() < 0.4:
			order["x"] = rng.randf_range(-15.0, 15.0)
			order["z"] = rng.randf_range(-15.0, 15.0)
		return order
	match rng.randi_range(0, 6):
		1:
			pass
		2:
			order["paced"] = true
			order["speed"] = rng.randf_range(0.4, 0.9)
		3:
			order["arrive"] = rng.randf_range(0.5, 6.0)
		4:
			order["reverse"] = true
			order["x"] = rng.randf_range(-20.0, 20.0)
		5:
			order["direct"] = true
	return order


## Drive every driving mover both ways from one snapshot of all of them; returns [drives, mismatches, first].
func _compare_tick(movers: Array[Movement], controllers: Array[OrderController], frame: int) -> Array:
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var drives := 0
	var mismatches := 0
	var first := ""
	for i in movers.size():
		var mover := movers[i]
		var order: Dictionary = controllers[i].move_order
		if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
			continue
		var start := _capture_all(movers)
		var live_cmd := TankCommand.new()
		BrainSwitches.native_drive = false
		mover.drive(live_cmd, order, delta)
		BrainSwitches.native_drive = true
		var live := _capture_all(movers)
		_restore_all(movers, start)
		var native_cmd := TankCommand.new()
		NativeDrive.drive(mover, native_cmd, order, delta)
		var native := _capture_all(movers)
		_restore_all(movers, start)
		drives += 1
		var differ := ""
		for j in movers.size():
			differ = MoverState.diff(live[j], native[j])
			if differ != "":
				differ = "mover %d: %s" % [j, differ]
				break
		if MoverState.command(live_cmd) != MoverState.command(native_cmd) or differ != "":
			mismatches += 1
			if first == "":
				first = "frame %d %s: command live %s native %s; %s" % [frame, mover.ctl.tank.name,
						MoverState.command(live_cmd), MoverState.command(native_cmd), differ.left(600)]
	return [drives, mismatches, first]


## Wheeled hulls nose-on to walls with their goal behind them: the k-turn planner, its legs, their ends.
func test_the_k_turn_legs_are_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the k-turn equality is not exercised in this run")
		return
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2407
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	var wheeled: Array[String] = ["ifv", "scout", "ifv", "scout", "ifv", "scout"]
	for i in wheeled.size():
		var tank := game_match.spawn_tank("Kturn%d" % i, 0, Match.Team.GREEN, wheeled[i])
		tank.global_position = Vector3(25.0 * i - 60.0, 0.0, 80.0)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
	var map: RID = controllers[0].tank.get_world_3d().navigation_map
	var kturn_before := [Movement.kturns + Movement.kturn_multi, Movement.kturn_ticks, Movement.kturn_aborted]
	var drives := 0
	var mismatches := 0
	var first := ""
	for frame in 240:
		if frame % 60 == 0:
			# Each hull to a spot a few metres from a wall it faces, its goal behind it.
			for i in controllers.size():
				var tank: Tank = controllers[i].tank
				for attempt in 60:
					var at := Vector3(rng.randf_range(-110.0, 110.0), 0.0, rng.randf_range(-110.0, 110.0))
					var on := NavigationServer3D.map_get_closest_point(map, at)
					if Vector2(on.x - at.x, on.z - at.z).length() > 0.3:
						continue
					var angle := rng.randf_range(0.0, TAU)
					var ahead := at + Vector3(cos(angle), 0.0, sin(angle)) * 4.0
					var probe := NavigationServer3D.map_get_closest_point(map, ahead)
					if Vector2(probe.x - ahead.x, probe.z - ahead.z).length() < 1.0:
						continue  # no wall ahead
					tank.global_position = at
					tank.global_basis = Basis(Vector3.UP, atan2(-cos(angle), -sin(angle)))
					var behind := at - Vector3(cos(angle), 0.0, sin(angle)) * rng.randf_range(8.0, 16.0)
					controllers[i].set_orders({"type": "move_to", "x": behind.x, "z": behind.z}, null)
					break
		await wait_physics_frames(1)
		var result := _compare_tick(movers, controllers, frame)
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
	var kturn_after := [Movement.kturns + Movement.kturn_multi, Movement.kturn_ticks, Movement.kturn_aborted]
	print("native drive k-turns: %d drives, plans / leg ticks / aborted %s -> %s, %d mismatches" % [drives, kturn_before,
			kturn_after, mismatches])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive through k-turns: %s" % first)
	assert_true(int(kturn_after[0]) - int(kturn_before[0]) >= 5 and int(kturn_after[1]) - int(kturn_before[1]) >= 60,
			"k-turns planned and driven (%s -> %s)" % [kturn_before, kturn_after])


func test_the_harness_reaches_the_statics() -> void:
	var mover := Movement.new(null)
	var before := Movement.a1_replans
	assert_eq(mover.get("a1_replans"), before, "a static is read through the instance (MoverState's capture)")
	mover.set("a1_replans", before + 7)
	assert_eq(Movement.a1_replans, before + 7, "and written through it (MoverState's restore)")
	Movement.a1_replans = before
	assert_true(MoverState.static_names().has("a1_replans") and MoverState.static_names().has("give_ways") == false,
			"the statics are movement.gd's own `static var` lines")


func test_drive_is_the_live_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the drive equality is not exercised in this run")
		return
	assert_true(Movement._off.is_empty(), "the default configuration (no --nav-off switch)")
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2405
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for i in UNITS.size():
		var tank := game_match.spawn_tank("Drive%02d" % i, 0, Match.Team.GREEN, UNITS[i])
		tank.global_position = Vector3(-30.0 + 6.0 * (i % 6), 0.0, -10.0 + 7.0 * (i / 6))
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
		orders.set_orders(_order(rng, movers[-1].wheel_radius() > 0.0), null)
	# Three followers keep station on a slot that slides with a leader (the formation case: _track_goal's velocity,
	# then _keep_station's PID), re-placed every tick the way an element re-issues a slot, without a new order.
	var followers := {2: 1, 6: 0, 9: 3}
	for f: int in followers:
		var leader: Tank = controllers[followers[f]].tank
		controllers[f].set_orders({"type": "move_to", "x": leader.global_position.x + 4.0, "z": leader.global_position.z - 6.0}, null)
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var asked := 0
	var mismatches := 0
	var first := ""
	var wheeled := 0
	var replans := 0
	var native_replans := 0
	var stationed := 0
	var avoided := 0
	var negotiated := 0
	var reversing := 0
	var gates_before := Movement.gate_report()
	var kturn_before := [Movement.kturns, Movement.kturn_multi, Movement.kturn_ticks, Movement.kturn_aborted]
	var live_usec := 0
	var native_usec := 0
	NativeBridge.impl.drive_profile(true)
	for frame in FRAMES:
		await wait_physics_frames(1)
		if frame % 75 == 74:
			for i in controllers.size():
				if rng.randf() < 0.5 and not followers.has(i):
					controllers[i].set_orders(_order(rng, movers[i].wheel_radius() > 0.0), null)
		for f: int in followers:
			var leader: Tank = controllers[followers[f]].tank
			var slot: Dictionary = controllers[f].move_order
			slot["x"] = leader.global_position.x + 4.0
			slot["z"] = leader.global_position.z - 6.0
		for i in movers.size():
			var mover := movers[i]
			var order: Dictionary = controllers[i].move_order
			if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
				continue
			var start := _capture_all(movers)
			var replans_before := Movement.a1_replans
			var live_cmd := TankCommand.new()
			var t0 := Time.get_ticks_usec()
			BrainSwitches.native_drive = false
			mover.drive(live_cmd, order, delta)
			BrainSwitches.native_drive = true
			live_usec += Time.get_ticks_usec() - t0
			var live := _capture_all(movers)
			var live_replanned := Movement.a1_replans != replans_before
			_restore_all(movers, start)
			var native_cmd := TankCommand.new()
			t0 = Time.get_ticks_usec()
			NativeDrive.drive(mover, native_cmd, order, delta)
			native_usec += Time.get_ticks_usec() - t0
			var native := _capture_all(movers)
			native_replans += 1 if Movement.a1_replans != replans_before else 0
			_restore_all(movers, start)
			asked += 1
			wheeled += 1 if mover.wheel_radius() > 0.0 else 0
			replans += 1 if live_replanned else 0
			stationed += 1 if live[i]["stationed_now"] else 0
			avoided += 1 if live[i]["_deflected"] else 0
			reversing += 1 if live_cmd.throttle < 0.0 else 0
			for j in movers.size():
				if j != i and MoverState.own(live[j]) != MoverState.own(start[j]):
					negotiated += 1
			var command_same := MoverState.command(live_cmd) == MoverState.command(native_cmd)
			var states_differ := ""
			for j in movers.size():
				var d := MoverState.diff(live[j], native[j])
				if d != "":
					states_differ = "mover %d: %s" % [j, d]
					break
			if not command_same or states_differ != "":
				mismatches += 1
				if first == "":
					first = "frame %d %s (%s, order %s): command live %s native %s; %s" % [frame, mover.ctl.tank.name,
							mover.ctl.tank.unit_id, order, MoverState.command(live_cmd), MoverState.command(native_cmd),
							states_differ.left(600)]
	print("native drive: %.1f usec a drive live, %.1f native (the callbacks included; this test's mix, not a match's)"
			% [float(live_usec) / maxi(asked, 1), float(native_usec) / maxi(asked, 1)])
	var profile: Dictionary = NativeBridge.impl.drive_profile(true)
	var parts := []
	for key: String in profile:
		if key != "drives":
			parts.append("%s %.1f" % [key, float(profile[key]) / maxi(int(profile["drives"]), 1)])
	print("native drive, usec a drive inside: %s" % ", ".join(parts))
	print("native drive: gates (the fight's own drives) %s -> %s" % [gates_before, Movement.gate_report()])
	print("native drive: k-turns planned / back-and-fills / leg ticks / aborted, the fight's own drives: %s -> %s"
			% [kturn_before, [Movement.kturns, Movement.kturn_multi, Movement.kturn_ticks, Movement.kturn_aborted]])
	print("native drive: %d drives (%d wheeled), %d replans (%d native), %d stationed, %d deflected, %d reversing, %d touched another mover, %d mismatches"
			% [asked, wheeled, replans, native_replans, stationed, avoided, reversing, negotiated, mismatches])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive: %s" % first)
	assert_true(asked >= 1000 and wheeled >= 200, "a real sample (%d drives, %d wheeled)" % [asked, wheeled])
	assert_true(replans >= 20 and native_replans == replans, "re-plans happen, and the native arm counts them through the statics (%d, %d)" % [replans, native_replans])
	assert_true(avoided >= 20, "avoidance shapes some drives (%d)" % avoided)
	assert_true(stationed >= 20, "station keeping runs (%d)" % stationed)
	var gates := Movement.gate_report()
	assert_true(int(gates["offered"]) - int(gates_before["offered"]) >= 200 and int(gates["refused"]) - int(gates_before["refused"]) >= 20,
			"the arrival gate is offered and refused (%s)" % gates)
