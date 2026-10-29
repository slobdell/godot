extends DriveTwinCase
## Round 45 (native N3, manoeuvre M2 (b), C45.4): a departure leg pressed against something its look cannot see ends as "stalled"
## (Movement._backout_stall_ticks, BACKOUT_STALL_MPS / _TICKS) on the C++ drive exactly as on the GDScript. His 08-15 start
## (tests/test_native_drive_backout.gd's stage); the moment Green_Guns_2's first departure leg starts reversing, a static box (not
## a tank, so the look's hull test never sees it) is dropped just behind its tail. Every frame every driving crew is driven both
## ways from one snapshot (DriveTwinCase._compare_tick: the command and every Movement member and static, `backout_stalls` and
## `_backout_stall_ticks` included). The proven arm: the leg must actually stall in the fight (backout_stalls >= 1).

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


func test_a_departure_leg_into_an_unseen_box_stalls_the_same_on_the_cpp_drive() -> void:
	if FreshStage.parent(self, "test_a_departure_leg_into_an_unseen_box_stalls_the_same_on_the_cpp_drive"):  # its own process
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
	var dropped := -1
	var stall_ticks_max := 0
	var rig_mover: Movement = null
	for mover: Movement in movers:
		if mover.ctl.tank == rig:
			rig_mover = mover
	for frame in WATCH_FRAMES:
		BrainSwitches.native_drive = true  # the fight's own drive: the C++ one
		if dropped < 0 and rig_mover._backout_leg and rig_mover._kturn_left_m > 0.0 and rig_mover._kturn_gear < 0:
			dropped = frame
			_drop_box_behind(rig)
		await _lab.step()
		stall_ticks_max = maxi(stall_ticks_max, rig_mover._backout_stall_ticks)
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
	var stalls := int(Movement.route_arms().get("backout_stalls", 0))
	print("native drive backout stall: %d drives, %d mismatches, %d departure looks, box dropped t%d, %d stalls (max %d stall ticks), Guns_2 reverse t%d"
			% [drives, mismatches, looks, dropped, stalls, stall_ticks_max, first_reverse])
	assert_eq(mismatches, 0, "the C++ drive is the live GDScript drive through a stalled departure leg: %s" % first)
	assert_true(drives >= 600, "his five crews drove (%d)" % drives)
	assert_true(dropped >= 0, "Guns_2's departure leg started reversing (t%d)" % dropped)
	assert_true(stalls >= 1, "and stalled against the unseen box in the C++ drive's fight (%d stalls)" % stalls)


## A box the departure look cannot see (a StaticBody3D, not a Tank) just behind `rig`'s tail: 7 m wide, 3 m high, 1 m deep.
func _drop_box_behind(rig: Tank) -> void:
	var back := Vector3(rig.global_basis.z.x, 0.0, rig.global_basis.z.z).normalized()
	var half_length := float(Movement.hull_box(rig.unit_id)[2]) * 0.5
	var body := StaticBody3D.new()
	body.name = "UnseenBox"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(7.0, 3.0, 1.0)
	shape.shape = box
	body.add_child(shape)
	_lab.arena.add_child(body)
	body.global_position = rig.global_position + back * (half_length + 0.4 + 0.5) + Vector3(0.0, 1.5, 0.0)
	body.look_at(body.global_position + back, Vector3.UP)
