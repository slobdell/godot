extends TestCase
## Round 41, manoeuvre Q2 (his rule, C41.2; `--traffic-on=wait`, Traffic.DEFAULT_OFF until its bar is judged): a crew ORCA would
## steer round a FRIEND that will clear its lane by itself soon WAITS instead: it keeps its route's steering, drives at a
## following speed behind the friend (slows, stops) and does not ask it to give way; after WAIT_CAP_S on one friend it hands back
## to today's avoidance. "Will clear soon": the friend is moving and not head-on (crossing my lane, or a leader going my way),
## or it is slow, under way and still turning toward where it is going. Parked, stalled and head-on friends are passed as today.
## Forward is -Z (trip-up 2); yard_open is flat and empty.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("wait", Traffic.DEFAULT_OFF.has("wait"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## My crew: a tracked tank at the origin facing north (-z), ordered 70 m north. A friend of `friend_unit` placed at `at`, facing
## `yaw`, given `order` (a stop = parked). Returns [me, friend].
func _stage(at: Vector3, yaw: float, order: Dictionary, friend_unit := "tank") -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3.ZERO, 0.0, "tank")
	var friend := _lab.gun(Match.Team.GREEN, "Green_Friend", at, yaw, friend_unit)
	await _lab.start()
	if not order.is_empty():
		Movement.of(friend).ctl.set_orders(order, {"type": "fire_at_will"})
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 0.0, "z": -70.0}, {"type": "fire_at_will"})
	return [me, friend]


func _steps(n: int) -> void:
	for i in n:
		await _lab.step()


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("wait"), "Q2 is opt-in until judged")


## The kind test, on staged friends: a friend driving across my lane is waited on ("moving"); one parked is not; one coming head-on
## is not; a tracked friend still pivoting toward its own way (nose 90 deg off it, slow) is ("turning").
func test_wait_kind_reads_what_the_friend_is_doing() -> void:
	var staged: Array = await _stage(Vector3(-8.0, 0.0, -8.0), -PI / 2.0, {"type": "move_to", "x": 60.0, "z": -8.0})
	var me := Movement.of(staged[0])
	var north := Vector2(0.0, -1.0)
	await _steps(2 * SimClock.TICK_RATE)
	print("MEASURE wait kind crossing: friend v %s" % (staged[1] as Tank).real_velocity)
	assert_eq(me._wait_kind(staged[1], north), "moving", "a friend driving east across my lane will clear it")
	_lab.dispose()
	staged = await _stage(Vector3(0.0, 0.0, -9.0), PI / 2.0, {})
	me = Movement.of(staged[0])
	await _steps(6)
	assert_eq(me._wait_kind(staged[1], north), "", "a parked friend is passed as today")
	_lab.dispose()
	staged = await _stage(Vector3(0.0, 0.0, -30.0), PI, {"type": "move_to", "x": 0.0, "z": 40.0})
	me = Movement.of(staged[0])
	await _steps(2 * SimClock.TICK_RATE)
	print("MEASURE wait kind head-on: friend v %s" % (staged[1] as Tank).real_velocity)
	assert_eq(me._wait_kind(staged[1], north), "", "a friend coming at me is not waited on")
	_lab.dispose()
	# Facing east, ordered north: a tracked hull pivots first (slow, nose 90 deg off its way).
	staged = await _stage(Vector3(0.0, 0.0, -9.0), -PI / 2.0, {"type": "move_to", "x": 0.0, "z": -70.0})
	me = Movement.of(staged[0])
	await _steps(3)
	var friend := staged[1] as Tank
	print("MEASURE wait kind turning: friend v %s nose %s" % [friend.real_velocity, -friend.global_basis.z])
	assert_eq(me._wait_kind(friend, north), "turning", "a slow friend still turning toward its own way will clear mine")
	# The chain: a friend ahead that is itself waiting for one that will clear is waited on; one waiting for ME is not (a cycle).
	var fm := Movement.of(friend)
	fm._wait_for = "Green_Someone"
	fm._wait_since = Engine.get_physics_frames()
	assert_eq(me._wait_kind(friend, north), "waiting", "the car ahead in the jam, itself waiting, will move when its friend does")
	fm._wait_for = "Green_Me"
	assert_eq(me._wait_kind(friend, north), "", "but not when it is waiting for me")
	fm._wait_for = ""


