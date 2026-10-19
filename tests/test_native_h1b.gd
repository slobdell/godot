extends ExecuteTwinCase
## Round 32 (native, C32.2's pair: manoeuvre H1b, the ask that never frees). NONE PORTED: H1b runs inside
## `Movement._escape_begin`, which the native unstick reaches only as a GDScript callback followed by `return` (as the
## GDScript does), and it writes the repair rows (`_repair_for`, `_repair_to`) the native drive already honours. This
## proves it: manoeuvre's stage (tests/test_manoeuvre_h1b.gd, a War Rig sent to the slot a parked squadmate sits on: two
## failed asks, then a settle at ~12.6 s) with the pinned hull's whole execute step twinned every tick from one snapshot
## (ExecuteTwinCase's capture: every mover, its gun, the statics): the live GDScript `compute_command`, then the native
## execute on the live members and on the C++-owned state. Then the live arm's state goes on, as the game plays it.
## With H1b OFF (its default until judged) the bookkeeping still runs in both arms (failed asks, `_h1b_*`); the settle
## floor applies only where H1b is ON with `--nav-off` empty (the only configuration the native drive runs).

const SECONDS := 20.0


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


func test_the_pinned_hull_settles_as_the_gdscript() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the H1b equality is not exercised in this run")
		return
	if not (Movement as Script).get_script_constant_map().has("H1B_DEFAULT"):
		print("native: this tree's Movement has no H1b (manoeuvre's C32.2 not merged): nothing to compare")
		return
	MoverState.world_reset()  # a crew an earlier test left held is not this case's world
	assert_true(Movement._off.is_empty(), "the default configuration (no --nav-off switch): the native drive runs")
	assert_true(NativeGun.configure() and NativeDrive.configure(), "the native drive and gun take the live constants")
	var lab := TacticsLab.create(self, 32)
	var a := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(TacticsScenarios.LANE_X, 0, 20), 0.0, "gang_tank")
	var b := lab.gun(Match.Team.GREEN, "Green_A_2", Vector3(TacticsScenarios.LANE_X, 0, 38), 0.0, "gang_tank")
	await lab.start()
	_controller_of(lab, a).set_physics_process(false)
	var ctl := _controller_of(lab, b)
	ctl.set_physics_process(false)
	var goal := a.global_position + Vector3(0, 0, 3.0)
	assert_eq(ctl.set_orders({"type": "move_to", "x": goal.x, "z": goal.z}, {"type": "hold_fire"}), "", "B told to move")
	var movers: Array[Movement] = [Movement.of(a), ctl.movement]
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var was_exec := BrainSwitches.native_exec
	BrainSwitches.native_exec = false
	var native := 0
	var handed_back := 0
	var mismatches := 0
	var first := ""
	var failed_asks := 0
	var settles := 0
	var native_settles := 0
	var fires := 0
	var census: Object = ManoeuvreCensus.new()  # H1b's statics by name: this file parses on a tree without them
	for tick in int(SimClock.TICK_RATE * SECONDS):
		ctl.movement.observe_contact()
		var start := _capture(movers, ctl)
		var asks_before := int(census.get("h1b_failed_asks"))
		var settles_before := int(census.get("h1b_settles"))
		var fires_before := Movement.esc_fires_hull
		BrainSwitches.native_drive = false  # the live arm all GDScript (drive's own dispatch too)
		var live_cmd: TankCommand = ctl.compute_command(delta)
		BrainSwitches.native_drive = true
		var live := _capture(movers, ctl)
		var settled := int(census.get("h1b_settles")) > settles_before
		failed_asks += int(census.get("h1b_failed_asks")) - asks_before
		settles += 1 if settled else 0
		fires += Movement.esc_fires_hull - fires_before
		for owned in [false, true]:
			_restore(movers, ctl, start)
			for each in movers:
				each.native_stale = Movement.STALE_ALL  # the test wrote the members back: a door from outside
			var answer: Variant = NativeBridge.impl.execute(ctl, delta, NativeExec.EXEC_OWNED_VERIFY if owned \
					else NativeExec.EXEC_LIVE)
			var after := _capture(movers, ctl)
			if answer == null:
				handed_back += 1
				var untouched := _diff(start, after)
				if untouched != "":
					mismatches += 1
					if first == "":
						first = "tick %d handed back but wrote: %s" % [tick, untouched]
				continue
			native += 1
			native_settles += 1 if settled else 0
			var differ := _diff(live, after)
			if _command(live_cmd) != _command(answer as TankCommand) or differ != "":
				mismatches += 1
				if first == "":
					first = "tick %d (owned %s, phase %s): command live %s native %s; %s" % [tick, owned,
							ctl.movement.phase, _command(live_cmd), _command(answer as TankCommand), differ]
		_restore(movers, ctl, live)
		for each in movers:
			each.native_stale = Movement.STALE_ALL
		b.command = live_cmd
		a.command = TankCommand.new(0.0, 0.0, a.global_position + Vector3(0, 0, -20))
		await lab.step()
	BrainSwitches.native_exec = was_exec
	var on: bool = ctl.movement.call("h1b_on")
	print("native h1b (H1b %s): %d executes native (both views), %d handed back, %d escape fires, %d failed asks, %d settles (%d compared natively), phase %s, %d mismatches" % [
			"ON" if on else "OFF", native, handed_back, fires, failed_asks, settles, native_settles, ctl.movement.phase,
			mismatches])
	lab.dispose()
	assert_eq(mismatches, 0, "the native execute is the live compute_command through H1b: %s" % first)
	assert_true(native >= 1000, "a real sample (%d native executes)" % native)
	assert_true(failed_asks >= 1, "the failed-ask bookkeeping ran (%d)" % failed_asks)
	if on:
		assert_true(native_settles >= 1, "a settle was compared natively (%d of %d)" % [native_settles, settles])
