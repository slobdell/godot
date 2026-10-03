extends TestCase
## Feel stretch: the slow-motion kill-cam when the last unit of a match dies. Presentation only: it starts after the rules
## have finished the match, never slows a networked match, focuses the camera on the final kill, and always gives time
## back.


func _world() -> Array:
	var fx: FxWorld = add_to_tree(FxWorld.new())
	var game_match: Match = add_to_tree(preload("res://game/match/match.tscn").instantiate())
	game_match.elimination = true
	fx.link.attach(game_match)
	return [fx, game_match]


func _final_kill(fx: FxWorld, at := Vector3(12, 1, -30)) -> void:
	fx.weapons.fired(K2Events.fired_event(1, "", "cannon", Weapons.profile("cannon"), Vector3.ZERO, Vector3.FORWARD, 77))
	fx.weapons.impact(K2Events.impact_event(2, 77, at, Vector3.BACK, "LastOne", true))


func test_the_final_kill_slows_time_then_gives_it_back() -> void:
	var setup := _world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	_final_kill(fx)
	game_match.finished.emit({"reason": "elimination", "winner": "Green"})
	assert_true(fx.kill_cam.active, "the last kill of an elimination starts the kill-cam")
	assert_true(Engine.time_scale < 0.5, "time slows (%.2f)" % Engine.time_scale)
	assert_near(fx.kill_cam.focus.x, 12.0, 0.01, "on the final kill")
	fx.kill_cam.advance(KillCam.HOLD_SECONDS + KillCam.RAMP_SECONDS + 0.1)
	assert_true(not fx.kill_cam.active, "then it ends")
	assert_eq(Engine.time_scale, 1.0, "and time runs at full speed again")
	assert_eq(AudioServer.playback_speed_scale, 1.0, "and so does the sound")


func test_no_kill_cam_for_a_networked_match_or_without_a_final_kill() -> void:
	var setup := _world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	game_match.finished.emit({"reason": "time_limit", "winner": "draw"})
	assert_true(not fx.kill_cam.active, "a match that ends on time with no kill just ends")
	game_match.networked = true
	_final_kill(fx)
	game_match.finished.emit({"reason": "elimination", "winner": "Green"})
	assert_true(not fx.kill_cam.active, "a networked match is never slowed (everyone shares its clock)")
	assert_eq(Engine.time_scale, 1.0, "time untouched")


func test_leaving_mid_kill_cam_restores_time() -> void:
	var setup := _world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	_final_kill(fx)
	game_match.finished.emit({"reason": "elimination", "winner": "Rust"})
	fx.free()
	assert_eq(Engine.time_scale, 1.0, "freeing the effects mid-slow-motion gives time back")


## Round 17 (sim F4): the slow motion is simulation input (Godot scales every physics step by Engine.time_scale and the
## simulation runs on after `finished`), so its schedule must be a function of simulation ticks. Counted in wall time,
## the same windowed seed ran a different number of slowed ticks per run: the Sumps "fork at 601-630".
func test_the_slow_motion_schedule_counts_simulation_ticks_not_wall_time() -> void:
	var setup := _world()
	var fx: FxWorld = setup[0]
	var game_match: Match = setup[1]
	_final_kill(fx)
	game_match.finished.emit({"reason": "elimination", "winner": "Green"})
	var cam := fx.kill_cam
	var scales: Array[float] = []
	for i in KillCam.HOLD_TICKS + KillCam.RAMP_TICKS:
		OS.delay_msec(1 if i % 7 else 15)  # uneven wall time between ticks must change nothing
		cam.propagate_notification(Node.NOTIFICATION_PROCESS)  # a rendered frame moves nothing
		scales.append(Engine.time_scale)
		cam._physics_process(SimClock.TICK_SECONDS)
	assert_eq(scales[0], KillCam.SLOW, "full slow motion on the first tick")
	assert_eq(scales[KillCam.HOLD_TICKS], KillCam.SLOW, "still full slow motion through the hold (%d ticks)" % KillCam.HOLD_TICKS)
	var mid := KillCam.HOLD_TICKS + KillCam.RAMP_TICKS / 2
	assert_near(scales[mid], lerpf(KillCam.SLOW, 1.0, 0.5), 1e-6, "halfway up the ramp at tick %d" % mid)
	assert_true(scales[-1] < 1.0, "the last ramp tick is still below full speed")
	assert_true(not cam.active, "over after exactly hold + ramp ticks")
	assert_eq(Engine.time_scale, 1.0, "time given back")


func test_the_tick_schedule_matches_its_seconds() -> void:
	assert_eq(KillCam.HOLD_TICKS, SimClock.ticks(KillCam.HOLD_SECONDS), "HOLD_TICKS is HOLD_SECONDS of ticks")
	assert_eq(KillCam.RAMP_TICKS, SimClock.ticks(KillCam.RAMP_SECONDS), "RAMP_TICKS is RAMP_SECONDS of ticks")
