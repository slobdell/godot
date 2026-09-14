class_name GarageScreen
extends Control
## The army builder (players see "ARMY"): spend a budget on fixed unit types and split them into up to
## 5 squads before a skirmish. Touch first: every action is a tap or a drag, and tap targets scale with
## the screen (≥ 48 px on a 1080p-tall screen).
##
##   UNITS    one card per unit type: role, cost, a blurb, what it's good and weak against, stat bars.
##            Tap + ADD (joins the selected squad) or drag a card onto a squad. COMPARE opens a table.
##   SQUADS   up to catalog.max_squads, each ≤ max_squad_size (5); panels wrap. Tap a squad's name to select
##            it; pick its formation and role. Tap a unit chip to inspect it; drag a chip onto another squad
##            to move it. ADD into a full squad spills into the next one with room.
##   UNIT     the selected unit on a turntable (swipe to spin), its weapon and matchups, army-composition
##            hints, its squad (tap to move), paint, REMOVE.
##   TOP      army name, budget bar, credits (UNLOCKS panel), presets, load, save, delete, share (army codes).
##   BOTTOM   problems, budget tier, opponent, FIGHT.
##
## Progression (Y2): the catalog is the player's view of it (Progression.catalog_for): the chosen tier's budget
## and only unlocked units. Locked cards show their price; UNLOCKS spends credits on units and budget tiers.
##
## Saving: an army remembers the file it came from. SAVE and FIGHT update that file; a new army (starter,
## preset, code) gets a fresh file on its first save, so two armies with the same name never overwrite each
## other. The builder reopens on the army you last fought with. DELETE takes two taps and leaves the army
## open (unsaved), so a mistaken delete is undone by tapping SAVE.
##
## All rules live in ArmyDraft; this file only shows them. Colors come from GameTheme.ui (art owns them)
## with army-specific keys falling back to placeholders here.

signal fight_requested(player_path: String, enemy: String)

const BASE_HEIGHT := 720.0
const FONT_SIZE := 17
## Minimum tap target at BASE_HEIGHT (scaled with the screen: 48 px at 1080p).
const TAP := 40.0
## Opponents: [value for --enemy, label]. "cpu" / "cpu:<archetype>" is a fresh seeded army at the SAME budget each
## fight, built by the rules stream's Army (a test keeps this list in sync with Army.ARCHETYPES).
const ENEMIES := [["cpu", "CPU: Random"], ["cpu:balanced", "CPU: Balanced"], ["cpu:armor", "CPU: Armor"],
		["cpu:recon_strike", "CPU: Recon Strike"], ["cpu:siege", "CPU: Siege"], ["cpu:swarm", "CPU: Swarm"]]

var draft: ArmyDraft
## The player's credits and unlocks (tests use Progression.new(""), in memory).
var progression: Progression
## Every unit the game has; draft.catalog is this at the chosen tier with the player's unlocks.
var base_catalog: ArmyCatalog
## The budget tier this army fights at (≤ progression.budget_tier).
var tier := 0
## Where armies are saved (tests point this elsewhere).
var store_dir := ArmyStore.DIR
var enemy := "cpu"
## Tips and the last army (tests use GarageSettings.new(""), in memory).
var settings: GarageSettings
## The file this army is saved in, or "" if it has never been saved.
var army_path := ""
var selected_squad := 0
## Index in the selected squad, or -1.
var selected_unit := -1
var ui_scale := 1.0

var _name_edit: LineEdit
var _budget_bar: ProgressBar
var _budget_label: Label
var _catalog_box: VBoxContainer
## Squad panels wrap onto new rows, so 5 squads fit a phone-width screen.
var _squads_box: HFlowContainer
var _inspector: VBoxContainer
var _turntable: GarageTurntable
var _problems_label: Label
var _fight_button: Button
var _load_menu: OptionButton
var _delete_button: Button
var _delete_armed_left := 0.0
var _preset_menu: OptionButton
var _enemy_menu: OptionButton
var _toast: Label
var _tip_bar: HBoxContainer
var _tip_label: Label
var _share_panel: PanelContainer
var _compare_panel: PanelContainer
var _code_edit: LineEdit
var _unlock_panel: PanelContainer
var _credits_button: Button
var _tier_menu: OptionButton
var _toast_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = GarageSettings.new()
	if progression == null:
		progression = Progression.new()
	if base_catalog == null:
		base_catalog = draft.catalog if draft != null else ArmyCatalog.from_game()
	tier = clampi(tier, 0, progression.budget_tier)
	if draft == null:
		draft = GarageScreen.starter_army(progression.catalog_for(base_catalog, tier))
		_reopen_last_army()
	else:
		draft.catalog = progression.catalog_for(base_catalog, tier)
	draft.tier = tier
	draft.changed.connect(_on_draft_changed)
	# Open on the first unit so the turntable shows something right away.
	selected_unit = 0 if not draft.unit_at(0, 0).is_empty() else -1
	resized.connect(_rebuild_if_scaled)
	_build()


