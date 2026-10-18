extends DriveTwinCase
## Round 33 (native N5.Y): `Movement._negotiate`'s body, `ask` and `_begin_yield` natively (drive_native.cpp
## negotiate_body: who gives way, the asked mover's give-way written through its own view, the spot search with its
## yield-run sweep over N2a's outline) against the live GDScript, on the tick a stalled crew negotiates. The drive twins'
## fights rarely stall nose to nose, so this stage makes them: two ranks of hulls (tracked, wheeled, the long rig, the
## artillery truck) facing each other across open ground and across the cramped Sumps, each sent to the slot of the hull
## opposite, and one friend parked in a lane with no order. After every physics frame each driving mover is driven twice
## from one snapshot of every mover (`_compare_tick`); command, members of EVERY mover (the asked one included),
## Movement's statics equal bit for bit. Then the ranks swap back.

const RANK: Array[String] = ["tank", "gang_tank", "ifv", "scout", "artillery", "lancer"]
const STAGE_FRAMES := 420
## The fewest negotiating drives a stage twins: the lowest seen is 238 (yard_open owned, builder0 light).
const MIN_COMPARED := 100
var screened := 0
var set_up_asks := 0
var _movers: Array[Movement] = []
const ASKED_FIELDS: Array[String] = ["native_stale", "yield_to", "yield_spot", "_yield_point", "_yield_from", "_yield_stop_m",
		"_yield_dir", "_yield_left", "_yield_held", "phase", "blocked_by", "_yield_unfit_last", "_wheel_radius_unit",
		"_wheel_radius_value"]


func test_the_give_way_on_open_ground() -> void:
	await _stage("yard_open", false, Vector3(0.0, 0.0, 15.0), 9.0, 24.0, {"": 1, "spot:spot": 1, "setup_refusals": 1}, 60)


func test_the_give_way_on_the_owned_state() -> void:
	await _stage("yard_open", true, Vector3(0.0, 0.0, 15.0), 9.0, 24.0, {"": 1, "spot:spot": 1})


func test_the_give_way_in_the_sumps() -> void:
	await _stage("sumps", false, Vector3(-16.0, 0.0, -6.0), 7.0, 16.0, {"": 1, "spot:spot": 1, "yield_spots_unfit": 1,
			"spot:back": 1, "spot:hold": 1, "parked_refusals": 1, "asks_refused": 1})


func test_the_give_way_in_the_sumps_owned() -> void:
	await _stage("sumps", true, Vector3(-16.0, 0.0, -6.0), 7.0, 16.0, {"": 1, "spot:spot": 1, "yield_spots_unfit": 1,
			"spot:back": 1, "spot:hold": 1})


## The shortened give-way (R2: no spot fits whole, so the asked hull gives way as far as it DOES fit): poses from a sweep of
## Movement._begin_yield in the Sumps at 6434969e (builder0 light: the War Rig 370, the IFV 415 of 7688 poses
## shortened). The asked hull is under way there; a tank 6 m off its nose, stalled with a direct order past it and further
## to go (so it asks rather than gives way), negotiates on the twinned tick.
const SHORT_POSES := [["gang_tank", Vector3(-60.0, 0.0, -36.0), 3], ["gang_tank", Vector3(-60.0, 0.0, -32.0), 5],
		["gang_tank", Vector3(-60.0, 0.0, -12.0), 0], ["ifv", Vector3(-60.0, 0.0, -40.0), 6],
		["ifv", Vector3(-60.0, 0.0, -24.0), 3]]


func test_the_asked_hull_gives_way_shortened() -> void:
	await _shortened(false)


func test_the_asked_hull_gives_way_shortened_owned() -> void:
	await _shortened(true)


