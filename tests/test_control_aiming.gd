extends TestCase
## Round 41 (C41.4, R41.1; camera's K2): RtsControls.is_aiming(), the read-only "the player is aiming" the camera holds
## the ground still on. True while an order is armed, a press or drag of either button is pending, or the cursor rests on
## a unit a click would pick; false otherwise. It reads state only: the pick is today's pick_unit.


func test_idle_controls_are_not_aiming() -> void:
	var controls := RtsControls.new()
	assert_true(not controls.is_aiming(), "no match, no camera, nothing pressed: not aiming")
	controls.free()


func test_an_armed_order_and_every_pending_press_is_aiming() -> void:
	var controls := RtsControls.new()
	controls.mode = "attack_move"
	assert_true(controls.is_aiming(), "an armed order")
	controls.mode = ""
	controls._press_at = Vector2(100, 100)
	assert_true(controls.is_aiming(), "a left press (a box) pending")
	controls._press_at = null
	controls._right_press_at = Vector2(100, 100)
	assert_true(controls.is_aiming(), "a right press (a drawn facing) pending")
	controls._right_press_at = null
	controls._armed_press_at = Vector2(100, 100)
	assert_true(controls.is_aiming(), "an armed order's press pending")
	controls._armed_press_at = null
	controls._attack_press = {"target": "Rust_1"}
	assert_true(controls.is_aiming(), "a press on an enemy pending")
	controls._attack_press = {}
	assert_true(not controls.is_aiming(), "all released: not aiming")
	controls.free()


func test_the_cursor_on_a_unit_is_aiming_and_on_open_ground_is_not() -> void:
	var lab := TacticsLab.create(self, 1)
	var ours := lab.unit(Match.Team.GREEN, "Green_A_1", Vector3(0, 0, 0), 0.0)
	await lab.start()
	var camera := Camera3D.new()
	add_to_tree(camera)
	camera.global_position = Vector3(0, 60, 40)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var controls := RtsControls.new()
	controls.game_match = lab.game_match
	controls.orders = lab.orders
	controls.camera = camera
	controls.team = Match.Team.GREEN
	controls.reveal_all = true
	add_to_tree(controls)
	await tree.process_frame
	controls._hover_at = camera.unproject_position(Shown.at(ours))
	assert_true(controls.pick_unit(controls._hover_at) == ours, "setup: a click there picks the unit")
	assert_true(controls.is_aiming(), "the cursor on his unit")
	controls._hover_at = camera.unproject_position(Vector3(40, 0, 0))
	assert_true(controls.pick_unit(controls._hover_at) == null, "setup: nothing to pick there")
	assert_true(not controls.is_aiming(), "the cursor on open ground")
