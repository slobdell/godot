extends TestCase
## Round 41, manoeuvre Q4 (R41.5; `--traffic-on=holdlane`, Traffic.DEFAULT_OFF until judged): a crew stalled behind a FRIEND that
## will clear by itself (Q2's wait kinds, the crosser included) asks nobody to give way, gives way to nobody and does not back off:
## it holds its lane and slows until the friend has moved. Parked, stalled and head-on friends keep today's asks, yields and
## unstick. Forward is -Z; yard_open is flat and empty.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("holdlane", Traffic.DEFAULT_OFF.has("holdlane"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## My tracked tank at the origin ordered 70 m north; a friend at `at` facing `yaw` with `order`.
func _stage(at: Vector3, yaw: float, order: Dictionary, friend_unit := "tank") -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3.ZERO, 0.0, "tank")
	var friend := _lab.gun(Match.Team.GREEN, "Green_Friend", at, yaw, friend_unit)
	await _lab.start()
	if not order.is_empty():
		Movement.of(friend).ctl.set_orders(order, {"type": "fire_at_will"})
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 0.0, "z": -70.0}, {"type": "fire_at_will"})
	return [me, friend]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("holdlane"), "Q4 is opt-in until judged")


## The patience read: a friend crossing or turning is one to be patient with; parked or head-on is not.
func test_patient_reads_a_friend_that_will_clear() -> void:
	var staged: Array = await _stage(Vector3(-8.0, 0.0, -8.0), -PI / 2.0, {"type": "move_to", "x": 60.0, "z": -8.0})
	var me := Movement.of(staged[0])
	var north := Vector2(0.0, -1.0)
	for i in 2 * SimClock.TICK_RATE:
		await _lab.step()
	assert_true(me._holdlane_patient(staged[1], north), "a friend driving across my lane will clear it: patient")
	_lab.dispose()
	staged = await _stage(Vector3(0.0, 0.0, -9.0), PI / 2.0, {})
	me = Movement.of(staged[0])
	for i in 6:
		await _lab.step()
	assert_true(not me._holdlane_patient(staged[1], north), "a parked friend: today's ask and yield")
	_lab.dispose()
	staged = await _stage(Vector3(0.0, 0.0, -30.0), PI, {"type": "move_to", "x": 0.0, "z": 40.0})
	me = Movement.of(staged[0])
	for i in 2 * SimClock.TICK_RATE:
		await _lab.step()
	assert_true(not me._holdlane_patient(staged[1], north), "a friend coming at me: today's rules")


## Live: a slow friend crawls across my lane 7 m ahead for 8 s. ON, my crew neither yields to it nor backs off while it crosses.
func test_on_holds_the_lane_behind_a_crossing_friend() -> void:
	var read := {}
	for arm: String in ["off", "on"]:
		Traffic.set_off("holdlane", arm == "off")
		var staged: Array = await _stage(Vector3(-6.0, 0.0, -7.0), -PI / 2.0, {"type": "move_to", "x": 60.0, "z": -7.0, "speed": 0.2})
		var me := staged[0] as Tank
		var mover := Movement.of(me)
		var yields := Movement.yields_started
		var fires := Movement.unstick_fires
		var yielded := 0
		var reversed := 0
		var skips := Movement.holdlane_skips
		var holds := Movement.holdlane_holds
		for i in 8 * SimClock.TICK_RATE:
			await _lab.step()
			if mover.yield_to != "":
				yielded += 1
			if Vector2(me.real_velocity.x, me.real_velocity.z).dot(Vector2(-me.global_basis.z.x, -me.global_basis.z.z)) < -0.2:
				reversed += 1
		read[arm] = {"yield_ticks": yielded, "reversed_ticks": reversed, "yields": Movement.yields_started - yields,
				"fires": Movement.unstick_fires - fires, "skips": Movement.holdlane_skips - skips, "holds": Movement.holdlane_holds - holds,
				"north": -me.global_position.z, "lateral": absf(me.global_position.x)}
		print("MEASURE holdlane %s: %s" % [arm, read[arm]])
		_lab.dispose()
		_lab = null
	assert_eq(int(read["on"]["yields"]), 0, "ON: no give-way begun while the friend crosses")
	assert_eq(int(read["on"]["fires"]), 0, "ON: no blind back-off")
	assert_true(int(read["on"]["skips"]) + int(read["on"]["holds"]) > 0, "ON: the rule acted (an ask skipped or a back-off held)")
	assert_true(float(read["on"]["north"]) > 15.0, "ON: and the crew went on once the friend was past")


## Until twinned in C++, ON runs the GDScript drive and the GDScript ask; OFF leaves both as they were.
func test_on_runs_the_gdscript_drive_and_ask_until_twinned() -> void:
	var drive := BrainSwitches.native_drive
	var yield_sw := BrainSwitches.native_yield
	Traffic.set_off("holdlane", false)
	assert_true(not BrainSwitches.native_drive and not BrainSwitches.native_yield, "ON: GDScript drive and ask")
	Traffic.set_off("holdlane", true)
	assert_eq(BrainSwitches.native_drive, drive, "OFF: native_drive back")
	assert_eq(BrainSwitches.native_yield, yield_sw, "OFF: native_yield back")
