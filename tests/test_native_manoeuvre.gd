extends DriveTwinCase
## Round 33 (native N5.M): `Movement._manoeuvre`'s DECISION natively (drive_native.cpp: Manoeuvre.choose, behind, simulate
## over motion_step and NavNative::outline_ok, _others / _hull_hit) against the live GDScript, on the tick it is made. The
## drive twins' fights rarely compare one (an order lands before the fight's own drive decides it first, and the Sumps
## refuses most reverses on its walls), so this stage asks for it: five hulls (tracked, three wheeled, the artillery
## truck) on the open band of yard_open, their controllers paused, each sent to goals behind it at several distances,
## bearings and facings, at rest and rolling. Each order is driven twice from one snapshot of every mover (`_compare_tick`:
## the GDScript drive, then the native drive); command, members, Movement's and Manoeuvre's statics equal bit for bit.

const STAGE_UNITS: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery"]
const SLOT_Z := 15.0
const SLOT_GAP := 18.0
const ASTERN: Array[float] = [3.0, 6.0, 10.0, 16.0, 24.0]
const BEARINGS: Array[float] = [180.0, 135.0, -120.0, 70.0]
const YAWS: Array[float] = [0.0, 1.9, -2.6]


func test_the_decision_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_the_decision_is_the_live_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _stage(false)


func test_the_decision_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_decision_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _stage(true)


func _stage(owned: bool) -> void:
	if not NativeBridge.available:
		print("native: absent, the manoeuvre decision is not exercised in this run")
		return
	MoverState.world_reset()  # a crew an earlier test left held is not this case's world
	_man_reset()
	NativeDrive.owned = owned
	assert_true(Movement._off.is_empty(), "the default configuration (no --nav-off switch): the native drive runs")
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for i in STAGE_UNITS.size():
		var tank := game_match.spawn_tank("Man%d" % i, 0, Match.Team.GREEN, STAGE_UNITS[i])
		tank.place(_slot(i), 0.0)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	# A parked enemy astern of the first hull's slot: its reverses meet a hull of the other team (`enemy`).
	var parked := game_match.spawn_tank("ManRust", 0, Match.Team.RUST, "tank")
	parked.place(_slot(0) + Vector3(0.0, 0.0, 8.0), 0.0)
	await wait_physics_frames(2)
	for orders in controllers:
		orders.set_physics_process(false)  # the stage asks; nothing drives between the asks unless rolling
		movers.append(Movement.of(orders.tank))
	var drives := 0
	var callback_usec := 0
	var mismatches := 0
	var first := ""
	# At rest: every hull at each yaw, each goal astern on each bearing, with no facing, the tail's facing, the nose's.
	var frame := 0
	for yaw in YAWS:
		for i in controllers.size():
			controllers[i].tank.place(_slot(i), yaw)
		await wait_physics_frames(1)
		for astern in ASTERN:
			for bearing in BEARINGS:
				for facing in 3:
					for i in controllers.size():
						controllers[i].set_orders(_behind(controllers[i].tank, astern, bearing, facing), null)
					if not owned:
						callback_usec += _callback_drives(movers, controllers)
					var result := _compare_tick(movers, controllers, frame)
					drives += result[0]
					mismatches += result[1]
					if first == "" and result[2] != "":
						first = result[2]
					frame += 1
	# `no_arrival`: goals a long wheeled hull's reverse does not reach inside SIM_HORIZON_S on open ground (a scratch sweep
	# of Manoeuvre.simulate at 145ada3a, builder0: the War Rig 15.5 m at 140 / 220 degrees and 17 m at 135 / 225 degrees,
	# 4 of 1604 behind goals; the lancer 6; no other unit). Every hull at yaw 0, no facing.
	for i in controllers.size():
		controllers[i].tank.place(_slot(i), 0.0)
	await wait_physics_frames(1)
	for ask: Array in [[15.5, 140.0], [15.5, 220.0], [17.0, 135.0], [17.0, 225.0]]:
		for i in controllers.size():
			controllers[i].set_orders(_behind(controllers[i].tank, float(ask[0]), float(ask[1]), 0), null)
		var result := _compare_tick(movers, controllers, frame)
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
		frame += 1
	# Rolling: driven ahead for three seconds (past REAIM_TICKS, so not a re-aimed point), then a goal astern.
	for bearing in BEARINGS:
		for i in controllers.size():
			controllers[i].tank.place(_slot(i), 0.0)
			controllers[i].set_orders(_behind(controllers[i].tank, 30.0, 0.0, 0), null)
			controllers[i].set_physics_process(true)
		await wait_physics_frames(3 * SimClock.TICK_RATE)
		for orders in controllers:
			orders.set_physics_process(false)
		for i in controllers.size():
			controllers[i].set_orders(_behind(controllers[i].tank, 8.0, bearing, 0), null)
		var result := _compare_tick(movers, controllers, frame)
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
		frame += 1
	NativeDrive.owned = false
	print("native manoeuvre stage%s: %d drives compared, %d mismatches; a decision tick's drive %.1f usec live GDScript, %.1f native (measurement: this stage's mix)" % [
			" (owned state)" if owned else "", drives, mismatches, float(tick_live_usec) / maxi(drives, 1),
			float(tick_native_usec) / maxi(drives, 1)])
	if not owned:
		# The at-rest asks only (the rolling ones are not in it): the native drive with the decision called back, as
		# rounds 26-32 shipped. The port's price is native against this.
		var at_rest := YAWS.size() * ASTERN.size() * BEARINGS.size() * 3 * STAGE_UNITS.size()
		print("native manoeuvre stage: the same at-rest decision ticks with the decision called back: %.1f usec a drive" % [
				float(callback_usec) / maxi(at_rest, 1)])
	assert_eq(mismatches, 0, "the native decision is the live GDScript's: %s" % first)
	# Floors against a vacuous run (about half of builder0's first count, 920 decisions at lab/native-n5m): both answers
	# and every refusal the stage reaches (`no_arrival`: the War Rig's asks above).
	_man_check("stage", {"": 450, "plans:reverse": 150, "plans:route": 300, "refused:route_faster": 30,
			"refused:facing_nose": 100, "refused:static": 40, "refused:friendly": 3, "refused:enemy": 1,
			"refused:no_arrival": 1})