## A ready-to-fight army for a first visit: the starter preset at the catalog's budget.
static func starter_army(catalog: ArmyCatalog) -> ArmyDraft:
	var starter := ArmyPresets.build(ArmyPresets.STARTER, catalog)
	starter.set_army_name("My Army")
	return starter


func _reopen_last_army() -> void:
	if settings.last_army == "" or not FileAccess.file_exists(settings.last_army):
		return
	var loaded := ArmyStore.read(settings.last_army)
	if loaded.has("doctrine"):
		draft = ArmyDraft.from_doctrine(draft.catalog, loaded["doctrine"])
		draft.make_player_army()
		army_path = settings.last_army
		tier = clampi(draft.tier, 0, progression.budget_tier)
		draft.catalog = progression.catalog_for(base_catalog, tier)


func _process(delta: float) -> void:
	if _delete_armed_left > 0.0:
		_delete_armed_left -= delta
		if _delete_armed_left <= 0.0 and _delete_button != null:
			_delete_button.text = "DELETE"
	if _toast_left > 0.0:
		_toast_left -= delta
		_toast.modulate.a = clampf(_toast_left / 0.4, 0.0, 1.0)
		_toast.visible = _toast_left > 0.0


# ---- Palette (art may add these keys to GameTheme.ui) ----------------------------------------------

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


# ---- Layout ----------------------------------------------------------------------------------------

func _rebuild_if_scaled() -> void:
	if not is_equal_approx(_scale_for(size.y), ui_scale):
		_build()


static func _scale_for(height: float) -> float:
	return maxf(1.0, height / BASE_HEIGHT) if height > 0.0 else 1.0


func _build() -> void:
	ui_scale = _scale_for(size.y if size.y > 0.0 else get_viewport_rect().size.y)
	# A rebuild (the window changed size) keeps open overlays open.
	var compare_open := _compare_panel != null and _compare_panel.visible
	var share_open := _share_panel != null and _share_panel.visible
	var unlocks_open := _unlock_panel != null and _unlock_panel.visible
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
	rows.add_child(_build_tip_bar())

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(10 * ui_scale))
	rows.add_child(body)
	body.add_child(_column("UNITS", 1.0, func(box: VBoxContainer) -> void: _catalog_box = box))
	var squads_scroll := _column("SQUADS", 1.5, func(_box: VBoxContainer) -> void: pass)
	_squads_box = HFlowContainer.new()
	_squads_box.add_theme_constant_override("h_separation", int(8 * ui_scale))
	_squads_box.add_theme_constant_override("v_separation", int(8 * ui_scale))
	_squads_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_squads_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	squads_scroll.get_meta("box").add_child(_squads_box)
	body.add_child(squads_scroll)
	body.add_child(_column("UNIT", 1.0, func(box: VBoxContainer) -> void: _inspector = box))

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
	_build_compare_panel()
	_build_unlock_panel()
	move_child(_toast, get_child_count() - 1)

	_turntable = GarageTurntable.new()
	_turntable.name = "Turntable"
	_turntable.custom_minimum_size = Vector2(0, 170 * ui_scale)
	_build_catalog()
	_refresh()
	toggle_compare(compare_open)
	if share_open:
		toggle_share(true)
	toggle_unlocks(unlocks_open)


