class_name ResultsScreen
extends Control
## Y3/Y4: after a skirmish, what happened and what it earned. Win or loss, the credits paid (with the
## breakdown), both armies' units fielded and lost, kills, the best unit, the opponent's composition and
## which units counter it (so players learn counters), then REMATCH (same opponent army) or ARMY.
## Built from code like the army builder, touch first, scaled with the screen height.

signal rematch_requested
signal army_requested

const BASE_HEIGHT := 720.0
const FONT_SIZE := 17
const TAP := 40.0
const REASONS := {"elimination": "Last army standing", "control": "Held the control point", "time_limit": "Time ran out",
		"score_limit": "Score limit"}

var report: Dictionary
## Progression.credits_for's {"credits", "outcome", "lines"} for the player.
var paid: Dictionary
var progression: Progression
var catalog: ArmyCatalog
## "CPU: Siege (seed 42)"
var enemy_label := ""
## Overrides the counter lesson (a challenge mission's own lesson).
var lesson := ""
var ui_scale := 1.0


func setup(p_report: Dictionary, p_paid: Dictionary, p_progression: Progression, p_catalog: ArmyCatalog, p_enemy_label: String) -> void:
	report = p_report
	paid = p_paid
	progression = p_progression
	catalog = p_catalog
	enemy_label = p_enemy_label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	resized.connect(_build)
	_build()


func _color(key: String) -> Color:
	const FALLBACK := {"garage_bg": Color(0.055, 0.06, 0.075, 0.94), "garage_panel": Color(0.1, 0.11, 0.14),
			"garage_text_dim": Color(0.62, 0.66, 0.72), "friendly": Color(0.45, 0.85, 0.4),
			"enemy": Color(0.95, 0.35, 0.3), "commander": Color(1.0, 0.85, 0.25)}
	return GameTheme.ui.get(key, FALLBACK.get(key, Color.WHITE))


func _build() -> void:
	ui_scale = maxf(1.0, size.y / BASE_HEIGHT) if size.y > 0.0 else 1.0
	for child in get_children():
		remove_child(child)
		child.queue_free()
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
		margin.add_theme_constant_override("margin_" + side, int(18 * ui_scale))
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", int(10 * ui_scale))
	margin.add_child(rows)

	var outcome := String(paid.get("outcome", "draw"))
	var headline := _label({"win": "VICTORY", "loss": "DEFEAT", "draw": "DRAW"}[outcome], 2.6)
	headline.name = "Headline"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_color", _color({"win": "friendly", "loss": "enemy", "draw": "commander"}[outcome]))
	rows.add_child(headline)
	var reason := _label("%s  ·  %s  ·  %s  ·  vs %s" % [REASONS.get(report.get("reason", ""), String(report.get("reason", "")).capitalize()),
			_duration(float(report.get("duration_seconds", 0.0))), Progression.tier_label(int(report.get("tier", 0))), enemy_label], 0.9)
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.add_theme_color_override("font_color", _color("garage_text_dim"))
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(reason)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", int(14 * ui_scale))
	rows.add_child(body)
	body.add_child(_panel("CREDITS", _credits_rows()))
	body.add_child(_panel("YOUR ARMY", _army_rows("green")))
	body.add_child(_panel("THEIR ARMY", _army_rows("rust") + [_note(lesson if lesson != "" else counter_lesson(report, catalog), 0.9, "commander", "Lesson")]))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", int(14 * ui_scale))
	var army := _button("ARMY", func() -> void: army_requested.emit())
	army.name = "Army"
	army.tooltip_text = "Back to the army builder"
	buttons.add_child(army)
	var rematch := _button("REMATCH", func() -> void: rematch_requested.emit())
	rematch.name = "Rematch"
	rematch.tooltip_text = "Fight the same opponent army again"
	rematch.add_theme_font_size_override("font_size", int(FONT_SIZE * 1.4 * ui_scale))
	buttons.add_child(rematch)
	rows.add_child(buttons)


func _credits_rows() -> Array:
	var rows := []
	var total := _label("+%d" % int(paid.get("credits", 0)), 2.0)
	total.name = "CreditsEarned"
	total.add_theme_color_override("font_color", _color("commander"))
	rows.append(total)
	for line: Array in paid.get("lines", []):
		rows.append(_note("%s   +%d" % [line[0], int(line[1])], 0.9))
	if progression != null:
		rows.append(_note("Balance: %d credits" % progression.credits, 1.0, "friendly", "Balance"))
		rows.append(_note(next_goal(progression, catalog), 0.85, "garage_text_dim", "NextGoal"))
	return rows