func _slot(i: int) -> Vector3:
	return Vector3((i - (STAGE_UNITS.size() - 1) * 0.5) * SLOT_GAP, 0.0, SLOT_Z)


## A move_to `astern` metres off the nose turned by `bearing` degrees; facing 0 none, 1 the hull's own heading (the tail
## arrives first), 2 the opposite (the nose).
func _behind(tank: Tank, astern: float, bearing: float, facing: int) -> Dictionary:
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var to := Vector2(tank.global_position.x, tank.global_position.z) + nose.rotated(deg_to_rad(bearing)) * astern
	var order := {"type": "move_to", "x": to.x, "z": to.y}
	if facing == 1:
		order["facing"] = [nose.x, nose.y]
	elif facing == 2:
		order["facing"] = [-nose.x, -nose.y]
	return order


## Measurement only: each mover's decision-tick drive natively with `native_manoeuvre` OFF (the round-26 callback), from
## and back to one snapshot; microseconds summed.
func _callback_drives(movers: Array[Movement], controllers: Array[OrderController]) -> int:
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var usec := 0
	BrainSwitches.native_manoeuvre = false
	for i in movers.size():
		var start := _capture_all(movers)
		var cmd := TankCommand.new()
		var t0 := Time.get_ticks_usec()
		NativeDrive.drive(movers[i], cmd, controllers[i].move_order, delta)
		usec += Time.get_ticks_usec() - t0
		_restore_all(movers, start)
	BrainSwitches.native_manoeuvre = true  # (the tally counts only the compared arm's own drive: _man_add)
	return usec
