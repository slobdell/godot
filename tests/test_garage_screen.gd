extends TestCase
## Garage GA1/GA2: the garage screen driven like a player, with taps and drags pushed through the
## real viewport (so hit-testing, drag thresholds, and drop targets are exercised), plus the
## --garage mode's handover to the skirmish.

const TEST_DIR := "user://test_garage_screen/"


func _starter_size() -> int:
	return GarageScreen.starter_loadout(GarageCatalog.from_game()).unit_count()


func _open(screen_size := Vector2i(1280, 720)) -> GarageScreen:
	# Headless Godot's root viewport is 64×64 (trip-up #31): give it a real screen.
	tree.root.size = screen_size
	var screen := GarageScreen.new()
	screen.settings = GarageSettings.new("")  # in memory: never the player's tips file
	screen.store_dir = TEST_DIR
	add_to_tree(screen)
	await wait_physics_frames(3)
	return screen


func _find(screen: Control, pattern: String) -> Control:
	var found := screen.find_children(pattern, "Control", true, false)
	return found[0] if not found.is_empty() else null


## Scroll a control into view (catalog v2 lists five unit cards, more than fit the column at 720p).
func _reveal(control: Control) -> Control:
	var parent := control.get_parent()
	while parent != null and not parent is ScrollContainer:
		parent = parent.get_parent()
	if parent != null:
		(parent as ScrollContainer).ensure_control_visible(control)
		await wait_physics_frames(2)
	return control


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


func _mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = position
	event.global_position = position
	tree.root.push_input(event)


func _tap(control: Control) -> void:
	_mouse(_center(control), true)
	_mouse(_center(control), false)
	await wait_physics_frames(2)


## Press on `from`, slide in steps, release on `to`: what a finger drag delivers via mouse emulation.
func _drag(from: Control, to: Control) -> void:
	var start := _center(from)
	var end := _center(to)
	_mouse(start, true)
	for step in range(1, 11):
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		motion.position = start.lerp(end, step / 10.0)
		motion.global_position = motion.position
		motion.relative = (end - start) / 10.0
		tree.root.push_input(motion)
		await tree.process_frame
	_mouse(end, false)
	await wait_physics_frames(2)


func test_opens_with_a_ready_starter_army() -> void:
	var screen := await _open()
	assert_true(screen.loadout.is_ready(), "a first visit can FIGHT immediately: %s" % [screen.loadout.problems()])
	assert_eq(screen.loadout.unit_count(), _starter_size(), "the starter army is the full starter roster")
	assert_eq(screen.selected_unit, 0, "the first unit is selected so the turntable shows something")
	var turntable := _find(screen, "Turntable") as GarageTurntable
	assert_true(turntable != null and turntable.is_visible_in_tree(), "the turntable is on screen")
	assert_true(String((_find(screen, "Problems") as Label).text).begins_with("READY"), "the status line says READY")


func test_tapping_add_without_the_money_explains_why() -> void:
	var screen := await _open()
	var add: Control = await _reveal(_find(screen, "Add_tank"))
	assert_true(add != null, "the tank card has an ADD button")
	var before := screen.loadout.unit_count()
	await _tap(add)
	assert_eq(screen.loadout.unit_count(), before, "the starter's change doesn't buy another tank")
	assert_true(screen.toast_text().contains("budget"), "a toast says why: '%s'" % screen.toast_text())


func test_tap_remove_then_tap_add_updates_the_budget_bar() -> void:
	var screen := await _open()
	await _tap(_find(screen, "RemoveUnit"))
	assert_eq(screen.loadout.unit_count(), _starter_size() - 1, "REMOVE UNIT removes the selected unit")
	var bar := _find(screen, "BudgetBar") as ProgressBar
	assert_eq(int(bar.value), screen.loadout.total_cost(), "the budget bar shows the spend after removing")
	await _tap(await _reveal(_find(screen, "Add_tank")))
	assert_eq(screen.loadout.unit_count(), _starter_size(), "+ ADD puts a unit back")
	assert_eq(int((_find(screen, "BudgetBar") as ProgressBar).value), screen.loadout.total_cost(), "and the bar follows")


