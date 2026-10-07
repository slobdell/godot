class_name GarageScreen
extends Control
## The garage (round 19, G3): one screen, three questions, then FIGHT. The lead: *"each player is given 1000 credits per
## game ... Each vehicle has a cost, and they allocate so many credits to buy the units they want, and the player should
## be able to group squads however they want ... This UX should be relatively simple, the beauty of this game is its
## simplicity. In the UI in the garage we also want chamfered borders"* (2026-10-05). Built from the kit
## (`_agents/ui_kit.md`).
##
##   TOP       GARAGE · the credits left (always visible) · VS <the CPU's faction> · FIGHT (green)
##   1 FACTION four cards; a tap switches roster (each faction keeps its own army while he looks around)
##   2 VEHICLES one card per vehicle: name, job, price. TAP BUYS one into the selected squad (a full squad spills into
##             the next with room, then a new squad); drag a card onto a squad to buy it there
##   3 SQUADS  up to five, any mix, five vehicles each. Tap a squad's name to send buys there. TAP A CHIP to pick it up:
##             then tap another squad to move it there, or tap it again to SELL it. Drag a chip onto a squad to move it,
##             onto the vehicles to sell it. + NEW SQUAD; an empty squad disappears unless it is the one selected.
##             SUGGESTED rebuilds the faction's suggested army; CLEAR sells everything.
## Formation and role are not set here: he sets formations in the match (round 18's picker), per squad (round 19).
## All rules live in ArmyDraft; prices and the budget are the catalog's credits (ArmyCatalog.for_game, Credits).
##
## Saving: FIGHT saves the army to its own file (a new army gets a fresh one) and the garage reopens on the army he
## last fought with; the file is army JSON v2 as before (ArmyFormat; `garage.tier` kept for older saves).

signal fight_requested(player_path: String, enemy: String)

## The CPU's choices, in the VS cycle: random (rolled from the fight's seed, never a mirror) then each faction.
const RANDOM := "random"
## Round 20 (R2): how tall a vehicle card's picture is at 1080 (the card is about 370 wide in two columns).
const CARD_PICTURE_HEIGHT := 104.0
## Round 22 (A2): a cap of up to this many squads is one column; over it (ten), two columns of five.
const ONE_COLUMN_MAX := 5
## Round 22 (A2): the squad header's width in two columns at 1080 (the longest name, FOXTROT, over its count).
const HEADER_NARROW := 92.0

var draft: ArmyDraft
## The record of play (wins, the earned total; never spent here). Tests use Progression.new(""), in memory.
var progression: Progression
## Every unit at points (challenge missions still read it; the garage's own catalog is draft.catalog).
var base_catalog: ArmyCatalog
## Where armies are saved (tests point this elsewhere).
var store_dir := ArmyStore.DIR
## The CPU's army: "cpu" (a seeded mix of its faction) or "cpu:<archetype>".
var enemy := "cpu"
## The CPU's faction: RANDOM or a Units.FACTIONS name.
var enemy_faction := RANDOM
## The player's faction (the roster on show).
var faction := Units.DEFAULT_FACTION
## Tips and the last army (tests use GarageSettings.new(""), in memory).
var settings: GarageSettings
## The file this army is saved in, or "" if it has never been saved.
var army_path := ""
## Where a tap on a vehicle buys it.
var selected_squad := 0
## A chip picked up for a tap-tap move or a sell: [squad, index], or [] when nothing is picked.
var picked: Array = []
var ui_scale := 1.0

## Each faction's army while he looks around: faction -> [ArmyDraft, army_path].
var _armies := {}
var _meter: CyberMeter
var _status: Label
var _status_is_error := false
var _fight: Button
var _vs: Button
var _faction_row: HBoxContainer
var _vehicles: GridContainer
var _squads: GridContainer
var _share: LineEdit
var _built_height := -1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	if settings == null:
		settings = GarageSettings.new()
	if progression == null:
		progression = Progression.new()
	if base_catalog == null:
		base_catalog = ArmyCatalog.from_game()
	if draft != null:
		faction = ArmyCatalog.faction_of_army(draft.army)
		_adopt(ArmyDraft.from_doctrine(ArmyCatalog.for_game(faction), draft.army), army_path)
	elif not _reopen_last_army():
		_adopt(GarageSuggest.draft(ArmyCatalog.for_game(faction)), "")
	resized.connect(_rebuild_if_scaled)
	_build()


## A first visit's army: the faction's suggested army (kept for callers of the old name).
static func starter_army(catalog: ArmyCatalog) -> ArmyDraft:
	return GarageSuggest.draft(catalog)


