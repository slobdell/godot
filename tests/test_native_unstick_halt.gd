extends DriveTwinCase
## Round 37 (native, manoeuvre's unstick line for rules' R2): a crew in R2's short halt (`Tank.short_halt_seconds > 0`: the
## plant zeroes throttle to shoot) is not stalled, in Movement.unstick and in drive_native's unstick alike. A hull at rest,
## a move order 40 m ahead, full throttle, its stall clock 0.01 s short of Movement.STUCK_SECONDS (DriveTwinCase's
## `_unstick_compare` variant 1), unstuck from one forced state by the GDScript and natively (live and owned views). Halted:
## neither fires. Not halted (the control): all three fire.

const HALT_UNITS: Array[String] = ["tank", "ifv", "gang_tank"]


func _arm(halted: bool) -> Array:
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	await ArenaFixture.build(self, "yard_open")
	var game_match: Match = MATCH.instantiate()
	add_to_tree(game_match)
	game_match.seed_spawns(1, 0.0)
	var drives := 0
	var mismatches := 0
	var first := ""
	var fired := 0
	var k := 0
	for unit: String in HALT_UNITS:
		for yaw in [0, 3, 6]:
			k += 1
			var tank := game_match.spawn_tank("Halt%d_%s" % [k, unit], 0, Match.Team.GREEN, unit)
			var orders := OrderController.new()
			orders.tank = tank
			orders.tanks_root = game_match.tanks
			add_to_tree(orders)
			tank.place(Vector3.ZERO, yaw * PI / 4.0)
			await wait_physics_frames(1)
			orders.set_physics_process(false)
			var mover := Movement.of(tank)
			var ahead := -tank.global_basis.z * 40.0
			orders.set_orders({"type": "move_to", "x": ahead.x, "z": ahead.z}, null)
			# _unstick_compare's variant 1 (about to fire the stall rule), with the short halt set or not; the three arms
			# (GDScript, native live, native owned) from one forced state.
			mover._unstick_left = 0.0
			mover._stuck_time = Movement.STUCK_SECONDS - 0.01
			tank.short_halt_seconds = 1.0 if halted else 0.0
			var movers: Array[Movement] = [mover]
			var forced := _capture_all(movers)
			var before := Movement.unstick_fires
			var arms := []
			for arm in 3:
				_restore_all(movers, forced)
				var cmd := TankCommand.new(1.0, 0.0, Vector3.ZERO)
				if arm == 0:
					mover.unstick(cmd, orders.move_order, 1.0 / float(SimClock.TICK_RATE))
					fired += 1 if mover._unstick_left > 0.0 else 0
				else:
					NativeBridge.impl.unstick(mover, cmd, orders.move_order, 1.0 / float(SimClock.TICK_RATE), arm == 2)
				arms.append([MoverState.command(cmd), _capture_all(movers)])
			_restore_all(movers, forced)
			Movement.unstick_fires = before
			for arm in [1, 2]:
				drives += 1
				var differ := MoverState.diff(arms[0][1][0], arms[arm][1][0])
				if arms[0][0] != arms[arm][0] or differ != "":
					mismatches += 1
					if first == "":
						first = "%s arm %d: command live %s native %s; %s" % [tank.name, arm, arms[0][0], arms[arm][0], differ.left(400)]
			tank.short_halt_seconds = 0.0
			orders.queue_free()
			tank.queue_free()
			await wait_physics_frames(1)
	return [drives, mismatches, first, fired]


func test_a_crew_in_a_short_halt_is_not_unstuck_natively_either() -> void:
	if NativeExpect.absent(self):
		print("native: absent, the short-halt unstick equality is not exercised in this run")
		return
	if not (Tank as Script).get_script_property_list().any(func(p: Dictionary) -> bool: return p["name"] == "short_halt_seconds"):
		print("native: this tree's Tank has no short_halt_seconds (rules R2 not merged): nothing to compare")
		return
	for halted: bool in [false, true]:
		var got: Array = await _arm(halted)
		var label := "short halt %s" % ("ON (1 s left)" if halted else "OFF (the control)")
		print("native unstick, %s: %d native unsticks compared, %d mismatches, GDScript fires %d" % [label, got[0], got[1], got[3]])
		assert_eq(int(got[1]), 0, "%s: the native unstick is the live GDScript's: %s" % [label, got[2]])
		assert_true(int(got[0]) >= 18, "%s: every hull compared, both native views (%d)" % [label, got[0]])
		if halted:
			assert_eq(int(got[3]), 0, "%s: no crew in a short halt is unstuck" % label)
		else:
			assert_true(int(got[3]) > 0, "%s: the stage reaches the unstick (%d fires)" % [label, got[3]])
