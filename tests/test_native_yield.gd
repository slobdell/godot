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
const UNDERFIRE_FLOORS := {"": 10, "underfire_gives": 1, "pass_ticks": 1, "passes_timeout": 1, "passes_done": 1,
		"yields_unfinished": 1, "yields_unfinished_capped": 1, "parked_refusals": 1}  # parked: 4 with W1c off and on
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
## Round 37 (native, R37.35: cover's K5 barrier runs, stream/cover 3923ba026): a run at (-39..-33, 72), 32 m north of
## (-40, 40), took the stage's spot:hold to 0. Re-pinned to (-30, 46) from a 23-centre sweep (builder0 light lane, fresh
## processes) as the pin that passes on BOTH main's and K5's arenas: every floor reached, no hull off the floor, owned =
## live exactly; spot:hold 3 and spot:back 2 on each. ((-32, 44) passed K5 only: spot:back 0 on main.) No logic change.
const SUMPS_CENTRE := Vector3(-30.0, 0.0, 46.0)
## Round 36 (native, R36.28's re-pin): the ranks 6 m apart side to side and 13 m across (were 7 and 16). With traffic's yieldgap
## ON the asker reads clear sooner (the gap after both noses), so the old pose's back-ups, which all came from RE-yields after an
## unfinished give-way, stopped: spot:back 15 -> 0 (laptop, main 17a3d967a v lab/s2a-on bf678480c). Tighter ranks leave no
## side spot for a FIRST give-way often enough that the stage backs up in both arms. builder0 quick: spot:back 21 OFF (main)
## and 21 ON (S2a + yieldgap), every floor reached, 0 mismatches over 376 and 477 compared drives. Laptop: 5 and 3 (a 16-cell
## sweep of gap 6 / 7 x across 11-14).
const SUMPS_GAP := 6.0
const SUMPS_ACROSS := 13.0
const SUMPS_FLOORS := {"": 10, "spot:spot": 1, "yield_spots_unfit": 1, "spot:back": 1, "spot:hold": 1,
		"parked_refusals": 1, "asks_refused": 1}


## Round 35 (manoeuvre W1c, `stallintent`; C34.6's rule: the floors are the paths the stage reaches). With W1c ON the Sumps
## fight changes: a pinned crew's stall reads its intent and it escapes before it meets a parked friend, so the stage reaches
## no parked refusal and no plain refused ask (lab 6548394ea, builder0: 0 and 0, 0 mismatches; OFF 8 and 1). Those two are
## floored here only with W1c off; the parked refusal is floored on the yard_open under-fire stages (4 in both W1c arms) and
## the plain refusal on the forced refusal stage (REFUSE_POSES).
func _sumps_floors() -> Dictionary:
	var floors := SUMPS_FLOORS.duplicate()
	if bool((Manoeuvre as Script).get_script_constant_map().get("STALL_INTENT_DEFAULT", false)):
		floors.erase("parked_refusals")
		floors.erase("asks_refused")
	return floors


func test_the_give_way_in_the_sumps() -> void:
	if FreshStage.parent(self, "test_the_give_way_in_the_sumps"):  # its own process (tests/native/fresh_stage.gd)
		return
	var before := Tank.off_floor
	await _stage("sumps", false, SUMPS_CENTRE, SUMPS_GAP, SUMPS_ACROSS, _sumps_floors())
	assert_eq(Tank.off_floor - before, 0, "no hull of the Sumps stage leaves the floor (N5)")


