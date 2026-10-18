extends TestCase
## Round 29 (native, C29.2: brains' B5c pair). Movement._approach_gate with the gate given up / latched / roomy (ON by
## default since brains' flip) in the native drive against the live GDScript, from the same state. Wheeled hulls on the
## Sumps with faced goals near and among the walls (the ring of navmesh round a gate: full, shortened, cramped); after
## every physics frame each driving mover is driven both ways from one snapshot of every mover (MoverState: members and
## statics, the counters included), live members and the C++-owned state. Every few frames a crew aiming at its gate is
## also driven from a forced `blocked` phase (the give-up). Every branch must fire and the two paths be equal bit for bit.

const MATCH := preload("res://game/match/match.tscn")
const UNITS: Array[String] = ["ifv", "scout", "gang_tank", "ifv", "scout", "gang_tank", "ifv", "scout", "gang_tank", "ifv"]
const FRAMES := 600


func teardown() -> void:
	BrainSwitches.native_drive = true
	NativeDrive.owned = false
	super.teardown()


## Every mover's state, then (one more entry) the world a drive can change besides them: the planner's seam (round 31;
## round 32: this file predates it, so a crew the live arm's _planned_reverse handed the seam stayed handed to the
## native arm: `_kturn_check` 6 v 1 on the carry tree).
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


func _order(rng: RandomNumberGenerator) -> Dictionary:
	var angle := rng.randf_range(0.0, TAU)
	var spread := 25.0 if rng.randf() < 0.5 else 90.0
	return {"type": "move_to", "x": rng.randf_range(-spread, spread), "z": rng.randf_range(-spread, spread),
			"facing": [cos(angle), sin(angle)]}


## One mover driven both ways from one snapshot; returns "" or what differed. `gave_up` counts the GDScript arm's give-ups.
var gave_up := 0


func _both_ways(movers: Array[Movement], i: int, order: Dictionary, delta: float) -> String:
	var mover := movers[i]
	var start := _capture_all(movers)
	var live_cmd := TankCommand.new()
	BrainSwitches.native_drive = false
	var given := Movement.gates_given_up
	mover.drive(live_cmd, order, delta)
	BrainSwitches.native_drive = true
	gave_up += Movement.gates_given_up - given
	var live := _capture_all(movers)
	_restore_all(movers, start)
	var native_cmd := TankCommand.new()
	NativeDrive.drive(mover, native_cmd, order, delta)
	var native := _capture_all(movers)
	_restore_all(movers, start)
	for j in movers.size():
		var differ := MoverState.diff(live[j], native[j])
		if differ != "":
			return "mover %d: %s" % [j, differ.left(600)]
	var world := MoverState.world_diff(live[movers.size()], native[movers.size()])
	if world != "":
		return world.left(600)
	if MoverState.command(live_cmd) != MoverState.command(native_cmd):
		return "command live %s native %s" % [MoverState.command(live_cmd), MoverState.command(native_cmd)]
	return ""