## Live: a friend crosses my lane 9 m ahead. OFF, ORCA steers me round it; ON, I hold my line and slow, and go on once it is past.
func test_on_holds_the_line_for_a_crossing_friend() -> void:
	var lateral := {}
	var ahead := {}
	for arm: String in ["off", "on"]:
		Traffic.set_off("wait", arm == "off")
		var staged: Array = await _stage(Vector3(-9.0, 0.0, -9.0), -PI / 2.0, {"type": "move_to", "x": 60.0, "z": -9.0})
		var me := staged[0] as Tank
		var queued := Movement.wait_queued
		var worst := 0.0
		for i in 8 * SimClock.TICK_RATE:
			await _lab.step()
			worst = maxf(worst, absf(me.global_position.x))
		lateral[arm] = worst
		ahead[arm] = -me.global_position.z
		print("MEASURE wait crossing %s: lateral %.2f m, north %.1f m, waited %d crew-ticks, waits %d, timeouts %d" % [arm, worst,
				-me.global_position.z, Movement.wait_queued - queued, Movement.waits, Movement.wait_timeouts])
		if arm == "on":
			assert_true(Movement.wait_queued > queued, "ON: the crew waited")
		_lab.dispose()
		_lab = null
	assert_true(float(lateral["on"]) <= float(lateral["off"]) + 0.05, "ON never leaves its line more than OFF does")
	assert_true(float(lateral["on"]) < 1.0, "ON holds its line (under 1 m off it)")
	assert_true(float(ahead["on"]) > 20.0, "and goes on once the friend is past (more than 20 m north in 8 s)")


## Live: a leader crawling up my lane going my way never clears it. ON, I wait WAIT_CAP_S behind it, then today's avoidance passes
## it as OFF does from the start (the leader sits 1 m left of my line, so ORCA has a side to pass on).
func test_the_wait_times_out_and_hands_back_to_avoidance() -> void:
	var passed := {}
	for arm: String in ["off", "on"]:
		Traffic.set_off("wait", arm == "off")
		var staged: Array = await _stage(Vector3(-1.0, 0.0, -8.0), 0.0, {"type": "move_to", "x": -1.0, "z": -70.0, "speed": 0.2})
		var me := staged[0] as Tank
		var leader := staged[1] as Tank
		var timeouts := Movement.wait_timeouts
		var passed_at := -1.0
		for i in 16 * SimClock.TICK_RATE:
			await _lab.step()
			if passed_at < 0.0 and me.global_position.z < leader.global_position.z:
				passed_at = i / float(SimClock.TICK_RATE)
		passed[arm] = passed_at
		print("MEASURE wait timeout %s: timeouts %d, longest %s, passed at %.1f s, me %s leader %s" % [arm, Movement.wait_timeouts - timeouts,
				Movement.wait_longest, passed_at, me.global_position, leader.global_position])
		if arm == "on":
			assert_true(Movement.wait_timeouts > timeouts, "the wait timed out on the crawler")
		_lab.dispose()
		_lab = null
	assert_true(float(passed["off"]) > 0.0, "OFF passes the crawler within 16 s (the stage's premise)")
	assert_true(float(passed["on"]) > 0.0, "ON passes it too, after the cap")
	assert_true(float(passed["on"]) >= Movement.WAIT_CAP_S, "no pass before the cap")
	assert_true(float(passed["on"]) <= float(passed["off"]) + Movement.WAIT_CAP_S + 2.0, "and not much later than the cap's worth")


## Until twinned in C++, ON runs the GDScript drive (as M3 and F1); OFF leaves native_drive as it was.
func test_on_runs_the_gdscript_drive_until_twinned() -> void:
	var before := BrainSwitches.native_drive
	Traffic.set_off("wait", false)
	assert_true(not BrainSwitches.native_drive, "ON: the GDScript drive")
	Traffic.set_off("wait", true)
	assert_eq(BrainSwitches.native_drive, before, "OFF: native_drive back as it was")
