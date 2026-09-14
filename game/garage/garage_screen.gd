class_name GarageScreen
extends Control
## The garage (GA1): spend a budget on an army before a skirmish. Touch first: every action is a
## tap or a drag, and tap targets scale with the screen (≥ 48 px on a 1080p-tall screen).
##
##   UNITS    catalog cards with stat bars. Tap ADD (joins the selected squad) or drag a card onto a squad.
##   SQUADS   up to Doctrine.MAX_SQUADS. Tap a squad to select it; pick its formation and role.
##            Tap a unit chip to equip it; drag a chip onto another squad to move it.
##   EQUIP    the selected unit on a turntable (swipe to spin): a weapon per hardpoint (tap, or drag a
##            weapon chip onto the hardpoint), components, role, paint, remove.
##   TOP      army name, budget bar, presets, load, save, share (army codes).   BOTTOM  problems, enemy, FIGHT.
##
## All rules live in Loadout; this file only shows them. Colors come from GameTheme.ui (look & feel
## owns them) with garage-specific keys falling back to placeholders here.

signal fight_requested(player_path: String, enemy: String)

const BASE_HEIGHT := 720.0
const FONT_SIZE := 17
## Minimum tap target at BASE_HEIGHT (scaled with the screen: 48 px at 1080p).
const TAP := 40.0
## Opponents offered for the skirmish: [value for --enemy, label]. "cpu:<archetype>" is a fresh seeded
## ArmyPresets army each fight (GarageMode builds it); the rest are hand-written res://doctrines.
const ENEMIES := [["cpu:balanced", "CPU army: Balanced"], ["cpu:rush", "CPU army: Rush"],
		["cpu:turtle", "CPU army: Turtle"], ["cpu:flamers", "CPU army: Flamers"],
		["individuals", "Doctrine: Individuals"], ["anvil_hammer", "Doctrine: Anvil & Hammer"],
		["flame_rush", "Doctrine: Flame Rush"], ["anvil_burners", "Doctrine: Anvil & Burners"]]

var loadout: Loadout
## Where armies are saved (tests point this elsewhere).
var store_dir := ArmyStore.DIR
var enemy := "cpu:balanced"
## Seed for the next preset the player picks (each pick rolls a new variation).
var preset_seed := 1
var selected_squad := 0
## Index in the selected squad, or -1.
var selected_unit := -1
var ui_scale := 1.0

var _name_edit: LineEdit
var _budget_bar: ProgressBar
var _budget_label: Label
var _catalog_box: VBoxContainer
var _squads_box: HBoxContainer
var _inspector: VBoxContainer
var _turntable: GarageTurntable
var _problems_label: Label
var _fight_button: Button
var _load_menu: OptionButton
var _preset_menu: OptionButton
var _enemy_menu: OptionButton
var _toast: Label
var _share_panel: PanelContainer
var _code_edit: LineEdit
var _toast_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if loadout == null:
		loadout = GarageScreen.starter_loadout(GarageCatalog.from_game())
	loadout.changed.connect(_refresh)
	# Open on the first unit so the turntable and equipment show something right away.
	selected_unit = 0 if not loadout.unit_at(0, 0).is_empty() else -1
	resized.connect(_rebuild_if_scaled)
	_build()


## A ready-to-fight army for a first visit: the cheapest unit class, 3 in Alpha and the rest in Bravo.
static func starter_loadout(catalog: GarageCatalog) -> Loadout:
	var loadout := Loadout.new(catalog)
	loadout.add_squad()
	var cheapest := catalog.unit_ids()[0]
	for i in catalog.max_units:
		if loadout.add_unit(0 if i < 3 else 1, cheapest) != "":
			break
	loadout.set_formation(1, "line")
	return loadout


func _process(delta: float) -> void:
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0


# ---- Palette (look & feel may add these keys to GameTheme.ui) ------------------------------

func _color(key: String) -> Color:
	const FALLBACK := {"garage_bg": Color(0.055, 0.06, 0.075), "garage_panel": Color(0.1, 0.11, 0.14),
			"garage_text_dim": Color(0.62, 0.66, 0.72), "friendly": Color(0.45, 0.85, 0.4),
			"enemy": Color(0.95, 0.35, 0.3), "commander": Color(1.0, 0.85, 0.25)}
	return GameTheme.ui.get(key, FALLBACK.get(key, Color.WHITE))


