extends TestCase
## Round 31 (native, C31.2/R31.2: the planner's seam in the native drive, the CP-P1 pair). A War Rig (gang_tank, >= the
## seam's 10 m scope) in the Terminus' west street, facing north, ordered to a goal behind it: the k-turn block asks the
## seam for a plan (PlannerSeam.take), the seam holds the crew while its search is sliced and while PlannerExecutor drives
## the legs. Every tick, the rig's drive and its unstick are run twice from one snapshot of every mover AND of the
## seam's world (MoverState.world_capture: crews, queue, retries, counters, the live session replayed by restore): the
## live GDScript, then the native drive (on the live members, or on the C++-owned state). Command, movers and seam must
## be equal; the seam must HOLD the rig on enough of the compared ticks (lesson 300), or the native gates (the
## planned-reverse callback for a held crew, unstick's early return) were never reached. Skipped where the seam is OFF
## (main: PlannerSeam.PLANNER_DEFAULT false; it runs on the pair tree that flips it).

const PLANNER_SEAM := "res://game/ai/planner/planner_seam.gd"
const SECONDS := 30.0


func teardown() -> void:
	NativeDrive.owned = false
	BrainSwitches.native_drive = true
	super.teardown()


func test_a_held_rig_drives_as_the_gdscript() -> void:
	await _case(false)


func test_a_held_rig_on_the_owned_state() -> void:
	await _case(true)


func _capture_all(movers: Array[Movement]) -> Array:
	var states := []
	for mover in movers:
		states.append(MoverState.capture(mover))
	states.append(MoverState.world_capture())
	return states


func _restore_all(movers: Array[Movement], states: Array) -> void:
	for i in movers.size():
		MoverState.restore(movers[i], states[i])
		movers[i].native_stale = Movement.STALE_ALL
	MoverState.world_restore(states[movers.size()])


func _diff(movers: Array[Movement], a: Array, b: Array) -> String:
	for j in movers.size():
		var d := MoverState.diff(a[j], b[j])
		if d != "":
			return "mover %d: %s" % [j, d.left(500)]
	return MoverState.world_diff(a[movers.size()], b[movers.size()])


func _case(owned: bool) -> void:
	if not NativeBridge.available:
		print("native: absent, the seam's drive equality is not exercised in this run")
		return
	if not ResourceLoader.exists(PLANNER_SEAM) or not bool(load(PLANNER_SEAM).call("on")):
		print("native: the planner's seam is OFF on this tree (PLANNER_DEFAULT): nothing to compare")
		return
	var seam: Script = load(PLANNER_SEAM)
	seam.call("reset")
	assert_true(NativeDrive.configure(), "the native drive takes the live constants (with the seam's switch)")
	NativeDrive.owned = owned
	var lab := TacticsLab.create(self, 31, "terminus")
	var rig := lab.gun(Match.Team.GREEN, "Green_P_1", Vector3(-70.0, 0.0, 0.0), 0.0, "gang_tank")
	await lab.start()
	var ctl: OrderController = null
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == rig:
			ctl = child
	assert_true(ctl != null, "the rig has a controller")
	ctl.set_orders({"type": "move_to", "x": -70.0, "z": 40.0}, {"type": "hold_fire"})
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var acc := {"drives": 0, "held": 0, "unsticks": 0, "held_unsticks": 0, "mismatches": 0, "first": ""}
	for tick in int(SimClock.TICK_RATE * SECONDS):
		await lab.step()
		var movers: Array[Movement] = []
		for node in lab.game_match.tanks.get_children():
			var m := Movement.of(node)
			if m != null and m.ctl != null and m.ctl.tank.is_alive():
				movers.append(m)
		var mover := ctl.movement
		var order: Dictionary = ctl.move_order
		if String(order.get("type", "")) != "move_to" or not rig.is_alive():
			continue
		var held := bool(seam.call("live", "Green_P_1"))
		# The drive, twinned.
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
		acc["drives"] += 1
		acc["held"] += 1 if held else 0
		var d := _diff(movers, live, native)
		if MoverState.command(live_cmd) != MoverState.command(native_cmd) or d != "":
			acc["mismatches"] += 1
			if acc["first"] == "":
				acc["first"] = "tick %d drive (%s): command live %s native %s; %s" % [tick, "held" if held else "-",
						MoverState.command(live_cmd), MoverState.command(native_cmd), d]
		# The unstick, twinned (its seam gate returns at once for a held crew).
		var arms := []
		for arm in 2:
			_restore_all(movers, start)
			var cmd := TankCommand.new(1.0, 0.0, Vector3.ZERO)
			if arm == 0:
				mover.unstick(cmd, order, delta)
			else:
				NativeBridge.impl.unstick(mover, cmd, order, delta, owned)
			arms.append([MoverState.command(cmd), _capture_all(movers)])
		_restore_all(movers, start)
		acc["unsticks"] += 1
		acc["held_unsticks"] += 1 if held else 0
		var ud := _diff(movers, arms[0][1], arms[1][1])
		if arms[0][0] != arms[1][0] or ud != "":
			acc["mismatches"] += 1
			if acc["first"] == "":
				acc["first"] = "tick %d unstick (%s): command live %s native %s; %s" % [tick, "held" if held else "-",
						arms[0][0], arms[1][0], ud]
	var report: Dictionary = seam.call("report")
	print("native planner seam%s: %d drives compared (%d held), %d unsticks (%d held), %d mismatches; the seam: %s" % [
			" (owned state)" if owned else "", acc["drives"], acc["held"], acc["unsticks"], acc["held_unsticks"],
			acc["mismatches"], JSON.stringify(report)])
	assert_eq(int(acc["mismatches"]), 0, "the native drive and unstick hold as the GDScript under the seam: %s" % acc["first"])
	assert_true(int(acc["drives"]) >= 600, "a real sample (%d drives)" % acc["drives"])
	assert_true(int(acc["held"]) >= 30, "the seam held the rig on compared drives (%d; requests %d)" % [acc["held"],
			int(report.get("requests", 0))])
	seam.call("reset")
	lab.dispose()