func _army_rows(team: String) -> Array:
	var summary: Dictionary = report.get("teams", {}).get(team, {})
	var rows := []
	rows.append(_note("Fielded: " + MatchReport.describe_units(summary.get("units", {}), catalog), 0.9, "garage_text_dim", "Fielded_" + team))
	rows.append(_note("Lost: " + (MatchReport.describe_units(summary.get("losses_by_unit", {}), catalog) if int(summary.get("units_lost", 0)) > 0 else "nothing"),
			0.9, "enemy" if int(summary.get("units_lost", 0)) > 0 else "friendly", "Lost_" + team))
	rows.append(_note("Destroyed %d enemy unit%s" % [int(summary.get("kills", 0)), "" if int(summary.get("kills", 0)) == 1 else "s"], 0.9, "garage_text_dim"))
	var best: Dictionary = report.get("best_unit", {})
	if not best.is_empty() and String(best.get("team", "")).to_lower() == team:
		rows.append(_note("Best unit: %s (%s), %d kill%s%s" % [_tank_label(String(best["name"])), catalog.display_name(String(best["unit"])),
				int(best["kills"]), "" if int(best["kills"]) == 1 else "s", "" if best.get("alive", false) else ", destroyed"], 0.9, "commander", "BestUnit"))
	return rows


## "Green_Alpha_2" → "Alpha #2"
static func _tank_label(tank_name: String) -> String:
	var parts := tank_name.split("_")
	return "%s #%s" % [" ".join(parts.slice(1, parts.size() - 1)), parts[parts.size() - 1]] if parts.size() >= 3 else tank_name


## One sentence that teaches a counter: what the opponent fielded most, and which unit types beat it.
static func counter_lesson(p_report: Dictionary, p_catalog: ArmyCatalog) -> String:
	var units: Dictionary = p_report.get("teams", {}).get("rust", {}).get("units", {})
	if units.is_empty():
		return ""
	var top := ""
	for unit_id: String in units:
		if top == "" or int(units[unit_id]) > int(units[top]) or (units[unit_id] == units[top] and unit_id < top):
			top = unit_id
	var role := p_catalog.role(top) if p_catalog.has_unit(top) else top
	var counters: PackedStringArray = []
	for unit_id in p_catalog.unit_ids():
		if p_catalog.good_vs(unit_id).has(role):
			counters.append(GarageAdvice._pluralize(p_catalog.display_name(unit_id)) + ("" if p_catalog.is_unlocked(unit_id) else " (locked)"))
	var top_name := GarageAdvice._pluralize(p_catalog.display_name(top) if p_catalog.has_unit(top) else top.capitalize())
	if counters.is_empty():
		return "Their army was mostly %s." % top_name
	return "Their army was mostly %s. %s %s built to beat them." % [top_name, " and ".join(counters), "is" if counters.size() == 1 and counters[0].begins_with("Artillery") else "are"]


## What to save up for next: the cheapest thing still locked, and how far away it is.
static func next_goal(p_progression: Progression, p_catalog: ArmyCatalog) -> String:
	var options := []
	for unit_id in p_catalog.unit_ids():
		if not p_progression.has_unit(p_catalog, unit_id):
			options.append([Progression.unit_unlock_credits(p_catalog, unit_id), "the %s" % p_catalog.display_name(unit_id)])
	var next := p_progression.next_tier()
	if not next.is_empty():
		options.append([int(next["unlock_credits"]), "the %s tier" % next["name"]])
	if options.is_empty():
		return "Everything is unlocked."
	options.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var price: int = options[0][0]
	if p_progression.credits >= price:
		return "You can unlock %s now (%d credits) in ARMY." % [options[0][1], price]
	return "%d more credits to unlock %s." % [price - p_progression.credits, options[0][1]]


static func _duration(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


func _panel(title: String, children: Array) -> Control:
	var panel := PanelContainer.new()
	panel.name = "Panel_" + title.replace(" ", "_")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = _color("garage_panel")
	style.border_color = _color("garage_text_dim").darkened(0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(int(6 * ui_scale))
	style.set_content_margin_all(12 * ui_scale)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", int(8 * ui_scale))
	panel.add_child(box)
	var heading := _label(title, 0.85)
	heading.add_theme_color_override("font_color", _color("garage_text_dim"))
	box.add_child(heading)
	for child: Control in children:
		box.add_child(child)
	return panel


func _label(text: String, relative_size := 1.0) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", int(FONT_SIZE * relative_size * ui_scale))
	return label


func _note(text: String, relative_size: float, color_key := "garage_text_dim", node_name := "") -> Label:
	var label := _label(text, relative_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", _color(color_key))
	if node_name != "":
		label.name = node_name
	return label


func _button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(170 * ui_scale, TAP * 1.3 * ui_scale)
	button.pressed.connect(on_press)
	return button
