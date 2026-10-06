extends Control
## The UI kit's gallery (G2, `make ui-kit-shots`, `_agents/ui_kit.md`): every kit element in its states on the HUD
## background, one section per element. `--kit-element=NAME` shows that section alone, large, for its own frame in
## the doc; without it the whole sheet is drawn. Flags: --screenshot=<abs png> [--screenshot-delay=S] [--ui-touch].
##   NAME: palette | type | frame | button | card | chip | tag | meter | crest | heading

const ELEMENTS := ["palette", "type", "frame", "button", "card", "chip", "tag", "meter", "crest", "heading"]

var element := ""
var _scale := 1.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var flags := LaunchFlags.from_environment()
	element = flags.text("kit-element", "")
	get_viewport().size_changed.connect(_build)
	_build()
	if flags.has("screenshot"):
		_capture(flags.text("screenshot"), float(flags.text("screenshot-delay", "1.5")))


func _build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_scale = CyberKit.s(self) * CyberStyle.touch_boost()
	var background := ColorRect.new()
	background.color = CyberStyle.HUD_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(CyberKit.GAP_L * 2.0 * _scale))
	add_child(margin)
	var sheet := VBoxContainer.new()
	sheet.add_theme_constant_override("separation", roundi(CyberKit.GAP_L * _scale))
	margin.add_child(sheet)
	var title := CyberStyle.label("UI KIT" if element == "" else "UI KIT · %s" % element.to_upper(),
			CyberKit.TITLE * _scale, CyberStyle.CYAN)
	sheet.add_child(title)
	if element != "":
		sheet.add_child(_section(element, 1.6))
		return
	# The whole sheet: two columns of sections.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", roundi(CyberKit.GAP_L * 2.0 * _scale))
	sheet.add_child(columns)
	var halves := [["palette", "type", "button", "tag", "heading"], ["frame", "card", "chip", "meter", "crest"]]
	for names: Array in halves:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", roundi(CyberKit.GAP_L * _scale))
		columns.add_child(column)
		for name: String in names:
			# The whole sheet fits one window: at the touch size (1.5x) it would run off a phone, so it is drawn at
			# the desktop size there; each element's own frame shows its true size.
			column.add_child(_section(name, 1.0 / CyberStyle.touch_boost()))


