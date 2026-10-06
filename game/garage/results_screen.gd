class_name ResultsScreen
extends Control
## After a garage fight (Y3/Y4; round 19, G4 in the kit, `_agents/ui_kit.md`): who won and why, both armies (fielded,
## lost, what each destroyed and what it cost, the best vehicle), one lesson, then REMATCH (the same opponent) or ARMY.
## Round 19: the credit breakdown and the "unlock next" line are gone with the unlocks (every vehicle is open and the
## money is 1000 a game); the profile still records the result (Progression.award) for his later layer.

signal rematch_requested
signal army_requested

const REASONS := {"elimination": "Last army standing", "control": "Held the zones", "time_limit": "Time ran out",
		"score_limit": "Score limit"}

var report: Dictionary
## Progression.credits_for's {"outcome", ...} for the player (only the outcome is shown).
var paid: Dictionary
var progression: Progression
var catalog: ArmyCatalog
## "The Law (CPU, seed 42)"
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


func outcome() -> String:
	return String(paid.get("outcome", "draw"))


func _build() -> void:
	ui_scale = CyberKit.s(self) * CyberStyle.touch_boost()
	var s := ui_scale
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var backdrop := ColorRect.new()
	backdrop.color = Color(CyberStyle.HUD_BACKGROUND, 0.94)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, roundi(CyberKit.GAP_L * 1.5 * s))
	add_child(margin)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", roundi(CyberKit.GAP_M * s))
	margin.add_child(rows)

	var accent := ResultsScreen.outcome_color(outcome())
	var headline := CyberStyle.label({"win": "VICTORY", "loss": "DEFEAT", "draw": "DRAW"}[outcome()], CyberKit.TITLE * 1.6 * s,
			accent)
	headline.name = "Headline"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_color_override("font_outline_color", Color.BLACK)
	headline.add_theme_constant_override("outline_size", 4)
	rows.add_child(headline)
	var reason := CyberStyle.label("%s  ·  %s  ·  vs %s" % [reason_text(report, outcome()),
			_duration(float(report.get("duration_seconds", 0.0))), enemy_label], CyberKit.BODY * s, Color(CyberStyle.TEXT, 0.75))
	reason.name = "Reason"
	reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(reason)
	if score_line(report) != "":
		var line := CyberStyle.label(score_line(report), CyberKit.BODY * s, CyberStyle.WHITE)
		line.name = "ScoreLine"
		line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(line)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", roundi(CyberKit.GAP_L * s))
	rows.add_child(body)
	body.add_child(_panel("YOUR ARMY", "green", CyberStyle.CYAN))
	body.add_child(_panel("THEIR ARMY", "rust", CyberStyle.PINK))

	var taught := lesson if lesson != "" else (point_lesson(report, outcome()) if point_lesson(report, outcome()) != ""
			else counter_lesson(report, catalog))
	var lesson_label := CyberStyle.label(taught, CyberKit.BODY * s, CyberStyle.YELLOW)
	lesson_label.name = "Lesson"
	lesson_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lesson_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(lesson_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(spacer)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", roundi(CyberKit.GAP_L * s))
	var army := CyberKit.button("ARMY", s)
	army.name = "Army"
	army.tooltip_text = "Back to the garage"
	army.custom_minimum_size.x = 220 * s
	army.pressed.connect(func() -> void: army_requested.emit())
	buttons.add_child(army)
	var rematch := CyberKit.button("REMATCH", s, CyberStyle.GREEN, CyberKit.HEADING)
	rematch.name = "Rematch"
	rematch.tooltip_text = "Fight the same opponent army again"
	rematch.custom_minimum_size.x = 260 * s
	rematch.pressed.connect(func() -> void: rematch_requested.emit())
	buttons.add_child(rematch)
	rows.add_child(buttons)


static func outcome_color(p_outcome: String) -> Color:
	return {"win": CyberStyle.GREEN, "loss": CyberStyle.PINK, "draw": CyberStyle.YELLOW}.get(p_outcome, CyberStyle.TEXT)


## One side's panel: its title in the side's colour, then what it fielded, lost, destroyed, and its best vehicle.
func _panel(title: String, team: String, accent: Color) -> Control:
	var s := ui_scale
	var panel := PanelContainer.new()
	panel.name = "Panel_" + title.replace(" ", "_")
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	panel.add_theme_stylebox_override("panel", CyberKit.panel_box(s, Color(accent, 0.6)))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * s))
	panel.add_child(box)
	box.add_child(CyberStyle.label(title, CyberKit.HEADING * s, accent))
	var summary: Dictionary = report.get("teams", {}).get(team, {})
	var lost := int(summary.get("units_lost", 0))
	box.add_child(_line("Fielded: " + MatchReport.describe_units(summary.get("units", {}), catalog), "Fielded_" + team))
	box.add_child(_line("Lost: " + (MatchReport.describe_units(summary.get("losses_by_unit", {}), catalog) if lost > 0 else "nothing"),
			"Lost_" + team, CyberStyle.PINK if lost > 0 else Color(CyberStyle.TEXT, 0.8)))
	var other := "rust" if team == "green" else "green"
	var kills := int(summary.get("kills", 0))
	var destroyed := ResultsScreen.credits_of(report.get("teams", {}).get(other, {}).get("losses_by_unit", {}))
	box.add_child(_line("Destroyed %d vehicle%s, worth %s" % [kills, "" if kills == 1 else "s", Credits.text(destroyed)],
			"Destroyed_" + team))
	var best: Dictionary = report.get("best_unit", {})
	if not best.is_empty() and String(best.get("team", "")).to_lower() == team:
		var unit_id := String(best["unit"])
		var unit_name := catalog.display_name(unit_id) if catalog.has_unit(unit_id) \
				else String(Units.profile(unit_id).get("display_name", unit_id))
		box.add_child(_line("Best: %s (%s), %d kill%s%s" % [_tank_label(String(best["name"])), unit_name, int(best["kills"]),
				"" if int(best["kills"]) == 1 else "s", "" if best.get("alive", false) else ", destroyed"], "BestUnit",
				CyberStyle.YELLOW))
	return panel


