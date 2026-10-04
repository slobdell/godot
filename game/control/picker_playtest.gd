class_name PickerPlaytest
extends ControlPlaytest
## Round 18 (picker, P4): the Formation panel played like a player, through real input events, in a real skirmish:
## `make picker-shots` (windowed, PICKER_SIZES) or headless (checks only). Launched by ControlPlaytest when the command
## line carries --picker-only. Frames, in order:
##   1_closed          a squad selected, the panel closed
##   2_open            the mouse rested on the Formation button: every formation, NOW and G marked
##   3_hover_line_*    a card hovered: its preview mid-drive and with the sectors lit
##   4_auto_squad1/2   AUTO's card for two different selections
##   5_picked          one click picked Line; the button reads it; the next order uses it
##   6_fight_*         mid-fight: the panel opened and Wedge picked while the squad is in contact
## Prints PICKER_PLAYTEST lines and PICKER_PLAYTEST_DONE ok=<bool>, then quits (exit 1 when a check failed).

var _panel: SelectionPanel
var _picker: FormationPicker


func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	_can_capture = DisplayServer.get_name() != "headless"
	if not _can_capture:
		get_tree().root.size = Vector2i(1280, 720)  # headless roots are 64×64 (trip-up 31)
	var tree := get_tree()
	_panel = controls.get_node("SelectionPanel") as SelectionPanel
	_picker = _panel.picker
	_panel.dismiss_intro()
	await tree.create_timer(1.0).timeout
	controls.recall_group(1)
	await _rest(_screen(Vector3.ZERO) + Vector2(0, -200), 0.3)
	await _capture("1_closed")
	_checks["closed_and_idle"] = not _picker.is_open and not _picker.is_processing()

	await _rest(_picker.button_rect().get_center(), FormationPicker.OPEN_DELAY_S + 0.25)
	_checks["resting_opens_it"] = _picker.is_open
	_report("open", {"cards": _picker.cards().map(func(c: Dictionary) -> String: return String(c["id"]))})
	await _capture("2_open")

	await _rest(_card("line"), FormationPreview.LOOP_S * FormationPreview.FORM_END + 0.5)
	await _capture("3_hover_line_driving")
	await tree.create_timer(FormationPreview.LOOP_S * 0.45).timeout
	await _capture("3_hover_line_sectors")
	_checks["hover_previews_the_card"] = _picker.preview_id() == "line"

	await _rest(_card(UnitCommand.AUTO), 0.6)
	_report("auto_squad1", {"units": controls.selection.units.size(), "shape": _picker.auto_shape()})
	await _capture("4_auto_squad1")
	await _key(KEY_ESCAPE)
	_checks["escape_closes_it"] = not _picker.is_open
	controls.recall_group(2)
	await tree.process_frame
	await _rest(_picker.button_rect().get_center(), FormationPicker.OPEN_DELAY_S + 0.25)
	await _rest(_card(UnitCommand.AUTO), 0.6)
	_report("auto_squad2", {"units": controls.selection.units.size(), "shape": _picker.auto_shape()})
	await _capture("4_auto_squad2")

	await _click(_card("line"))
	await tree.process_frame
	_checks["one_click_picks_line"] = controls.formation == "line" and not _picker.is_open
	await _rest(_picker.button_rect().get_center() + Vector2(0, -400), 0.2)
	await _capture("5_picked")

	# Mid-fight: attack-move the first squad at the enemy, wait for contact, then open the panel and pick.
	controls.recall_group(1)
	var members := _alive(controls.selection.units)
	var forward: Vector3 = Match.team_frame(controls.team)["forward"]
	await _key(KEY_A)
	await _click(_screen(_middle(members) + forward * 60.0))
	var waited := 0.0
	while waited < 40.0 and not _alive(members).any(func(n: String) -> bool: return _in_contact(n)):
		await tree.create_timer(0.5).timeout
		waited += 0.5
	_report("contact", {"after_s": waited, "in_contact": _alive(members).any(func(n: String) -> bool: return _in_contact(n))})
	controls.recall_group(1)
	await tree.process_frame
	await _rest(_picker.button_rect().get_center(), FormationPicker.OPEN_DELAY_S + 0.25)
	await _rest(_card("wedge"), 1.2)
	await _capture("6_fight_open")
	await _click(_card("wedge"))
	var target := _middle(_alive(members)) + forward * 25.0
	await _right_click(_screen(target))
	await tree.process_frame
	var ordered := _alive(members)
	var element := controls.selected_element()
	var carried := ordered.any(func(n: String) -> bool: return String(controls.orders.current(n).get("formation", "")) == "wedge")
	if element != null:
		carried = carried or String(element.task.get("formation", "")) == "wedge"
	_checks["mid_fight_pick_reaches_the_order"] = controls.formation == "wedge" and carried
	await tree.create_timer(1.5).timeout
	await _capture("6_fight_after")

	var ok := _checks.values().all(func(v: bool) -> bool: return v)
	print("PICKER_PLAYTEST ", JSON.stringify({"checks": _checks, "size": [get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y]}))
	print("PICKER_PLAYTEST_DONE ok=%s dir=%s" % [ok, out_dir])
	tree.quit(0 if ok else 1)


## Move the mouse there (a few motion events, as a hand does) and rest for `seconds`.
func _rest(at: Vector2, seconds: float) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	_push(motion)
	await get_tree().process_frame
	await get_tree().create_timer(seconds).timeout


func _card(id: String) -> Vector2:
	return _picker.get_global_transform() * _picker.card_rect(id).get_center()


func _report(step_name: String, data: Dictionary) -> void:
	data["step"] = step_name
	data["tick"] = controls.game_match.tick
	print("PICKER_PLAYTEST ", JSON.stringify(data))
