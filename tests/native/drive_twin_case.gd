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

## Round 33 (N5.M): `_manoeuvre`'s decisions in the COMPARED native arm (not the fight's own drives): made natively, called
## back, and the plans / refusals they counted (Manoeuvre's tables, read from the native arm's capture).
var man_native := 0
var man_called_back := 0
var man_tally := {}
## Round 33 (N5.Y): `_negotiate` bodies in the COMPARED native arm, run natively and called back, and what they did
## (Movement's give-way counters and the spot kinds taken, read from the native arm's capture).
var yield_native := 0
var yield_called_back := 0
var yield_tally := {}
const YIELD_COUNTERS: Array[String] = ["yields_started", "asks_refused", "setup_refusals", "parked_refusals",
		"yield_swaps", "yield_swaps_shorter", "yield_spots_unfit", "yield_spots_shortened", "yield_holds",
		"underfire_refusals", "underfire_holds", "underfire_gives", "passes", "passes_done", "passes_timeout", "pass_ticks",
		"yields_unfinished", "yields_unfinished_capped"]
## `_compare_tick`'s clocks (measurement): microseconds in the live GDScript drive and the native drive, and drives.
var tick_live_usec := 0
var tick_native_usec := 0


func _man_reset() -> void:
	man_native = 0
	man_called_back = 0
	man_tally = {}
	tick_live_usec = 0
	tick_native_usec = 0


## Every decision in the compared native arm made natively (N5.M), and floors: "" the decisions, else a tally key.
func _man_check(stage: String, floors := {"": 1}) -> void:
	print("native manoeuvre (%s): %d decisions native, %d called back, plans / refusals %s" % [stage, man_native,
			man_called_back, man_tally])
	assert_eq(man_called_back, 0, "the native drive decides _manoeuvre itself (%s)" % stage)
	for key: String in floors:
		var have := man_native if key == "" else int(man_tally.get(key, 0))
		assert_true(have >= int(floors[key]), "%s: %s %d >= %d" % [stage, key if key != "" else "decisions", have, floors[key]])


func _yield_reset() -> void:
	yield_native = 0
	yield_called_back = 0
	yield_tally = {}


## Every negotiation in the compared native arm run natively (N5.Y), and floors: "" the bodies, else a tally key.
func _yield_check(stage: String, floors := {"": 1}) -> void:
	print("native yield (%s): %d negotiations native, %d called back, %s" % [stage, yield_native, yield_called_back,
			yield_tally])
	assert_eq(yield_called_back, 0, "the native drive runs _negotiate's body itself (%s)" % stage)
	for key: String in floors:
		var have := yield_native if key == "" else int(yield_tally.get(key, 0))
		assert_true(have >= int(floors[key]), "%s: %s %d >= %d" % [stage, key if key != "" else "negotiations", have,
				floors[key]])


## Adds the native arm's negotiation counts since `before`, its give-way counter deltas, and the kind of every spot a
## give-way began at (`start`, `after`: every mover's capture).
func _yield_add(before: Array, start: Array, after: Array, count: int) -> void:
	var now := _man_counts()
	yield_native += now[2] - int(before[2])
	yield_called_back += now[3] - int(before[3])
	for name: String in YIELD_COUNTERS:
		var moved := int(after[0].get("static:" + name, 0)) - int(start[0].get("static:" + name, 0))
		if moved != 0:
			yield_tally[name] = int(yield_tally.get(name, 0)) + moved
	for j in count:
		var to := String(after[j].get("yield_to", ""))
		if to != "" and to != String(start[j].get("yield_to", "")):
			var spot := String(after[j].get("yield_spot", ""))
			var kind := "spot:" + spot.get_slice("(", 0)
			yield_tally[kind] = int(yield_tally.get(kind, 0)) + 1


func _man_counts() -> Array:
	var c: Dictionary = NativeBridge.impl.drive_owned_counts(false)
	return [int(c.get("manoeuvre_native", 0)), int(c.get("manoeuvre_called_back", 0)), int(c.get("negotiate_native", 0)),
			int(c.get("negotiate_called_back", 0))]


