extends TestCase
## Round 18 (picker): the Formation button becomes a picker he can see. P1: one formation list and one card for the
## play view, the tactical map and G (FormationCatalog).


func test_every_formation_a_player_can_name_has_a_card() -> void:
	for id: String in Formations.NAMES:
		assert_true(FormationCatalog.ORDER.has(id), "%s (in the geometry a player can name) is in the picker" % id)
	for id: String in FormationCatalog.shapes():
		assert_true(TacticsFormation.NAMES.has(id), "%s has real geometry" % id)
		assert_true(Formations.NAMES.has(id), "%s is a shape a player can order" % id)
	for id: String in FormationCatalog.ORDER:
		var card := FormationCatalog.card(id)
		assert_eq(card.get("id", ""), id, "%s has a card" % id)
		assert_true(String(card["name"]) != "" and String(card["tagline"]) != "", "%s: a name and a tagline" % id)
		assert_true(String(card["line"]).length() > 20, "%s: a one-line description that says something" % id)
	assert_eq(FormationCatalog.ORDER[0], UnitCommand.AUTO, "AUTO is the first card")
	assert_eq(FormationCatalog.ORDER.size(), Formations.NAMES.size() + 1, "every shape once, plus AUTO")


func test_the_two_pickers_list_the_same_set_and_g_cycles_a_subset_in_order() -> void:
	assert_eq(TacticalMap.PICKER_FORMATIONS, FormationCatalog.shapes(), "the tactical map's picker is the same list")
	assert_eq(RtsControls.FORMATION_CYCLE, FormationCatalog.CYCLE, "G cycles the catalog's cycle")
	var last := -1
	for id: String in FormationCatalog.CYCLE:
		var at := FormationCatalog.ORDER.find(id)
		assert_true(at > last, "%s is in the list, after the cycle's previous step" % id)
		last = at
	for id: String in Formations.NAMES:
		assert_eq(CommandIcons.FORMATION_INFO.get(id), FormationCatalog.INFO[id], "%s: one description, not two" % id)


func test_g_from_a_shape_outside_the_cycle_goes_on_round() -> void:
	assert_eq(FormationCatalog.next_in_cycle(UnitCommand.AUTO), "wedge", "AUTO then wedge")
	assert_eq(FormationCatalog.next_in_cycle("vee"), UnitCommand.AUTO, "the last step wraps to AUTO")
	assert_eq(FormationCatalog.next_in_cycle("coil"), UnitCommand.AUTO, "coil (panel only) steps on round to AUTO")
	assert_eq(FormationCatalog.next_in_cycle("echelon_left"), UnitCommand.AUTO, "so does an echelon")
	assert_eq(FormationCatalog.next_in_cycle("nonsense"), UnitCommand.AUTO, "an unknown id goes back to AUTO")


# ---- P2: the panel ------------------------------------------------------------------------------------------------

const Fixture := preload("res://tests/support/control_fixture.gd")
const SQUAD := ["Green_Alpha_1", "Green_Alpha_2", "Green_Alpha_3"]


func _setup() -> Array:
	var f := Fixture.new(self)
	await f.build(false)
	var panel := SelectionPanel.new()
	panel.name = "SelectionPanel"
	panel.controls = f.controls
	f.controls.add_child(panel)
	await tree.process_frame
	await f.select(SQUAD)
	await tree.process_frame
	panel.dismiss_intro()
	return [f, panel, panel.picker]


func _seconds(s: float) -> void:
	await tree.create_timer(s, true, false, true).timeout


func _button_center(picker: FormationPicker) -> Vector2:
	return picker.button_rect().get_center()


func _card_center(picker: FormationPicker, id: String) -> Vector2:
	return picker.get_global_transform() * picker.card_rect(id).get_center()


func _open_by_hover(f: Fixture, picker: FormationPicker) -> void:
	f.motion(_button_center(picker), false, 0)
	await _seconds(FormationPicker.OPEN_DELAY_S + 0.15)


