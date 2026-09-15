extends TestCase
## Control X2: StarCraft-style selection through Godot's real input pipeline (Viewport.push_input): click a unit,
## drag a box, shift adds or removes, double-click or ctrl-click selects every visible unit of that type, Escape
## clears, enemies can be inspected but not commanded.

const Fixture := preload("res://tests/support/control_fixture.gd")


func _setup() -> Fixture:
	var f := Fixture.new(self)
	await f.build(false)
	return f


func test_click_selects_one_unit_and_clicking_the_ground_keeps_it() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_2"))
	assert_eq(f.controls.selection.units, ["Green_Alpha_2"], "a click selects exactly that unit")
	await f.click(f.screen("Green_Bravo_2"))
	assert_eq(f.controls.selection.units, ["Green_Bravo_2"], "a click on another unit replaces the selection")
	await f.click(f.ground(Vector3(-30, 0, 10)))
	assert_eq(f.controls.selection.units, ["Green_Bravo_2"], "a plain click on empty ground doesn't drop the selection")


func test_box_select_takes_every_friendly_inside() -> void:
	var f := await _setup()
	var left := f.screen("Green_Alpha_2")
	var right := f.screen("Green_Bravo_1")
	await f.drag(left + Vector2(-20, -30), right + Vector2(20, 30))
	assert_eq(f.controls.selection.units, ["Green_Alpha_2", "Green_Alpha_3", "Green_Bravo_1"],
			"the box selects the three units inside it, not the ones outside")
	await f.drag(Vector2(10, 10), Vector2(80, 60))
	assert_eq(f.controls.selection.units, ["Green_Alpha_2", "Green_Alpha_3", "Green_Bravo_1"],
			"a box around nothing keeps the old selection")
	var enemy := f.screen("Rust_Alpha_1")
	await f.drag(enemy + Vector2(-400, -30), enemy + Vector2(400, 200))
	assert_true(not f.controls.selection.units.has("Rust_Alpha_1"), "a box never selects enemies alongside friendlies")


func test_shift_click_adds_and_removes_and_shift_box_adds() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.click(f.screen("Green_Bravo_2"), true)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Bravo_2"], "shift-click adds a unit")
	await f.click(f.screen("Green_Alpha_1"), true)
	assert_eq(f.controls.selection.units, ["Green_Bravo_2"], "shift-click on a selected unit removes it")
	var a3 := f.screen("Green_Alpha_3")
	await f.drag(a3 + Vector2(-15, -25), a3 + Vector2(15, 25), true)
	assert_eq(f.controls.selection.units, ["Green_Alpha_3", "Green_Bravo_2"], "shift-box adds to the selection")


func test_double_click_and_ctrl_click_select_every_visible_unit_of_that_type() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_3"), false, false, true)
	assert_eq(f.controls.selection.units, ["Green_Alpha_3", "Green_Bravo_1"], "double-clicking an IFV selects both IFVs")
	await f.click(f.screen("Green_Alpha_1"), false, true)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1", "Green_Alpha_2"], "ctrl-clicking a tank selects both tanks")
	# Move one tank far off screen: "visible" means on screen.
	f.tank("Green_Alpha_2").global_position = Vector3(100, 0, -100)
	await wait_physics_frames(2)
	await f.click(f.screen("Green_Alpha_1"), false, true)
	assert_eq(f.controls.selection.units, ["Green_Alpha_1"], "units off screen aren't picked up")


func test_escape_clears_and_enemies_are_inspected_not_commanded() -> void:
	var f := await _setup()
	await f.click(f.screen("Green_Alpha_1"))
	await f.key(KEY_ESCAPE)
	assert_eq(f.controls.selection.units, [], "Escape clears the selection")
	await f.click(f.screen("Rust_Alpha_1"))
	assert_eq(f.controls.selection.inspected, "Rust_Alpha_1", "clicking an enemy inspects it")
	assert_eq(f.controls.selection.units, [], "an inspected enemy isn't in the commandable selection")
	await f.right_click(f.ground(Vector3(-30, 0, 10)))
	assert_eq(f.orders.ordered_units(), [], "an inspected enemy can't be ordered around")
	await f.click(f.screen("Green_Alpha_1"))
	assert_eq(f.controls.selection.inspected, "", "selecting a friendly ends the inspection")


func test_selected_units_get_bright_ground_rings() -> void:
	var f := await _setup()
	var markers := SelectionMarkers.new()
	markers.game_match = f.game_match
	markers.selection = f.controls.selection
	markers.reveal_all = true
	add_to_tree(markers)
	await f.click(f.screen("Green_Alpha_2"))
	markers.refresh()
	var state := markers.state()
	assert_eq(state["Green_Alpha_2"]["kind"], "selected", "the selected unit's ring is bright")
	assert_eq(state["Green_Alpha_1"]["kind"], "friendly", "other friendlies keep a faint ring")
	assert_eq(state["Rust_Alpha_1"]["kind"], "enemy", "enemies in sight keep their dashed ring")
	await f.click(f.screen("Rust_Alpha_1"))
	markers.refresh()
	assert_eq(markers.state()["Rust_Alpha_1"]["kind"], "inspected", "an inspected enemy's ring stands out")


func test_dead_units_drop_out_of_the_selection() -> void:
	var f := await _setup()
	await f.drag(f.screen("Green_Alpha_1") + Vector2(-20, -30), f.screen("Green_Alpha_2") + Vector2(20, 30))
	assert_eq(f.controls.selection.units.size(), 2, "setup: two selected")
	f.tank("Green_Alpha_1").apply_damage(100000)
	await tree.process_frame
	await tree.process_frame
	assert_eq(f.controls.selection.units, ["Green_Alpha_2"], "a destroyed unit leaves the selection")
