extends TestCase
## Round 29 (native, C29.2: traffic's T1 street hold, the pair). His Terminus head-on case through traffic's own stage
## (TrafficStage, the game's path: the squads meet in the street, one waits at spots beside the mouth). Every tick, every
## crew under a move_to is driven twice from one snapshot of every mover AND of traffic.gd's statics (the table, the
## looks, the waits, `_live`, the counters): the live GDScript drive, then the native drive (on the live members, or on
## the C++-owned state). The command, every mover and Traffic's state must be equal bit for bit. Then the same for
## Movement.unstick (its hold gate, and _pressing_escape's), from forced stuck / pressing states. The hold must fire:
## crews reach their spots and hold there (lesson 300).

const TRAFFIC_SOURCE := "res://game/ai/traffic.gd"
var _saved_native := false
var _statics: PackedStringArray = []
## Traffic's statics are read and written through an instance (MoverState's way).
var _traffic: Traffic = Traffic.new()
## Traffic's statics that a tree without T1 lacks are called through the script (this file parses on either tree).
var _script: Script = Traffic


func teardown() -> void:
	BrainSwitches.native = _saved_native
	BrainSwitches.native_drive = true
	NativeDrive.owned = false
	Traffic.set_off("hold", false)
	super.teardown()


func _traffic_statics() -> PackedStringArray:
	if _statics.is_empty():
		var regex := RegEx.create_from_string("(?m)^static var ([A-Za-z_][A-Za-z0-9_]*)")
		for found in regex.search_all(FileAccess.get_file_as_string(TRAFFIC_SOURCE)):
			_statics.append(found.get_string(1))
	return _statics