func _panel_style(border: Color, width := 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _color("garage_panel")
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(int(6 * ui_scale))
	style.set_content_margin_all(8 * ui_scale)
	return style


# ---- Layout -------------------------------------------------------------------------------

func _rebuild_if_scaled() -> void:
	if not is_equal_approx(_scale_for(size.y), ui_scale):
		_build()


static func _scale_for(height: float) -> float:
	return maxf(1.0, height / BASE_HEIGHT) if height > 0.0 else 1.0


func _build() -> void:
	ui_scale = _scale_for(size.y if size.y > 0.0 else get_viewport_rect().size.y)
	_clear(self)
	if _turntable != null and _turntable.get_parent() == null:
		_turntable.queue_free()
	var ui_theme := Theme.new()
	ui_theme.default_font_size = int(FONT_SIZE * ui_scale)
	theme = ui_theme

	var background := ColorRect.new()
	background.color = _color("garage_bg")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(12 * ui_scale))
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(10 * ui_scale))
	margin.add_child(rows)
	rows.add_child(_build_top_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(10 * ui_scale))
	rows.add_child(body)
	body.add_child(_column("UNITS", 0.9, func(box: VBoxContainer) -> void: _catalog_box = box))
	var squads_scroll := _column("SQUADS", 1.6, func(_box: VBoxContainer) -> void: pass)
	_squads_box = HBoxContainer.new()
	_squads_box.add_theme_constant_override("separation", int(8 * ui_scale))
	_squads_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	squads_scroll.get_meta("box").add_child(_squads_box)
	body.add_child(squads_scroll)
	body.add_child(_column("EQUIP", 1.1, func(box: VBoxContainer) -> void: _inspector = box))

	rows.add_child(_build_bottom_bar())

	_toast = _label("", 1.1)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.position.y -= 110 * ui_scale
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", int(6 * ui_scale))
	_toast.visible = false
	add_child(_toast)

	_build_share_panel()
	move_child(_toast, get_child_count() - 1)

	_turntable = GarageTurntable.new()
	_turntable.name = "Turntable"
	_turntable.custom_minimum_size = Vector2(0, 200 * ui_scale)
	_build_catalog()
	_refresh()


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(10 * ui_scale))
	var title := _label("GARAGE", 1.5)
	title.add_theme_color_override("font_color", _color("commander"))
	bar.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.name = "ArmyName"
	_name_edit.text = String(loadout.army.get("name", ""))
	_name_edit.placeholder_text = "Army name"
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size = Vector2(220 * ui_scale, TAP * ui_scale)
	_name_edit.text_changed.connect(func(text: String) -> void: loadout.set_army_name(text))
	bar.add_child(_name_edit)

	var budget := VBoxContainer.new()
	budget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	budget.add_theme_constant_override("separation", 0)
	_budget_label = _label("", 0.9)
	budget.add_child(_budget_label)
	_budget_bar = ProgressBar.new()
	_budget_bar.name = "BudgetBar"
	_budget_bar.show_percentage = false
	_budget_bar.custom_minimum_size = Vector2(0, 14 * ui_scale)
	budget.add_child(_budget_bar)
	bar.add_child(budget)

	_preset_menu = OptionButton.new()
	_preset_menu.name = "PresetMenu"
	_preset_menu.custom_minimum_size = Vector2(150 * ui_scale, TAP * ui_scale)
	_preset_menu.add_item("PRESETS...")
	_preset_menu.set_item_metadata(0, "")
	_preset_menu.add_item("Starter")
	_preset_menu.set_item_metadata(1, "starter")
	for archetype in ArmyPresets.ids():
		_preset_menu.add_item(ArmyPresets.label(archetype))
		_preset_menu.set_item_metadata(_preset_menu.item_count - 1, archetype)
		_preset_menu.set_item_tooltip(_preset_menu.item_count - 1, String(ArmyPresets.ARCHETYPES[archetype]["blurb"]))
	_preset_menu.item_selected.connect(func(index: int) -> void:
		var archetype := String(_preset_menu.get_item_metadata(index))
		_preset_menu.select(0)
		if archetype != "":
			apply_preset(archetype))
	bar.add_child(_preset_menu)
	_load_menu = OptionButton.new()
	_load_menu.name = "LoadMenu"
	_load_menu.custom_minimum_size = Vector2(150 * ui_scale, TAP * ui_scale)
	_load_menu.item_selected.connect(_on_load_selected)
	bar.add_child(_load_menu)
	_fill_load_menu()
	bar.add_child(_button("SAVE", func() -> void: save()))
	var share := _button("SHARE", func() -> void: toggle_share(true))
	share.name = "Share"
	bar.add_child(share)
	return bar


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(10 * ui_scale))
	_problems_label = _label("", 0.95)
	_problems_label.name = "Problems"
	_problems_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_problems_label)
	_enemy_menu = OptionButton.new()
	_enemy_menu.name = "EnemyMenu"
	_enemy_menu.custom_minimum_size = Vector2(230 * ui_scale, TAP * 1.3 * ui_scale)
	for entry in ENEMIES:
		_enemy_menu.add_item(entry[1])
		if entry[0] == enemy:
			_enemy_menu.select(_enemy_menu.item_count - 1)
	_enemy_menu.item_selected.connect(func(index: int) -> void: enemy = ENEMIES[index][0])
	bar.add_child(_enemy_menu)
	_fight_button = _button("FIGHT", func() -> void: fight())
	_fight_button.name = "Fight"
	_fight_button.custom_minimum_size = Vector2(170 * ui_scale, TAP * 1.3 * ui_scale)
	_fight_button.add_theme_font_size_override("font_size", int(FONT_SIZE * 1.5 * ui_scale))
	bar.add_child(_fight_button)
	return bar