## Adds the native arm's decision counts since `before` and its plan / refusal deltas (`start`, `after`: one mover's capture).
func _man_add(before: Array, start: Dictionary, after: Dictionary) -> void:
	var now := _man_counts()
	man_native += now[0] - int(before[0])
	man_called_back += now[1] - int(before[1])
	for table: String in ["plans", "refused"]:
		var was: Dictionary = start.get("static:Manoeuvre." + table, {})
		var is_now: Dictionary = after.get("static:Manoeuvre." + table, {})
		for key: String in is_now:
			var moved := int(is_now[key]) - int(was.get(key, 0))
			if moved != 0:
				man_tally["%s:%s" % [table, key]] = int(man_tally.get("%s:%s" % [table, key], 0)) + moved


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
func _compare_tick(movers: Array[Movement], controllers: Array[OrderController], frame: int, only := -1) -> Array:
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var drives := 0
	var mismatches := 0
	var first := ""
	for i in movers.size():
		if only >= 0 and i != only:
			continue  # round 33 (N5.Y): one mover's drive only
		var mover := movers[i]
		var order: Dictionary = controllers[i].move_order
		if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
			continue
		var start := _capture_all(movers)
		var live_cmd := TankCommand.new()
		BrainSwitches.native_drive = false
		var t0 := Time.get_ticks_usec()
		mover.drive(live_cmd, order, delta)
		tick_live_usec += Time.get_ticks_usec() - t0
		BrainSwitches.native_drive = true
		var live := _capture_all(movers)
		_restore_all(movers, start)
		var native_cmd := TankCommand.new()
		var man_before := _man_counts()
		t0 = Time.get_ticks_usec()
		NativeDrive.drive(mover, native_cmd, order, delta)
		tick_native_usec += Time.get_ticks_usec() - t0
		var native := _capture_all(movers)
		_man_add(man_before, start[i], native[i])
		_yield_add(man_before, start, native, movers.size())
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
## `part` of `parts` (round 33): a mover is compared on the frames where `(frame + i) % parts == part`, so every half
## sees every crew (a branch floor splits by frame). The draws are made for every pair either way: `rng` also places the
## k-turns, and the fight must be the same in every half.
func _unstick_compare(movers: Array[Movement], controllers: Array[OrderController], rng: RandomNumberGenerator,
		frame: int, part := 0, parts := 1) -> Array:
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
		var mine := (frame + i) % parts == part
		for variant in 5:
			# The draws first, in the order the forcing below reads them.
			var pivot := false
			var left := 0.0
			var gear := 0.0
			var esc_turn := 0.0
			var press := 0.0
			match variant:
				2:
					pivot = rng.randf() < 0.5
				3:
					left = rng.randf_range(0.01, 0.5)
					gear = 1.0 if rng.randf() < 0.5 else -1.0
					esc_turn = 1.0 if rng.randf() < 0.5 else -1.0
					press = rng.randf_range(-2.0, 2.0)
			var throttle := 1.0 if variant == 1 else rng.randf_range(-1.0, 1.0)
			var turn := rng.randf_range(-1.0, 1.0)
			if not mine:
				continue
			var start := _capture_all(movers)
			match variant:
				1:
					mover._unstick_left = 0.0
					mover._stuck_time = Movement.STUCK_SECONDS - 0.01
				2:
					mover._unstick_left = 0.5
					mover._escape_gear = 0.0
					mover._unstick_pivot = pivot
				3:
					mover._unstick_left = left
					mover._escape_gear = gear
					mover._escape_turn = esc_turn
					mover._press_from = mover.ctl.tank.global_position + Vector3(press, 0.0, 0.5)
				4:
					mover._unstick_left = 0.0
					mover._press_time = Movement.PRESS_SECONDS - 0.01
			var forced := _capture_all(movers)
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