func _build_top_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(10 * ui_scale))
	var title := _label("ARMY", 1.5)
	title.add_theme_color_override("font_color", _color("commander"))
	bar.add_child(title)
	_name_edit = LineEdit.new()
	_name_edit.name = "ArmyName"
	_name_edit.text = String(draft.army.get("name", ""))
	_name_edit.placeholder_text = "Army name"
	_name_edit.max_length = 32
	_name_edit.custom_minimum_size = Vector2(200 * ui_scale, TAP * ui_scale)
	_name_edit.text_changed.connect(func(text: String) -> void: draft.set_army_name(text))
	bar.add_child(_name_edit)

	var budget := VBoxContainer.new()
	budget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	budget.add_theme_constant_override("separation", 0)
	_budget_label = _label("", 0.9)
	_budget_label.clip_text = true
	budget.add_child(_budget_label)
	_budget_bar = ProgressBar.new()
	_budget_bar.name = "BudgetBar"
	_budget_bar.show_percentage = false
	_budget_bar.custom_minimum_size = Vector2(0, 14 * ui_scale)
	budget.add_child(_budget_bar)
	bar.add_child(budget)

	_credits_button = _button("", func() -> void: toggle_unlocks(true))
	_credits_button.name = "Credits"
	_credits_button.tooltip_text = "Spend credits on new unit types and bigger budgets"
	_credits_button.add_theme_color_override("font_color", _color("commander"))
	bar.add_child(_credits_button)

	_preset_menu = OptionButton.new()
	_preset_menu.name = "PresetMenu"
	_preset_menu.custom_minimum_size = Vector2(140 * ui_scale, TAP * ui_scale)
	_preset_menu.add_item("PRESETS...")
	_preset_menu.set_item_metadata(0, "")
	for preset in ArmyPresets.ids():
		var missing := ArmyPresets.missing_units(preset, draft.catalog).map(func(id: String) -> String: return draft.catalog.display_name(id))
		_preset_menu.add_item(ArmyPresets.label(preset) + ("" if missing.is_empty() else "  (needs %s)" % ", ".join(missing)))
		_preset_menu.set_item_metadata(_preset_menu.item_count - 1, preset)
		_preset_menu.set_item_tooltip(_preset_menu.item_count - 1, ArmyPresets.blurb(preset))
	_preset_menu.item_selected.connect(func(index: int) -> void:
		var preset := String(_preset_menu.get_item_metadata(index))
		_preset_menu.select(0)
		if preset != "":
			apply_preset(preset))
	bar.add_child(_preset_menu)
	_load_menu = OptionButton.new()
	_load_menu.name = "LoadMenu"
	_load_menu.custom_minimum_size = Vector2(120 * ui_scale, TAP * ui_scale)
	_load_menu.item_selected.connect(_on_load_selected)
	bar.add_child(_load_menu)
	_fill_load_menu()
	var save_button := _button("SAVE", func() -> void: save())
	save_button.name = "Save"
	bar.add_child(save_button)
	_delete_button = _button("DELETE", func() -> void: delete_army())
	_delete_button.name = "Delete"
	_delete_button.add_theme_color_override("font_color", _color("enemy"))
	bar.add_child(_delete_button)
	var share := _button("SHARE", func() -> void: toggle_share(true))
	share.name = "Share"
	bar.add_child(share)
	return bar


func _build_tip_bar() -> Control:
	_tip_bar = HBoxContainer.new()
	_tip_bar.name = "TipBar"
	_tip_label = _label("", 1.0)
	_tip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tip_label.add_theme_color_override("font_color", _color("commander"))
	_tip_bar.add_child(_tip_label)
	var skip := _button("X", func() -> void:
		settings.skip_tips()
		_refresh_tip())
	skip.name = "SkipTips"
	skip.tooltip_text = "Hide tips"
	_tip_bar.add_child(skip)
	_refresh_tip()
	return _tip_bar


func _refresh_tip() -> void:
	_tip_label.text = settings.tip()
	_tip_bar.visible = _tip_label.text != ""


func _tutorial(event: String) -> void:
	if settings.notify(event) and _tip_bar != null:
		_refresh_tip()


func _build_bottom_bar() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", int(10 * ui_scale))
	_problems_label = _label("", 0.95)
	_problems_label.name = "Problems"
	_problems_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_problems_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bar.add_child(_problems_label)
	_tier_menu = OptionButton.new()
	_tier_menu.name = "TierMenu"
	_tier_menu.custom_minimum_size = Vector2(200 * ui_scale, TAP * 1.3 * ui_scale)
	_tier_menu.tooltip_text = "Budget tier: both armies spend the same budget"
	for info: Dictionary in Progression.BUDGET_TIERS:
		var owned := int(info["tier"]) <= progression.budget_tier
		_tier_menu.add_item(Progression.tier_label(int(info["tier"])) + ("" if owned else " (locked)"))
		_tier_menu.set_item_disabled(_tier_menu.item_count - 1, not owned)
	_tier_menu.select(tier)
	_tier_menu.item_selected.connect(func(index: int) -> void: set_tier(index))
	bar.add_child(_tier_menu)
	_enemy_menu = OptionButton.new()
	_enemy_menu.name = "EnemyMenu"
	_enemy_menu.custom_minimum_size = Vector2(210 * ui_scale, TAP * 1.3 * ui_scale)
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
	panel.name = "Column_" + title
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


## A wrapping, dim label for longer text.
func _note(text: String, relative_size := 0.8, color_key := "garage_text_dim") -> Label:
	var label := _label(text, relative_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _color(color_key))
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
	rows.add_child(_note("Copy this code to share your army, or paste a friend's code and tap IMPORT.", 0.85, "garage_text_dim"))
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