## A titled, scrolling column. `bind` receives its content box; the column's meta "box" holds it too.
func _column(title: String, stretch: float, bind: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = stretch
	panel.add_theme_stylebox_override("panel", _panel_style(_color("garage_text_dim").darkened(0.5), 1))
	var rows := VBoxContainer.new()
	panel.add_child(rows)
	var heading := _label(title, 0.85)
	heading.add_theme_color_override("font_color", _color("garage_text_dim"))
	rows.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rows.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", int(8 * ui_scale))
	scroll.add_child(box)
	panel.set_meta("box", box)
	bind.call(box)
	return panel


## Chips and choices: a clear bright border when selected, a quiet one otherwise, same in every state.
func _style_choice(button: Button, selected: bool) -> void:
	var style := _panel_style(_color("commander") if selected else _color("garage_text_dim").darkened(0.55), 3 if selected else 1)
	style.set_content_margin_all(6 * ui_scale)
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		button.add_theme_stylebox_override(state, style if state != "focus" else StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color.WHITE if selected else _color("garage_text_dim").lightened(0.2))


func _label(text: String, relative_size := 1.0) -> Label:
	var label := Label.new()
	label.text = text
	if not is_equal_approx(relative_size, 1.0):
		label.add_theme_font_size_override("font_size", int(FONT_SIZE * relative_size * ui_scale))
	return label


func _button(text: String, on_press: Callable, toggled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(TAP * ui_scale, TAP * ui_scale)
	button.toggle_mode = toggled
	button.button_pressed = toggled
	button.pressed.connect(on_press)
	return button


## An overlay with the army's code: copy it to share, or paste a friend's code and import it.
func _build_share_panel() -> void:
	_share_panel = PanelContainer.new()
	_share_panel.name = "SharePanel"
	_share_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_share_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_share_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_share_panel.custom_minimum_size = Vector2(620 * ui_scale, 0)
	_share_panel.add_theme_stylebox_override("panel", _panel_style(_color("commander"), 3))
	_share_panel.visible = false
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(10 * ui_scale))
	_share_panel.add_child(rows)
	rows.add_child(_section("ARMY CODE"))
	var hint := _label("Copy this code to share your army, or paste a friend's code and tap IMPORT.", 0.85)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(hint)
	_code_edit = LineEdit.new()
	_code_edit.name = "CodeEdit"
	_code_edit.custom_minimum_size.y = TAP * ui_scale
	_code_edit.select_all_on_focus = true
	rows.add_child(_code_edit)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", int(10 * ui_scale))
	var copy := _button("COPY", func() -> void:
		DisplayServer.clipboard_set(_code_edit.text)
		_show_toast("Army code copied", false))
	copy.name = "Copy"
	buttons.add_child(copy)
	var import := _button("IMPORT", func() -> void:
		if import_code(_code_edit.text) == "":
			toggle_share(false))
	import.name = "Import"
	buttons.add_child(import)
	var close := _button("CLOSE", func() -> void: toggle_share(false))
	close.name = "Close"
	buttons.add_child(close)
	rows.add_child(buttons)
	add_child(_share_panel)


# ---- Catalog ------------------------------------------------------------------------------

func _build_catalog() -> void:
	var catalog := loadout.catalog
	for unit_id in catalog.unit_ids():
		var profile := catalog.unit(unit_id)
		var card := PanelContainer.new()
		card.name = "Card_" + unit_id
		card.add_theme_stylebox_override("panel", _panel_style(_color("friendly").darkened(0.45)))
		var rows := VBoxContainer.new()
		card.add_child(rows)
		var header := HBoxContainer.new()
		var title := _label(catalog.display_name(profile, unit_id).to_upper(), 1.1)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(title)
		var cost := _label("%d" % catalog.unit_cost(unit_id), 1.1)
		cost.add_theme_color_override("font_color", _color("commander"))
		header.add_child(cost)
		rows.add_child(header)
		var stats := GridContainer.new()
		stats.columns = 2
		for bar_data in catalog.unit_stat_bars(unit_id):
			var stat_label := _label("%s %s" % [bar_data["label"], GarageCatalog._number(bar_data["value"])], 0.8)
			stat_label.add_theme_color_override("font_color", _color("garage_text_dim"))
			stats.add_child(stat_label)
			stats.add_child(_stat_bar(bar_data["ratio"], GarageCatalog._number(bar_data["value"])))
		rows.add_child(stats)
		var mounts: PackedStringArray = []
		for hardpoint in catalog.hardpoints(unit_id):
			mounts.append("%s: %s" % [hardpoint["id"], "/".join(hardpoint.get("accepts", []))])
		var slots := catalog.component_slots(unit_id)
		if slots > 0:
			mounts.append("%d component slot%s" % [slots, "" if slots == 1 else "s"])
		var mounts_label := _label("\n".join(mounts), 0.8)
		mounts_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		mounts_label.add_theme_color_override("font_color", _color("garage_text_dim"))
		rows.add_child(mounts_label)
		var add := _button("+ ADD", func() -> void: add_unit(unit_id))
		add.name = "Add_" + unit_id
		rows.add_child(add)
		_forward_drag(card, func(_at: Vector2) -> Variant: return _drag({"kind": "catalog", "unit": unit_id},
				catalog.display_name(profile, unit_id)))
		_catalog_box.add_child(card)


func _stat_bar(ratio: float, value_text: String) -> Control:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = ratio
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(60 * ui_scale, 10 * ui_scale)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _color("friendly")
	bar.add_theme_stylebox_override("fill", fill)
	bar.tooltip_text = value_text
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	return bar


# ---- Refresh (everything that depends on the army) -----------------------------------------

func _refresh() -> void:
	if _squads_box == null:
		return
	selected_squad = clampi(selected_squad, 0, maxi(loadout.squads().size() - 1, 0))
	if loadout.unit_at(selected_squad, selected_unit).is_empty():
		selected_unit = -1
	_refresh_budget()
	_refresh_squads()
	_refresh_inspector()
	_refresh_problems()


func _refresh_budget() -> void:
	var catalog := loadout.catalog
	var spent := loadout.total_cost()
	_budget_bar.max_value = catalog.budget
	_budget_bar.value = mini(spent, catalog.budget)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _color("enemy") if spent > catalog.budget else _color("commander")
	_budget_bar.add_theme_stylebox_override("fill", fill)
	_budget_label.text = "BUDGET  %d / %d   (%d left)      UNITS  %d / %d" % [spent, catalog.budget,
			catalog.budget - spent, loadout.unit_count(), catalog.max_units]


func _refresh_squads() -> void:
	_clear(_squads_box)
	for squad_index in loadout.squads().size():
		_squads_box.add_child(_squad_panel(squad_index))
	if loadout.squads().size() < loadout.catalog.max_squads:
		var add := _button("+\nSQUAD", func() -> void: _act(loadout.add_squad()))
		add.name = "AddSquad"
		add.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_squads_box.add_child(add)


func _squad_panel(squad_index: int) -> Control:
	var squad_data := loadout.squad(squad_index)
	var selected := squad_index == selected_squad
	var panel := PanelContainer.new()
	panel.name = "Squad_%d" % squad_index
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(_color("commander") if selected else _color("garage_text_dim").darkened(0.4),
			3 if selected else 1))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(6 * ui_scale))
	panel.add_child(rows)

	var header := HBoxContainer.new()
	var title := _button(String(squad_data["name"]).to_upper(), func() -> void: select_squad(squad_index))
	title.name = "Select"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.flat = true
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", int(FONT_SIZE * 1.15 * ui_scale))
	header.add_child(title)
	var remove := _button("X", func() -> void: _act(loadout.remove_squad(squad_index)))
	remove.name = "Remove"
	remove.tooltip_text = "Remove this squad and its units"
	header.add_child(remove)
	rows.add_child(header)

	rows.add_child(_option_menu("Formation", Formations.NAMES, String(squad_data.get("formation", Formations.DEFAULT)),
			func(value: String) -> void: _act(loadout.set_formation(squad_index, value))))
	var role := String(squad_data.get("directive", {}).get("role", "assault")) if typeof(squad_data.get("directive")) == TYPE_DICTIONARY else "assault"
	rows.add_child(_option_menu("Role", Directives.ROLES, role,
			func(value: String) -> void: _act(loadout.set_squad_role(squad_index, value))))

	var tanks: Array = squad_data.get("tanks", [])
	for unit_index in tanks.size():
		var tank: Dictionary = tanks[unit_index]
		var chip := _button(_chip_text(tank), func() -> void: select_unit(squad_index, unit_index))
		chip.name = "Unit_%d" % unit_index
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.clip_text = true
		_style_choice(chip, selected and unit_index == selected_unit)
		_forward_drag(chip, func(_at: Vector2) -> Variant: return _drag(
				{"kind": "unit", "squad": squad_index, "unit": unit_index}, _chip_text(tank)))
		rows.add_child(chip)
	if tanks.is_empty():
		var hint := _label("Empty: tap + ADD or drag a unit here", 0.8)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", _color("garage_text_dim"))
		rows.add_child(hint)
	_accept_drops(panel, func(data: Dictionary) -> bool: return data.get("kind") in ["catalog", "unit"],
			func(data: Dictionary) -> void: _drop_on_squad(squad_index, data))
	return panel


