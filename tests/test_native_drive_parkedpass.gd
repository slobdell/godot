extends DriveTwinCase
## Round 44 (native N3, the twin manoeuvre asked for; C44.4): with `--traffic-on=parkedpass` (manoeuvre M3: Movement.ask's refusal
## with a pass lane by a parked crew, `_parked_for_pass`) the native drive and its yield (BrainSwitches.native_yield: _negotiate,
## ask and _begin_yield in drive_native.cpp) are the live GDScript on manoeuvre's stage (tests/test_manoeuvre_parkedpass.gd): two
## War Rigs parked abreast on yard_open, a Gun Truck sent through the right one's place. Every frame every driving crew is driven
## both ways from one snapshot (DriveTwinCase._compare_tick: the command, every Movement member and static, `parkedpass_refusals`
## and `pass_offer` included); the fight itself runs on the C++ drive and yield.

const WATCH_FRAMES := 14 * 30

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("parkedpass", Traffic.DEFAULT_OFF.has("parkedpass"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


func test_the_parked_pass_offer_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_the_parked_pass_offer_is_the_live_gdscript"):  # its own process
		return
	if NativeExpect.absent(self):
		print("native: absent, the parkedpass equality is not exercised in this run")
		return
	Traffic.set_off("parkedpass", false)
	assert_true(BrainSwitches.native_yield, "ON keeps the C++ yield (traffic.gd's gate lifted for parkedpass)")
	MoverState.world_reset()
	_man_reset()
	_yield_reset()
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3(4.0, 0.0, 0.0), 0.0, "gang_ifv")
	var right := _lab.gun(Match.Team.GREEN, "Green_Parked_R", Vector3(4.0, 0.0, -24.0), 0.0, "gang_tank")
	_lab.gun(Match.Team.GREEN, "Green_Parked_L", Vector3(-1.0, 0.0, -24.0), 0.0, "gang_tank")
	await _lab.start()
	Movement.reset_route_arms()
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 4.0, "z": -60.0}, {"type": "fire_at_will"})
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for tank: Tank in [me, right, _lab.tank_of("Green_Parked_L")]:
		var mover := Movement.of(tank)
		movers.append(mover)
		controllers.append(mover.ctl as OrderController)
	var right_from := right.global_position
	var drives := 0
	var mismatches := 0
	var first := ""
	for frame in WATCH_FRAMES:
		BrainSwitches.native_drive = true  # the fight's own drive and yield: the C++ ones
		await _lab.step()
		var result := _compare_tick(movers, controllers, frame)
		drives += int(result[0])
		mismatches += int(result[1])
		if first == "" and String(result[2]) != "":
			first = result[2]
	var refusals := int(Movement.route_arms().get("parkedpass_refusals", 0))
	var moved := right.global_position.distance_to(right_from)
	print("native drive parkedpass: %d drives, %d mismatches, %d parked-pass refusals in the fight (C++ yield), the rig moved %.1f m"
			% [drives, mismatches, refusals, moved])
	assert_eq(mismatches, 0, "the C++ drive and yield are the live GDScript with parkedpass ON: %s" % first)
	assert_true(drives >= 200, "the truck drove (%d)" % drives)
	assert_true(refusals >= 1, "the parked rig refused with a lane in the C++ yield (%d)" % refusals)
	assert_true(moved < 0.5, "and never moved (%.2f m): the truck passed beside it" % moved)