## An overlay comparing every unit type (GarageAdvice.unit_table).
func _build_compare_panel() -> void:
	_compare_panel = PanelContainer.new()
	_compare_panel.name = "ComparePanel"
	_compare_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_compare_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_compare_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_compare_panel.add_theme_stylebox_override("panel", _panel_style(_color("commander"), 3))
	_compare_panel.visible = false
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(10 * ui_scale))
	_compare_panel.add_child(rows)
	rows.add_child(_section("UNIT TYPES"))
	rows.add_child(_table_grid(GarageAdvice.unit_table(draft.catalog), "UnitTable"))
	rows.add_child(_note("Good vs / weak vs is what each unit is built for. Fights decide the rest: angles, range, and focus fire.", 0.8))
	var close := _button("CLOSE", func() -> void: _compare_panel.visible = false)
	close.name = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	rows.add_child(close)
	add_child(_compare_panel)


func _table_grid(table: Dictionary, grid_name: String) -> GridContainer:
	var grid := GridContainer.new()
	grid.name = grid_name
	grid.columns = table["headers"].size()
	grid.add_theme_constant_override("h_separation", int(18 * ui_scale))
	for header: String in table["headers"]:
		var cell := _label(header, 0.8)
		cell.add_theme_color_override("font_color", _color("garage_text_dim"))
		grid.add_child(cell)
	for row_index in table["rows"].size():
		for column in table["rows"][row_index].size():
			var cell := _label(String(table["rows"][row_index][column]), 0.9)
			if table["best"][row_index][column]:
				cell.add_theme_color_override("font_color", _color("friendly"))
			grid.add_child(cell)
	return grid


func toggle_compare(open: bool) -> void:
	_compare_panel.visible = open


# ---- Unit cards ------------------------------------------------------------------------------------

func _build_catalog() -> void:
	var catalog := draft.catalog
	for unit_id in catalog.unit_ids():
		_catalog_box.add_child(_unit_card(unit_id))
	var compare := _button("COMPARE", func() -> void: toggle_compare(true))
	compare.name = "Compare"
	_catalog_box.add_child(compare)