func _shortened(owned: bool) -> void:
	if not NativeBridge.available:
		return
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	NativeDrive.owned = owned
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "sumps")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var drives := 0
	var mismatches := 0
	var first := ""
	for k in SHORT_POSES.size():
		var pose: Array = SHORT_POSES[k]
		var controllers: Array[OrderController] = []
		var movers: Array[Movement] = []
		for unit: String in ["tank", String(pose[0])]:
			var tank := game_match.spawn_tank("Short%d_%s" % [k, unit], 0, Match.Team.GREEN, unit)
			var orders := OrderController.new()
			orders.tank = tank
			orders.tanks_root = game_match.tanks
			add_to_tree(orders)
			controllers.append(orders)
		var asked := controllers[1].tank
		asked.place(pose[1], int(pose[2]) * PI / 4.0)
		var nose := -asked.global_basis.z
		var at: Vector3 = pose[1]
		controllers[0].tank.place(at + nose * 6.0, int(pose[2]) * PI / 4.0 + PI)
		await wait_physics_frames(1)
		for orders in controllers:
			orders.set_physics_process(false)
			movers.append(Movement.of(orders.tank))
		var past: Vector3 = at - nose * 30.0
		var away: Vector3 = at + nose * -2.0
		controllers[0].set_orders({"type": "move_to", "x": past.x, "z": past.z, "direct": true}, null)
		controllers[1].set_orders({"type": "move_to", "x": away.x, "z": away.z}, null)
		var asker := movers[0]
		asker._progress_goal = Vector3(past.x, 0.0, past.z)
		asker._progress_best = 0.0
		asker.stalled_ticks = 100000
		asker._ask_left = 0
		movers[1].phase = "driving"
		movers[1]._remaining = 3.0
		for mover in movers:
			mover.native_stale |= Movement.STALE_ALL
		var result := _compare_tick(movers, controllers, k, 0)
		drives += result[0]
		mismatches += result[1]
		if first == "" and result[2] != "":
			first = result[2]
		for orders in controllers:
			orders.tank.queue_free()
			orders.queue_free()
		await wait_physics_frames(1)
	NativeDrive.owned = false
	print("native yield shortened%s: %d drives compared, %d mismatches" % [" (owned state)" if owned else "", drives, mismatches])
	assert_eq(mismatches, 0, "the native shortened give-way is the live GDScript's: %s" % first)
	_yield_check("shortened%s" % [" owned" if owned else ""], {"": 1, "yield_spots_shortened": 1})


func _stage(arena: String, owned: bool, centre: Vector3, gap: float, across: float, floors: Dictionary, set_up := 0) -> void:
	if not NativeBridge.available:
		print("native: absent, the give-way is not exercised in this run")
		return
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	NativeDrive.owned = owned
	assert_true(Movement._off.is_empty(), "the default configuration (no --nav-off switch): the native drive runs")
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	var slots: Array[Vector3] = []
	# Two ranks across from each other: rank A at z - across/2 facing +z, rank B at z + across/2 facing -z.
	for side in 2:
		for i in RANK.size():
			var at := centre + Vector3((i - (RANK.size() - 1) * 0.5) * gap, 0.0, (across * 0.5) * (1.0 if side == 1 else -1.0))
			var tank := game_match.spawn_tank("Yield%d%d" % [side, i], 0, Match.Team.GREEN, RANK[i if side == 0 else RANK.size() - 1 - i])
			tank.place(at, PI if side == 1 else 0.0)
			slots.append(at)
			var orders := OrderController.new()
			orders.tank = tank
			orders.tanks_root = game_match.tanks
			add_to_tree(orders)
			controllers.append(orders)
	# A friend parked in the middle lane with no order: a crew that meets it is refused (parked) or goes round.
	var parked := game_match.spawn_tank("YieldParked", 0, Match.Team.GREEN, "tank")
	parked.place(centre + Vector3(gap * 0.5, 0.0, 0.0), PI * 0.5)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
	_movers = movers
	var drives := 0
	screened = 0
	set_up_asks = set_up
	var mismatches := 0
	var first := ""
	for leg in 2:
		# Each hull to the slot of the hull opposite (leg 0), then back (leg 1).
		var count := RANK.size()
		for i in controllers.size():
			var mine := i if leg == 1 else (i + count) % (2 * count)
			controllers[i].set_orders({"type": "move_to", "x": slots[mine].x, "z": slots[mine].z}, null)
		for frame in STAGE_FRAMES:
			await wait_physics_frames(1)
			for i in movers.size():
				if not _negotiates(movers[i], controllers[i]):
					continue
				var result := _compare_tick(movers, controllers, leg * STAGE_FRAMES + frame, i)
				drives += result[0]
				mismatches += result[1]
				if first == "" and result[2] != "":
					first = result[2]
				if set_up_asks > 0:
					# Forced: every other hull SET UP on a fire post (legs down, a weapon order, no move of its own), so the
					# friend this crew asks refuses (Movement.ask's T1c-b rule, `setup_refusals`). Put back after.
					set_up_asks -= 1
					result = _set_up_compare(movers, controllers, i, leg * STAGE_FRAMES + frame)
					drives += result[0]
					mismatches += result[1]
					if first == "" and result[2] != "":
						first = "(others set up) " + result[2]
	NativeDrive.owned = false
	print("native yield stage %s%s: %d negotiating drives compared (of %d drives screened), %d mismatches" % [arena,
			" (owned state)" if owned else "", drives, screened, mismatches])
	assert_eq(mismatches, 0, "the native give-way is the live GDScript's: %s" % first)
	# Coverage, not a count: each path the stage reaches is floored at 1 (reached at all), plus MIN_COMPARED drives
	# twinned. The counts depend on what ran before the stage in the process, so a floor at a fraction of one
	# observation cannot hold. The Sumps' parked refusals were 129 alone, 47 in builder0's check, and 6 in builder2's
	# 16 shards (main 4d6f321d). Not reached here: the swap (native.md N5.Y: why); the shortened spot is forced below.
	assert_true(drives >= MIN_COMPARED, "%s: %d negotiating drives compared >= %d" % [arena, drives, MIN_COMPARED])
	_yield_check("%s%s" % [arena, " owned" if owned else ""], floors)