func test_drag_a_unit_chip_onto_another_squad() -> void:
	var screen := await _open()
	var chip := _find(screen, "Squad_0").find_child("Unit_2", true, false) as Control
	await _drag(chip, _find(screen, "Squad_1"))
	assert_eq(screen.loadout.squad(0)["tanks"].size(), 2, "Alpha gave up a unit")
	assert_eq(screen.loadout.squad(1)["tanks"].size(), 3, "Bravo received it")
	assert_eq([screen.selected_squad, screen.selected_unit], [1, 2], "the moved unit stays selected in its new squad")


func test_drag_a_catalog_card_onto_a_new_squad() -> void:
	var screen := await _open()
	await _tap(_find(screen, "RemoveUnit"))
	await _tap(_find(screen, "AddSquad"))
	assert_eq(screen.loadout.squads().size(), 3, "+ SQUAD adds Charlie")
	await _drag(await _reveal(_find(screen, "Card_tank")), _find(screen, "Squad_2"))
	assert_eq(screen.loadout.squad(2)["tanks"].size(), 1, "dropping the tank card on Charlie adds a tank there")
	assert_true(screen.loadout.is_ready(), "the army is ready again: %s" % [screen.loadout.problems()])


func test_fight_refuses_until_ready_then_saves_a_loadable_army() -> void:
	var screen := await _open()
	var requests: Array = []
	screen.fight_requested.connect(func(path: String, enemy: String) -> void: requests.append([path, enemy]))
	await _tap(_find(screen, "AddSquad"))
	await _tap(_find(screen, "Fight"))
	assert_true(requests.is_empty(), "FIGHT with an empty squad doesn't start a match")
	assert_true(screen.toast_text().contains("Charlie has no units"), "and says what to fix: '%s'" % screen.toast_text())
	await _tap(_find(screen, "Squad_2").find_child("Remove", true, false))
	await _tap(_find(screen, "Fight"))
	assert_eq(requests.size(), 1, "FIGHT with a ready army asks for the skirmish")
	if requests.size() == 1:
		assert_eq(requests[0][0], TEST_DIR + "my_army.json", "the army was saved under its name")
		assert_true(Doctrine.load_file(requests[0][0]).has("doctrine"), "the saved file is a valid doctrine")
		ArmyStore.remove("my_army", TEST_DIR)


func test_tap_targets_are_phone_sized() -> void:
	var screen := await _open(Vector2i(2400, 1080))
	assert_near(screen.ui_scale, 1.5, 0.01, "a 1080-tall screen scales the UI 1.5x")
	for control_name in ["Fight", "Add_tank", "RemoveUnit", "AddSquad"]:
		var control := _find(screen, control_name)
		assert_true(control != null and control.size.y >= 48.0, "%s is at least 48 px tall at 1080p (%s)" % [control_name,
				control.size.y if control != null else "missing"])
	var fight := _find(screen, "Fight")
	assert_true(fight.get_global_rect().end.x <= 2400.0 and fight.get_global_rect().end.y <= 1080.0, "FIGHT is on screen")


func test_turntable_builds_the_unit_from_visual_slots() -> void:
	var screen := await _open()
	var turntable := _find(screen, "Turntable") as GarageTurntable
	var slots := turntable.find_children("*", "VisualSlot", true, false)
	var filled := slots.filter(func(slot: VisualSlot) -> bool: return slot.visual != null).map(func(slot: VisualSlot) -> String: return slot.slot)
	filled.sort()
	assert_eq(filled, ["tank.hull", "tank.turret", "weapon.cannon"], "hull, turret, and the mounted weapon come from theme slots")
	var before := turntable.spin_degrees()
	await _drag(turntable, _find(screen, "Fight"))
	assert_true(absf(turntable.spin_degrees() - before) > 5.0, "a swipe spins the turntable")


func test_garage_flag_chooses_the_garage_mode() -> void:
	assert_true(GameMode.choose(LaunchFlags.parse(["--garage"])) is GarageMode, "--garage opens the garage")
	assert_true(GameMode.choose(LaunchFlags.parse(["--match", "--garage"])) is MatchRunnerMode, "the match runner still wins")



