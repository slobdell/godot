class_name FactionPicker
extends Control
## Control X5 (L3): choose a faction per side before a skirmish.
##
## The lead wanted army size to be a consequence, not a setting: "the gang is diluted with cheaper units, so it
## should be a bigger swarm, the condemned have more expensive and smaller unit counts from there, then the law
## ... and the syndicate would have the fewest". So the picker shows what each faction actually fields at the
## match budget - the Road Gangs bring 44 vehicles where the Syndicate brings 17 - and nothing else to set.
##
##   1-4 or click        your faction        shift+1-4 or right-click   the enemy's
##   FIGHT or Enter      fight               Escape                     fight with the defaults
##
## Picking restarts the skirmish with --player-faction / --enemy-faction (Main.next_flags, trip-up 61), so the
## armies are built by the same code path as the flags. `make skirmish --player-faction=gangs` skips it entirely.

signal chosen(player_faction: String, enemy_faction: String)

const PAD := 14.0
## Rows are this tall at 1080p and the panel this wide, scaled with the window.
const ROW := 74.0
const WIDTH := 880.0
## Seeded the same way every time, so the counts shown are the counts you get.
const PREVIEW_SEED := 3

var player_faction := Units.DEFAULT_FACTION
var enemy_faction := Units.DEFAULT_FACTION
var budget := Units.BASELINE_BUDGET

var _rows := {}  # "<faction>:<side>" -> Rect2 (local)
var _fight := Rect2()
var _choices: Array = []
var _hover_fight := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	z_index = 80
	set_process_unhandled_key_input(true)


## What each faction fields at `match_budget`, as data (drawn below, checked by tests):
## [{"faction", "name", "units": int, "average_cost": float, "summary"}]. A faction with no armies is skipped.
static func options(match_budget: int) -> Array:
	var result: Array = []
	for faction: String in Units.FACTIONS:
		var loaded := Army.load_army("cpu", PREVIEW_SEED, match_budget, faction)
		if loaded.has("error"):
			continue
		var doctrine: Dictionary = loaded["doctrine"]
		var units := 0
		for squad: Dictionary in doctrine["squads"]:
			units += (squad["units"] as Array).size()
		result.append({"faction": faction, "name": String(Units.FACTION_NAMES.get(faction, faction)),
				"units": units, "average_cost": Units.roster_average_cost(faction),
				"summary": Army.describe(doctrine)})
	return result


## `options(budget)`, built once and reused by every redraw and key press (it assembles four armies).
func choices() -> Array:
	if _choices.is_empty():
		_choices = options(budget)
	return _choices


## The FIGHT button, in local coordinates (empty until the menu has been drawn once).
func fight_rect() -> Rect2:
	return _fight


func set_side(faction: String, enemy: bool) -> void:
	if not Units.FACTIONS.has(faction):
		return
	if enemy:
		enemy_faction = faction
	else:
		player_faction = faction
	queue_redraw()


## Start the match with what is picked.
func confirm() -> void:
	chosen.emit(player_faction, enemy_faction)


func row_rect(faction: String, enemy: bool) -> Rect2:
	return _rows.get("%s:%s" % [faction, "enemy" if enemy else "player"], Rect2())


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var index := int(key.keycode - KEY_1)
		if index < choices().size():
			set_side(String(choices()[index]["faction"]), key.shift_pressed)
			get_viewport().set_input_as_handled()
		return
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_ESCAPE]:
		confirm()
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		var over := _fight.has_point(motion.position)
		if over != _hover_fight:
			_hover_fight = over
			mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if over else Control.CURSOR_ARROW
			queue_redraw()
		return
	var button := event as InputEventMouseButton
	if button == null:
		return
	accept_event()
	if _fight.has_point(button.position):
		# Confirm on release, like a Button, so the press can't leak into the match that starts behind it.
		if not button.pressed and button.button_index == MOUSE_BUTTON_LEFT:
			confirm()
		return
	if not button.pressed:
		return
	var enemy := button.button_index == MOUSE_BUTTON_RIGHT
	for key: String in _rows:
		if (_rows[key] as Rect2).has_point(button.position):
			set_side(key.split(":")[0], enemy)
			return


