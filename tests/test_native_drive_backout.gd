extends DriveTwinCase
## Round 44 (native N3, the twin manoeuvre asked for; C44.4): with `--traffic-on=backout` (manoeuvre M2: Movement._backout_due,
## the departure look in _planned_reverse, the `_backout_leg` continuation, the station PID kept off a planned leg) the native drive
## is the live GDScript drive on HIS case: Locks 56416, his five Guns as his 08-15 recording spawned them, an element's move to his
## click (tests/test_manoeuvre_backout.gd's stage). Every frame every driving crew is driven both ways from one snapshot of all of
## them (DriveTwinCase._compare_tick: the command and every Movement member and static, `backout_looks` and the five _backout_
## members included); the fight itself runs on the native drive, so its own departure looks are the C++ drive's.

const SPAWN := Vector3(-42.1429, 0.0, 90.0)
const CLICK := [-90.52, 44.77]
const SQUAD := {"Green_Guns_1": [Vector3(-50.375, 0.0, 89.0), "gang_tank"], "Green_Guns_2": [SPAWN, "gang_tank"],
		"Green_Guns_3": [Vector3(-37.375, 0.0, 89.0), "gang_tank"], "Green_Guns_4": [Vector3(-47.125, 0.0, 105.0), "gang_ifv"],
		"Green_Guns_5": [Vector3(-40.625, 0.0, 105.0), "gang_support"]}
const BOX_WEST_X := -45.0
const BOX_NORTH_Z := 81.3
const WATCH_FRAMES := 8 * 30

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("backout", Traffic.DEFAULT_OFF.has("backout"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


func test_his_container_start_backs_out_the_same_on_the_cpp_drive() -> void:
	if FreshStage.parent(self, "test_his_container_start_backs_out_the_same_on_the_cpp_drive"):  # its own process
		return
	if NativeExpect.absent(self):
		print("native: absent, the backout equality is not exercised in this run")
		return
	Traffic.set_off("backout", false)
	MoverState.world_reset()
	_man_reset()
	assert_true(NativeDrive.configure(), "the native drive takes the live constants")
	_lab = TacticsLab.create(self, 56416, "locks")
	var rig: Tank = null
	for unit_name: String in SQUAD:
		var tank := _lab.unit(Match.Team.GREEN, unit_name, SQUAD[unit_name][0], 0.0, String(SQUAD[unit_name][1]))
		if unit_name == "Green_Guns_2":
			rig = tank
	await _lab.start()
	Movement.reset_route_arms()
	DoctrineTable.clear_cache()
	var gangs: DoctrineTable = DoctrineTable.load_table("gangs").get("table")
	var element := _lab.elements.form(SQUAD.keys(), "Guns", gangs)
	element.assign({"verb": "move", "to": CLICK, "drills": false})
	var controllers: Array[OrderController] = []
	var movers: Array[Movement] = []
	for child in _lab.game_match.brains.get_children():
		var brain := child as OrderController
		if brain != null and brain.tank != null and SQUAD.has(String(brain.tank.name)) and brain.movement != null:
			controllers.append(brain)
			movers.append(brain.movement)
	assert_eq(movers.size(), SQUAD.size(), "his five crews are compared")
	var drives := 0
	var mismatches := 0
	var first := ""
	var first_reverse := -1
	var cleared := -1
	for frame in WATCH_FRAMES:
		BrainSwitches.native_drive = true  # the fight's own drive: the C++ one
		await _lab.step()
		var result := _compare_tick(movers, controllers, frame)
		drives += int(result[0])
		mismatches += int(result[1])
		if first == "" and String(result[2]) != "":
			first = result[2]
		var along := rig.real_velocity.dot(-rig.global_basis.z)
		if first_reverse < 0 and along < -0.5:
			first_reverse = frame + 1
		if cleared < 0 and rig.global_position.x < BOX_WEST_X and rig.global_position.z < BOX_NORTH_Z:
			cleared = frame + 1
	var looks := int(Movement.route_arms().get("backout_looks", 0))
	print("native drive backout: %d drives, %d mismatches, %d departure looks in the fight (C++ drive), Guns_2 reverse t%d past the box t%d"
			% [drives, mismatches, looks, first_reverse, cleared])
	assert_eq(mismatches, 0, "the C++ drive is the live GDScript drive with backout ON: %s" % first)
	assert_true(drives >= 600, "his five crews drove (%d)" % drives)
	assert_true(looks >= 1, "the departure look ran in the C++ drive's fight (%d)" % looks)
	assert_true(first_reverse > 0 and first_reverse <= 30, "on the C++ drive his War Rig backs within a second (t%d)" % first_reverse)
	assert_true(cleared > 0, "and is past the box within 8 s (t%d)" % cleared)