func test_a_resize_rebuild_keeps_open_overlays() -> void:
	var screen := await _open()
	screen.toggle_compare(true)
	tree.root.size = Vector2i(2400, 1080)
	await wait_physics_frames(3)
	assert_near(screen.ui_scale, 1.5, 0.01, "setup: the screen rebuilt at the new scale")
	assert_true((_find(screen, "ComparePanel") as Control).visible, "COMPARE stays open across the rebuild")


# ---- Saving policy ----------------------------------------------------------------------------

const SAVE_DIR := "user://test_garage_saving/"
const SETTINGS_PATH := "user://test_garage_saving.cfg"


func _clean_saves() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	for file_name in DirAccess.get_files_at(SAVE_DIR):
		DirAccess.remove_absolute(SAVE_DIR.path_join(file_name))
	DirAccess.remove_absolute(SETTINGS_PATH)


func _open_with(settings: GarageSettings) -> GarageScreen:
	tree.root.size = Vector2i(1280, 720)
	var screen := GarageScreen.new()
	screen.settings = settings
	screen.store_dir = SAVE_DIR
	add_to_tree(screen)
	await wait_physics_frames(2)
	return screen


func test_two_new_armies_with_the_same_name_never_overwrite_each_other() -> void:
	_clean_saves()
	var screen := await _open_with(GarageSettings.new(""))
	var first := screen.save()
	screen.apply_preset("flamers")
	screen.loadout.set_army_name("My Army")
	var second := screen.save()
	assert_eq(first, SAVE_DIR + "my_army.json", "the first army takes the plain name")
	assert_eq(second, SAVE_DIR + "my_army_2.json", "a different army with the same name gets its own file")
	assert_eq(ArmyStore.read(first)["doctrine"]["squads"].size(), 2, "the first army's file is untouched")
	_clean_saves()


func test_a_loaded_army_saves_back_to_its_own_file_even_when_renamed() -> void:
	_clean_saves()
	var screen := await _open_with(GarageSettings.new(""))
	var path := screen.save()
	screen.apply_preset("rush")
	screen.set_loadout(Loadout.from_doctrine(screen.loadout.catalog, ArmyStore.read(path)["doctrine"]), path)
	screen.loadout.set_army_name("Renamed")
	screen.loadout.set_formation(0, "column")
	assert_eq(screen.save(), path, "SAVE updates the file it was loaded from")
	assert_eq(ArmyStore.list(SAVE_DIR).size(), 1, "no duplicate file appeared")
	assert_eq(ArmyStore.read(path)["doctrine"]["name"], "Renamed", "with the edits")
	_clean_saves()


func test_the_garage_reopens_on_the_army_you_last_fought_with() -> void:
	_clean_saves()
	var screen := await _open_with(GarageSettings.new(SETTINGS_PATH))
	screen.apply_preset("flamers")
	var fought := screen.fight()
	assert_true(fought != "", "setup: FIGHT saved the preset army")
	screen.queue_free()
	await wait_physics_frames(1)
	var again := await _open_with(GarageSettings.new(SETTINGS_PATH))
	assert_eq(String(again.loadout.army["name"]), "Flamers #1", "the next visit opens the same army")
	assert_eq(again.army_path, fought, "tied to its file, so SAVE updates it")
	_clean_saves()


func test_delete_takes_two_taps_and_keeps_the_army_open() -> void:
	_clean_saves()
	var screen := await _open_with(GarageSettings.new(""))
	var delete := screen.find_child("Delete", true, false) as Button
	assert_true(not delete.visible, "an unsaved army has nothing to delete")
	var path := screen.save()
	assert_true(delete.visible, "a saved army can be deleted")
	delete.pressed.emit()
	assert_true(FileAccess.file_exists(path), "one tap only arms DELETE")
	assert_eq(delete.text, "CONFIRM?", "and asks for confirmation")
	delete.pressed.emit()
	assert_true(not FileAccess.file_exists(path), "the second tap deletes the file")
	assert_eq(screen.loadout.unit_count(), _starter_size(), "the army stays open")
	assert_eq(screen.save(), path, "so SAVE brings it back")
	_clean_saves()