func _draw() -> void:
	var s := CyberStyle.ui_scale(size)
	var font := CyberStyle.font()
	var listed := choices()
	var panel := Rect2(Vector2.ZERO, Vector2(minf(WIDTH * s, size.x - PAD * 2.0), (ROW * (listed.size() + 2.2)) * s))
	panel.position = (size - panel.size) / 2.0
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.72))
	draw_rect(panel, Color(CyberStyle.HUD_BACKGROUND, 0.96))
	draw_rect(panel, Color(CyberStyle.CYAN, 0.8), false, 2.0)
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy_color: Color = GameTheme.ui["enemy"]
	var x := panel.position.x + PAD * s
	var y := panel.position.y + PAD * s
	draw_string(font, Vector2(x, y + 24.0 * s), "CHOOSE YOUR FACTION", HORIZONTAL_ALIGNMENT_LEFT, -1,
			roundi(24.0 * s), CyberStyle.CYAN)
	draw_string(font, Vector2(x, y + 46.0 * s),
			"click yours, right-click theirs (or 1-4, shift+1-4)   budget %d: size is the faction's, not a setting" % budget,
			HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(14.0 * s), Color(CyberStyle.TEXT, 0.75))
	y += ROW * 0.9 * s
	_rows.clear()
	for i in listed.size():
		var option: Dictionary = listed[i]
		var faction := String(option["faction"])
		var row := Rect2(x, y, panel.size.x - PAD * s * 2.0, ROW * s - 6.0 * s)
		_rows["%s:player" % faction] = Rect2(row.position, Vector2(row.size.x * 0.5, row.size.y))
		_rows["%s:enemy" % faction] = Rect2(row.position + Vector2(row.size.x * 0.5, 0.0), Vector2(row.size.x * 0.5, row.size.y))
		var mine := faction == player_faction
		var theirs := faction == enemy_faction
		draw_rect(row, Color(CyberStyle.CARD, 0.95))
		if mine:
			draw_rect(_rows["%s:player" % faction], Color(friendly, 0.22))
		if theirs:
			draw_rect(_rows["%s:enemy" % faction], Color(enemy_color, 0.22))
		draw_rect(row, Color(friendly if mine else (enemy_color if theirs else CyberStyle.CYAN), 0.9 if mine or theirs else 0.3),
				false, 2.0 if mine or theirs else 1.0)
		draw_string(font, row.position + Vector2(10.0 * s, 24.0 * s), "%d  %s" % [i + 1, option["name"]],
				HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(19.0 * s), CyberStyle.TEXT)
		draw_string(font, row.position + Vector2(10.0 * s, 46.0 * s),
				"%d vehicles   %d pts each   %s" % [int(option["units"]), roundi(float(option["average_cost"])), option["summary"]],
				HORIZONTAL_ALIGNMENT_LEFT, row.size.x - 20.0 * s, roundi(13.0 * s), Color(CyberStyle.TEXT, 0.75))
		if mine:
			draw_string(font, row.position + Vector2(row.size.x * 0.5 - 52.0 * s, 24.0 * s), "YOURS",
					HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15.0 * s), friendly)
		if theirs:
			draw_string(font, row.position + Vector2(row.size.x - 62.0 * s, 24.0 * s), "ENEMY",
					HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(15.0 * s), enemy_color)
		y += ROW * s
	# Never smaller than a comfortable click target, however small the window.
	var fight_size := Vector2(maxf(200.0 * s, 160.0), maxf(48.0 * s, 44.0))
	_fight = Rect2(Vector2(panel.end.x - PAD * s - fight_size.x, y + 6.0 * s), fight_size)
	var fight_color := CyberStyle.YELLOW
	draw_rect(_fight, Color(fight_color, 0.35 if _hover_fight else 0.18))
	draw_rect(_fight, Color(fight_color, 1.0 if _hover_fight else 0.8), false, 2.0)
	draw_string(font, _fight.position + Vector2(0.0, _fight.size.y * 0.5 + 9.0 * s), "FIGHT", HORIZONTAL_ALIGNMENT_CENTER,
			_fight.size.x, roundi(24.0 * s), fight_color)
	draw_string(font, Vector2(x, _fight.get_center().y + 6.0 * s), "or Enter", HORIZONTAL_ALIGNMENT_LEFT, -1,
			roundi(15.0 * s), Color(CyberStyle.TEXT, 0.6))