func _unit_card(unit_id: String) -> Control:
	var catalog := draft.catalog
	var unlocked := catalog.is_unlocked(unit_id)
	var card := PanelContainer.new()
	card.name = "Card_" + unit_id
	card.add_theme_stylebox_override("panel", _panel_style(_color("friendly").darkened(0.45) if unlocked else _color("garage_text_dim").darkened(0.6)))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(2 * ui_scale))
	card.add_child(rows)
	var header := HBoxContainer.new()
	var title := _label(catalog.display_name(unit_id).to_upper(), 1.1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var cost := _label("%d" % catalog.unit_cost(unit_id), 1.1)
	cost.add_theme_color_override("font_color", _color("commander"))
	header.add_child(cost)
	rows.add_child(header)
	rows.add_child(_note(catalog.weapon_name(unit_id) + (" (fixed forward)" if catalog.mount_label(unit_id).begins_with("fixed") else " (turret)"), 0.8))
	if catalog.blurb(unit_id) != "":
		rows.add_child(_note(catalog.blurb(unit_id), 0.8))
	var good := catalog.matchup_text(unit_id, true)
	if good != "":
		var good_label := _note(good, 0.85, "friendly")
		good_label.name = "GoodVs"
		rows.add_child(good_label)
	var weak := catalog.matchup_text(unit_id, false)
	if weak != "":
		var weak_label := _note(weak, 0.85, "enemy")
		weak_label.name = "WeakVs"
		rows.add_child(weak_label)
	var stats := GridContainer.new()
	stats.columns = 2
	for bar_data in catalog.unit_stat_bars(unit_id):
		var stat_label := _label("%s %s" % [bar_data["label"], ArmyCatalog.number(bar_data["value"])], 0.75)
		stat_label.add_theme_color_override("font_color", _color("garage_text_dim"))
		stats.add_child(stat_label)
		stats.add_child(_stat_bar(bar_data["ratio"], ArmyCatalog.number(bar_data["value"])))
	rows.add_child(stats)
	var price := Progression.unit_unlock_credits(catalog, unit_id)
	var add := _button("+ ADD" if unlocked else "UNLOCK  %d CR" % price, func() -> void:
		if catalog.is_unlocked(unit_id):
			add_unit(unit_id)
		else:
			_show_toast("The %s is locked: unlock it for %d credits (you have %d)." % [catalog.display_name(unit_id), price, progression.credits], true)
			toggle_unlocks(true))
	add.name = "Add_" + unit_id
	rows.add_child(add)
	if unlocked:
		_forward_drag(card, func(_at: Vector2) -> Variant: return _drag({"kind": "catalog", "unit": unit_id}, catalog.display_name(unit_id)))
	else:
		card.modulate = Color(1, 1, 1, 0.7)
	return card


func _stat_bar(ratio: float, value_text: String) -> Control:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.max_value = 1.0
	bar.value = ratio
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size = Vector2(50 * ui_scale, 8 * ui_scale)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _color("friendly")
	bar.add_theme_stylebox_override("fill", fill)
	bar.tooltip_text = value_text
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	return bar


# ---- Refresh (everything that depends on the army) -----------------------------------------------

func _on_draft_changed() -> void:
	_tutorial("edit")
	_refresh()


func _refresh() -> void:
	if _squads_box == null:
		return
	selected_squad = clampi(selected_squad, 0, maxi(draft.squads().size() - 1, 0))
	if draft.unit_at(selected_squad, selected_unit).is_empty():
		selected_unit = -1
	_refresh_budget()
	_refresh_credits()
	_refresh_delete()
	_refresh_squads()
	_refresh_inspector()
	_refresh_problems()


func _refresh_budget() -> void:
	var catalog := draft.catalog
	var spent := draft.total_cost()
	_budget_bar.max_value = catalog.budget
	_budget_bar.value = mini(spent, catalog.budget)
	var fill := StyleBoxFlat.new()
	fill.bg_color = _color("enemy") if spent > catalog.budget else _color("commander")
	_budget_bar.add_theme_stylebox_override("fill", fill)
	_budget_label.text = "BUDGET  %d / %d   (%d left)      UNITS  %d / %d" % [spent, catalog.budget,
			catalog.budget - spent, draft.unit_count(), catalog.max_units]


func _refresh_squads() -> void:
	_clear(_squads_box)
	for squad_index in draft.squads().size():
		_squads_box.add_child(_squad_panel(squad_index))
	if draft.squads().size() < draft.catalog.max_squads:
		var add := _button("+\nSQUAD", func() -> void: _act(draft.add_squad()))
		add.name = "AddSquad"
		add.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		_squads_box.add_child(add)


func _squad_panel(squad_index: int) -> Control:
	var squad_data := draft.squad(squad_index)
	var selected := squad_index == selected_squad
	var panel := PanelContainer.new()
	panel.name = "Squad_%d" % squad_index
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.x = 200 * ui_scale
	panel.add_theme_stylebox_override("panel", _panel_style(_color("commander") if selected else _color("garage_text_dim").darkened(0.4),
			3 if selected else 1))
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(6 * ui_scale))
	panel.add_child(rows)

	var header := HBoxContainer.new()
	var entries: Array = squad_data.get("units", [])
	var squad_cost := 0
	for entry: Dictionary in entries:
		squad_cost += draft.unit_cost(entry)
	var title := _button("%s  %d/%d" % [String(squad_data["name"]).to_upper(), entries.size(), draft.catalog.max_squad_size],
			func() -> void: select_squad(squad_index))
	title.name = "Select"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.flat = true
	title.alignment = HORIZONTAL_ALIGNMENT_LEFT
	title.add_theme_font_size_override("font_size", int(FONT_SIZE * 1.1 * ui_scale))
	header.add_child(title)
	var remove := _button("X", func() -> void: _act(draft.remove_squad(squad_index)))
	remove.name = "Remove"
	remove.tooltip_text = "Remove this squad and its units"
	header.add_child(remove)
	rows.add_child(header)

	rows.add_child(_option_menu("Formation", Formations.NAMES, String(squad_data.get("formation", Formations.DEFAULT)),
			func(value: String) -> void: _act(draft.set_formation(squad_index, value))))
	var role := String(squad_data.get("directive", {}).get("role", "assault")) if typeof(squad_data.get("directive")) == TYPE_DICTIONARY else "assault"
	rows.add_child(_option_menu("Role", Directives.ROLES, role,
			func(value: String) -> void: _act(draft.set_squad_role(squad_index, value))))

	for unit_index in entries.size():
		var entry: Dictionary = entries[unit_index]
		var chip := _button(_chip_text(entry), func() -> void: select_unit(squad_index, unit_index))
		chip.name = "Unit_%d" % unit_index
		chip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		chip.clip_text = true
		_style_choice(chip, selected and unit_index == selected_unit)
		if draft.unit_problem(entry) != "":
			chip.add_theme_color_override("font_color", _color("enemy"))
		_forward_drag(chip, func(_at: Vector2) -> Variant: return _drag(
				{"kind": "unit", "squad": squad_index, "unit": unit_index}, _chip_text(entry)))
		rows.add_child(chip)
	if entries.is_empty():
		rows.add_child(_note("Empty: tap + ADD or drag a unit here", 0.8))
	else:
		rows.add_child(_note("%d pts" % squad_cost, 0.75))
	_accept_drops(panel, func(data: Dictionary) -> bool: return data.get("kind") in ["catalog", "unit"],
			func(data: Dictionary) -> void: _drop_on_squad(squad_index, data))
	return panel