func _line(text: String, node_name: String, color := Color(CyberStyle.TEXT, 0.85)) -> Label:
	var label := CyberStyle.label(text, CyberKit.BODY * ui_scale, color)
	label.name = node_name
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


## What a set of vehicles cost, in credits: {unit: n} -> the sum of their prices (the board's "credits destroyed").
static func credits_of(counts: Dictionary) -> int:
	var total := 0
	for unit_id: String in counts:
		total += Credits.of_unit(unit_id) * int(counts[unit_id])
	return total


## "Green_Alpha_2" → "Alpha #2"
static func _tank_label(tank_name: String) -> String:
	var parts := tank_name.split("_")
	return "%s #%s" % [" ".join(parts.slice(1, parts.size() - 1)), parts[parts.size() - 1]] if parts.size() >= 3 else tank_name


## One sentence that teaches a counter: what the opponent fielded most, and which of HIS vehicles beat it. The other
## side is usually another faction (round 19), so its vehicle is named from the unit catalog and judged by its role.
static func counter_lesson(p_report: Dictionary, p_catalog: ArmyCatalog) -> String:
	var units: Dictionary = p_report.get("teams", {}).get("rust", {}).get("units", {})
	if units.is_empty():
		return ""
	var top := ""
	for unit_id: String in units:
		if top == "" or int(units[unit_id]) > int(units[top]) or (units[unit_id] == units[top] and unit_id < top):
			top = unit_id
	var role := p_catalog.role(top) if p_catalog.has_unit(top) else Units.role_of(top)
	var counters: PackedStringArray = []
	for unit_id in p_catalog.unit_ids():
		if p_catalog.good_vs(unit_id).has(role):
			counters.append(GarageAdvice._pluralize(p_catalog.display_name(unit_id)))
	var top_name := GarageAdvice._pluralize(p_catalog.display_name(top) if p_catalog.has_unit(top)
			else String(Units.profile(top).get("display_name", top.capitalize())))
	if counters.is_empty():
		return "Their army was mostly %s." % top_name
	return "Their army was mostly %s. %s %s built to beat them." % [top_name, " and ".join(counters),
			"is" if counters.size() == 1 and counters[0].begins_with("Artillery") else "are"]


## How the map's scoring zones are named in a sentence: "the rings" where the map scores two (every dealt map),
## "the centre" where it scores one. Board's request (round 19): the reason line said "the centre" on two-ring maps.
## Without the board's final score (an older report) it stays "the centre".
static func zones_noun(p_report: Dictionary) -> String:
	var score: Variant = p_report.get("score")
	if score is Dictionary and (score.get("objectives", []) as Array).size() > 1:
		return "the rings"
	return "the centre"


## "Points 34 to 12  ·  Kills 5 to 3  ·  Destroyed 220 CR to 140 CR" from the board's final score (you first), or "".
static func score_line(p_report: Dictionary) -> String:
	var score: Variant = p_report.get("score")
	if not score is Dictionary or (score.get("sides", []) as Array).size() < 2:
		return ""
	var sides: Array = score["sides"]
	var you: Dictionary = sides[0]
	var them: Dictionary = sides[1]
	var parts: PackedStringArray = []
	if bool(score.get("control", false)):
		parts.append("Points %d to %d of %d" % [int(you.get("points", 0)), int(them.get("points", 0)),
				int(score.get("points_to_win", 0))])
	parts.append("Kills %d to %d" % [int(you.get("kills", 0)), int(them.get("kills", 0))])
	parts.append("Destroyed %s to %s" % [Credits.text(Credits.of_points(int(you.get("points_destroyed", 0)))),
			Credits.text(Credits.of_points(int(them.get("points_destroyed", 0))))])
	return "  ·  ".join(parts)


static func _duration(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]


## Round 15 (H6): a time-out lost on the control point teaches the first fight's tip, word for word (CentreTip.LINE),
## instead of a counter lesson about units that never fought. "" otherwise.
static func point_lesson(p_report: Dictionary, p_outcome: String) -> String:
	var control: Variant = p_report.get("control")
	if p_outcome != "loss" or String(p_report.get("reason", "")) != "time_limit" or not control is Dictionary:
		return ""
	return CentreTip.LINE if int(control.get("rust", 0)) > int(control.get("green", 0)) else ""


## The line under the headline: why the match ended. Round 14 (G3): a time-out says how Match.result judged it -- the
## control point first when either side held it longer, then points destroyed; equal is a draw. Round 13's tour: a
## time-out with nothing lost read just "DEFEAT · Time ran out", and the player could not see that the CPU had held
## the centre the whole time.
static func reason_text(p_report: Dictionary, p_outcome: String) -> String:
	var why := String(p_report.get("reason", ""))
	if why != "time_limit":
		return String(REASONS.get(why, why.capitalize()))
	if p_outcome == "draw":
		return "%s — draw" % REASONS[why]
	var control: Variant = p_report.get("control")
	if control is Dictionary and int(control.get("green", 0)) != int(control.get("rust", 0)):
		return "%s — %s held %s longer (%d to %d)" % [REASONS[why], "you" if p_outcome == "win" else "they",
				ResultsScreen.zones_noun(p_report),
				maxi(int(control["green"]), int(control["rust"])), mini(int(control["green"]), int(control["rust"]))]
	return "%s — %s destroyed more" % [REASONS[why], "you" if p_outcome == "win" else "they"]
