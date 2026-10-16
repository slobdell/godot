class_name DriveTwinCase
extends TestCase
## Round 24 (native, N3c): `Movement.drive` as one native call (NativeDrive -> TankNative.drive, drive_native.cpp)
## against the LIVE GDScript drive, from the same state. Twelve hulls of seven units (tracked and wheeled) are driven
## round the Sumps by their own controllers with orders that use every input drive reads (plain, a facing for the
## wheeled gate, paced, a slower speed, an arrive radius, reverse, direct), re-ordered every few seconds. After every
## physics frame each driving mover is driven twice from one snapshot of EVERY mover (drive can ask another to give
## way): once by `Movement.drive` (GDScript), once natively; the command and every member and static of every mover
## (MoverState: movement.gd's own `static var` lines, the station PID's members) must be equal bit for bit. Then all
## movers go back to the snapshot, so the fight goes on exactly as the game drives it.
## Round 32 (native, C32.8): split by case into test_native_drive (+ the harness check), test_native_drive_owned,
## test_native_drive_kturn and test_native_drive_kturn_owned; this base holds the harness and both cases, bodies
## unchanged (it has no test_ methods of its own).

const MATCH := preload("res://game/match/match.tscn")
const UNITS: Array[String] = ["tank", "ifv", "scout", "gang_tank", "artillery", "lancer", "burner", "tank", "ifv",
		"gang_tank", "scout", "tank"]
const FRAMES := 180


## Every mover's state, then (one more entry) the world a drive can change besides them: the planner's seam (round 31).
func _capture_all(movers: Array[Movement]) -> Array:
	var states := []
	for mover in movers:
		states.append(MoverState.capture(mover))
	states.append(MoverState.world_capture())
	return states


func _restore_all(movers: Array[Movement], states: Array) -> void:
	for i in movers.size():
		MoverState.restore(movers[i], states[i])
	MoverState.world_restore(states[movers.size()])


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
		if differ == "":
			differ = MoverState.world_diff(live[movers.size()], native[movers.size()])
		if MoverState.command(live_cmd) != MoverState.command(native_cmd) or differ != "":
			mismatches += 1
			if first == "":
				first = "frame %d %s: command live %s native %s; %s" % [frame, mover.ctl.tank.name,
						MoverState.command(live_cmd), MoverState.command(native_cmd), differ.left(600)]
	return [drives, mismatches, first]


## Round 27 (stage 1 E4): `Movement.unstick` natively (TankNative.unstick, both views) against the live GDScript, for
## every mover with a move order, from one snapshot of all movers: the game's own state, then forced states that reach
## each branch (about to fire the stall rule, backing off, escaping a pressed wall, about to call a press). Returns
## [compared, mismatches, first, branches].
func _unstick_compare(movers: Array[Movement], controllers: Array[OrderController], rng: RandomNumberGenerator,
		frame: int) -> Array:
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var compared := 0
	var mismatches := 0
	var first := ""
	var branches := {}
	for i in movers.size():
		var mover := movers[i]
		var order: Dictionary = controllers[i].move_order
		if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
			continue
		for variant in 5:
			var start := _capture_all(movers)
			match variant:
				1:
					mover._unstick_left = 0.0
					mover._stuck_time = Movement.STUCK_SECONDS - 0.01
				2:
					mover._unstick_left = 0.5
					mover._escape_gear = 0.0
					mover._unstick_pivot = rng.randf() < 0.5
				3:
					mover._unstick_left = rng.randf_range(0.01, 0.5)
					mover._escape_gear = 1.0 if rng.randf() < 0.5 else -1.0
					mover._escape_turn = 1.0 if rng.randf() < 0.5 else -1.0
					mover._press_from = mover.ctl.tank.global_position + Vector3(rng.randf_range(-2.0, 2.0), 0.0, 0.5)
				4:
					mover._unstick_left = 0.0
					mover._press_time = Movement.PRESS_SECONDS - 0.01
			var forced := _capture_all(movers)
			var throttle := 1.0 if variant == 1 else rng.randf_range(-1.0, 1.0)
			var turn := rng.randf_range(-1.0, 1.0)
			var arms := []
			for arm in 3:
				_restore_all(movers, forced)
				var cmd := TankCommand.new(throttle, turn, Vector3.ZERO)
				if arm == 0:
					mover.unstick(cmd, order, delta)
				else:
					NativeBridge.impl.unstick(mover, cmd, order, delta, arm == 2)
				arms.append([MoverState.command(cmd), _capture_all(movers)])
			_restore_all(movers, start)
			compared += 1
			var key := "%d:%s" % [variant, "fired" if arms[0][1][i]["_unstick_left"] > forced[i]["_unstick_left"] else "-"]
			branches[key] = int(branches.get(key, 0)) + 1
			for arm in [1, 2]:
				var differ := ""
				for j in movers.size():
					differ = MoverState.diff(arms[0][1][j], arms[arm][1][j])
					if differ != "":
						differ = "mover %d: %s" % [j, differ]
						break
				if differ == "":
					differ = MoverState.world_diff(arms[0][1][movers.size()], arms[arm][1][movers.size()])
				if arms[0][0] != arms[arm][0] or differ != "":
					mismatches += 1
					if first == "":
						first = "frame %d %s variant %d arm %d: command live %s native %s; %s" % [frame,
								mover.ctl.tank.name, variant, arm, arms[0][0], arms[arm][0], differ.left(400)]
	return [compared, mismatches, first, branches]