func _capture(movers: Array[Movement]) -> Array:
	var states := []
	for mover in movers:
		states.append(MoverState.capture(mover))
	var traffic := {}
	for name in _traffic_statics():
		var value: Variant = _traffic.get(name)
		traffic[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return [states, traffic]


func _restore(movers: Array[Movement], snap: Array) -> void:
	for i in movers.size():
		MoverState.restore(movers[i], snap[0][i])
	for name: String in snap[1]:
		var value: Variant = snap[1][name]
		_traffic.set(name, value.duplicate(true) if value is Array or value is Dictionary else value)


func _diff(a: Array, b: Array) -> String:
	for j in a[0].size():
		var d := MoverState.diff(a[0][j], b[0][j])
		if d != "":
			return "mover %d: %s" % [j, d.left(500)]
	for name: String in a[1]:
		if typeof(a[1][name]) != typeof(b[1][name]) or a[1][name] != b[1][name]:
			return "Traffic.%s: %s v %s" % [name, var_to_str(a[1][name]).left(200), var_to_str(b[1][name]).left(200)]
	return ""


func test_the_street_hold_drives_as_the_gdscript() -> void:
	await _case(false)


func test_the_street_hold_on_the_owned_state() -> void:
	await _case(true)


func _case(owned: bool) -> void:
	if not NativeBridge.available:
		print("native: absent, the hold's drive equality is not exercised in this run")
		return
	if NativeTraffic.drive_config().is_empty():
		print("native: this tree's Traffic has no street hold (traffic T1 not merged): nothing to compare")
		return
	_saved_native = BrainSwitches.native
	Traffic.set_off("hold", false)
	assert_true(NativeDrive.configure(), "the native drive takes the live constants (with the hold's)")
	NativeDrive.owned = owned
	var acc := {"drives": 0, "held": 0, "at_spot": 0, "approach": 0, "mismatches": 0, "first": "", "unsticks": 0,
			"held_unsticks": 0}
	var rng := RandomNumberGenerator.new()
	rng.seed = 2929
	var delta := 1.0 / float(SimClock.TICK_RATE)
	var on_tick := func(lab: TacticsLab, now: int) -> void:
		var movers: Array[Movement] = []
		for node in lab.game_match.tanks.get_children():
			var m := Movement.of(node)
			if m != null and m.ctl != null and m.ctl.tank.is_alive():
				movers.append(m)
		for mover in movers:
			var order: Dictionary = mover.ctl.move_order
			if String(order.get("type", "")) != "move_to":
				continue
			var name := String(mover.ctl.tank.name)
			var start := _capture(movers)
			var live_cmd := TankCommand.new()
			BrainSwitches.native_drive = false
			mover.drive(live_cmd, order, delta)
			BrainSwitches.native_drive = true
			var held_now: bool = _script.call("holding", name)
			var live := _capture(movers)
			_restore(movers, start)
			for each in movers:
				each.native_stale = Movement.STALE_ALL
			var native_cmd := TankCommand.new()
			NativeDrive.drive(mover, native_cmd, order, delta)
			var native := _capture(movers)
			_restore(movers, start)
			for each in movers:
				each.native_stale = Movement.STALE_ALL
			acc["drives"] += 1
			if held_now:
				acc["held"] += 1
				if live_cmd.throttle == 0.0:
					acc["at_spot"] += 1
				else:
					acc["approach"] += 1
			var d := _diff(live, native)
			if MoverState.command(live_cmd) != MoverState.command(native_cmd) or d != "":
				acc["mismatches"] += 1
				if acc["first"] == "":
					acc["first"] = "tick %d %s (%s, %s): command live %s native %s; %s" % [now, name,
							mover.ctl.tank.unit_id, "holding" if held_now else "-", MoverState.command(live_cmd),
							MoverState.command(native_cmd), d]
			# Movement.unstick from a forced stuck / pressing state: the hold's gates (unstick, _pressing_escape).
			if now % 5 == 0:
				var forced_start := _capture(movers)
				mover._unstick_left = 0.0
				if rng.randf() < 0.5:
					mover._stuck_time = Movement.STUCK_SECONDS - 0.01
				else:
					mover._press_time = Movement.PRESS_SECONDS - 0.01
				var forced := _capture(movers)
				var arms := []
				for arm in 2:
					_restore(movers, forced)
					for each in movers:
						each.native_stale = Movement.STALE_ALL
					var cmd := TankCommand.new(1.0, rng.randf_range(-1.0, 1.0), Vector3.ZERO)
					if arm == 0:
						mover.unstick(cmd, order, delta)
					else:
						NativeBridge.impl.unstick(mover, cmd, order, delta, owned)
					arms.append([MoverState.command(cmd), _capture(movers)])
				_restore(movers, forced_start)
				for each in movers:
					each.native_stale = Movement.STALE_ALL
				acc["unsticks"] += 1
				if _script.call("holding", name):
					acc["held_unsticks"] += 1
				var ud := _diff(arms[0][1], arms[1][1])
				if arms[0][0] != arms[1][0] or ud != "":
					acc["mismatches"] += 1
					if acc["first"] == "":
						acc["first"] = "tick %d %s unstick: command live %s native %s; %s" % [now, name, arms[0][0],
								arms[1][0], ud]
	var report := await TrafficStage.run(self, 1, "terminus", "head", "both", 30.0, "green", false, on_tick)
	print("native traffic hold%s: %d drives compared (%d holding: %d at the spot, %d approaching), %d unsticks (%d holding), %d mismatches; the stage: %s" % [
			" (owned state)" if owned else "", acc["drives"], acc["held"], acc["at_spot"], acc["approach"], acc["unsticks"],
			acc["held_unsticks"], acc["mismatches"], _script.call("report")])
	assert_eq(int(acc["mismatches"]), 0, "the native drive holds as the GDScript: %s" % acc["first"])
	assert_true(int(acc["drives"]) >= 2000, "a real sample (%d drives)" % acc["drives"])
	assert_true(int(acc["at_spot"]) >= 30 and int(acc["approach"]) >= 30, "the hold fired both ways: at the spot %d, approaching %d" % [
			acc["at_spot"], acc["approach"]])
	assert_true(int(acc["held_unsticks"]) >= 5, "a holding crew's unstick was compared (%d)" % acc["held_unsticks"])
	assert_true(int(report["tr_holds"]) > 0, "the stage held a squad: %s" % report)