func _reopen_last_army() -> bool:
	if settings.last_army == "" or not FileAccess.file_exists(settings.last_army):
		return false
	var loaded := ArmyStore.read(settings.last_army)
	if not loaded.has("doctrine"):
		return false
	faction = ArmyCatalog.faction_of_army(loaded["doctrine"])
	_adopt(ArmyDraft.from_doctrine(ArmyCatalog.for_game(faction), loaded["doctrine"]), settings.last_army)
	return true


## Make `new_draft` the army on show (a player army: squads formed up and holding), remembered for its faction.
func _adopt(new_draft: ArmyDraft, path: String) -> void:
	if draft != null and draft.changed.is_connected(_on_changed):
		draft.changed.disconnect(_on_changed)
	draft = new_draft
	draft.make_player_army()
	if draft.squads().is_empty():
		draft.add_squad()
	army_path = path
	selected_squad = 0
	picked = []
	_status_is_error = false
	draft.changed.connect(_on_changed)
	_armies[faction] = [draft, army_path]


# ---- Layout -----------------------------------------------------------------------------------------------

func _rebuild_if_scaled() -> void:
	if not is_equal_approx(size.y, _built_height):
		_build()


func _build() -> void:
	_built_height = size.y
	for child in get_children():
		remove_child(child)
		child.queue_free()
	ui_scale = CyberKit.s(self) * CyberStyle.touch_boost()
	var s := ui_scale
	var backdrop := ColorRect.new()
	backdrop.color = Color(CyberStyle.HUD_BACKGROUND, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(CyberKit.GAP_L * s))
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", roundi(CyberKit.GAP_M * s))
	margin.add_child(page)
	page.add_child(_build_top_bar())
	_status = CyberStyle.label("", CyberKit.SMALL * s, Color(CyberStyle.TEXT, 0.75))
	_status.name = "Status"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.y = CyberKit.SMALL * s * 1.4
	page.add_child(_status)
	page.add_child(_build_factions())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", roundi(CyberKit.GAP_L * s))
	page.add_child(body)
	body.add_child(_build_vehicles())
	body.add_child(_build_squads())
	_refresh()


func _build_top_bar() -> Control:
	var s := ui_scale
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", roundi(CyberKit.GAP_M * s))
	var title := CyberStyle.label("GARAGE", CyberKit.TITLE * s, CyberStyle.CYAN)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 3)
	bar.add_child(title)
	_meter = CyberMeter.new()
	_meter.name = "Credits"
	_meter.label = "CREDITS"
	_meter.unit = Credits.SUFFIX
	_meter.shows_left = true
	_meter.low_fraction = 0.1
	_meter.ui_scale = s
	_meter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_meter.custom_minimum_size = Vector2(320, CyberKit.TAP) * s
	bar.add_child(_meter)
	_vs = CyberKit.button("", s, CyberStyle.PINK)
	_vs.name = "Opponent"
	_vs.custom_minimum_size.x = 260 * s
	_vs.pressed.connect(cycle_enemy_faction)
	bar.add_child(_vs)
	_fight = CyberKit.button("FIGHT", s, CyberStyle.GREEN, CyberKit.HEADING)
	_fight.name = "Fight"
	_fight.custom_minimum_size.x = 200 * s
	_fight.pressed.connect(func() -> void: fight())
	bar.add_child(_fight)
	return bar


func _build_factions() -> Control:
	var s := ui_scale
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	box.add_child(CyberKit.heading(1, "FACTION", s))
	_faction_row = HBoxContainer.new()
	_faction_row.add_theme_constant_override("separation", roundi(CyberKit.GAP_M * s))
	box.add_child(_faction_row)
	for name: String in Units.FACTIONS:
		var card := CyberCard.new()
		card.name = "Faction_" + name
		card.set_scale_1080(s)
		card.accent = CyberKit.faction_color(name)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.custom_minimum_size.y = 64 * s
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_theme_constant_override("separation", roundi(CyberKit.GAP_M * s))
		card.content.add_child(row)
		var crest := CyberCrest.new()
		crest.faction = name
		crest.custom_minimum_size = Vector2(44, 44) * s
		row.add_child(crest)
		var words := VBoxContainer.new()
		words.mouse_filter = Control.MOUSE_FILTER_IGNORE
		words.add_theme_constant_override("separation", 0)
		row.add_child(words)
		words.add_child(CyberStyle.label(String(Units.FACTION_NAMES.get(name, name)), CyberKit.BODY * s, CyberStyle.WHITE))
		words.add_child(CyberStyle.label(_faction_line(name), CyberKit.MICRO * s, Color(CyberStyle.TEXT, 0.6)))
		card.pressed.connect(set_faction.bind(name))
		_faction_row.add_child(card)
	return box


