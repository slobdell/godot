extends TestCase
## Round 47 (orders O4, C47.4). His Sumps game (references/round46/playtest/2026-10-30T15-53-39-sumps.jsonl): Bravo selected at
## frame 601, Charlie (his artillery) at 618, and his screen click went to Charlie; the recording had no row for the input that
## switched it. Every key press or mouse button of his that changes the selection or gives an order is now an `inp` row:
## {"t":"inp","f","k","act","sel_before","sel_after"}, written after the `sel` / `order` rows it caused, on the same frame.

const Fixture := preload("res://tests/support/control_fixture.gd")
const ALPHA := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]
const BRAVO := ["Green_Bravo_1", "Green_Bravo_2"]
const DIR := "user://test_control_inp_row"

var _recorder: MatchRecorder


func teardown() -> void:
	if _recorder != null and _recorder.path != "":
		DirAccess.remove_absolute(_recorder.path)
	_recorder = null
	super.teardown()


func _fixture() -> Fixture:
	var f := Fixture.new(self)
	await f.build()
	f.controls.elements = Elements.install(f.game_match, f.orders)
	f.place("Rust_Alpha_1", Vector3(0.0, 0.0, -150.0))  # out of the fight
	f.controls.groups.save(1, ALPHA.duplicate())
	f.controls.groups.save(2, BRAVO.duplicate())
	_recorder = MatchRecorder.start(f.game_match, f.orders, f.controls, f.controls.elements, DIR, "inp")
	await wait_physics_frames(1)
	return f


func _rows(kind: String) -> Array:
	_recorder._exit_tree()
	var rows: Array = []
	for line in FileAccess.get_file_as_string(_recorder.path).split("\n"):
		if line.strip_edges() != "":
			rows.append(JSON.parse_string(line))
	return rows.filter(func(r: Dictionary) -> bool: return kind == "" or r["t"] == kind)


func _key(keycode: Key, ctrl := false) -> void:
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.ctrl_pressed = ctrl
		event.pressed = pressed
		tree.root.push_input(event)


func test_a_group_key_writes_the_key_the_act_and_both_selections() -> void:
	var f := await _fixture()
	_key(KEY_1)
	await tree.process_frame
	_key(KEY_2)
	await tree.process_frame
	var rows := _rows("inp")
	assert_eq(rows.size(), 2, "one row per key that changed the selection: %s" % [rows])
	if rows.size() < 2:
		return
	assert_eq(String(rows[0]["k"]), "1", "the key")
	assert_eq(String(rows[0]["act"]), "recall_group:1", "what it did")
	assert_eq(rows[0]["sel_before"], [], "nothing selected before")
	assert_eq(rows[0]["sel_after"], ALPHA, "Alpha after")
	assert_eq(String(rows[1]["act"]), "recall_group:2", "the second key")
	assert_eq(rows[1]["sel_before"], ALPHA, "Alpha before the second key")
	assert_eq(rows[1]["sel_after"], BRAVO, "Bravo after it")
	for key in ["t", "f", "k", "act", "sel_before", "sel_after"]:
		assert_true(rows[0].has(key), "C47.4's key %s" % key)
	assert_eq(rows[0].size(), 6, "exactly C47.4's keys")
	assert_true(int(rows[1]["f"]) >= int(rows[0]["f"]), "frames never count down")
	f.controls.selection.clear()


func test_the_inp_row_shares_the_frame_of_the_sel_row_it_caused() -> void:
	var f := await _fixture()
	_key(KEY_2)
	await tree.process_frame
	var rows := _rows("")
	var sel := rows.filter(func(r: Dictionary) -> bool: return r["t"] == "sel" and r["units"] == BRAVO)
	var inp := rows.filter(func(r: Dictionary) -> bool: return r["t"] == "inp")
	assert_eq(sel.size(), 1, "one sel row for Bravo")
	assert_eq(inp.size(), 1, "one inp row")
	if sel.size() == 1 and inp.size() == 1:
		assert_eq(int(inp[0]["f"]), int(sel[0]["frame"]), "the inp row's frame is the sel row's")
		assert_true(rows.find(inp[0]) > rows.find(sel[0]), "written after the sel row it caused")
	f.controls.selection.clear()


func test_an_order_key_writes_a_row_without_a_selection_change() -> void:
	var f := await _fixture()
	f.controls.selection.set_units(ALPHA)
	_key(KEY_S)
	await tree.process_frame
	var rows := _rows("inp")
	assert_eq(rows.size(), 1, "the stop key gave an order: %s" % [rows])
	if rows.size() == 1:
		assert_eq(String(rows[0]["act"]), "order:stop", "named by the order")
		assert_eq(rows[0]["sel_before"], rows[0]["sel_after"], "the selection did not change")


func test_a_key_that_changes_nothing_writes_no_row() -> void:
	var f := await _fixture()
	_key(KEY_C)  # centre the camera: no selection change, no order
	_key(KEY_9)  # an empty group
	await tree.process_frame
	assert_eq(_rows("inp").size(), 0, "no row")
	assert_eq(f.controls.selection.units.size(), 0, "nothing selected")


func test_saving_a_group_writes_a_row_and_a_same_recall_does_not() -> void:
	var f := await _fixture()
	f.controls.selection.set_units(ALPHA + BRAVO)
	_key(KEY_4, true)
	await tree.process_frame
	assert_eq(f.controls.groups.members(4).size(), 5, "group 4 saved")
	_key(KEY_4)
	await tree.process_frame
	var rows := _rows("inp")
	# His Crossing ctrl+4 merge: a save changes neither the selection nor an order, and it is a row; 4 then recalls the same
	# units: no change, no row.
	assert_eq(rows.size(), 1, "one row, the save: %s" % [rows])
	if rows.size() == 1:
		assert_eq(String(rows[0]["act"]), "group_save:4", "named")
		assert_eq(String(rows[0]["k"]), "Ctrl+4", "the key with its modifier")
		assert_eq(rows[0]["sel_before"], rows[0]["sel_after"], "the selection as it was")


func test_the_input_key_names_a_mouse_click() -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	assert_eq(RtsControls.input_key(press), "mouse_left", "a left press")
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_RIGHT
	up.shift_pressed = true
	assert_eq(RtsControls.input_key(up), "shift+mouse_right_up", "a shifted right release")
	assert_eq(RtsControls.input_key(InputEventMouseMotion.new()), "", "motion is no input")
	var held := InputEventKey.new()
	held.keycode = KEY_2
	held.pressed = true
	held.echo = true
	assert_eq(RtsControls.input_key(held), "", "a key repeat is no input")