## Sumps: tight ground (gates shortened, cramped, given up).
func test_the_gate_rule_drives_as_the_gdscript() -> void:
	if FreshStage.parent(self, "test_the_gate_rule_drives_as_the_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(false, "sumps")


func test_the_gate_rule_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_gate_rule_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(true, "sumps")


## The default layout's open ground (brains' latch case): gates reached and latched.
func test_the_latch_drives_as_the_gdscript() -> void:
	if FreshStage.parent(self, "test_the_latch_drives_as_the_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(false, Arena.DEFAULT_LAYOUT)


func test_the_latch_on_the_owned_state() -> void:
	if FreshStage.parent(self, "test_the_latch_on_the_owned_state"):  # its own process (tests/native/fresh_stage.gd)
		return
	await _case(true, Arena.DEFAULT_LAYOUT)


func _case(owned: bool, arena: String) -> void:
	if not NativeBridge.available:
		print("native: absent, the gate rule's drive equality is not exercised in this run")
		return
	if not Movement.gate_giveup_on():
		print("native: the gate rule is off on this tree (brains' B5c flip not merged): nothing to compare")
		return
	NativeDrive.owned = owned
	assert_true(Movement._off.is_empty(), "the default configuration (no --nav-off switch)")
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, arena)
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2959
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for i in UNITS.size():
		var tank := game_match.spawn_tank("Gate%02d" % i, 0, Match.Team.GREEN, UNITS[i])
		tank.global_position = Vector3(-30.0 + 7.0 * (i % 5), 0.0, -10.0 + 8.0 * (i / 5))
		var orders := OrderController.new()
		orders.tank = tank
		orders.tanks_root = game_match.tanks
		add_to_tree(orders)
		controllers.append(orders)
	await wait_physics_frames(2)
	for orders in controllers:
		movers.append(Movement.of(orders.tank))
		orders.set_orders(_order(rng), null)
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var before := Movement.gate_report()
	var counts_before := [Movement.gates_given_up, Movement.gates_reached_latched, Movement.gates_shortened,
			Movement.gates_turned, Movement.gates_latched_away, Movement.gates_near, int(movers[0].get("gates_side")),
			int(movers[0].get("gates_inside"))]
	var forced_turning := 0
	var drives := 0
	var forced := 0
	var forced_gave := 0
	var mismatches := 0
	var first := ""
	for frame in FRAMES:
		await wait_physics_frames(1)
		if frame % 90 == 89:
			for i in controllers.size():
				if rng.randf() < 0.5:
					controllers[i].set_orders(_order(rng), null)
		for i in movers.size():
			var mover := movers[i]
			var order: Dictionary = controllers[i].move_order
			if String(order.get("type", "")) != "move_to" or not mover.ctl.tank.is_alive():
				continue
			drives += 1
			var d := _both_ways(movers, i, order, delta)
			if d != "":
				mismatches += 1
				if first == "":
					first = "frame %d %s: %s" % [frame, mover.ctl.tank.name, d]
			# The give-up: a crew aiming at its gate, forced BLOCKED (the stall the rule answers).
			if frame % 7 == i % 7 and mover.arc_live:
				var keep := _capture_all(movers)
				mover.phase = "blocked"
				forced += 1
				var gave := gave_up
				d = _both_ways(movers, i, order, delta)
				_restore_all(movers, keep)
				forced_gave += gave_up - gave
				if d != "":
					mismatches += 1
					if first == "":
						first = "frame %d %s (forced blocked): %s" % [frame, mover.ctl.tank.name, d]
			# v4: a crew coming round its gate, out of time (the cap) and stuck while turning (blocked, not no_path).
			if mover._gate_turning_for != Vector3.INF:
				for variant in ["capped", "stuck"]:
					var keep := _capture_all(movers)
					if variant == "capped":
						mover._order_ticks = mover._gate_turning_tick + int(Movement.GATE_TURN_SECONDS * SimClock.TICK_RATE) + 1
					else:
						mover.phase = "blocked"
						mover.blocked_by = "terrain"
					mover.native_stale |= Movement.STALE_ALL
					forced_turning += 1
					d = _both_ways(movers, i, order, delta)
					_restore_all(movers, keep)
					if d != "":
						mismatches += 1
						if first == "":
							first = "frame %d %s (turning, %s): %s" % [frame, mover.ctl.tank.name, variant, d]
	var after := Movement.gate_report()
	# The comparisons restore every static, so the counters moved only by the game's own (native) drive.
	var given_up := Movement.gates_given_up - int(counts_before[0])
	var latched := Movement.gates_reached_latched - int(counts_before[1])
	var shortened := Movement.gates_shortened - int(counts_before[2])
	var turned := Movement.gates_turned - int(counts_before[3])
	var latched_away := Movement.gates_latched_away - int(counts_before[4])
	var near := Movement.gates_near - int(counts_before[5])
	# Round 32 (B5c-v6): side gates chosen by the game's own drive (`gates_side`, by name: v5 trees lack it).
	var sides := int(movers[0].get("gates_side")) - int(counts_before[6])
	# Round 33 (B5c-v6, R33.8): gates latched from inside the turning circle (`gates_inside`, by name: older trees lack it).
	var inside := int(movers[0].get("gates_inside")) - int(counts_before[7])
	print("native gate v4 %s%s: turned %d, latched away %d, near %d, side %d, inside %d; %d turning crews forced (capped / stuck)" % [
			arena, " (owned state)" if owned else "", turned, latched_away, near, sides, inside, forced_turning])
	print("native gate %s%s: %d drives + %d forced blocked (%d given up) compared, %d mismatches; the game's own drive: given up %d, latched %d, shortened %d; refusals %s (before %s)" % [
			arena, " (owned state)" if owned else "", drives, forced, forced_gave, mismatches, given_up, latched, shortened,
			after["refusals"], before["refusals"]])
	assert_eq(mismatches, 0, "the native gate rule is the GDScript's: %s" % first)
	assert_true(drives >= 3000, "a real sample (%d drives)" % drives)
	if bool(movers[0].call("gate_side_on")) and arena == "sumps":
		# Round 32 (B5c-v6, builder0 light at d282ae51: 11-15 a case): a floor against a vacuous run, not a target. Round 33
		# (R4, filed under R4's bar on main e4d1f749): on the Sumps only, where the rear gates are cramped (6 / 6 at
		# 560e09e8); on open ground the rear gate has turning room and v4's come-round takes it (foundry: 1 / 1).
		assert_true(sides >= 5, "side gates chosen (%d)" % sides)
	assert_true(forced >= 50 and forced_gave >= 20, "the give-up compared from a forced stall (%d, %d given up)" % [forced,
			forced_gave])
	if arena == "sumps":
		assert_true(shortened > 0, "a gate was shortened for its turning room (%d)" % shortened)
		assert_true(int(after["refusals"].get("cramped", 0)) > int(before["refusals"].get("cramped", 0)), "a gate had no room")
	else:
		# v4 on open ground: the near rule (a new goal within the approach), the come-round of a gate reached facing away
		# (started, then capped or stuck: forced), and a gate latched (facing the heading or, with no room, away).
		assert_true(near > 0, "the near rule fired (%d)" % near)
		assert_true(turned > 0 and forced_turning > 0, "a crew came round its gate (%d), compared capped / stuck (%d)" % [
				turned, forced_turning])
		# Round 33 (R4, main e4d1f749): inside_circle is a _gate_latch too (foundry at 560e09e8: latched 0 / 2, inside 3 / 1).
		assert_true(latched + latched_away + inside > 0, "a gate was latched (%d, away %d, inside the circle %d)" % [latched,
				latched_away, inside])
		if bool(movers[0].call("gate_inside_on")):
			assert_true(inside >= 1, "a gate inside the turning circle was latched (%d)" % inside)
