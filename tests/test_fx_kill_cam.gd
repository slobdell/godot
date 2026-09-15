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