func _chip_text(entry: Dictionary) -> String:
	var unit_id := String(entry.get("unit", ""))
	return "%s   %d" % [draft.catalog.display_name(unit_id), draft.unit_cost(entry)]


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
	var entry := draft.unit_at(selected_squad, selected_unit)
	if entry.is_empty():
		_inspector.add_child(_note("Tap a unit in a squad to see what it's good and weak against.", 1.0))
		_add_composition_hints()
		return
	var catalog := draft.catalog
	var unit_id := String(entry["unit"])
	_inspector.add_child(_turntable)
	_turntable.show_unit(entry, _paint_color(entry), catalog.weapon_id(unit_id))

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", int(12 * ui_scale))
	var title := _label("%s  %s #%d" % [draft.squad(selected_squad)["name"], catalog.display_name(unit_id), selected_unit + 1], 1.1)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	header.add_child(title)
	var cost := _label("%d" % draft.unit_cost(entry), 1.1)
	cost.add_theme_color_override("font_color", _color("commander"))
	header.add_child(cost)
	# In the header so it's reachable without scrolling on a short screen.
	var remove := _button("REMOVE", func() -> void: _act(draft.remove_unit(selected_squad, selected_unit)))
	remove.name = "RemoveUnit"
	remove.add_theme_color_override("font_color", _color("enemy"))
	header.add_child(remove)
	_inspector.add_child(header)

	var problem := draft.unit_problem(entry)
	if problem != "":
		_inspector.add_child(_note(problem.substr(0, 1).to_upper() + problem.substr(1), 0.9, "enemy"))
	var weapon := _note(catalog.weapon_summary(unit_id), 0.8)
	weapon.name = "WeaponSummary"
	_inspector.add_child(weapon)
	for strong in [true, false]:
		var text := catalog.matchup_text(unit_id, strong)
		if text != "":
			_inspector.add_child(_note(text, 0.9, "friendly" if strong else "enemy"))
	_add_composition_hints()

	if draft.squads().size() > 1:
		var squad_names: Array = draft.squads().map(func(squad_data: Dictionary) -> String: return String(squad_data["name"]))
		_inspector.add_child(_option_menu("Squad", squad_names, String(draft.squad(selected_squad)["name"]),
				func(value: String) -> void: move_selected_unit(squad_names.find(value))))

	_inspector.add_child(_section("PAINT (free)"))
	var paints := HFlowContainer.new()
	paints.name = "Paints"
	for paint: String in ArmyDraft.PAINTS:
		var swatch := _button("TEAM" if paint == "" else "", func() -> void: _act(draft.set_paint(selected_squad, selected_unit, paint)))
		var style := _panel_style(_color("commander") if String(entry.get("paint", "")) == paint else Color(0, 0, 0, 0), 3)
		style.bg_color = GameTheme.team_color(Match.Team.GREEN) if paint == "" else Color.html(paint)
		for state in ["normal", "hover", "pressed"]:
			swatch.add_theme_stylebox_override(state, style)
		paints.add_child(swatch)
	_inspector.add_child(paints)


func _add_composition_hints() -> void:
	for hint in GarageAdvice.composition_hints(draft):
		var advice := _note("> " + hint, 0.8, "commander")
		advice.name = "Advice"
		_inspector.add_child(advice)


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


func _paint_color(entry: Dictionary) -> Color:
	var paint := String(entry.get("paint", ""))
	return Color.html(paint) if paint != "" and Color.html_is_valid(paint) else GameTheme.team_color(Match.Team.GREEN)


func _refresh_problems() -> void:
	var problems := draft.problems()
	if problems.is_empty():
		_problems_label.text = "READY: %s, %d units. Tap FIGHT." % [draft.army.get("name", ""), draft.unit_count()]
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


# ---- Progression: credits, unlocks, tiers ---------------------------------------------------------

func _refresh_credits() -> void:
	if _credits_button != null:
		_credits_button.text = "CREDITS %d" % progression.credits


## An overlay to spend credits: each locked unit type, and the next budget tier.
func _build_unlock_panel() -> void:
	_unlock_panel = PanelContainer.new()
	_unlock_panel.name = "UnlockPanel"
	_unlock_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_unlock_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_unlock_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_unlock_panel.custom_minimum_size = Vector2(640 * ui_scale, 0)
	_unlock_panel.add_theme_stylebox_override("panel", _panel_style(_color("commander"), 3))
	_unlock_panel.visible = false
	add_child(_unlock_panel)