func _k_turn_case(owned: bool) -> void:
	if not NativeBridge.available:
		print("native: absent, the k-turn equality is not exercised in this run")
		return
	NativeDrive.owned = owned
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
	var unstick_compared := 0
	var unstick_mismatches := 0
	var unstick_first := ""
	var unstick_branches := {}
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
		var stuck := _unstick_compare(movers, controllers, rng, frame) if not owned else [0, 0, "", {}]
		unstick_compared += stuck[0]
		unstick_mismatches += stuck[1]
		if unstick_first == "" and stuck[2] != "":
			unstick_first = stuck[2]
		for key: String in stuck[3]:
			unstick_branches[key] = int(unstick_branches.get(key, 0)) + int(stuck[3][key])
	var kturn_after := [Movement.kturns + Movement.kturn_multi, Movement.kturn_ticks, Movement.kturn_aborted]
	NativeDrive.owned = false
	print("native drive k-turns%s: %d drives, plans / leg ticks / aborted %s -> %s, %d mismatches" % [
			" (owned state)" if owned else "", drives, kturn_before, kturn_after, mismatches])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive through k-turns: %s" % first)
	if not owned:
		print("native unstick: %d compared (by variant:fired %s), %d mismatches" % [unstick_compared, unstick_branches,
				unstick_mismatches])
		assert_eq(unstick_mismatches, 0, "the native unstick is the live GDScript unstick: %s" % unstick_first)
		assert_true(unstick_compared >= 1000 and int(unstick_branches.get("1:fired", 0)) >= 20,
				"every branch asked (%s)" % unstick_branches)
	# Floors against a vacuous run, not targets: kturnarc (a leg ends by the arc driven; round 31's H2 signed by gear)
	# leaves this fight 4 plans (builder0, pair/cph-on), against >= 5 before (round 30's lab measured the same).
	assert_true(int(kturn_after[0]) - int(kturn_before[0]) >= 3 and int(kturn_after[1]) - int(kturn_before[1]) >= 60,
			"k-turns planned and driven (%s -> %s)" % [kturn_before, kturn_after])


func _drive_case(owned: bool) -> void:
	if not NativeBridge.available:
		print("native: absent, the drive equality is not exercised in this run")
		return
	NativeDrive.owned = owned
	NativeBridge.impl.drive_owned_counts(true)
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
	# Five followers keep station on a slot that slides with a leader (the formation case: _track_goal's velocity,
	# then _keep_station's PID), re-placed every tick the way an element re-issues a slot, without a new order. Each
	# starts ON its slot, so station keeping runs whenever its leader moves, not only once it has caught up (round 31:
	# three followers from the grid stationed 44 / 20 / 12 times as the planner and CP-H turned on; the floor is 20).
	var followers := {2: 1, 6: 0, 9: 3, 10: 4, 11: 5}  # leaders from the front row, so the slots (z - 6) form a row of their own
	for f: int in followers:
		var leader: Tank = controllers[followers[f]].tank
		var slot := Vector3(leader.global_position.x + 4.0, leader.global_position.y, leader.global_position.z - 6.0)
		controllers[f].tank.global_position = slot
		controllers[f].set_orders({"type": "move_to", "x": slot.x, "z": slot.z}, null)
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
			if states_differ == "":
				states_differ = MoverState.world_diff(live[movers.size()], native[movers.size()])
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
	NativeDrive.owned = false
	print("native drive%s: %d drives (%d wheeled), %d replans (%d native), %d stationed, %d deflected, %d reversing, %d touched another mover, %d mismatches"
			% [" (owned state)" if owned else "", asked, wheeled, replans, native_replans, stationed, avoided, reversing,
			negotiated, mismatches])
	if owned:
		var counts: Dictionary = NativeBridge.impl.drive_owned_counts(true)
		print("native drive (owned state): %d drives, %.2f pulls and %.2f pushes a drive (the transition's syncs)" % [
				int(counts["drives"]), float(counts["pulls"]) / maxi(int(counts["drives"]), 1),
				float(counts["pushes"]) / maxi(int(counts["drives"]), 1)])
		# The match's own controllers drive on the owned state too while NativeDrive.owned is set: at least the test's.
		assert_true(int(counts["drives"]) >= asked, "every native drive ran on the owned state (%d >= %d)" % [
				int(counts["drives"]), asked])
	assert_eq(mismatches, 0, "the native drive is the live GDScript drive: %s" % first)
	assert_true(asked >= 1000 and wheeled >= 200, "a real sample (%d drives, %d wheeled)" % [asked, wheeled])
	assert_true(replans >= 20 and native_replans == replans, "re-plans happen, and the native arm counts them through the statics (%d, %d)" % [replans, native_replans])
	assert_true(avoided >= 20, "avoidance shapes some drives (%d)" % avoided)
	assert_true(stationed >= 20, "station keeping runs (%d)" % stationed)
	var gates := Movement.gate_report()
	assert_true(int(gates["offered"]) - int(gates_before["offered"]) >= 200 and int(gates["refused"]) - int(gates_before["refused"]) >= 20,
			"the arrival gate is offered and refused (%s)" % gates)
