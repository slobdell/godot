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
## The fewest negotiating drives a stage twins: half the lowest fresh-process count (the Sumps, 370).
const MIN_COMPARED := 185
var screened := 0
var set_up_asks := 0
var _movers: Array[Movement] = []
const ASKED_FIELDS: Array[String] = ["native_stale", "yield_to", "yield_spot", "_yield_point", "_yield_from", "_yield_stop_m",
		"_yield_dir", "_yield_left", "_yield_held", "phase", "blocked_by", "_yield_unfit_last", "_wheel_radius_unit",
		"_wheel_radius_value", "pass_offer"]


func test_the_give_way_on_open_ground() -> void:
	if FreshStage.parent(self, "test_the_give_way_on_open_ground"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _stage("yard_open", false, Vector3(0.0, 0.0, 15.0), 9.0, 24.0, {"": 10, "spot:spot": 1, "setup_refusals": 1}, 60)


func test_the_give_way_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_give_way_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _stage("yard_open", true, Vector3(0.0, 0.0, 15.0), 9.0, 24.0, {"": 10, "spot:spot": 1})


## Round 34 (traffic T6b, R34.17, `underfire`): the open-ground stage with the switch on in forced compares. After a
## negotiating compare: every OTHER hull hit this tick (the asked crew refuses: underfire_refusals), then every hull hit
## (its own step aside held: underfire_holds); and every frame, each crew giving way hit this tick, its whole execute
## step compared: T6b's give-way FINISHES under fire (T6's abort, dropped at R34.17, reversed crews into the asker), so
## the native step must carry it on too. Tanks' ticks_since_hit and the switch are put back after each.
## Round 35 (T7): in this stage's ranks a neighbour sits in every pass lane, so an asked crew under fire gives way as
## today (underfire_gives); the refusal, the hold and a real pass start are floored on the pass stage below.
const UNDERFIRE_FLOORS := {"": 10, "underfire_gives": 1, "pass_ticks": 1, "passes_timeout": 1, "passes_done": 1}
## Round 35 (traffic T7): the forced passes. Each mover with a move order, `under_fire` times a stage, is put mid-pass round
## the nearest other hull and its drive twinned (`_avoid` steers by `_pass_point`): cycling a live pass (its way toward the
## refuser: behind it, the abreast point), one on its last tick (the clock ends it: passes_timeout) and one already past
## the refuser's nose (passes_done). Put back after each.
const PASS_CASES := ["live", "timeout", "done"]


func test_the_give_way_under_fire() -> void:
	if FreshStage.parent(self, "test_the_give_way_under_fire"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _stage("yard_open", false, Vector3(0.0, 0.0, 15.0), 9.0, 24.0, UNDERFIRE_FLOORS, 0, 60)


func test_the_give_way_under_fire_owned() -> void:
	if FreshStage.parent(self, "test_the_give_way_under_fire_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _stage("yard_open", true, Vector3(0.0, 0.0, 15.0), 9.0, 24.0, UNDERFIRE_FLOORS, 0, 60)


## Round 35 (traffic T7): the pass, end to end (traffic's open-ground staging, test_traffic_underfire). Two law tanks on
## yard_open. Leg 0: the crew under fire stands on a stop order, hit every tick, and a squadmate is sent 30 m straight
## through it: asked, it refuses with a side offered (a lane on open ground), the asker passes and ends abreast. Leg 1: both
## drive head-on, both hit every tick: the one to give way holds its own step aside when the other has a lane. Every drive
## of both twinned, every frame.
const PASS_FLOORS := {"": 2, "underfire_refusals": 1, "passes": 1, "pass_ticks": 1, "passes_done": 1, "underfire_holds": 1}
const PASS_FRAMES := 600


func test_the_pass_under_fire() -> void:
	if FreshStage.parent(self, "test_the_pass_under_fire"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _pass_stage(false)


func test_the_pass_under_fire_owned() -> void:
	if FreshStage.parent(self, "test_the_pass_under_fire_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _pass_stage(true)


func _pass_stage(owned: bool) -> void:
	if NativeExpect.absent(self):
		print("native: absent, the pass is not exercised in this run")
		return
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	NativeDrive.owned = owned
	var was_off := Traffic.off("underfire")
	Traffic.set_off("underfire", false)
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	var tanks: Array[Tank] = []
	for spec: Array in [["PassRefuser", Vector3(0.0, 0.0, 0.0), 0.0], ["PassAsker", Vector3(0.0, 0.0, 14.0), 0.0]]:
		var tank := game_match.spawn_tank(spec[0], 0, Match.Team.GREEN, "tank")
		tank.place(spec[1], spec[2])
		tanks.append(tank)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
	_movers = movers
	var drives := 0
	var mismatches := 0
	var first := ""
	for leg in 2:
		var start_asker := Vector3(0.0, 0.0, 14.0)
		tanks[0].place(Vector3.ZERO, 0.0)
		tanks[1].place(start_asker, 0.0)
		await wait_physics_frames(2)
		if leg == 0:
			controllers[0].set_orders({"type": "stop"}, null)
		else:
			controllers[0].set_orders({"type": "move_to", "x": 0.0, "z": 30.0}, null)
		controllers[1].set_orders({"type": "move_to", "x": 0.0, "z": -30.0}, null)
		for frame in PASS_FRAMES:
			tanks[0].ticks_since_hit = 0
			if leg == 1:
				tanks[1].ticks_since_hit = 0
			var result := _compare_tick(movers, controllers, leg * PASS_FRAMES + frame)
			drives += result[0]
			mismatches += result[1]
			if first == "" and result[2] != "":
				first = "(pass leg %d) %s" % [leg, result[2]]
			await wait_physics_frames(1)
			if tanks[1].global_position.z < -20.0:
				break
	NativeDrive.owned = false
	Traffic.set_off("underfire", was_off)
	print("native yield pass stage%s: %d drives compared, %d mismatches" % [" (owned state)" if owned else "", drives, mismatches])
	assert_eq(mismatches, 0, "the native pass is the live GDScript's: %s" % first)
	_yield_check("pass%s" % [" owned" if owned else ""], PASS_FLOORS)


## Round 34 (native N5): the Sumps stage stands beside the west pit, not on its edge. At (-16, -6) its ranks overlapped
## the pump house and the pit's rim, and 7 hulls were pushed off the floor at spawn (TANK_OFF_FLOOR), so its counts rode
## on that geometry. (-40, 40) was chosen from a sweep of 961 centres (laptop: 231 spawn clean) and six builder2 stage
## runs: no hull leaves the floor all stage, every path is reached, and its ranks are 6 m from the pit, so the pit still
## makes give-way spots unfit.
## Round 34 (C34.6 ruling): the floors are what the twin is for, not the fight's size. Every path the stage reaches is
## floored at 1, and the negotiations at 10 (with MIN_COMPARED drives). The counts are a fight, and they move with
## any traffic or planner timing change: planner's C34.6 phase fix took this stage from 44 negotiations to 30 (spot
## 34 -> 14) and yard_open's owned stage from 22 to 15, with 0 mismatches. The yard_open live and owned stages are
## different stages: the live one forces 60 set-up compares (`set_up`) and the owned one none, so their counts differ.
## Here, with the same parameters, owned = live exactly.
const SUMPS_CENTRE := Vector3(-40.0, 0.0, 40.0)
const SUMPS_FLOORS := {"": 10, "spot:spot": 1, "yield_spots_unfit": 1, "spot:back": 1, "spot:hold": 1,
		"parked_refusals": 1, "asks_refused": 1}


func test_the_give_way_in_the_sumps() -> void:
	if FreshStage.parent(self, "test_the_give_way_in_the_sumps"):  # its own process (tests/native/fresh_stage.gd)
		return
	var before := Tank.off_floor
	await _stage("sumps", false, SUMPS_CENTRE, 7.0, 16.0, SUMPS_FLOORS)
	assert_eq(Tank.off_floor - before, 0, "no hull of the Sumps stage leaves the floor (N5)")


func test_the_give_way_in_the_sumps_owned() -> void:
	if FreshStage.parent(self, "test_the_give_way_in_the_sumps_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	var before := Tank.off_floor
	await _stage("sumps", true, SUMPS_CENTRE, 7.0, 16.0, SUMPS_FLOORS)
	assert_eq(Tank.off_floor - before, 0, "no hull of the Sumps stage leaves the floor (N5)")


## The shortened give-way (R2: no spot fits whole, so the asked hull gives way as far as it DOES fit): poses from a sweep of
## Movement._begin_yield in the Sumps at 6434969e (builder0 light: the War Rig 370, the IFV 415 of 7688 poses
## shortened). The asked hull is under way there; a tank 6 m off its nose, stalled with a direct order past it and further
## to go (so it asks rather than gives way), negotiates on the twinned tick.
const SHORT_POSES := [["gang_tank", Vector3(-60.0, 0.0, -36.0), 3], ["gang_tank", Vector3(-60.0, 0.0, -32.0), 5],
		["gang_tank", Vector3(-60.0, 0.0, -12.0), 0], ["ifv", Vector3(-60.0, 0.0, -40.0), 6],
		["ifv", Vector3(-60.0, 0.0, -24.0), 3]]


func test_the_asked_hull_gives_way_shortened() -> void:
	if FreshStage.parent(self, "test_the_asked_hull_gives_way_shortened"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _shortened(false)


func test_the_asked_hull_gives_way_shortened_owned() -> void:
	if FreshStage.parent(self, "test_the_asked_hull_gives_way_shortened_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _shortened(true)


func _shortened(owned: bool) -> void:
	if NativeExpect.absent(self):
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
	_yield_check("shortened%s" % [" owned" if owned else ""], {"": 2, "yield_spots_shortened": 2})


func _stage(arena: String, owned: bool, centre: Vector3, gap: float, across: float, floors: Dictionary, set_up := 0,
		under_fire := 0) -> void:
	if NativeExpect.absent(self):
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
	var fire_asks := under_fire
	var fire_aborts := under_fire
	var fire_passes := under_fire
	var fire_executes := 0
	if under_fire > 0:
		assert_true(NativeGun.configure(), "the native gun takes the live constants (the execute step)")
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
				if fire_aborts > 0 and movers[i].yield_to != "":
					fire_aborts -= 1
					var result := _abort_compare(movers, controllers[i], owned, leg * STAGE_FRAMES + frame)
					fire_executes += result[0]
					mismatches += result[1]
					if first == "" and result[2] != "":
						first = "(hit giving way) " + result[2]
			for i in movers.size():
				if fire_passes > 0 and String(controllers[i].move_order.get("type", "")) == "move_to" \
						and movers[i].ctl.tank.is_alive() and movers[i].yield_to == "":
					fire_passes -= 1
					var result := _pass_compare(movers, controllers, i, PASS_CASES[fire_passes % PASS_CASES.size()],
							leg * STAGE_FRAMES + frame)
					drives += result[0]
					mismatches += result[1]
					if first == "" and result[2] != "":
						first = "(passing) " + result[2]
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
				if fire_asks > 0:
					fire_asks -= 1
					var others: Array[int] = []
					for j in movers.size():
						if j != i:
							others.append(j)
					var all: Array[int] = others.duplicate()
					all.append(i)
					for hit: Array[int] in [others, all]:
						result = _fire_compare(movers, controllers, i, hit, leg * STAGE_FRAMES + frame)
						drives += result[0]
						mismatches += result[1]
						if first == "" and result[2] != "":
							first = "(%s under fire) %s" % ["others" if hit.size() < movers.size() else "all", result[2]]
	NativeDrive.owned = false
	print("native yield stage %s%s: %d negotiating drives compared (of %d drives screened), %d mismatches" % [arena,
			" (owned state)" if owned else "", drives, screened, mismatches])
	assert_eq(mismatches, 0, "the native give-way is the live GDScript's: %s" % first)
	# Floors at half the fresh-process counts. Each test runs in its own child (tests/native/fresh_stage.gd), so the
	# counts are a function of the stage alone: identical on builder0 and builder2 (main 822b3f9e + 43562eab), and the
	# owned arm reads the live arm's counts. In a shared process they moved with the shard order (the Sumps' parked
	# refusals 129, 47, 6, 0). Not reached here: the swap (native.md N5.Y: why); the shortened spot is forced below.
	assert_true(drives >= MIN_COMPARED, "%s: %d negotiating drives compared >= %d" % [arena, drives, MIN_COMPARED])
	if under_fire > 0:
		print("native yield %s%s: %d give-ways hit (execute step compared)" % [arena, " (owned state)" if owned else "",
				fire_executes])
		assert_true(fire_executes >= 1, "%s: a crew giving way is hit and compared" % arena)
		assert_eq(int(yield_tally.get("underfire_aborts", 0)), 0, "%s: a give-way under fire finishes (T6b)" % arena)
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
## Round 33 overnight (traffic item 4, `firemission`): the set-up hulls' fire order cycles fire_at_will / target /
## suppress, and the switch alternates, so on_fire_post's fire-mission test is twinned both ways in both switch states.
func _set_up_compare(movers: Array[Movement], controllers: Array[OrderController], i: int, frame: int) -> Array:
	var keep := []
	var kinds := ["fire_at_will", "target", "suppress"]
	var kind: String = kinds[set_up_asks % kinds.size()]
	var mission_was := Traffic.off("firemission")
	Traffic.set_off("firemission", set_up_asks % 2 == 0)
	for j in controllers.size():
		keep.append([controllers[j].tank.deploy_ratio, controllers[j].weapon_order, controllers[j].move_order])
		if j != i:
			controllers[j].tank.deploy_ratio = 1.0
			controllers[j].weapon_order = {"type": kind, "name": String(controllers[i].tank.name), "x": 0.0, "z": 0.0}
			controllers[j].move_order = {"type": "stop"}
	var result := _compare_tick(movers, controllers, frame, i)
	Traffic.set_off("firemission", mission_was)
	for j in controllers.size():
		controllers[j].tank.deploy_ratio = keep[j][0]
		controllers[j].weapon_order = keep[j][1]
		controllers[j].move_order = keep[j][2]
	return result


## Round 34 (traffic T6): mover `i`'s drive twinned with the hulls `hit` struck this tick (ticks_since_hit 0) and the
## `underfire` switch on; both put back.
func _fire_compare(movers: Array[Movement], controllers: Array[OrderController], i: int, hit: Array[int], frame: int) -> Array:
	var was_off := Traffic.off("underfire")
	Traffic.set_off("underfire", false)
	var keep := []
	for j in hit:
		keep.append(controllers[j].tank.ticks_since_hit)
		controllers[j].tank.ticks_since_hit = 0
	var result := _compare_tick(movers, controllers, frame, i)
	for k in hit.size():
		controllers[hit[k]].tank.ticks_since_hit = keep[k]
	Traffic.set_off("underfire", was_off)
	return result


## Round 35 (traffic T7): mover `i` put mid-pass round the nearest other hull (`which` of PASS_CASES), its drive twinned with
## the `underfire` switch on; the pass state and the switch put back.
func _pass_compare(movers: Array[Movement], controllers: Array[OrderController], i: int, which: String, frame: int) -> Array:
	var was_off := Traffic.off("underfire")
	Traffic.set_off("underfire", false)
	var mover := movers[i]
	var here := mover.ctl.tank.global_position
	var nearest: Tank = null
	for j in controllers.size():
		var other := controllers[j].tank
		if j != i and other.is_alive() and (nearest == null or here.distance_to(other.global_position) < here.distance_to(nearest.global_position)):
			nearest = other
	var keep := [mover._pass_by, mover._pass_side, mover._pass_way, mover._pass_left, mover._pass_failed_by]
	var toward := Vector2(nearest.global_position.x - here.x, nearest.global_position.z - here.z).normalized()
	mover._pass_by = String(nearest.name)
	mover._pass_side = 1.0 if frame % 2 == 0 else -1.0
	mover._pass_way = -toward if which == "done" else toward
	mover._pass_left = 1 if which == "timeout" else int(Movement.PASS_MAX_S * SimClock.TICK_RATE)
	mover._pass_failed_by = ""
	var result := _compare_tick(movers, controllers, frame, i)
	mover._pass_by = keep[0]
	mover._pass_side = keep[1]
	mover._pass_way = keep[2]
	mover._pass_left = keep[3]
	mover._pass_failed_by = keep[4]
	Traffic.set_off("underfire", was_off)
	return result


## Round 34 (traffic T6b): a crew GIVING WAY hit this tick, its whole execute step (OrderController.compute_command, where
## right_of_way runs) against the native one (NativeBridge.impl.execute, execute_native.cpp's right_of_way_with), the
## `underfire` switch on; the give-way goes on in both (no abort: underfire_aborts must not move, and is tallied if it
## does). [executes, mismatches, first]; all put back.
func _abort_compare(movers: Array[Movement], ctl: OrderController, owned: bool, frame: int) -> Array:
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var was_off := Traffic.off("underfire")
	Traffic.set_off("underfire", false)
	var was_hit := ctl.tank.ticks_since_hit
	ctl.tank.ticks_since_hit = 0
	var was_exec := BrainSwitches.native_exec
	BrainSwitches.native_exec = false
	var start := ExecuteTwinCase._capture(movers, ctl)
	var live_cmd: TankCommand = ctl.compute_command(delta)
	var live := ExecuteTwinCase._capture(movers, ctl)
	ExecuteTwinCase._restore(movers, ctl, start)
	for each in movers:
		each.native_stale = Movement.STALE_ALL
	var answer: Variant = NativeBridge.impl.execute(ctl, delta, NativeExec.EXEC_OWNED_VERIFY if owned else NativeExec.EXEC_LIVE)
	var after := ExecuteTwinCase._capture(movers, ctl)
	var result := [0, 0, ""]
	if answer == null:
		result = [0, 1, "frame %d %s: the execute step handed back" % [frame, ctl.tank.name]]
	else:
		result[0] = 1
		var differ := ExecuteTwinCase._diff(live, after)
		if ExecuteTwinCase._command(live_cmd) != ExecuteTwinCase._command(answer as TankCommand) or differ != "":
			result = [1, 1, "frame %d %s: command live %s native %s; %s" % [frame, ctl.tank.name,
					ExecuteTwinCase._command(live_cmd), ExecuteTwinCase._command(answer as TankCommand), differ]]
		var moved := int(after[0][0].get("static:underfire_aborts", 0)) - int(start[0][0].get("static:underfire_aborts", 0))
		if moved != 0:
			yield_tally["underfire_aborts"] = int(yield_tally.get("underfire_aborts", 0)) + moved
	ExecuteTwinCase._restore(movers, ctl, start)
	for each in movers:
		each.native_stale = Movement.STALE_ALL
	BrainSwitches.native_exec = was_exec
	ctl.tank.ticks_since_hit = was_hit
	Traffic.set_off("underfire", was_off)
	return result
