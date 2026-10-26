extends TestCase
## Round 41, manoeuvre Q5 (R41.8; `--traffic-on=nopush`, Traffic.DEFAULT_OFF until judged): a crew whose hull touches a FRIEND
## ahead that is not pulling away eases off (forward throttle 0 while the contact lasts, and half a second after) instead of
## pushing it. Speed only: ORCA's steer point, asks and give-ways as today. The reversing report: 59 % of a jammed crew's
## backward motion was being shoved by a friend. Forward -Z; yard_open.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("nopush", Traffic.DEFAULT_OFF.has("nopush"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## My tracked tank at the origin ordered 70 m north; a parked friend `gap` m ahead facing north (a column's head that stopped).
func _stage(gap: float) -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var me := _lab.gun(Match.Team.GREEN, "Green_Me", Vector3.ZERO, 0.0, "tank")
	var friend := _lab.gun(Match.Team.GREEN, "Green_Friend", Vector3(0.0, 0.0, -gap), 0.0, "tank")
	await _lab.start()
	Movement.of(me).ctl.set_orders({"type": "move_to", "x": 0.0, "z": -70.0}, {"type": "fire_at_will"})
	return [me, friend]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("nopush"), "Q5 is opt-in until judged")


## Live: driving into a parked friend's tail. OFF, the crew presses (throttle on while touching) and shoves it; ON, the throttle is
## off while touching and the friend is shoved less.
func test_on_eases_off_against_a_parked_friend() -> void:
	var read := {}
	for arm: String in ["off", "on"]:
		Traffic.set_off("nopush", arm == "off")
		var staged: Array = await _stage(9.0)
		var me := staged[0] as Tank
		var friend := staged[1] as Tank
		var start := friend.global_position
		var touch_ticks := 0
		var pressing_ticks := 0
		var episodes := Movement.nopush_episodes
		var ticks := Movement.nopush_ticks
		for i in 6 * SimClock.TICK_RATE:
			await _lab.step()
			var touching := false
			for k in me.get_slide_collision_count():
				if me.get_slide_collision(k).get_collider() == friend:
					touching = true
			if touching:
				touch_ticks += 1
				if me.command.throttle > 0.3:
					pressing_ticks += 1
		read[arm] = {"touch_ticks": touch_ticks, "pressing_ticks": pressing_ticks, "shoved_m": snappedf(Vector2(friend.global_position.x - start.x,
				friend.global_position.z - start.z).length(), 0.01), "nopush_ticks": Movement.nopush_ticks - ticks,
				"nopush_episodes": Movement.nopush_episodes - episodes, "me_z": snappedf(me.global_position.z, 0.1)}
		print("MEASURE nopush %s: %s" % [arm, read[arm]])
		_lab.dispose()
		_lab = null
	assert_true(int(read["off"]["touch_ticks"]) > 0, "the stage: the crew reaches the friend's tail")
	assert_true(int(read["on"]["nopush_ticks"]) > 0, "ON: the rule acted")
	assert_true(int(read["on"]["pressing_ticks"]) <= int(read["off"]["pressing_ticks"]) / 4, "ON: no pressing while touching (a quarter of OFF's at most)")
	assert_true(float(read["on"]["shoved_m"]) <= float(read["off"]["shoved_m"]), "ON: the friend is shoved no farther than OFF")


## Until twinned in C++, ON runs the GDScript drive; OFF leaves native_drive as it was.
func test_on_runs_the_gdscript_drive_until_twinned() -> void:
	var before := BrainSwitches.native_drive
	Traffic.set_off("nopush", false)
	assert_true(not BrainSwitches.native_drive, "ON: the GDScript drive")
	Traffic.set_off("nopush", true)
	assert_eq(BrainSwitches.native_drive, before, "OFF: native_drive back as it was")
