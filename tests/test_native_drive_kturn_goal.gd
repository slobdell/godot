extends DriveTwinCase
## Round 43 (native N3, the twin manoeuvre asked for; C43.4): with `--traffic-on=kturngoal` (Movement._kturn_goal_moved_out,
## manoeuvre S3) the native drive is the live GDScript drive through k-turns whose goal jumps ahead of the nose mid-leg
## (tests/native/drive_twin_case.gd `goal_jump`): the backing leg's goal-moved end (a callback into _planned_reverse) and the
## goal notes the cheap look writes natively.


func test_the_goal_moved_end_is_the_live_gdscript() -> void:
	if FreshStage.parent(self, "test_the_goal_moved_end_is_the_live_gdscript"):  # its own process (tests/native/fresh_stage.gd)
		return
	var was := Traffic.off("kturngoal")
	Traffic.set_off("kturngoal", false)
	var moved_before := Movement.kturn_goal_moved
	await _k_turn_case(false, 0, 2, true, true)
	var moved := Movement.kturn_goal_moved - moved_before
	Traffic.set_off("kturngoal", was)
	print("native drive kturngoal: %d goal-moved ends" % moved)
	if not NativeExpect.absent(self):
		assert_true(moved >= 1, "the goal-moved end was exercised (%d)" % moved)
