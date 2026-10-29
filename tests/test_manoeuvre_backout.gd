extends TestCase
## Round 44 (manoeuvre M2, `--traffic-on=backout`, Traffic.DEFAULT_OFF until Bar S v3): his container moment. On Locks 56416
## (2026-10-28 08:15) Green_Guns_2, a War Rig, stood at (-42.1, 90) facing south with a 20-foot container two metres past its
## nose and was sent 87 m to the west-south-west: it crept forward for a second toward the transit's converging station a metre
## ahead, planned the 4 m back-up that clears the box only at tick 30 and drove off at tick 97 ("it should have been obvious to
## the tank that they should have backed up first to create clearance"). ON, the k-turn is decided at the order's first look
## against where the rig's own route to its seat leaves: it backs out first and is past the box sooner. The real chain: the Locks
## arena, a brain crew, an element's move task and the station it publishes. Forward is -Z (trip-up 2); yaw 0 faces -z.

const SPAWN := Vector3(-42.1429, 0.0, 90.0)
const CLICK := [-90.52, 44.77]
## His five Guns as the recording's header spawned them (three War Rigs on the front row, the two lighter crews behind): the squad's
## centre 5.6 m north of Guns_2 and a neighbour either side are what made Guns_2's start what it was (a rig alone reverses straight).
const SQUAD := {"Green_Guns_1": [Vector3(-50.375, 0.0, 89.0), "gang_tank"], "Green_Guns_2": [SPAWN, "gang_tank"],
		"Green_Guns_3": [Vector3(-37.375, 0.0, 89.0), "gang_tank"], "Green_Guns_4": [Vector3(-47.125, 0.0, 105.0), "gang_ifv"],
		"Green_Guns_5": [Vector3(-40.625, 0.0, 105.0), "gang_support"]}
## ArenaKit's container_20 at (-42, 80), 6.06 m along x: past the box means west of its west end and south of its north face.
const BOX_WEST_X := -45.0
const BOX_NORTH_Z := 81.3
const WATCH_S := 8

var _lab: TacticsLab


var _native_drive_was := BrainSwitches.native_drive


func teardown() -> void:
	Traffic.set_off("backout", Traffic.DEFAULT_OFF.has("backout"))
	BrainSwitches.native_drive = _native_drive_was
	ManoeuvreCensus.trace_unit = ""
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


func _run(arm: String) -> Dictionary:
	Traffic.set_off("backout", arm == "off")
	if OS.get_environment("NOSED_GDSCRIPT") == "on":
		BrainSwitches.native_drive = false  # round 45: a dev read of a GDScript change before native's twin follows it
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
	assert_true(gangs != null, "the gangs table loads")
	var element := _lab.elements.form(SQUAD.keys(), "Guns", gangs)
	element.assign({"verb": "move", "to": CLICK, "drills": false})
	var nose0 := -rig.global_basis.z
	var first_reverse := -1
	var first_forward := -1
	var cleared := -1
	var crept := 0.0
	for i in WATCH_S * SimClock.TICK_RATE:
		await _lab.step()
		var along := rig.real_velocity.dot(-rig.global_basis.z)
		if first_reverse < 0 and along < -0.5:
			first_reverse = i + 1
		if first_forward < 0 and along > 0.5:
			first_forward = i + 1
		if first_reverse < 0:
			crept = maxf(crept, (rig.global_position - SPAWN).dot(nose0))
		if rig.global_position.x < BOX_WEST_X and rig.global_position.z < BOX_NORTH_Z:
			cleared = i + 1
			break
	var out := {"first_reverse": first_reverse, "first_forward": first_forward, "cleared": cleared, "crept_m": snappedf(crept, 0.01),
			"looks": int(Movement.route_arms().get("backout_looks", 0)), "kturns": int(Movement.route_arms().get("kturns", 0)),
			"pos": rig.global_position}
	print("BACKOUT_STAGE %s %s" % [arm, str(out)])
	_lab.dispose()
	_lab = null
	return out


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("backout"), "M2 is opt-in until Bar S v3")
	assert_true(Traffic.off("backout") or OS.get_cmdline_user_args().has("--traffic-on=backout"), "off unless asked")