## One element's section: its name, then the element in its states. `zoom` enlarges a section shown alone.
func _section(name: String, zoom: float) -> Control:
	var s := _scale * zoom
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	box.add_child(CyberStyle.label(name.to_upper(), CyberKit.SMALL * s, Color(CyberStyle.TEXT, 0.6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(CyberKit.GAP_M * s))
	box.add_child(row)
	match name:
		"palette":
			for spec in [["CYAN", CyberStyle.CYAN], ["PINK", CyberStyle.PINK], ["PURPLE", CyberStyle.PURPLE],
					["GREEN", CyberStyle.GREEN], ["YELLOW", CyberStyle.YELLOW], ["ERROR", CyberStyle.ERROR_BORDER],
					["TEXT", CyberStyle.TEXT], ["CARD", CyberStyle.CARD]]:
				var swatch := VBoxContainer.new()
				var color_box := Panel.new()
				color_box.custom_minimum_size = Vector2(64, 40) * s
				color_box.add_theme_stylebox_override("panel", CyberKit.box(spec[1], Color(CyberStyle.TEXT, 0.4), 1,
						CyberKit.CUT * 0.6 * s))
				swatch.add_child(color_box)
				swatch.add_child(CyberStyle.label(spec[0], CyberKit.MICRO * s, CyberStyle.TEXT))
				row.add_child(swatch)
			for faction: String in CyberKit.FACTION_COLORS:
				var swatch := VBoxContainer.new()
				var color_box := Panel.new()
				color_box.custom_minimum_size = Vector2(64, 40) * s
				color_box.add_theme_stylebox_override("panel", CyberKit.box(CyberKit.faction_color(faction),
						Color(CyberStyle.TEXT, 0.4), 1, CyberKit.CUT * 0.6 * s))
				swatch.add_child(color_box)
				swatch.add_child(CyberStyle.label(faction.to_upper(), CyberKit.MICRO * s, CyberStyle.TEXT))
				row.add_child(swatch)
		"type":
			var column := VBoxContainer.new()
			for spec in [["TITLE 44", CyberKit.TITLE], ["HEADING 28", CyberKit.HEADING], ["BODY 22", CyberKit.BODY],
					["SMALL 18", CyberKit.SMALL], ["MICRO 15", CyberKit.MICRO]]:
				column.add_child(CyberStyle.label("%s  The Condemned · 40 CR" % spec[0], float(spec[1]) * s, CyberStyle.TEXT))
			row.add_child(column)
		"frame":
			for theme in [CyberStyle.THEME_INFO, CyberStyle.THEME_WARNING, CyberStyle.THEME_ERROR]:
				var frame := CyberFrame.new()
				frame.apply_theme(theme)
				frame.custom_minimum_size = Vector2(160, 110) * s
				row.add_child(frame)
			var panel := PanelContainer.new()
			panel.add_theme_stylebox_override("panel", CyberKit.panel_box(s))
			panel.add_child(CyberStyle.label("panel_box()", CyberKit.BODY * s))
			panel.custom_minimum_size = Vector2(160, 110) * s
			row.add_child(panel)
		"button":
			row.add_child(CyberKit.button("NORMAL", s))
			var toggled := CyberKit.button("TOGGLED", s)
			toggled.toggle_mode = true
			toggled.button_pressed = true
			row.add_child(toggled)
			var disabled := CyberKit.button("DISABLED", s)
			disabled.disabled = true
			row.add_child(disabled)
			row.add_child(CyberKit.button("FIGHT", s, CyberStyle.GREEN, CyberKit.HEADING))
			row.add_child(CyberKit.button("CLEAR", s, CyberStyle.ERROR_BORDER))
		"card":
			for spec in [["Tank", "40 CR", false, false], ["Scout", "22 CR", true, false], ["Artillery", "44 CR", false, true]]:
				var card := CyberCard.new()
				card.set_scale_1080(s)
				card.custom_minimum_size = Vector2(200, 120) * s
				card.content.add_child(CyberStyle.label(spec[0], CyberKit.BODY * s, CyberStyle.WHITE))
				card.content.add_child(CyberStyle.label("Assault", CyberKit.MICRO * s, Color(CyberStyle.TEXT, 0.6)))
				card.content.add_child(CyberKit.tag(spec[1], s))
				card.selected = spec[2]
				card.disabled = spec[3]
				card.set_scale_1080(s)
				row.add_child(card)
			var law := CyberCard.new()
			law.set_scale_1080(s)
			law.accent = CyberKit.faction_color("law")
			law.selected = true
			law.custom_minimum_size = Vector2(200, 120) * s
			law.content.add_child(CyberStyle.label("The Law", CyberKit.BODY * s, CyberStyle.WHITE))
			row.add_child(law)
		"chip":
			row.add_child(CyberKit.chip("TANK", s))
			row.add_child(CyberKit.chip("SCOUT", s, CyberKit.faction_color("condemned")))
			var picked := CyberKit.chip("IFV", s)
			picked.toggle_mode = true
			picked.button_pressed = true
			row.add_child(picked)
		"tag":
			row.add_child(CyberKit.tag("40 CR", s))
			row.add_child(CyberKit.tag("94 CR", s))
			row.add_child(CyberKit.tag("SOLD", s, CyberStyle.PINK))
			row.add_child(CyberKit.tag("5 / 5", s, CyberStyle.CYAN))
		"meter":
			var column := VBoxContainer.new()
			column.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
			for spec in [[620, false], [1000, false], [-40, true], [140, false]]:
				var meter := CyberMeter.new()
				meter.total = 1000
				meter.value = spec[0]
				meter.shows_left = true
				meter.unit = "CR"
				meter.label = "CREDITS"
				meter.ui_scale = s
				meter.custom_minimum_size = Vector2(520, 48) * s
				column.add_child(meter)
			row.add_child(column)
		"crest":
			for faction: String in CyberKit.FACTION_COLORS:
				var crest := CyberCrest.new()
				crest.faction = faction
				crest.custom_minimum_size = Vector2(88, 88) * s
				row.add_child(crest)
			var dim := CyberCrest.new()
			dim.faction = "law"
			dim.dim = true
			dim.custom_minimum_size = Vector2(88, 88) * s
			row.add_child(dim)
		"heading":
			var column := VBoxContainer.new()
			column.add_child(CyberKit.heading(1, "FACTION", s))
			column.add_child(CyberKit.heading(2, "VEHICLES", s))
			column.add_child(CyberKit.heading(3, "SQUADS", s, CyberStyle.PINK))
			row.add_child(column)
	return box


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: " if err == OK else "screenshot failed: ", path)
	get_tree().quit(err)