func test_resting_on_the_button_opens_every_formation_and_crossing_it_does_not() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	assert_true(not picker.is_open and not picker.is_processing(), "closed and idle before anything happens")
	# Crossing the button on the way somewhere else: no flash.
	f.motion(_button_center(picker), false, 0)
	await tree.process_frame
	f.motion(f.ground(Vector3(-15, 0, 15)), false, 0)
	await _seconds(FormationPicker.OPEN_DELAY_S + 0.15)
	assert_true(not picker.is_open, "a mouse crossing the button does not open the panel")
	assert_true(not picker.is_processing(), "and nothing ticks once it has gone")
	await _open_by_hover(f, picker)
	assert_true(picker.is_open and picker.visible, "resting on the Formation button opens the panel")
	var cards := picker.cards()
	assert_eq(cards.map(func(c: Dictionary) -> String: return c["id"]), FormationCatalog.ORDER, "every formation, AUTO first")
	assert_eq(cards.filter(func(c: Dictionary) -> bool: return c["current"]).map(func(c: Dictionary) -> String: return c["id"]),
			[UnitCommand.AUTO], "the one in use is marked")
	assert_eq(cards.filter(func(c: Dictionary) -> bool: return c["next"]).map(func(c: Dictionary) -> String: return c["id"]),
			["wedge"], "and the one G picks next")
	var screen := Rect2(Vector2.ZERO, Vector2(tree.root.size))
	assert_true(screen.encloses(picker.get_global_rect()), "the panel is on screen (%s)" % picker.get_global_rect())
	assert_eq(String(picker.panel.tooltip().get("id", "")), "", "no button tooltip draws over the open panel")


func test_one_click_picks_and_the_next_order_uses_it() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	await f.click(_button_center(picker))
	assert_true(picker.is_open, "a click (a tap) on the button opens the panel at once")
	f.motion(_card_center(picker, "line"), false, 0)
	await tree.process_frame
	assert_eq(picker.preview_id(), "line", "hovering a card previews it")
	await f.click(_card_center(picker, "line"))
	assert_eq(f.controls.formation, "line", "one click picks it")
	assert_true(not picker.is_open and not picker.is_processing(), "and closes the panel")
	await f.right_click(f.ground(Vector3(-15, 0, 15)))
	assert_eq(f.orders.current("Green_Alpha_1").get("formation", ""), "line", "the next order uses it")
	await f.click(_button_center(picker))
	await f.click(_card_center(picker, "coil"))
	assert_eq(f.controls.formation, "coil", "coil, which G never reaches, is one click away")
	await f.key(KEY_G)
	assert_eq(f.controls.formation, UnitCommand.AUTO, "G still cycles, on round from a panel-only shape")


func test_escape_closes_it_and_keeps_the_selection() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	await f.click(_button_center(picker))
	assert_true(picker.is_open, "open")
	await f.key(KEY_ESCAPE)
	assert_true(not picker.is_open, "Escape closes the panel")
	assert_eq(f.controls.selection.units.size(), SQUAD.size(), "and is spent there: the selection stays")


func test_a_world_order_given_while_it_is_open_still_lands() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	await f.click(_button_center(picker))
	assert_true(picker.is_open, "open")
	await f.right_click(f.ground(Vector3(-15, 0, 15)))
	assert_true(not picker.is_open, "a click elsewhere closes the panel")
	assert_eq(f.orders.current("Green_Alpha_1").get("verb", ""), "move", "and the move order it was still lands")
	await f.click(_button_center(picker))
	await f.click(f.screen("Green_Bravo_2"))
	assert_true(not picker.is_open, "a left click elsewhere closes it too")
	assert_eq(f.controls.selection.units, ["Green_Bravo_2"] as Array[String], "and still selects what it clicked")