func test_the_give_way_in_the_sumps_owned() -> void:
	if FreshStage.parent(self, "test_the_give_way_in_the_sumps_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	var before := Tank.off_floor
	await _stage("sumps", true, SUMPS_CENTRE, SUMPS_GAP, SUMPS_ACROSS, _sumps_floors())
	assert_eq(Tank.off_floor - before, 0, "no hull of the Sumps stage leaves the floor (N5)")


## The shortened give-way (R2: no spot fits whole, so the asked hull gives way as far as it DOES fit): poses from a sweep of
## Movement._begin_yield in the Sumps at 6434969e (builder0 light: the War Rig 370, the IFV 415 of 7688 poses
## shortened). The asked hull is under way there; a tank 6 m off its nose, stalled with a direct order past it and further
## to go (so it asks rather than gives way), negotiates on the twinned tick.
const SHORT_POSES := [["gang_tank", Vector3(-60.0, 0.0, -36.0), 3], ["gang_tank", Vector3(-60.0, 0.0, -32.0), 5],
		["gang_tank", Vector3(-60.0, 0.0, -12.0), 0], ["ifv", Vector3(-60.0, 0.0, -40.0), 6],
		["ifv", Vector3(-60.0, 0.0, -24.0), 3]]


## Round 35 (traffic T9 / manoeuvre W1c, the orchestrator's request): a PLAIN refusal (ask -> _begin_yield false -> asks_refused:
## no spot free and none merely unfit), forced, since with W1c ON no fight stage reaches one. Poses from a sweep of
## Movement.ask in the Sumps (laptop, GDScript, main 1a18dd278; 12 of 15392 poses refused): the asked hull under way, a tank
## 6 m off its nose driving straight through it, as the shortened stage stages it.
const REFUSE_POSES := [["tank", Vector3(-12.0, 0.0, -24.0), 1], ["tank", Vector3(-4.0, 0.0, 24.0), 3],
		["tank", Vector3(4.0, 0.0, -24.0), 7], ["tank", Vector3(12.0, 0.0, 24.0), 5], ["ifv", Vector3(-100.0, 0.0, -4.0), 0]]


func test_the_asked_hull_refuses_with_no_spot() -> void:
	if FreshStage.parent(self, "test_the_asked_hull_refuses_with_no_spot"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _shortened(false, REFUSE_POSES, "refused", {"": 2, "asks_refused": 2})


func test_the_asked_hull_refuses_with_no_spot_owned() -> void:
	if FreshStage.parent(self, "test_the_asked_hull_refuses_with_no_spot_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _shortened(true, REFUSE_POSES, "refused", {"": 2, "asks_refused": 2})


func test_the_asked_hull_gives_way_shortened() -> void:
	if FreshStage.parent(self, "test_the_asked_hull_gives_way_shortened"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _shortened(false)


func test_the_asked_hull_gives_way_shortened_owned() -> void:
	if FreshStage.parent(self, "test_the_asked_hull_gives_way_shortened_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _shortened(true)


func _shortened(owned: bool, poses: Array = SHORT_POSES, label := "shortened",
		floors := {"": 2, "yield_spots_shortened": 2}) -> void:
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
	for k in poses.size():
		var pose: Array = poses[k]
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
	print("native yield %s%s: %d drives compared, %d mismatches" % [label, " (owned state)" if owned else "", drives, mismatches])
	assert_eq(mismatches, 0, "the native shortened give-way is the live GDScript's: %s" % first)
	_yield_check("%s%s" % [label, " owned" if owned else ""], floors)


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
	var yield_ends := under_fire
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
				# Round 35 (traffic T9, `yieldfit2`): a give-way ended on its clock this tick (the asker usually still close
				# and under way), its whole execute step twinned; every other one with the retry count at the cap.
				if yield_ends > 0 and movers[i].yield_to != "":
					yield_ends -= 1
					var result := _end_compare(movers, controllers[i], owned, yield_ends % 2 == 0, leg * STAGE_FRAMES + frame,
							yield_ends % 4 < 2)
					fire_executes += result[0]
					mismatches += result[1]
					if first == "" and result[2] != "":
						first = "(give-way ended) " + result[2]
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


## Round 35 (traffic T9): a crew GIVING WAY whose give-way ends this tick (_yield_left 1), `yieldfit2` on, its whole execute
## step (right_of_way -> _end_yield -> _yield_unfinished) against the native one; `capped`: the retry count already at
## YIELD_RETRIES for this asker. The give-way counters' moves are tallied. [executes, mismatches, first]; all put back.
func _end_compare(movers: Array[Movement], ctl: OrderController, owned: bool, capped: bool, frame: int, gap := false) -> Array:
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var was_off := Traffic.off("yieldfit2")
	Traffic.set_off("yieldfit2", false)
	# Round 36 (traffic R36.4, `yieldgap`): `gap` = the clear-by-gap reading ON for this end (the stage alternates).
	var gap_was_off := Traffic.off("yieldgap")
	Traffic.set_off("yieldgap", not gap)
	var mover := Movement.of(ctl.tank)
	var keep := [mover._yield_left, mover._unfinished_to, mover._unfinished_count, mover._unfinished_since]
	mover._yield_left = 1
	if capped:
		mover._unfinished_to = mover.yield_to
		mover._unfinished_count = Movement.YIELD_RETRIES
		mover._unfinished_since = Engine.get_physics_frames()
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
		for name: String in ["yields_unfinished", "yields_unfinished_capped"]:
			var moved := int(after[0][0].get("static:" + name, 0)) - int(start[0][0].get("static:" + name, 0))
			if moved != 0:
				yield_tally[name] = int(yield_tally.get(name, 0)) + moved
	ExecuteTwinCase._restore(movers, ctl, start)
	for each in movers:
		each.native_stale = Movement.STALE_ALL
	BrainSwitches.native_exec = was_exec
	mover._yield_left = keep[0]
	mover._unfinished_to = keep[1]
	mover._unfinished_count = keep[2]
	mover._unfinished_since = keep[3]
	Traffic.set_off("yieldfit2", was_off)
	Traffic.set_off("yieldgap", gap_was_off)
	return result


## Round 36 (traffic R36.4, `yieldgap`): traffic's nose-on long-hull case (test_traffic_yieldfit2's _stage_long, manoeuvre's
## X4b trace condemned-6325): a parked tank (9.70 m) giving way to an artillery asker (8.20 m) whose centre is 9.05 m off,
## nose to nose. Its give-way ends this tick and the execute step is twinned in each arm; then the GDScript's own end shows
## the arms differ here (ON: not recorded; OFF: recorded, YIELD_CLEAR's centre distance reads passed).
func _long_end(gap: bool) -> Array:
	var lab := TacticsLab.create(self, 7, "yard_open")
	var parked := lab.gun(Match.Team.GREEN, "Green_Parked", Vector3.ZERO, 0.0, "tank")
	var asker := lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 9.05), 0.0, "artillery")
	await lab.start()
	for i in 3:
		await lab.step()
	asker.global_position = Vector3(0.0, 0.0, 9.05)
	parked.global_position = Vector3.ZERO
	lab.element([String(asker.name)], "Go").assign({"verb": "move", "to": [0.0, -30.0]})
	for i in 2:
		await lab.step()
	asker.global_position = Vector3(0.0, 0.0, 9.05)
	parked.global_position = Vector3.ZERO
	var mover := Movement.of(parked)
	var was_off := [Traffic.off("yieldfit2"), Traffic.off("yieldgap")]
	Traffic.set_off("yieldfit2", false)
	Traffic.set_off("yieldgap", not gap)
	var asked := mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0))
	var movers: Array[Movement] = [mover, Movement.of(asker)]
	var result := _end_compare(movers, mover.ctl, false, false, 0, gap) if asked else [0, 1, "setup: the parked tank did not give way"]
	Traffic.set_off("yieldfit2", false)
	Traffic.set_off("yieldgap", not gap)
	mover._end_yield()
	var recorded := mover._last_yielded_to
	var asker_name := String(asker.name)  # read before dispose() frees the hull
	Traffic.set_off("yieldfit2", was_off[0])
	Traffic.set_off("yieldgap", was_off[1])
	lab.dispose()
	return [result, recorded, asker_name]


func test_the_long_hull_nose_on_end_both_arms() -> void:
	for gap: bool in [true, false]:
		var got: Array = await _long_end(gap)
		var result: Array = got[0]
		print("native yield, nose-on long hulls, yieldgap %s: %d executes twinned, %d mismatches, the GDScript end recorded '%s'"
				% ["ON" if gap else "OFF", result[0], result[1], got[1]])
		assert_eq(int(result[0]), 1, "yieldgap %s: the give-way's end is twinned" % gap)
		assert_eq(int(result[1]), 0, "yieldgap %s: the native end is the GDScript's: %s" % [gap, result[2]])
		assert_eq(got[1], "" if gap else got[2], "yieldgap %s: the arms differ on this stage (ON not recorded, OFF as before)" % gap)


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


## Round 39 (manoeuvre M1, `givewaychain`, C39.2; native N3): a PARKED crew already more than Movement.CHAIN_M off its seat
## takes no give-way spot farther from that seat (Movement._chain_reach / _chain_far, drive_native.cpp chain_in_play /
## chain_far). Forced poses on open ground, one twinned negotiation each, as the shortened stage stages them: the asked
## crew parked (phase arrived) with its seat placed to reach every branch, a tank 6 m off its nose driving straight
## through it (stalled, so it asks). Seats, relative to the crew: `side` 6 m to one side (in play, spots skipped, it gives
## way along or toward the seat), `toward` 8 m back toward the asker (in play, every spot farther: the chain's refusal),
## `near` 3 m off (within CHAIN_M: not in play), `moveto` the side seat as an arrived move_to (yield_seat's move_to branch),
## `underway` that move_to still driving (not in play). Both switch arms, so OFF stays today's give-way.
const CHAIN_UNITS: Array[String] = ["tank", "gang_tank", "ifv"]
const CHAIN_AT: Array[Vector3] = [Vector3(0.0, 0.0, 0.0), Vector3(20.0, 0.0, -20.0), Vector3(-20.0, 0.0, 30.0)]
const CHAIN_SEATS: Array[String] = ["side", "toward", "near", "moveto", "underway"]
const CHAIN_FLOORS_ON := {"": 30, "chain_in_play": 20, "chain_spots_skipped": 10, "chain_refusals": 2, "yields_started": 10}
const CHAIN_FLOORS_OFF := {"": 30, "yields_started": 10}
## The slack poses (a mutation found the stage blind to CHAIN_SLACK_M: no spot fell in the band): for each YIELD_SPOTS
## candidate (and flip), a seat 5 m off the crew placed so THAT candidate lies CHAIN_SLACK_M / 2 beyond the crew's own
## distance from the seat, inside the slack: taken with the slack, skipped without it. The tank, at the origin, heading 0.
const CHAIN_SLACK_OFF := 5.0


func test_the_chain_give_way_on() -> void:
	if FreshStage.parent(self, "test_the_chain_give_way_on"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _chain(false, true)


func test_the_chain_give_way_on_owned() -> void:
	if FreshStage.parent(self, "test_the_chain_give_way_on_owned"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _chain(true, true)


func test_the_chain_give_way_off() -> void:
	if FreshStage.parent(self, "test_the_chain_give_way_off"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _chain(false, false)


func _chain(owned: bool, chain_on: bool) -> void:
	if NativeExpect.absent(self):
		return
	if not (Movement as Script).get_script_constant_map().has("CHAIN_M"):
		print("native yield chain: this tree has no givewaychain (Movement.CHAIN_M), nothing to twin")
		return
	var was_off := Traffic.off("givewaychain")
	Traffic.set_off("givewaychain", not chain_on)
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	NativeDrive.owned = owned
	assert_true(BrainSwitches.native_yield, "the switch leaves native's yield port on (the C++ mirror exists)")
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var drives := 0
	var mismatches := 0
	var first := ""
	var k := 0
	for unit: String in CHAIN_UNITS:
		for at: Vector3 in CHAIN_AT:
			for seat_kind: String in CHAIN_SEATS:
				for heading in [0, 3]:
					var r: Array = await _chain_pose(game_match, k, unit, at, heading, seat_kind)
					drives += r[0]
					mismatches += r[1]
					if first == "" and r[2] != "":
						first = "%s %s %s h%d: %s" % [unit, at, seat_kind, heading, r[2]]
					k += 1
	# The slack poses: along = the asker's way (-nose), across = (-along.y, along.x), as _begin_yield builds them.
	for spot: Vector2 in Movement.YIELD_SPOTS:
		for flip: float in ([1.0, -1.0] if spot.y != 0.0 else [1.0]):
			var r: Array = await _chain_pose(game_match, k, "tank", Vector3.ZERO, 0, "slack", Vector2(spot.x, spot.y * flip))
			drives += r[0]
			mismatches += r[1]
			if first == "" and r[2] != "":
				first = "slack %s x%d: %s" % [spot, flip, r[2]]
			k += 1
	NativeDrive.owned = false
	Traffic.set_off("givewaychain", was_off)
	var label := "chain %s%s" % ["ON" if chain_on else "OFF", " (owned state)" if owned else ""]
	print("native yield %s: %d drives compared, %d mismatches" % [label, drives, mismatches])
	assert_eq(mismatches, 0, "the native chain give-way is the live GDScript's: %s" % first)
	_yield_check(label, CHAIN_FLOORS_ON if chain_on else CHAIN_FLOORS_OFF)
	if not chain_on:
		assert_eq(int(yield_tally.get("chain_in_play", 0)), 0, "OFF: the rule never runs")


## One pose, one twinned negotiation (the asker's drive); returns [drives, mismatches, first]. `slack_spot` (seat "slack"):
## the candidate's offset (along, across) the seat is placed for.
func _chain_pose(game_match: Match, k: int, unit: String, at: Vector3, heading: int, seat_kind: String,
		slack_spot := Vector2.ZERO) -> Array:
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for who: String in ["tank", unit]:
		var tank := game_match.spawn_tank("Chain%d_%s" % [k, who], 0, Match.Team.GREEN, who)
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	var asked := controllers[1].tank
	asked.place(at, heading * PI / 4.0)
	var nose := -asked.global_basis.z
	var right := asked.global_basis.x
	controllers[0].tank.place(at + nose * 6.0, heading * PI / 4.0 + PI)
	await wait_physics_frames(1)
	for orders in controllers:
		orders.set_physics_process(false)
		movers.append(Movement.of(orders.tank))
	var past: Vector3 = at - nose * 30.0
	controllers[0].set_orders({"type": "move_to", "x": past.x, "z": past.z, "direct": true}, null)
	var here := asked.global_position
	var seat: Vector3 = here + right * 6.0
	match seat_kind:
		"toward":
			seat = here + nose * 8.0
		"near":
			seat = here + right * 3.0
		"slack":
			# The candidate S = here + along * x + across * y; a seat w (|w| = d) with |S - here - w| = d + slack / 2:
			# s.w = (L^2 - 2 d e - e^2) / 2 for e = slack / 2, so w's angle off s is acos of that over (L d).
			var along := Vector2(-nose.x, -nose.z).normalized()
			var across := Vector2(-along.y, along.x)
			var s2 := along * slack_spot.x + across * slack_spot.y
			var d := CHAIN_SLACK_OFF
			var e := Movement.CHAIN_SLACK_M * 0.5
			var cos_a := clampf((s2.length_squared() - 2.0 * d * e - e * e) / (2.0 * s2.length() * d), -1.0, 1.0)
			var w := s2.normalized().rotated(acos(cos_a)) * d
			seat = here + Vector3(w.x, 0.0, w.y)
	if seat_kind == "moveto" or seat_kind == "underway":
		controllers[1].set_orders({"type": "move_to", "x": seat.x, "z": seat.z}, null)
		controllers[1].face_slot = Vector3.INF
	else:
		controllers[1].set_orders({"type": "stop"}, null)
		controllers[1].face_slot = seat
	var asker := movers[0]
	asker._progress_goal = Vector3(past.x, 0.0, past.z)
	asker._progress_best = 0.0
	asker.stalled_ticks = 100000
	asker._ask_left = 0
	movers[1].phase = "driving" if seat_kind == "underway" else "arrived"
	movers[1]._remaining = 6.0 if seat_kind == "underway" else 0.0
	for mover in movers:
		mover.native_stale |= Movement.STALE_ALL
	var result := _compare_tick(movers, controllers, k, 0)
	for orders in controllers:
		orders.tank.queue_free()
		orders.queue_free()
	await wait_physics_frames(1)
	return result
