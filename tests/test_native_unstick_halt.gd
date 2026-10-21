extends DriveTwinCase
## Round 37 (native, manoeuvre's unstick line for rules' R2): a crew in R2's short halt (`Tank.short_halt_seconds > 0`: the
## plant zeroes throttle to shoot) is not stalled, in Movement.unstick and in drive_native's unstick alike. A hull at rest,
## a move order 40 m ahead, its stall clock a tick short of Movement.STUCK_SECONDS, so this tick's drive fires the unstick;
## driven from one snapshot by the live GDScript and natively. Halted: neither fires. Not halted (the control): both fire.

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
			mover.phase = "driving"
			mover._stuck_time = Movement.STUCK_SECONDS - 0.5 / float(SimClock.TICK_RATE)
			tank.short_halt_seconds = 1.0 if halted else 0.0
			mover.native_stale |= Movement.STALE_ALL
			var before := Movement.unstick_fires
			var movers: Array[Movement] = [mover]
			var controllers: Array[OrderController] = [orders]
			var result := _compare_tick(movers, controllers, k, 0)
			drives += result[0]
			mismatches += result[1]
			if first == "" and result[2] != "":
				first = result[2]
			fired += Movement.unstick_fires - before
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
		print("native unstick, %s: %d drives compared, %d mismatches, unstick fires %d" % [label, got[0], got[1], got[3]])
		assert_eq(int(got[1]), 0, "%s: the native unstick is the live GDScript's: %s" % [label, got[2]])
		assert_true(int(got[0]) >= 9, "%s: every hull's drive was compared (%d)" % [label, got[0]])
		if halted:
			assert_eq(int(got[3]), 0, "%s: no crew in a short halt is unstuck" % label)
		else:
			assert_true(int(got[3]) > 0, "%s: the stage reaches the unstick (%d fires)" % [label, got[3]])