func _fill_unlock_panel() -> void:
	_clear(_unlock_panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(10 * ui_scale))
	_unlock_panel.add_child(rows)
	rows.add_child(_section("UNLOCKS: %d CREDITS   (record %d won, %d lost)" % [progression.credits, progression.wins, progression.losses]))
	rows.add_child(_note("Win matches to earn credits. New units add options, not power: both armies always fight at the same budget.", 0.85))
	var any_locked := false
	for unit_id in base_catalog.unit_ids():
		if progression.has_unit(base_catalog, unit_id):
			continue
		any_locked = true
		rows.add_child(_unlock_row("Unlock_" + unit_id, "%s: %s" % [base_catalog.display_name(unit_id).to_upper(), base_catalog.matchup_text(unit_id, true)],
				base_catalog.blurb(unit_id), Progression.unit_unlock_credits(base_catalog, unit_id),
				func() -> String: return progression.unlock_unit(base_catalog, unit_id)))
	if not any_locked:
		rows.add_child(_note("Every unit type is unlocked.", 0.9, "friendly"))
	var next := progression.next_tier()
	if next.is_empty():
		rows.add_child(_note("You have the biggest budget tier.", 0.9, "friendly"))
	else:
		rows.add_child(_unlock_row("UnlockTier", "BUDGET TIER: %s" % Progression.tier_label(int(next["tier"])),
				"Bigger armies: both sides spend %d." % int(next["budget"]), int(next["unlock_credits"]),
				func() -> String: return progression.unlock_next_tier()))
	var close := _button("CLOSE", func() -> void: toggle_unlocks(false))
	close.name = "Close"
	close.size_flags_horizontal = Control.SIZE_SHRINK_END
	rows.add_child(close)


func _unlock_row(row_name: String, title: String, detail: String, price: int, unlock: Callable) -> Control:
	var row := HBoxContainer.new()
	row.name = row_name
	row.add_theme_constant_override("separation", int(12 * ui_scale))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_child(_label(title, 0.95))
	text.add_child(_note(detail, 0.8))
	row.add_child(text)
	var buy := _button("UNLOCK  %d" % price, func() -> void:
		var error: String = unlock.call()
		if error == "":
			_on_unlocked()
		else:
			_act(error))
	buy.name = "Buy"
	buy.disabled = progression.credits < price
	buy.custom_minimum_size.x = 150 * ui_scale
	row.add_child(buy)
	return row


func _on_unlocked() -> void:
	_show_toast("Unlocked! %d credits left." % progression.credits, false)
	set_tier(tier)
	toggle_unlocks(true)


func toggle_unlocks(open: bool) -> void:
	if open:
		_fill_unlock_panel()
	_unlock_panel.visible = open


## Fight at `new_tier`'s budget (clamped to the tiers owned). The army keeps its units; over budget shows as a problem.
func set_tier(new_tier: int) -> void:
	tier = clampi(new_tier, 0, progression.budget_tier)
	draft.catalog = progression.catalog_for(base_catalog, tier)
	draft.tier = tier
	_build()


# ---- Actions (public, so tests and presets drive the same paths as taps) -----------------------------

func select_squad(squad_index: int) -> void:
	if squad_index != selected_squad:
		selected_unit = -1
	selected_squad = squad_index
	_refresh()


func select_unit(squad_index: int, unit_index: int) -> void:
	selected_squad = squad_index
	selected_unit = unit_index
	_tutorial("select_unit")
	_refresh()


## Adds to the selected squad, or (when it's full) the next squad with room, starting a new one if allowed.
func add_unit(unit_id: String) -> String:
	if not draft.catalog.is_unlocked(unit_id):
		return _act("The %s is locked." % draft.catalog.display_name(unit_id))
	if draft.unit_count() >= draft.catalog.max_units:
		return _act("The army is full: %d units max." % draft.catalog.max_units)
	if draft.catalog.unit_cost(unit_id) > draft.remaining_budget():
		return _act("Not enough budget: a %s costs %d, %d left." % [draft.catalog.display_name(unit_id),
				draft.catalog.unit_cost(unit_id), draft.remaining_budget()])
	var target := draft.squad_with_room(selected_squad)
	if target < 0:
		return _act("Every squad is full.")
	var error := draft.add_unit(target, unit_id)
	if error == "":
		if target != selected_squad and not draft.squad(selected_squad).is_empty():
			_show_toast("%s is full: added to %s." % [draft.squad(selected_squad)["name"], draft.squad(target)["name"]], false)
		selected_squad = target
		selected_unit = draft.units_of(target).size() - 1
		_refresh()
	return _act(error)