func test_a_diagonal_path_into_the_panel_keeps_it_open_and_leaving_closes_it() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	await _open_by_hover(f, picker)
	assert_true(picker.is_open, "open")
	# From the button toward the far card, across the command card and the gap: inside the bridge.
	var far := _card_center(picker, FormationCatalog.ORDER[FormationPicker.COLUMNS])
	var start := _button_center(picker)
	for i in range(1, 6):
		f.motion(start.lerp(far, i / 6.0), false, 0)
		await tree.process_frame
	await _seconds(FormationPicker.CLOSE_GRACE_S + 0.1)
	assert_true(picker.is_open, "moving diagonally from the button into the panel does not close it")
	# A brief overshoot past its edge and back does not close it either.
	var outside := picker.get_global_rect().position - Vector2(30, 30)
	f.motion(outside, false, 0)
	await tree.process_frame
	f.motion(far, false, 0)
	await _seconds(FormationPicker.CLOSE_GRACE_S + 0.1)
	assert_true(picker.is_open, "a brief overshoot is forgiven")
	f.motion(outside, false, 0)
	await _seconds(FormationPicker.CLOSE_GRACE_S + 0.2)
	assert_true(not picker.is_open, "leaving it closes it")
	assert_eq(f.controls.formation, UnitCommand.AUTO, "and picks nothing")


func test_a_long_press_on_a_card_previews_it_without_picking() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	await f.click(_button_center(picker))
	var at := _card_center(picker, "vee")
	f.motion(at, false, 0)
	f.button(at, true)
	await _seconds(FormationPicker.LONG_PRESS_S + 0.15)
	assert_eq(picker.preview_id(), "vee", "a held press shows that card's preview (a phone has no hover)")
	f.button(at, false)
	await tree.process_frame
	assert_true(picker.is_open, "lifting the finger keeps the panel open")
	assert_eq(f.controls.formation, UnitCommand.AUTO, "and picks nothing")


# ---- P3: the preview -----------------------------------------------------------------------------------------------

func test_the_preview_is_the_real_formation_for_the_vehicles_selected() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	var preview := FormationPreview.new()
	var members := picker._preview_members()
	assert_eq(members.size(), SQUAD.size(), "the preview draws the selected vehicles")
	var plan := preview.layout("line", members)
	assert_eq(int(plan["count"]), SQUAD.size(), "three vehicles draw three")
	assert_eq((plan["roles"] as Array).count("tank"), 2, "two tanks and")
	assert_eq((plan["roles"] as Array).count("ifv"), 1, "an IFV: its real seats")
	var line := plan["slots"] as Array
	assert_near((line[0] as Vector2).y, (line[1] as Vector2).y, 0.01, "a line is side by side")
	var expected := TacticsFormation.centered(TacticsFormation.offsets("line", SQUAD.size()))
	var xs := (line.map(func(v: Vector2) -> float: return v.x))
	xs.sort()
	var want := expected.map(func(v: Vector2) -> float: return v.x)
	want.sort()
	for i in xs.size():
		assert_near(float(xs[i]), float(want[i]), 0.5, "slot %d is the planner's" % i)
	assert_true(preview.layout("line", members) == plan, "remembered: the planner runs once per card")
	var coil := preview.layout("coil", members)
	assert_true(float(coil["coverage"]) > float(plan["coverage"]), "a coil watches more of the circle than a line")
	var lone := preview.layout("wedge", [])
	assert_eq(int(lone["count"]), FormationPreview.STAND_IN, "one vehicle or none: a squad of four stands in")


func test_auto_draws_the_shape_the_squad_would_take_for_two_selections() -> void:
	var setup: Array = await _setup()
	var f: Fixture = setup[0]
	var picker: FormationPicker = setup[2]
	var three := picker.auto_shape()
	assert_true(FormationCatalog.INFO.has(three) and three != UnitCommand.AUTO, "AUTO draws a real shape (%s)" % three)
	assert_eq(String(picker.cards()[0]["shape"]), three, "AUTO's card draws it")
	await f.select(["Green_Bravo_1", "Green_Bravo_2"])
	var two := picker.auto_shape()
	assert_true(FormationCatalog.INFO.has(two), "for another selection too (%s)" % two)