## Does this mover's drive negotiate this tick? Its live GDScript drive is run once from its own snapshot (and the world's)
## and put back: the ask cadence fired (`_ask_left` was due and came back reset to ASK_EVERY_SECONDS) only on a tick
## `_negotiate` was called. Only those ticks are twinned whole (every mover captured): the rest cost one capture.
func _negotiates(mover: Movement, orders: OrderController) -> bool:
	var order: Dictionary = orders.move_order
	if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
		return false
	screened += 1
	var due := int(mover._ask_left) - int(mover.ctl._step) <= 0
	var own := MoverState.capture(mover)
	var world := MoverState.world_capture()
	# The fields an ask writes on ANOTHER mover (Movement.ask / _start_yield / _yield_fits): put back with this one.
	var others := []
	for other in _movers:
		var fields := {}
		for name: String in ASKED_FIELDS:
			fields[name] = other.get(name)
		others.append(fields)
	BrainSwitches.native_drive = false
	mover.drive(TankCommand.new(), order, 1.0 / float(SimClock.TICK_RATE))
	BrainSwitches.native_drive = true
	var fired := due and int(mover._ask_left) == int(Movement.ASK_EVERY_SECONDS * SimClock.TICK_RATE)
	for j in _movers.size():
		for name: String in ASKED_FIELDS:
			_movers[j].set(name, others[j][name])
	MoverState.restore(mover, own)
	MoverState.world_restore(world)
	return fired


## One mover's negotiating drive twinned with every OTHER hull set up on a fire post; tanks and controllers put back.
func _set_up_compare(movers: Array[Movement], controllers: Array[OrderController], i: int, frame: int) -> Array:
	var keep := []
	for j in controllers.size():
		keep.append([controllers[j].tank.deploy_ratio, controllers[j].weapon_order, controllers[j].move_order])
		if j != i:
			controllers[j].tank.deploy_ratio = 1.0
			controllers[j].weapon_order = {"type": "fire_at_will"}
			controllers[j].move_order = {"type": "stop"}
	var result := _compare_tick(movers, controllers, frame, i)
	for j in controllers.size():
		controllers[j].tank.deploy_ratio = keep[j][0]
		controllers[j].weapon_order = keep[j][1]
		controllers[j].move_order = keep[j][2]
	return result