## `parts` > 1 (round 33): the unstick compare's `part` of the frames (see `_unstick_compare`); `drive` false leaves the
## drive compare to the file that has it (the fight is the same either way: the compares restore what they touch).
func _k_turn_case(owned: bool, part := 0, parts := 1, drive := true) -> void:
	if NativeExpect.absent(self):
		print("native: absent, the k-turn equality is not exercised in this run")
		return
	MoverState.world_reset()  # a crew an earlier test left held is not this case's world
	_man_reset()
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
		tank.place(Vector3(25.0 * i - 60.0, 0.0, 80.0), tank.rotation.y)
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
		var result := _compare_tick(movers, controllers, frame) if drive else [0, 0, ""]
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
		var stuck := _unstick_compare(movers, controllers, rng, frame, part, parts) if not owned else [0, 0, "", {}]
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
	# (No _man_check here: an order lands between frames and the fight's own drive makes its decision before the compare;
	# test_native_manoeuvre compares decisions on their tick. The comparison above still covers every gate tick.)
	if not owned:
		print("native unstick (part %d of %d): %d compared (by variant:fired %s), %d mismatches" % [part, parts,
				unstick_compared, unstick_branches, unstick_mismatches])
		assert_eq(unstick_mismatches, 0, "the native unstick is the live GDScript unstick: %s" % unstick_first)
		assert_true(unstick_compared >= 1000 / parts and int(unstick_branches.get("1:fired", 0)) >= 20 / parts,
				"every branch asked (%s)" % unstick_branches)
	# Floors against a vacuous run, not targets: kturnarc (a leg ends by the arc driven; round 31's H2 signed by gear)
	# leaves this fight 4 plans (builder0, pair/cph-on), against >= 5 before (round 30's lab measured the same).
	assert_true(int(kturn_after[0]) - int(kturn_before[0]) >= 3 and int(kturn_after[1]) - int(kturn_before[1]) >= 60,
			"k-turns planned and driven (%s -> %s)" % [kturn_before, kturn_after])


func _drive_case(owned: bool) -> void:
	if NativeExpect.absent(self):
		print("native: absent, the drive equality is not exercised in this run")
		return
	MoverState.world_reset()  # a crew an earlier test left held is not this case's world
	_man_reset()
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
		tank.place(Vector3(-30.0 + 6.0 * (i % 6), 0.0, -10.0 + 7.0 * (i / 6)), tank.rotation.y)
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
		controllers[f].tank.place(slot, controllers[f].tank.rotation.y)
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
			var man_before := _man_counts()
			t0 = Time.get_ticks_usec()
			NativeDrive.drive(mover, native_cmd, order, delta)
			native_usec += Time.get_ticks_usec() - t0
			var native := _capture_all(movers)
			_man_add(man_before, start[i], native[i])
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
	if (Manoeuvre as Script).get_script_constant_map().has("STALL_INTENT_DEFAULT"):  # round 35 (W1c): its reach in this fight
		print("native drive: stall intent ticks (the fight's own drives) %d (STALL_INTENT_DEFAULT %s)" % [
				Manoeuvre.stall_intent_ticks, Manoeuvre.STALL_INTENT_DEFAULT])
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
	_man_check("drive")
	assert_true(asked >= 1000 and wheeled >= 200, "a real sample (%d drives, %d wheeled)" % [asked, wheeled])
	assert_true(replans >= 20 and native_replans == replans, "re-plans happen, and the native arm counts them through the statics (%d, %d)" % [replans, native_replans])
	assert_true(avoided >= 20, "avoidance shapes some drives (%d)" % avoided)
	assert_true(stationed >= 20, "station keeping runs (%d)" % stationed)
	var gates := Movement.gate_report()
	assert_true(int(gates["offered"]) - int(gates_before["offered"]) >= 200 and int(gates["refused"]) - int(gates_before["refused"]) >= 20,
			"the arrival gate is offered and refused (%s)" % gates)