func test_a_war_rig_nose_on_to_the_container_backs_out_first() -> void:
	var off := await _run("off")
	var on := await _run("on")
	assert_eq(int(off["looks"]), 0, "OFF: no departure look (today's drive)")
	assert_true(int(on["looks"]) >= 1, "ON: the k-turn decision was made against the departure point (%d looks)" % on["looks"])
	assert_true(int(on["first_reverse"]) > 0 and int(on["first_reverse"]) <= SimClock.TICK_RATE,
			"ON: the rig is backing within a second of the order (tick %d)" % on["first_reverse"])
	assert_true(int(on["first_forward"]) < 0 or int(on["first_reverse"]) < int(on["first_forward"]),
			"ON: the back-up comes before any forward drive (reverse t%d, forward t%d)" % [on["first_reverse"], on["first_forward"]])
	assert_true(float(on["crept_m"]) < 0.3, "ON: it does not creep into the gap first (%.2f m v OFF %.2f m)" % [on["crept_m"], off["crept_m"]])
	assert_true(int(on["cleared"]) > 0, "ON: it is past the box within %d s (at %s)" % [WATCH_S, str(on["pos"])])
	if int(off["cleared"]) > 0:
		assert_true(int(on["cleared"]) + SimClock.TICK_RATE / 2 <= int(off["cleared"]),
				"ON: past the box at least half a second sooner than OFF (t%d v t%d)" % [on["cleared"], off["cleared"]])


## Round 45 (M2 (b), `stalled`): a departure leg pressed against a HULL its look could not see ends as "stalled" within a second,
## not at the leg's timeout (1.5 s a metre + 1 s). Staged: his start ON; the moment Guns_2's departure leg starts reversing, a parked
## War Rig is placed 1 m behind its tail (a Tank, not a wall: a wall ends a leg through today's lead_hit rule; a hull is no WallContact,
## so dev read 0's pose 10 stood 5 s against a squadmate). Expect: backout_stalls >= 1 and the rig moving its own way again within
## BACKOUT_STALL_TICKS + a second of the parked rig's arrival (no 4 s stand).
func test_a_departure_leg_pressed_on_a_hull_that_arrived_behind_it_ends_stalled() -> void:
	Traffic.set_off("backout", false)
	if OS.get_environment("NOSED_GDSCRIPT") == "on":
		BrainSwitches.native_drive = false
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
	var mover := Movement.of(rig)
	var placed := -1
	var stalled_at := -1
	var moving_again := -1
	var stall_ticks_max := 0
	for i in WATCH_S * SimClock.TICK_RATE:
		if placed < 0 and mover._backout_leg and mover._kturn_left_m > 0.0 and mover._kturn_gear < 0:
			placed = i + 1
			var back := Vector3(rig.global_basis.z.x, 0.0, rig.global_basis.z.z).normalized()
			var half := float(Movement.hull_box(rig.unit_id)[2]) * 0.5
			# The parked rig's nose 1.0 m off Guns_2's tail: its centre a hull's length + 1 m behind Guns_2's centre.
			_lab.unit(Match.Team.GREEN, "Green_Parked", rig.global_position + back * (half * 2.0 + 1.0), rig.rotation.y, "gang_tank")
		await _lab.step()
		stall_ticks_max = maxi(stall_ticks_max, mover._backout_stall_ticks)
		if OS.get_environment("NOSED_TRACE") == "on" and placed > 0 and i + 1 < placed + 150:
			var nose := Vector3(-rig.global_basis.z.x, 0.0, -rig.global_basis.z.z).normalized()
			print("STALL_TICK %d at (%.2f, %.2f) speed %.2f real_along %.2f real %.2f gear %d left %.2f bo_leg %s plan %s stall_ticks %d phase %s touch %s stalls %d" % [
					i + 1, rig.global_position.x, rig.global_position.z, rig.speed(), rig.real_velocity.dot(nose), rig.real_velocity.length(),
					mover._kturn_gear, mover._kturn_left_m, str(mover._backout_leg), mover._kturn_plan_kind, mover._backout_stall_ticks, mover.phase,
					str(mover.contact.touching), int(Movement.route_arms().get("backout_stalls", 0))])
		if placed > 0 and stalled_at < 0 and int(Movement.route_arms().get("backout_stalls", 0)) >= 1:
			stalled_at = i + 1
		if stalled_at > 0 and moving_again < 0 and rig.real_velocity.length() > 0.5:
			moving_again = i + 1
	var stalls := int(Movement.route_arms().get("backout_stalls", 0))
	print("BACKOUT_STALL_STAGE placed t%d stalled t%d moving_again t%d stalls %d max_stall_ticks %d looks %d" % [
			placed, stalled_at, moving_again, stalls, stall_ticks_max, int(Movement.route_arms().get("backout_looks", 0))])
	assert_true(placed > 0, "Guns_2's departure leg started reversing (the parked rig was placed at t%d)" % placed)
	assert_true(stalls >= 1, "the leg pressed on the parked rig ended as stalled (%d stalls, max %d stall ticks)" % [stalls, stall_ticks_max])
	if stalled_at > 0:
		assert_true(stalled_at - placed <= 3 * SimClock.TICK_RATE,
				"it ended within 3 s of the hull's arrival, not at the leg's timeout (placed t%d, stalled t%d)" % [placed, stalled_at])
	_lab.dispose()
	_lab = null
