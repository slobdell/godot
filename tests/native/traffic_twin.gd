class_name TrafficTwin
extends RefCounted
## Round 29 (native, C29.2) / round 31 (C31.2, C31.9): the twin harness behind `test_native_traffic_hold*` (traffic's T1
## street hold) and `test_native_traffic_turns*` (traffic's T3b crossing), split out of round 29's test so each case is its
## own file (the hold's was the shard plan's floor, 486 s). Through traffic's own stage (TrafficStage, the game's path):
## every tick, every crew under a move_to is driven twice from one snapshot of every mover AND of traffic.gd's statics
## (the table, the looks, the waits, `_live`, the crossing's verdicts and shares, the counters): the live GDScript drive,
## then the native drive (on the live members, or on the C++-owned state). The command, every mover and Traffic's state
## must be equal bit for bit. Then the same for Movement.unstick (its hold gate, and _pressing_escape's), from forced
## stuck / pressing states.

const TRAFFIC_SOURCE := "res://game/ai/traffic.gd"
static var _statics: PackedStringArray = []


static func _traffic_statics() -> PackedStringArray:
	if _statics.is_empty():
		var regex := RegEx.create_from_string("(?m)^static var ([A-Za-z_][A-Za-z0-9_]*)")
		for found in regex.search_all(FileAccess.get_file_as_string(TRAFFIC_SOURCE)):
			_statics.append(found.get_string(1))
	return _statics


## Traffic's statics are read and written through an instance (MoverState's way).
static func _capture(traffic: Traffic, movers: Array[Movement]) -> Array:
	var states := []
	for mover in movers:
		states.append(MoverState.capture(mover))
	var values := {}
	for name in _traffic_statics():
		var value: Variant = traffic.get(name)
		values[name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return [states, values, MoverState.world_capture()]


static func _restore(traffic: Traffic, movers: Array[Movement], snap: Array) -> void:
	for i in movers.size():
		MoverState.restore(movers[i], snap[0][i])
	for name: String in snap[1]:
		var value: Variant = snap[1][name]
		traffic.set(name, value.duplicate(true) if value is Array or value is Dictionary else value)
	MoverState.world_restore(snap[2])
	for each in movers:
		each.native_stale = Movement.STALE_ALL


static func _diff(a: Array, b: Array) -> String:
	for j in a[0].size():
		var d := MoverState.diff(a[0][j], b[0][j])
		if d != "":
			return "mover %d: %s" % [j, d.left(500)]
	for name: String in a[1]:
		if typeof(a[1][name]) != typeof(b[1][name]) or a[1][name] != b[1][name]:
			return "Traffic.%s: %s v %s" % [name, var_to_str(a[1][name]).left(200), var_to_str(b[1][name]).left(200)]
	return MoverState.world_diff(a[2], b[2])


## Runs the stage (`arena`, `kind`: "head" or "cross") for `seconds` with the twin compare on every tick; `owned` = the
## native arm on the C++-owned state. Returns the counts: drives, held (holding after the live drive), at_spot /
## approach (held with zero / non-zero throttle), shaped (drives whose live arm slowed a wish at the crossing),
## unsticks, held_unsticks, mismatches, first (the first mismatch), and the stage's report. `stage` (R37.35): the stage's
## points instead of TrafficStage.STAGES[arena][kind] (TrafficStage.run's stage_override). Round 32 (C32.8): only the
## crews at `part` mod `parts` in each tick's mover list are compared (the hold's files split by crew); the rest play on.
static func run(case: TestCase, owned: bool, arena: String, kind: String, seconds: float, part := 0, parts := 1,
		stage := {}) -> Dictionary:
	MoverState.world_reset()  # a crew an earlier test left held is not this case's world
	var traffic: Traffic = Traffic.new()
	var script: Script = Traffic
	case.assert_true(NativeDrive.configure(), "the native drive takes the live constants (with traffic's)")
	NativeDrive.owned = owned
	var acc := {"drives": 0, "held": 0, "at_spot": 0, "approach": 0, "shaped": 0, "mismatches": 0, "first": "",
			"unsticks": 0, "held_unsticks": 0}
	var counts_shapes := _traffic_statics().has("cross_slowed")
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
			if movers.find(mover) % parts != part:
				continue
			var order: Dictionary = mover.ctl.move_order
			if String(order.get("type", "")) != "move_to":
				continue
			var name := String(mover.ctl.tank.name)
			var start := _capture(traffic, movers)
			var slowed_before: int = traffic.get("cross_slowed") if counts_shapes else 0
			var live_cmd := TankCommand.new()
			BrainSwitches.native_drive = false
			mover.drive(live_cmd, order, delta)
			BrainSwitches.native_drive = true
			var held_now: bool = script.call("holding", name)
			var shaped_now: bool = counts_shapes and int(traffic.get("cross_slowed")) > slowed_before
			var live := _capture(traffic, movers)
			_restore(traffic, movers, start)
			var native_cmd := TankCommand.new()
			NativeDrive.drive(mover, native_cmd, order, delta)
			var native := _capture(traffic, movers)
			_restore(traffic, movers, start)
			acc["drives"] += 1
			if shaped_now:
				acc["shaped"] += 1
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
							mover.ctl.tank.unit_id, "holding" if held_now else ("shaped" if shaped_now else "-"),
							MoverState.command(live_cmd), MoverState.command(native_cmd), d]
			# Movement.unstick from a forced stuck / pressing state: the hold's gates (unstick, _pressing_escape).
			if now % 5 == 0:
				var forced_start := _capture(traffic, movers)
				mover._unstick_left = 0.0
				if rng.randf() < 0.5:
					mover._stuck_time = Movement.STUCK_SECONDS - 0.01
				else:
					mover._press_time = Movement.PRESS_SECONDS - 0.01
				var forced := _capture(traffic, movers)
				var turn := rng.randf_range(-1.0, 1.0)
				var arms := []
				for arm in 2:
					_restore(traffic, movers, forced)
					var cmd := TankCommand.new(1.0, turn, Vector3.ZERO)
					if arm == 0:
						mover.unstick(cmd, order, delta)
					else:
						NativeBridge.impl.unstick(mover, cmd, order, delta, owned)
					arms.append([MoverState.command(cmd), _capture(traffic, movers)])
				_restore(traffic, movers, forced_start)
				acc["unsticks"] += 1
				if script.call("holding", name):
					acc["held_unsticks"] += 1
				var ud := _diff(arms[0][1], arms[1][1])
				if arms[0][0] != arms[1][0] or ud != "":
					acc["mismatches"] += 1
					if acc["first"] == "":
						acc["first"] = "tick %d %s unstick: command live %s native %s; %s" % [now, name, arms[0][0],
								arms[1][0], ud]
	acc["report"] = await TrafficStage.run(case, 1, arena, kind, "both", seconds, "green", false, on_tick, stage)
	return acc


## The switch `name`'s default on this tree (Traffic.DEFAULT_OFF lists those OFF unless `--traffic-on=`; a tree without
## it has every behaviour on).
static func default_off(name: String) -> bool:
	var consts := (Traffic as Script).get_script_constant_map()
	return consts.has("DEFAULT_OFF") and (consts["DEFAULT_OFF"] as Array).has(name)