## Tap alternative to dragging a unit chip: move the selected unit to another squad.
func move_selected_unit(to_squad: int) -> String:
	var error := draft.move_unit(selected_squad, selected_unit, to_squad)
	if error == "" and to_squad != selected_squad:
		selected_squad = to_squad
		selected_unit = draft.units_of(to_squad).size() - 1
		_refresh()
	return _act(error)


## `path`: the file the army was loaded from ("" = a new, unsaved army).
func set_draft(new_draft: ArmyDraft, path := "") -> void:
	army_path = path
	if draft != null and draft.changed.is_connected(_on_draft_changed):
		draft.changed.disconnect(_on_draft_changed)
	draft = new_draft
	draft.catalog = progression.catalog_for(base_catalog, tier)
	draft.tier = tier
	draft.make_player_army()
	draft.changed.connect(_on_draft_changed)
	selected_squad = 0
	selected_unit = 0 if not draft.unit_at(0, 0).is_empty() else -1
	if _name_edit != null:
		_name_edit.text = String(draft.army.get("name", ""))
	_refresh()
	if not draft.notes.is_empty():
		_show_toast(draft.notes[0], false)


## Replace the army with a preset (ArmyPresets id) for the player to tweak.
func apply_preset(preset: String) -> void:
	set_draft(ArmyPresets.build(preset, draft.catalog))
	_show_toast("Preset: %s. %s" % [draft.army["name"], ArmyPresets.blurb(preset)], false)


func toggle_share(open: bool) -> void:
	_code_edit.text = ArmyCode.encode(draft)
	_share_panel.visible = open


## Replace the army with the one in `code`. Returns "" or the reason (also shown as a toast).
func import_code(code: String) -> String:
	var decoded := ArmyCode.decode(code, draft.catalog)
	if decoded.has("error"):
		return _act(String(decoded["error"]))
	set_draft(decoded["draft"])
	var problems := draft.problems()
	_show_toast("Imported %s" % draft.army["name"] if problems.is_empty() else "Imported, but: " + problems[0], not problems.is_empty())
	return ""


## Saves to the army's own file (a new file the first time). Returns the path, or "" (with a toast) on failure.
func save() -> String:
	var stem := army_path.get_file().get_basename() if army_path != "" \
			else ArmyStore.unused_stem(String(draft.army.get("name", "")), store_dir)
	var dir := army_path.get_base_dir() if army_path != "" else store_dir
	var saved := ArmyStore.save(draft.to_doctrine(), stem, dir)
	if saved.has("error"):
		_act(String(saved["error"]))
		return ""
	army_path = saved["path"]
	_fill_load_menu()
	_refresh_delete()
	_show_toast("Saved %s" % draft.army.get("name", ""), false)
	return army_path


## First tap arms, a second tap within 3 s deletes the saved file. The army stays open, unsaved.
func delete_army() -> void:
	if army_path == "":
		return
	if _delete_armed_left <= 0.0:
		_delete_armed_left = 3.0
		_delete_button.text = "CONFIRM?"
		return
	ArmyStore.remove(army_path.get_file().get_basename(), army_path.get_base_dir())
	if settings.last_army == army_path:
		settings.remember_army("")
	army_path = ""
	_delete_armed_left = 0.0
	_fill_load_menu()
	_refresh_delete()
	_show_toast("Deleted. It's still open: tap SAVE to keep it after all.", false)


func _refresh_delete() -> void:
	if _delete_button != null:
		_delete_button.text = "DELETE"
		_delete_button.visible = army_path != ""


## Saves and asks to start the skirmish. Returns the saved path, or "" if the army can't fight yet.
func fight() -> String:
	var problems := draft.problems()
	if not problems.is_empty():
		_act("Not ready: " + problems[0])
		return ""
	var path := save()
	if path != "":
		settings.remember_army(path)
		_tutorial("fight")
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
	set_draft(ArmyDraft.from_doctrine(draft.catalog, loaded["doctrine"]), path)
	if draft.notes.is_empty():
		_show_toast("Loaded %s" % draft.army["name"], false)


func _drop_on_squad(squad_index: int, data: Dictionary) -> void:
	match data.get("kind"):
		"catalog":
			selected_squad = squad_index
			add_unit(String(data["unit"]))
		"unit":
			var error := draft.move_unit(int(data["squad"]), int(data["unit"]), squad_index)
			if error == "" and int(data["squad"]) != squad_index:
				selected_squad = squad_index
				selected_unit = draft.units_of(squad_index).size() - 1
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
	_toast_left = 3.0


func toast_text() -> String:
	return _toast.text if _toast != null and _toast.visible else ""


# ---- Drag and drop (Godot's GUI drag works with touch through mouse emulation) ------------------------

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