func _chip_text(tank: Dictionary) -> String:
	var catalog := loadout.catalog
	var unit_id := String(tank.get("unit", ""))
	var weapon_id := String(tank.get("weapon", ""))
	var weapon_name := catalog.display_name(catalog.weapon(weapon_id), weapon_id) if weapon_id != "" else "unarmed"
	var extras := ""
	if not tank.get("components", []).is_empty():
		extras = " +%d" % tank["components"].size()
	return "%s  %s%s   %d" % [catalog.display_name(catalog.unit(unit_id), unit_id), weapon_name, extras, loadout.unit_cost(tank)]


func _option_menu(label_text: String, values: Array, current: String, on_pick: Callable) -> Control:
	var row := HBoxContainer.new()
	var label := _label(label_text, 0.8)
	label.add_theme_color_override("font_color", _color("garage_text_dim"))
	label.custom_minimum_size.x = 80 * ui_scale
	row.add_child(label)
	var menu := OptionButton.new()
	menu.name = label_text
	menu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.custom_minimum_size.y = TAP * ui_scale
	menu.clip_text = true
	for value: String in values:
		menu.add_item(value.capitalize())
		if value == current:
			menu.select(menu.item_count - 1)
	menu.item_selected.connect(func(index: int) -> void: on_pick.call(String(values[index])))
	row.add_child(menu)
	return row


