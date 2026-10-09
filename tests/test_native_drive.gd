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
	match rng.randi_range(0, 6):
		1:
			if wheeled:
				var angle := rng.randf_range(0.0, TAU)
				order["facing"] = [cos(angle), sin(angle)]
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
	for frame in FRAMES:
		await wait_physics_frames(1)
		if frame % 75 == 74:
			for i in controllers.size():
				if rng.randf() < 0.5:
					controllers[i].set_orders(_order(rng, movers[i].wheel_radius() > 0.0), null)
		for i in movers.size():
			var mover := movers[i]
			var order: Dictionary = controllers[i].move_order
			if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
				continue
			var start := _capture_all(movers)
			var replans_before := Movement.a1_replans
			var live_cmd := TankCommand.new()
			mover.drive(live_cmd, order, delta)
			var live := _capture_all(movers)
			var live_replanned := Movement.a1_replans != replans_before
			_restore_all(movers, start)
			var native_cmd := TankCommand.new()
			NativeDrive.drive(mover, native_cmd, order, delta)
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
				if j != i and live[j] != start[j]:
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
	print("native drive: %d drives (%d wheeled), %d replans (%d native), %d stationed, %d deflected, %d reversing, %d touched another mover, %d mismatches"
			% [asked, wheeled, replans, native_replans, stationed, avoided, reversing, negotiated, mismatches])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive: %s" % first)
	assert_true(asked >= 1000 and wheeled >= 200, "a real sample (%d drives, %d wheeled)" % [asked, wheeled])
	assert_true(replans >= 20 and native_replans == replans, "re-plans happen, and the native arm counts them through the statics (%d, %d)" % [replans, native_replans])
	assert_true(avoided >= 20, "avoidance shapes some drives (%d)" % avoided)