## "5 vehicles · 22–60 CR": the roster's size and price range, in credits.
static func _faction_line(name: String) -> String:
	var low := 1 << 30
	var high := 0
	for unit_id: String in Units.roster(name):
		low = mini(low, Credits.of_unit(unit_id))
		high = maxi(high, Credits.of_unit(unit_id))
	return "%d vehicles · %d–%d %s" % [Units.roster(name).size(), low, high, Credits.SUFFIX]


func _build_vehicles() -> Control:
	var s := ui_scale
	var panel := PanelContainer.new()
	panel.name = "Vehicles"
	panel.add_theme_stylebox_override("panel", CyberKit.panel_box(s))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	panel.add_child(box)
	box.add_child(CyberKit.heading(2, "VEHICLES", s))
	box.add_child(CyberStyle.label("Tap to buy · drag a squad's vehicle here to sell it", CyberKit.MICRO * s,
			Color(CyberStyle.TEXT, 0.6)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_vehicles = GridContainer.new()
	_vehicles.columns = 2
	_vehicles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vehicles.add_theme_constant_override("h_separation", roundi(CyberKit.GAP_M * s))
	_vehicles.add_theme_constant_override("v_separation", roundi(CyberKit.GAP_M * s))
	scroll.add_child(GarageScreen._scroll_gutter(_vehicles, s))
	_accept_drops(panel, func(data: Dictionary) -> bool: return data.get("kind") == "unit",
			func(data: Dictionary) -> void: sell(int(data["squad"]), int(data["unit"])))
	return panel


func _build_squads() -> Control:
	var s := ui_scale
	var panel := PanelContainer.new()
	panel.name = "Squads"
	panel.add_theme_stylebox_override("panel", CyberKit.panel_box(s))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.25
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	panel.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	box.add_child(head)
	var heading := CyberKit.heading(3, "SQUADS", s)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(heading)
	var suggested := CyberKit.button("SUGGESTED", s, CyberStyle.CYAN, CyberKit.SMALL)
	suggested.name = "Suggested"
	suggested.pressed.connect(suggest)
	head.add_child(suggested)
	var clear_button := CyberKit.button("CLEAR", s, CyberStyle.ERROR_BORDER, CyberKit.SMALL)
	clear_button.name = "Clear"
	clear_button.pressed.connect(clear)
	head.add_child(clear_button)
	if not compact_chips():
		# Round 22 (A2): on the phone the line gives its height to the fifth row of squads (the tips say it once).
		box.add_child(CyberStyle.label("Tap a squad to buy into it · tap a vehicle to pick it up", CyberKit.MICRO * s,
				Color(CyberStyle.TEXT, 0.6)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	# Round 22 (A2): ten squads stand in two columns of five (one column for a cap of five or fewer).
	_squads = GridContainer.new()
	_squads.name = "SquadGrid"
	_squads.columns = squad_columns()
	_squads.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_squads.add_theme_constant_override("v_separation", roundi(CyberKit.GAP_S * (0.5 if compact_chips() else 1.0) * s))
	_squads.add_theme_constant_override("h_separation", roundi(CyberKit.GAP_S * s))
	scroll.add_child(GarageScreen._scroll_gutter(_squads, s))
	# Stretch b: the army code as one line to copy and paste in chat (select it; it is read-only). `--army=CODE`, or
	# ?garage&army=CODE in the browser, opens it (GarageMode.open_code).
	var share := HBoxContainer.new()
	share.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	box.add_child(share)
	share.add_child(CyberStyle.label("SHARE", CyberKit.MICRO * s, Color(CyberStyle.TEXT, 0.6)))
	_share = LineEdit.new()
	_share.name = "ShareCode"
	_share.editable = false
	_share.selecting_enabled = true
	_share.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_share.add_theme_font_override("font", CyberStyle.font())
	_share.add_theme_font_size_override("font_size", roundi(CyberKit.MICRO * s))
	_share.add_theme_color_override("font_uneditable_color", Color(CyberStyle.TEXT, 0.7))
	_share.add_theme_stylebox_override("read_only", CyberKit.box(Color(CyberStyle.CARD, 0.6), Color(CyberStyle.CYAN, 0.25), 1,
			CyberKit.CUT * 0.6 * s, CyberKit.GAP_S * s))
	share.add_child(_share)
	return panel


# ---- Refresh ----------------------------------------------------------------------------------------------

func _on_changed() -> void:
	_refresh()


func _refresh() -> void:
	if _meter == null:
		return
	var catalog := draft.catalog
	_meter.total = catalog.budget
	_meter.value = draft.remaining_budget()
	_meter.step = 100 if catalog.budget >= 500 else 0
	_vs.text = "VS %s" % ("RANDOM" if not Units.FACTIONS.has(enemy_faction) else
			String(Units.FACTION_NAMES.get(enemy_faction, enemy_faction)).to_upper().trim_prefix("THE "))
	for card: CyberCard in _faction_row.get_children():
		card.selected = card.name == "Faction_" + faction
	_refresh_vehicles()
	_refresh_squads()
	_share.text = ArmyCode.encode(draft) if draft.unit_count() > 0 else ""
	_refresh_fight()


func _refresh_vehicles() -> void:
	var s := ui_scale
	_clear(_vehicles)
	var catalog := draft.catalog
	var counts := draft.counts_by_unit()
	_vehicles.columns = 2 if size.x / maxf(s, 0.01) > 900.0 else 1
	for unit_id in catalog.unit_ids():
		var card := CyberCard.new()
		card.name = "Card_" + unit_id
		card.set_scale_1080(s)
		card.accent = CyberKit.faction_color(faction)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.tooltip_text = catalog.blurb(unit_id)
		# Round 20 (R2): the vehicle itself, from its real mesh (UnitThumbs), with the price tag over its corner.
		var price := CyberKit.tag(catalog.money(catalog.unit_cost(unit_id)), s)
		price.name = "Price"
		var thumb := UnitThumbs.card(unit_id)
		var name_label := CyberStyle.label(catalog.display_name(unit_id), CyberKit.BODY * s, CyberStyle.WHITE)
		name_label.name = "Name"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.clip_text = true
		if thumb != null:
			card.set_picture(thumb, CARD_PICTURE_HEIGHT)
			card.pin_to_picture(price)
			card.content.add_child(name_label)
		else:
			var top := HBoxContainer.new()
			top.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
			card.content.add_child(top)
			top.add_child(name_label)
			top.add_child(price)
		var job := "%s · %s" % [ArmyCatalog.role_label(catalog.role(unit_id)), catalog.length_text(unit_id)]
		var owned := int(counts.get(unit_id, 0))
		if owned > 0:
			job += "  ·  ×%d in the army" % owned
		var detail := CyberStyle.label(job, CyberKit.MICRO * s, Color(CyberStyle.TEXT, 0.7))
		detail.name = "Detail"
		card.content.add_child(detail)
		var matchup := catalog.matchup_text(unit_id, true)
		if matchup != "":
			card.content.add_child(CyberStyle.label(matchup, CyberKit.MICRO * s, Color(CyberStyle.GREEN, 0.8)))
		# A card he can't afford dims but still answers a tap, with why (a refusal in words, not a dead button).
		card.modulate.a = 0.55 if catalog.unit_cost(unit_id) > draft.remaining_budget() or army_full() else 1.0
		card.pressed.connect(func() -> void: buy(unit_id))
		_forward_drag(card, func(_at: Vector2) -> Variant:
			return _drag({"kind": "catalog", "unit": unit_id}, catalog.display_name(unit_id)))
		_vehicles.add_child(card)


func _refresh_squads() -> void:
	var s := ui_scale
	_clear(_squads)
	_squads.columns = squad_columns()
	var catalog := draft.catalog
	for squad_index in draft.squads().size():
		var squad_data := draft.squad(squad_index)
		var selected := squad_index == selected_squad
		var row := PanelContainer.new()
		row.name = "Squad_%d" % squad_index
		var row_box := CyberKit.box(Color(CyberStyle.CYAN, 0.08) if selected else
				Color(CyberStyle.CARD, 0.6), Color(CyberStyle.CYAN, 0.9 if selected else 0.3), 2 if selected else 1,
				CyberKit.CUT * s, CyberKit.GAP_S * s)
		if compact_chips():
			# R4: five rows of tap-tall chips fit the phone's panel only with the rows' own padding cut to a hair.
			row_box.content_margin_top = 2.0 * s
			row_box.content_margin_bottom = 2.0 * s
		row.add_theme_stylebox_override("panel", row_box)
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
		row.add_child(line)
		var units: Array = squad_data.get("units", [])
		var two := squad_columns() > 1
		# Round 22 (A2): in two columns the name sits over the count, so the header is narrow and the chips get the row.
		var header := CyberKit.button("%s%s%d/%d" % [String(squad_data.get("name", "")).to_upper(), "\n" if two else "  ",
				units.size(), catalog.max_squad_size], s, CyberStyle.CYAN, CyberKit.MICRO if two else CyberKit.SMALL)
		header.name = "Header"
		header.custom_minimum_size.x = (HEADER_NARROW if two else 150.0) * s
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.toggle_mode = true
		header.button_pressed = selected
		header.pressed.connect(tap_squad.bind(squad_index))
		line.add_child(header)
		# Two columns: five equal slots in one line (a chip shares the row five ways, never under one tap target), so
		# the chips line up down the column; one column: round 20's flow of fixed-width chips.
		var chips: Container = HBoxContainer.new() if two else HFlowContainer.new()
		chips.name = "Chips"
		chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chips.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * 0.5 * s))
		chips.add_theme_constant_override("h_separation", roundi(CyberKit.GAP_S * s))
		chips.add_theme_constant_override("v_separation", roundi(CyberKit.GAP_S * s))
		line.add_child(chips)
		for unit_index in units.size():
			var unit_id := String(units[unit_index].get("unit", ""))
			var is_picked := picked == [squad_index, unit_index]
			# Round 20 (R2): the vehicle's picture over its name (two lines for a long one), five across a squad.
			var chip := CyberPictureChip.new(UnitThumbs.chip(unit_id), "", s,
					CyberStyle.PINK if is_picked else CyberKit.faction_color(faction))
			# A picked chip offers the sale; on the phone without "CR" (it wrapped to three lines in a picture chip).
			var sale := ("SELL +%d" % catalog.unit_cost(unit_id)) if compact_chips() \
					else "SELL +%s" % catalog.money(catalog.unit_cost(unit_id))
			chip.set_caption(sale if is_picked else catalog.display_name(unit_id).to_upper())
			# R4: on a touch screen the picture alone (its name is on the card with the same picture, and in the line
			# when it is picked up), so five squads fit without scrolling; a picked chip still says SELL.
			# Round 22 (A2): in two columns too (a fifth of half the panel wraps "RESUPPLY" mid-word on the desktop).
			chip.caption.visible = is_picked or not (compact_chips() or two)
			if compact_chips() and not is_picked:
				chip.picture.custom_minimum_size.y = (CyberKit.TAP - 10.0) * s  # the chip is one tap target tall
			if two:
				chip.set_width(CyberKit.TAP * s)
				chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			chip.name = "Unit_%d" % unit_index
			chip.toggle_mode = true
			chip.button_pressed = is_picked
			chip.pressed.connect(tap_chip.bind(squad_index, unit_index))
			_forward_drag(chip, func(_at: Vector2) -> Variant:
				return _drag({"kind": "unit", "squad": squad_index, "unit": unit_index}, catalog.display_name(unit_id)))
			chips.add_child(chip)
		if units.is_empty():
			chips.add_child(CyberStyle.label("empty: tap a vehicle" if two else "empty: tap a vehicle to buy it here",
					CyberKit.MICRO * s, Color(CyberStyle.TEXT, 0.5)))
		elif two:
			for slot in catalog.max_squad_size - units.size():
				var spacer := Control.new()
				spacer.custom_minimum_size.x = CyberKit.TAP * s
				spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
				chips.add_child(spacer)
		_accept_drops(row, func(data: Dictionary) -> bool: return data.get("kind") in ["unit", "catalog"],
				func(data: Dictionary) -> void: _drop_on_squad(squad_index, data))
		# A tap anywhere on the row is a tap on the squad (the chips and the header take their own taps first).
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				tap_squad(squad_index))
		_squads.add_child(row)
	if draft.squads().size() < catalog.max_squads:
		var add := CyberKit.button("+ NEW SQUAD", s, CyberStyle.CYAN, CyberKit.SMALL)
		add.name = "AddSquad"
		add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add.pressed.connect(new_squad)
		_accept_drops(add, func(data: Dictionary) -> bool: return data.get("kind") in ["unit", "catalog"],
				func(data: Dictionary) -> void:
					if new_squad() == "":
						_drop_on_squad(selected_squad, data))
		_squads.add_child(add)


func _refresh_fight() -> void:
	var problems := ready_problems()
	_fight.disabled = not problems.is_empty()
	if not problems.is_empty() and not _status_is_error:
		_say(problems[0], true, false)
	elif problems.is_empty() and (_status.text == "" or ((army_full() or not _can_afford_any()) and not _status_is_error)):
		_say(_hint(), false)


## Why FIGHT can't start yet, in words (empty = ready). An empty squad is not a problem: it is dropped on FIGHT.
func ready_problems() -> PackedStringArray:
	var found: PackedStringArray = []
	for problem in draft.problems(false):
		if not problem.contains(" is empty:"):
			found.append(problem)
	return found


func _hint() -> String:
	if army_full():
		return GarageScreen.full_line(draft)
	var squad_name := String(draft.squad(selected_squad).get("name", "a squad")).to_upper()
	# The meter beside it already says what is left; the line carries only what to do (orchestrator's note).
	if not _can_afford_any():
		return GarageScreen.spent_line(draft)
	var one_more := GarageScreen.one_more_line(draft)
	if one_more != "":
		return "%s · FIGHT when ready" % one_more
	return "Tap a vehicle to buy it into %s · FIGHT when ready" % squad_name


func _can_afford_any() -> bool:
	for unit_id in draft.catalog.unit_ids():
		if draft.catalog.unit_cost(unit_id) <= draft.remaining_budget():
			return true
	return false


## Round 20 (R1): the credits ran out before the slots did (every faction but the Gangs' all-scout army): say so.
## Round 22 (stretch a): without the change that buys nothing -- the meter beside it shows what is left, and a
## suggested army opened on "the 1 CR left buys no vehicle" (true, and odd).
static func spent_line(p_draft: ArmyDraft) -> String:
	if p_draft.remaining_budget() <= 0:
		return "Every credit is spent: sell a vehicle to buy another, or FIGHT."
	return "Your credits are spent: FIGHT when ready, or sell a vehicle to buy another."


## Round 22 (stretch a): when the money left buys only a vehicle or two (less than three of the cheapest) and there is
## room, say what it buys: the dearest vehicle that fits ("100 CR left: one more War Rig"). "" otherwise.
static func one_more_line(p_draft: ArmyDraft) -> String:
	var catalog := p_draft.catalog
	var left := p_draft.remaining_budget()
	if p_draft.unit_count() >= catalog.max_units or left <= 0:
		return ""
	var cheapest := 1 << 30
	var best := ""
	for unit_id in catalog.unit_ids():
		var cost := catalog.unit_cost(unit_id)
		cheapest = mini(cheapest, cost)
		if catalog.is_unlocked(unit_id) and cost <= left and (best == "" or cost > catalog.unit_cost(best)):
			best = unit_id
	if best == "" or left >= cheapest * 3:
		return ""
	return "%s left: one more %s" % [catalog.money(left), catalog.display_name(best)]


## Round 20 (R4): the squad chips show only their pictures (a touch screen: the phone's five squads of captioned
## chips were taller than the panel and scrolled).
## Round 22 (A2): columns of squads: two when the cap is over five (ten squads: two columns of five), else one.
func squad_columns() -> int:
	return 2 if draft != null and draft.catalog.max_squads > ONE_COLUMN_MAX else 1


func compact_chips() -> bool:
	return CyberStyle.touch_boost() > 1.0


## Every place in the army is taken (five squads of five): the money left can't be spent.
func army_full() -> bool:
	return draft.unit_count() >= draft.catalog.max_units


## The orchestrator's ruling (2026-10-06; put to the lead): 25 vehicles is the field limit for every faction, and the
## garage says so in words when the credits can't be spent, instead of "tap a vehicle to buy". Round 20 (R1): at 1000
## credits only the Gangs' all-scout army reaches 25, and it spends every credit; the "can't be spent" line stays for
## a budget that outgrows the slots (his later "more credits as players advance").
static func full_line(p_draft: ArmyDraft) -> String:
	var left := p_draft.remaining_budget()
	if left <= 0:
		return "Your army is full: %d vehicles, every credit spent. FIGHT when ready." % p_draft.unit_count()
	return "Your army is full: %d squads of %d. The %s left can't be spent; sell a vehicle for a dearer one, or FIGHT." \
			% [p_draft.catalog.max_squads, p_draft.catalog.max_squad_size, p_draft.catalog.money(left)]


# ---- Gestures (each returns "" or the reason, which is also shown) --------------------------------------------

## Buy one `unit_id` into the selected squad (spilling into the next with room, then a new squad).
func buy(unit_id: String) -> String:
	picked = []
	var catalog := draft.catalog
	# Full first (round 20): the Gangs' 25 scouts are full AND spent, and "full" is the reason that holds.
	if draft.unit_count() >= catalog.max_units:
		return _fail(GarageScreen.full_line(draft))
	if catalog.unit_cost(unit_id) > draft.remaining_budget():
		return _fail("Not enough credits: a %s costs %s, %s left. Tap a vehicle in a squad, then tap it again to sell it." % [
				catalog.display_name(unit_id), catalog.money(catalog.unit_cost(unit_id)), catalog.money(draft.remaining_budget())])
	var target := draft.squad_with_room(selected_squad)
	if target < 0:
		return _fail("Every squad is full.")
	var error := draft.add_unit(target, unit_id)
	if error != "":
		return _fail(error)
	var spilled := target != selected_squad
	selected_squad = target
	_say("Bought a %s for %s into %s%s." % [catalog.display_name(unit_id), catalog.money(catalog.unit_cost(unit_id)),
			String(draft.squad(target)["name"]).to_upper(), " (the squad you picked was full)" if spilled else ""], false)
	_sound("ui_select")
	_refresh()
	return ""


## Sell one vehicle back for its full price.
func sell(squad_index: int, unit_index: int) -> String:
	var entry := draft.unit_at(squad_index, unit_index)
	if entry.is_empty():
		return _fail("No such vehicle.")
	picked = []
	var unit_id := String(entry.get("unit", ""))
	draft.remove_unit(squad_index, unit_index)
	_say("Sold a %s: +%s." % [draft.catalog.display_name(unit_id), draft.catalog.money(draft.catalog.unit_cost(unit_id))],
			false)
	_sound("ui_tick")
	_tidy()
	return ""


## Move a vehicle to another squad.
func move(squad_index: int, unit_index: int, to_squad: int) -> String:
	picked = []
	if squad_index == to_squad:
		_refresh()
		return ""
	var error := draft.move_unit(squad_index, unit_index, to_squad)
	if error != "":
		return _fail(error)
	var target_name := String(draft.squad(to_squad)["name"])
	selected_squad = to_squad
	_tidy()
	_say("Moved to %s." % target_name.to_upper(), false)
	return ""


## A tap on a chip: pick it up; a second tap on the same chip sells it.
func tap_chip(squad_index: int, unit_index: int) -> void:
	if picked == [squad_index, unit_index]:
		sell(squad_index, unit_index)
		return
	picked = [squad_index, unit_index]
	var unit_id := String(draft.unit_at(squad_index, unit_index).get("unit", ""))
	_say("%s picked up: tap another squad to move it there, or tap it again to sell it (+%s)." % [
			draft.catalog.display_name(unit_id), draft.catalog.money(draft.catalog.unit_cost(unit_id))], false)
	_refresh()


## A tap on a squad: with a chip picked up, move it here; otherwise buys go here.
func tap_squad(squad_index: int) -> void:
	if not picked.is_empty():
		move(int(picked[0]), int(picked[1]), squad_index)
		return
	selected_squad = squad_index
	_say(_hint(), false)
	_tidy()


## A new empty squad, selected, so the next buys go into it.
func new_squad() -> String:
	picked = []
	var error := draft.add_squad()
	if error != "":
		return _fail(error)
	selected_squad = draft.squads().size() - 1
	_say("%s is ready: tap vehicles to buy into it, or move vehicles here." % String(draft.squad(selected_squad)["name"]).to_upper(),
			false)
	_tidy()
	return ""


## Switch to `name`'s roster. Each faction keeps the army built for it while he looks around; a faction he has not
## built for opens on its suggested army.
func set_faction(name: String) -> void:
	if not Units.FACTIONS.has(name):
		return
	if name == faction:
		_refresh()
		return
	_armies[faction] = [draft, army_path]
	faction = name
	if _armies.has(name):
		_adopt(_armies[name][0], String(_armies[name][1]))
	else:
		_adopt(GarageSuggest.draft(ArmyCatalog.for_game(name)), "")
	_build()
	_say(_hint() if army_full() or not _can_afford_any() else "%s: sell what you don't want, buy what you do."
			% Units.FACTION_NAMES.get(name, name), false)


## Replace the army with the faction's suggested one.
func suggest() -> void:
	var path := army_path
	_adopt(GarageSuggest.draft(ArmyCatalog.for_game(faction)), path)
	_say(_hint() if army_full() or not _can_afford_any() else "Suggested army: %s spent, %s left." % [
			draft.catalog.money(draft.total_cost()), draft.catalog.money(draft.remaining_budget())], false)
	_refresh()


## Sell everything: one empty squad, the whole budget back.
func clear() -> void:
	picked = []
	draft.army["squads"] = [ArmyDraft.new_squad(ArmyDraft.SQUAD_NAMES[0])]
	selected_squad = 0
	_say("Sold everything: %s to spend." % draft.catalog.money(draft.remaining_budget()), false)
	_refresh()


## The VS button: random, then each faction, then random again.
func cycle_enemy_faction() -> void:
	var choices: Array = [RANDOM] + Array(Units.FACTIONS)
	enemy_faction = String(choices[(choices.find(enemy_faction) + 1) % choices.size()])
	_say("You fight %s." % ("a random faction (never your own)" if enemy_faction == RANDOM
			else Units.FACTION_NAMES.get(enemy_faction, enemy_faction)), false)
	_refresh()


## Drop squads left empty, except the selected one (where the next buy goes), keeping the selection on its squad.
func _tidy() -> void:
	var keep := draft.squad(selected_squad)
	var before := draft.squads().size()
	draft.army["squads"] = draft.squads().filter(func(squad_data: Dictionary) -> bool:
		return not (squad_data.get("units", []) as Array).is_empty() or is_same(squad_data, keep))
	if draft.squads().is_empty():
		draft.add_squad()
	selected_squad = maxi(0, _index_of(keep))
	if draft.squads().size() != before:
		picked = []
	_refresh()


func _index_of(squad_data: Dictionary) -> int:
	for index in draft.squads().size():
		if is_same(draft.squads()[index], squad_data):
			return index
	return -1


func _drop_on_squad(squad_index: int, data: Dictionary) -> void:
	match data.get("kind"):
		"catalog":
			selected_squad = squad_index
			buy(String(data["unit"]))
		"unit":
			move(int(data["squad"]), int(data["unit"]), squad_index)


# ---- FIGHT ---------------------------------------------------------------------------------------------------

## Saves and asks to start the skirmish. Returns the saved path, or "" (with the reason shown) if it can't fight yet.
func fight() -> String:
	picked = []
	draft.drop_empty_squads()
	if draft.squads().is_empty():
		draft.add_squad()
	selected_squad = clampi(selected_squad, 0, draft.squads().size() - 1)
	var problems := draft.problems()
	if not problems.is_empty():
		_refresh()
		_fail("Not ready: " + problems[0])
		return ""
	var path := save()
	if path != "":
		settings.remember_army(path)
		_sound("ui_ack_attack")
		fight_requested.emit(path, enemy)
	return path


## Saves to the army's own file (a new file the first time). Returns the path, or "" (with the reason) on failure.
func save() -> String:
	if String(draft.army.get("name", "")).strip_edges() == "":
		draft.army["name"] = GarageSuggest.army_name(faction)
	var stem := army_path.get_file().get_basename() if army_path != "" \
			else ArmyStore.unused_stem(String(draft.army["name"]), store_dir)
	var dir := army_path.get_base_dir() if army_path != "" else store_dir
	var saved := ArmyStore.save(draft.to_doctrine(), stem, dir)
	if saved.has("error"):
		_fail(String(saved["error"]))
		return ""
	army_path = saved["path"]
	_armies[faction] = [draft, army_path]
	return army_path


# ---- Words ---------------------------------------------------------------------------------------------------

## For the mode and other callers: show a problem the player should know about.
func report(error: String) -> void:
	_fail(error)


func _fail(error: String) -> String:
	if error != "":
		_say(error, true)
		_sound("ui_alert")
	return error


## Stretch c (round 20): the garage's gestures heard, from the game's own UI sounds (SfxSystem.play_ui; nothing new):
## a buy ui_select, a sale ui_tick, a refusal ui_alert, FIGHT ui_ack_attack. Silent where no FxWorld is up (tests).
static var sounds_played: Array[String] = []


func _sound(sound: String) -> void:
	sounds_played.append(sound)
	var fx := FxWorld.existing()
	if fx != null:
		fx.sfx.play_ui(sound)


## The status line: what just happened, or why not (pink).
func _say(text: String, is_error: bool, sticky := true) -> void:
	if _status == null:
		return
	_status.text = text
	_status_is_error = is_error and sticky
	_status.add_theme_color_override("font_color", CyberStyle.PINK if is_error else Color(CyberStyle.TEXT, 0.8))


## The status line's text (tests and the tour read it).
func toast_text() -> String:
	return _status.text if _status != null else ""


## Round 20 (R2): `content` in a margin as wide as a scroll bar, so a scrolling list's right edge (a card's price tag,
## a squad's frame) is never under the bar (the phone's frame cut "63 CR" in half).
static func _scroll_gutter(content: Control, scale: float) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", roundi(14.0 * scale))
	margin.add_child(content)
	return margin


static func _clear(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


# ---- Drag and drop (Godot's GUI drag works with touch through mouse emulation) ----------------------------------

func _drag(data: Dictionary, preview_text: String) -> Dictionary:
	var preview := CyberKit.tag(preview_text.to_upper(), ui_scale, CyberStyle.CYAN, CyberKit.BODY)
	set_drag_preview(preview)
	return data


## Dragging from `control` or anything inside it produces `make_data.call(at_position)`.
func _forward_drag(control: Control, make_data: Callable) -> void:
	for target: Control in [control] + control.find_children("*", "Control", true, false):
		target.set_meta("drag_source", make_data)
		target.set_drag_forwarding(make_data, Callable(), Callable())


## `control` and everything inside it accept drops that pass `accepts`; drag sources stay draggable.
func _accept_drops(control: Control, accepts: Callable, on_drop: Callable) -> void:
	for target: Control in [control] + control.find_children("*", "Control", true, false):
		target.set_drag_forwarding(target.get_meta("drag_source", Callable()),
				func(_at: Vector2, data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and accepts.call(data),
				func(_at: Vector2, data: Variant) -> void: on_drop.call(data))