func _refresh_inspector() -> void:
	if _turntable.get_parent() != null:
		_turntable.get_parent().remove_child(_turntable)
	_clear(_inspector)
	var tank := loadout.unit_at(selected_squad, selected_unit)
	if tank.is_empty():
		var hint := _label("Tap a unit in a squad to equip it.", 1.0)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint.add_theme_color_override("font_color", _color("garage_text_dim"))
		_inspector.add_child(hint)
		return
	var catalog := loadout.catalog
	var unit_id := String(tank["unit"])
	_inspector.add_child(_turntable)
	_turntable.show_unit(tank, _paint_color(tank))

	var header := HBoxContainer.new()
	var title := _label("%s  %s #%d" % [loadout.squad(selected_squad)["name"], catalog.display_name(catalog.unit(unit_id), unit_id),
			selected_unit + 1], 1.1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var cost := _label("%d" % loadout.unit_cost(tank), 1.1)
	cost.add_theme_color_override("font_color", _color("commander"))
	header.add_child(cost)
	# In the header so it's reachable without scrolling on a short screen.
	header.add_theme_constant_override("separation", int(12 * ui_scale))
	var remove := _button("REMOVE", func() -> void: _act(loadout.remove_unit(selected_squad, selected_unit)))
	remove.name = "RemoveUnit"
	remove.add_theme_color_override("font_color", _color("enemy"))
	header.add_child(remove)
	_inspector.add_child(header)

	for hardpoint in catalog.hardpoints(unit_id):
		var hardpoint_id := String(hardpoint["id"])
		var mounted := String(tank["weapons"].get(hardpoint_id, ""))
		_inspector.add_child(_section("WEAPON: " + hardpoint_id.to_upper()))
		var choices := HFlowContainer.new()
		choices.name = "Hardpoint_" + hardpoint_id
		for weapon_id: String in hardpoint.get("accepts", []):
			var weapon_cost := catalog.weapon_cost(weapon_id)
			var text := catalog.display_name(catalog.weapon(weapon_id), weapon_id) + ("  +%d" % weapon_cost if weapon_cost > 0 else "")
			var choice := _button(text, func() -> void: _act(loadout.set_weapon(selected_squad, selected_unit, hardpoint_id, weapon_id)),
					weapon_id == mounted)
			choice.name = weapon_id
			_style_choice(choice, weapon_id == mounted)
			_forward_drag(choice, func(_at: Vector2) -> Variant: return _drag({"kind": "weapon", "weapon": weapon_id}, text))
			choices.add_child(choice)
		_accept_drops(choices, func(data: Dictionary) -> bool: return data.get("kind") == "weapon" \
				and hardpoint.get("accepts", []).has(data.get("weapon")),
				func(data: Dictionary) -> void: _act(loadout.set_weapon(selected_squad, selected_unit, hardpoint_id, data["weapon"])))
		_inspector.add_child(choices)
		if mounted != "":
			var summary := _label(catalog.weapon_summary(mounted), 0.8)
			summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			summary.add_theme_color_override("font_color", _color("garage_text_dim"))
			_inspector.add_child(summary)

	var slots := catalog.component_slots(unit_id)
	var installed: Array = tank.get("components", [])
	_inspector.add_child(_section("COMPONENTS  %d / %d" % [installed.size(), slots]))
	if slots == 0:
		var none := _label("This chassis has no component slots.", 0.8)
		none.add_theme_color_override("font_color", _color("garage_text_dim"))
		_inspector.add_child(none)
	else:
		var components := HFlowContainer.new()
		components.name = "Components"
		for component_index in installed.size():
			var component_id := String(installed[component_index])
			var chip := _button(catalog.display_name(catalog.component(component_id), component_id) + "  X",
					func() -> void: _act(loadout.remove_component(selected_squad, selected_unit, component_index)), true)
			components.add_child(chip)
		if installed.size() < slots:
			for component_id in catalog.component_ids():
				var profile := catalog.component(component_id)
				var add := _button("+ %s %d" % [catalog.display_name(profile, component_id), catalog.component_cost(component_id)],
						func() -> void: _act(loadout.add_component(selected_squad, selected_unit, component_id)))
				add.name = "Add_" + component_id
				add.tooltip_text = String(profile.get("description", ""))
				components.add_child(add)
		_inspector.add_child(components)

	_inspector.add_child(_section("ORDERS"))
	var role := String(tank.get("directive", {}).get("role", "")) if typeof(tank.get("directive")) == TYPE_DICTIONARY else ""
	var roles: Array = [""] + Directives.ROLES
	var role_row := _option_menu("Role", roles, role, func(value: String) -> void:
			_act(loadout.set_unit_role(selected_squad, selected_unit, value)))
	var role_menu := role_row.get_node("Role") as OptionButton
	role_menu.set_item_text(0, "Squad's role")
	_inspector.add_child(role_row)

	_inspector.add_child(_section("PAINT"))
	var paints := HFlowContainer.new()
	paints.name = "Paints"
	for paint: String in Loadout.PAINTS:
		var swatch := _button("TEAM" if paint == "" else "", func() -> void: _act(loadout.set_paint(selected_squad, selected_unit, paint)))
		var style := _panel_style(_color("commander") if String(tank.get("paint", "")) == paint else Color(0, 0, 0, 0), 3)
		style.bg_color = GameTheme.team_color(Match.Team.GREEN) if paint == "" else Color.html(paint)
		for state in ["normal", "hover", "pressed"]:
			swatch.add_theme_stylebox_override(state, style)
		paints.add_child(swatch)
	_inspector.add_child(paints)



## Rebuilds happen inside button callbacks, so children are detached now and freed after the signal.
static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _exit_tree() -> void:
	if _turntable != null and _turntable.get_parent() == null:
		_turntable.free()


func _section(text: String) -> Label:
	var label := _label(text, 0.8)
	label.add_theme_color_override("font_color", _color("commander").darkened(0.15))
	return label


func _paint_color(tank: Dictionary) -> Color:
	var paint := String(tank.get("paint", ""))
	return Color.html(paint) if paint != "" and Color.html_is_valid(paint) else GameTheme.team_color(Match.Team.GREEN)


func _refresh_problems() -> void:
	var problems := loadout.problems()
	if problems.is_empty():
		_problems_label.text = "READY: %s, %d units. Tap FIGHT." % [loadout.army.get("name", ""), loadout.unit_count()]
		_problems_label.add_theme_color_override("font_color", _color("friendly"))
	else:
		_problems_label.text = "  ".join(problems)
		_problems_label.add_theme_color_override("font_color", _color("enemy"))
	var fight_style := _panel_style(_color("friendly") if problems.is_empty() else _color("garage_text_dim").darkened(0.5), 0)
	fight_style.bg_color = _color("friendly").darkened(0.25) if problems.is_empty() else _color("garage_panel")
	for state in ["normal", "hover", "pressed", "focus"]:
		_fight_button.add_theme_stylebox_override(state, fight_style)
	_fight_button.add_theme_color_override("font_color", Color.BLACK if problems.is_empty() else _color("garage_text_dim"))
	_fight_button.add_theme_color_override("font_hover_color", Color.BLACK if problems.is_empty() else _color("garage_text_dim"))


# ---- Actions (public, so tests and presets drive the same paths as taps) ---------------------------

func select_squad(squad_index: int) -> void:
	if squad_index != selected_squad:
		selected_unit = -1
	selected_squad = squad_index
	_refresh()


func select_unit(squad_index: int, unit_index: int) -> void:
	selected_squad = squad_index
	selected_unit = unit_index
	_refresh()


func add_unit(unit_id: String) -> String:
	if loadout.squads().is_empty():
		loadout.add_squad()
	var error := loadout.add_unit(selected_squad, unit_id)
	if error == "":
		selected_unit = loadout.squad(selected_squad)["tanks"].size() - 1
		_refresh()
	return _act(error)


func set_loadout(new_loadout: Loadout) -> void:
	if loadout != null and loadout.changed.is_connected(_refresh):
		loadout.changed.disconnect(_refresh)
	loadout = new_loadout
	loadout.make_player_army()
	loadout.changed.connect(_refresh)
	selected_squad = 0
	selected_unit = 0 if not loadout.unit_at(0, 0).is_empty() else -1
	if _name_edit != null:
		_name_edit.text = String(loadout.army.get("name", ""))
	_refresh()


## Replace the army with a preset ("starter" or an ArmyPresets archetype) for the player to tweak.
func apply_preset(archetype: String) -> void:
	var catalog := loadout.catalog
	if archetype == "starter":
		set_loadout(GarageScreen.starter_loadout(catalog))
	else:
		set_loadout(ArmyPresets.build(archetype, catalog, preset_seed, true))
		preset_seed += 1
	_show_toast("Preset: %s" % loadout.army["name"], false)


func toggle_share(open: bool) -> void:
	_code_edit.text = ArmyCode.encode(loadout)
	_share_panel.visible = open


## Replace the army with the one in `code`. Returns "" or the reason (also shown as a toast).
func import_code(code: String) -> String:
	var decoded := ArmyCode.decode(code, loadout.catalog)
	if decoded.has("error"):
		return _act(String(decoded["error"]))
	set_loadout(decoded["loadout"])
	var problems := loadout.problems()
	_show_toast("Imported %s" % loadout.army["name"] if problems.is_empty() else "Imported, but: " + problems[0], not problems.is_empty())
	return ""


## Saves under the army's name. Returns the path, or "" (with a toast) on failure.
func save() -> String:
	var saved := ArmyStore.save(loadout.to_doctrine(), ArmyStore.slug(String(loadout.army.get("name", ""))), store_dir)
	if saved.has("error"):
		_act(String(saved["error"]))
		return ""
	_fill_load_menu()
	_show_toast("Saved %s" % saved["path"], false)
	return saved["path"]


## Saves and asks to start the skirmish. Returns the saved path, or "" if the army can't fight yet.
func fight() -> String:
	var problems := loadout.problems()
	if not problems.is_empty():
		_act("Not ready: " + problems[0])
		return ""
	var path := save()
	if path != "":
		fight_requested.emit(path, enemy)
	return path


func _fill_load_menu() -> void:
	if _load_menu == null:
		return
	_load_menu.clear()
	_load_menu.add_item("LOAD...")
	_load_menu.set_item_metadata(0, "")
	for entry in ArmyStore.list(store_dir):
		_load_menu.add_item(String(entry["name"]))
		_load_menu.set_item_metadata(_load_menu.item_count - 1, entry["path"])
	_load_menu.select(0)


func _on_load_selected(index: int) -> void:
	var path := String(_load_menu.get_item_metadata(index))
	_load_menu.select(0)
	if path == "":
		return
	var loaded := ArmyStore.read(path)
	if loaded.has("error"):
		_act(String(loaded["error"]))
		return
	set_loadout(Loadout.from_doctrine(loadout.catalog, loaded["doctrine"]))
	_show_toast("Loaded %s" % loadout.army["name"], false)


func _drop_on_squad(squad_index: int, data: Dictionary) -> void:
	match data.get("kind"):
		"catalog":
			selected_squad = squad_index
			add_unit(String(data["unit"]))
		"unit":
			var error := loadout.move_unit(int(data["squad"]), int(data["unit"]), squad_index)
			if error == "" and int(data["squad"]) != squad_index:
				selected_squad = squad_index
				selected_unit = loadout.squad(squad_index)["tanks"].size() - 1
				_refresh()
			_act(error)


## For the mode and other callers: show a problem the player should know about.
func report(error: String) -> void:
	_act(error)


## Shows `error` as a toast if there is one; returns it.
func _act(error: String) -> String:
	if error != "":
		_show_toast(error, true)
	return error


func _show_toast(text: String, is_error: bool) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", _color("enemy") if is_error else _color("friendly"))
	_toast.visible = true
	_toast_left = 2.5


func toast_text() -> String:
	return _toast.text if _toast != null and _toast.visible else ""


# ---- Drag and drop (Godot's GUI drag works with touch through mouse emulation) ------------------

func _drag(data: Dictionary, preview_text: String) -> Dictionary:
	var preview := _label(preview_text, 1.1)
	preview.add_theme_color_override("font_color", _color("commander"))
	set_drag_preview(preview)
	return data


## Dragging from `control` or anything inside it produces `make_data.call(at_position)`.
func _forward_drag(control: Control, make_data: Callable) -> void:
	for target: Control in [control] + control.find_children("*", "Control", true, false):
		if not target.has_meta("drag_source"):
			target.set_meta("drag_source", make_data)
			target.set_drag_forwarding(make_data, Callable(), Callable())


## `control` and everything inside it accept drops that pass `accepts`; drag sources stay draggable.
func _accept_drops(control: Control, accepts: Callable, on_drop: Callable) -> void:
	for target: Control in [control] + control.find_children("*", "Control", true, false):
		target.set_drag_forwarding(target.get_meta("drag_source", Callable()),
				func(_at: Vector2, data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and accepts.call(data),
				func(_at: Vector2, data: Variant) -> void: on_drop.call(data))
