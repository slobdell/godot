extends TestCase
## Round 44 (manoeuvre M3, `--traffic-on=parkedpass`, Traffic.DEFAULT_OFF until Bar S v3): a parked crew with a lane beside it offers
## the pass instead of stepping aside. Bar S v2's Locks cost read in its logs: the second squad driving into the first squad's compact
## zone, a parked War Rig backing 6 m for a Hunter and asking the squadmate behind it to back too. Open ground (yard_open); forward is -Z.
## Two War Rigs parked abreast (no order: arrived, still), a Gun Truck sent through the right one's place with open ground to its right:
## OFF the rig gives way (it moves); ON it refuses with the lane and the truck passes beside it (the rig never moves).

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("parkedpass", Traffic.DEFAULT_OFF.has("parkedpass"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


func _stage() -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3(4.0, 0.0, 0.0), 0.0, "gang_ifv")
	var right := _lab.gun(Match.Team.GREEN, "Green_Parked_R", Vector3(4.0, 0.0, -24.0), 0.0, "gang_tank")
	var left := _lab.gun(Match.Team.GREEN, "Green_Parked_L", Vector3(-1.0, 0.0, -24.0), 0.0, "gang_tank")
	await _lab.start()
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 4.0, "z": -60.0}, {"type": "fire_at_will"})
	return [me, right, left]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("parkedpass"), "M3's rule is opt-in until Bar S v3")


func test_a_parked_rig_with_a_lane_offers_the_pass() -> void:
	var out := {}
	for arm in ["off", "on"]:
		Traffic.set_off("parkedpass", arm == "off")
		var staged := await _stage()
		var me := staged[0] as Tank
		var right := staged[1] as Tank
		var left := staged[2] as Tank
		Movement.reset_route_arms()
		var right_start := right.global_position
		var left_start := left.global_position
		var arrived_at := -1
		var rig_moved := 0.0
		for i in 30 * SimClock.TICK_RATE:
			await _lab.step()
			rig_moved = maxf(rig_moved, maxf(right.global_position.distance_to(right_start), left.global_position.distance_to(left_start)))
			if me.global_position.z < -57.0:
				arrived_at = i + 1
				break
		var arms := Movement.route_arms()
		out[arm] = {"arrived_at": arrived_at, "rig_moved": snappedf(rig_moved, 0.1), "refusals": int(arms.get("parkedpass_refusals", 0)),
				"passes": int(arms.get("passes", 0)), "yields": int(arms.get("yields_started", 0)), "pos": me.global_position}
		print("PARKEDPASS_STAGE %s %s" % [arm, str(out[arm])])
		_lab.dispose()
		_lab = null
	var off: Dictionary = out["off"]
	var on: Dictionary = out["on"]
	assert_eq(int(off["refusals"]), 0, "OFF: no parked refusal (today's yield)")
	assert_true(int(on["refusals"]) >= 1, "ON: the parked rig refused with a lane (%d)" % on["refusals"])
	assert_true(int(on["passes"]) >= 1, "ON: the truck took the pass (%d)" % on["passes"])
	assert_true(float(on["rig_moved"]) < 1.0, "ON: the parked rigs never moved (%.1f m; OFF %.1f m)" % [on["rig_moved"], off["rig_moved"]])
	assert_true(int(on["arrived_at"]) > 0, "ON: the truck still arrives within 30 s (at %s)" % str(on["pos"]))
	# The pass costs the PASSER: round a 14 m rig it swings out, drives the rig's length abreast and swings back (~3 s on open
	# ground, builder0 light: t324 v OFF's t232, where the rig backed 9 m and the truck drove straight through). What the rule buys
	# is the parked squad's: the rig and the squadmate behind it never move. The squad-level net is Bar S v3's to judge.
	if int(off["arrived_at"]) > 0:
		assert_true(int(on["arrived_at"]) <= int(off["arrived_at"]) + 4 * SimClock.TICK_RATE,
				"ON: ...within four seconds of OFF's arrival (t%d v t%d)" % [on["arrived_at"], off["arrived_at"]])
