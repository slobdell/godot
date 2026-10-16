extends ExecuteTwinCase
## Round 32 (native, the orchestrator's question): a War Rig at rest told to face behind it (manoeuvre's M1b stage,
## tests/test_manoeuvre_behind.gd `_face_behind`) failed on `check NATIVE=off` (traffic's gate, 0adc6deb: drift_m 25.3,
## legs 2) and passed native. Which arm is the odd one out? The hull's whole execute step twinned every tick from one
## snapshot (ExecuteTwinCase's capture: the mover, its gun, the statics, the planner seam's world): the live GDScript
## `compute_command`, then the native execute on the live members and on the C++-owned state. The live arm's state goes
## on, as the game plays it with native off; the stage's own numbers (legs, drift, aligned) are printed from that arm.

const START := Vector3(0.0, 0.0, 15.0)
const SECONDS := 30.0


func test_the_war_rig_faces_behind_as_the_gdscript() -> void:
	if not NativeBridge.available:
		print("native: absent, the face-behind equality is not exercised in this run")
		return
	assert_true(Movement._off.is_empty(), "the default configuration (no --nav-off switch): the native drive runs")
	assert_true(NativeGun.configure() and NativeDrive.configure(), "the native drive and gun take the live constants")
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var tank := game_match.spawn_tank("Rig", 0, Match.Team.GREEN, "gang_tank")
	tank.place(START, 0.0)
	var ctl := OrderController.new()
	ctl.tank = tank
	ctl.tanks_root = game_match.tanks
	add_to_tree(ctl)
	await wait_physics_frames(2)
	ctl.set_physics_process(false)
	assert_eq(ctl.set_orders({"type": "face", "x": START.x, "z": START.z + 100.0}, {"type": "hold_fire"}), "",
			"the Rig told to face behind it")
	var movers: Array[Movement] = [ctl.movement]
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var was_exec := BrainSwitches.native_exec
	BrainSwitches.native_exec = false
	var native := 0
	var handed_back := 0
	var mismatches := 0
	var first := ""
	var legs := 0
	var gear := 0
	var aligned := -1
	for tick in int(SimClock.TICK_RATE * SECONDS):
		ctl.movement.observe_contact()
		var start := _capture(movers, ctl)
		BrainSwitches.native_drive = false  # the live arm all GDScript (drive's own dispatch too)
		var live_cmd: TankCommand = ctl.compute_command(delta)
		BrainSwitches.native_drive = true
		var live := _capture(movers, ctl)
		for owned in [false, true]:
			_restore(movers, ctl, start)
			ctl.movement.native_stale = Movement.STALE_ALL  # the test wrote the members back: a door from outside
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
			var differ := _diff(live, after)
			if _command(live_cmd) != _command(answer as TankCommand) or differ != "":
				mismatches += 1
				if first == "":
					first = "tick %d (owned %s, phase %s): command live %s native %s; %s" % [tick, owned,
							ctl.movement.phase, _command(live_cmd), _command(answer as TankCommand), differ]
		_restore(movers, ctl, live)
		ctl.movement.native_stale = Movement.STALE_ALL
		tank.command = live_cmd
		await tree.physics_frame
		var speed := tank.speed()
		var g := 1 if speed > 0.3 else (-1 if speed < -0.3 else 0)
		if g != 0 and g != gear:
			legs += 1
			gear = g
		var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
		if absf(rad_to_deg(nose.angle_to(Vector2(0.0, 1.0)))) <= 10.0 and absf(speed) < 0.2:
			aligned = tick
			break
	BrainSwitches.native_exec = was_exec
	var drift := Vector2(tank.global_position.x - START.x, tank.global_position.z - START.z).length()
	print("native face_behind: %d executes native (both views), %d handed back, %d mismatches; the GDScript-played stage: legs %d, drift_m %.1f, aligned_s %.2f, phase %s" % [
			native, handed_back, mismatches, legs, drift, float(aligned) / SimClock.TICK_RATE if aligned >= 0 else -1.0,
			ctl.movement.phase])
	assert_eq(mismatches, 0, "the native execute is the live compute_command through the planned turn: %s" % first)
	assert_true(native + handed_back >= 100, "a real sample (%d native, %d handed back)" % [native, handed_back])
