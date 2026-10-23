class_name EndCard
extends Control
## Round 38 (feedback F1/F2): the end of a match he commands. The Hud mounts it on `Match.finished`.
##
## F2: once the match is over, a click on the field or an order key no longer orders anything (round 37: his clicks after the
## end still answered "move"). A click says MATCH OVER where he clicked and the choices pulse; the wheel and a middle drag still
## look around (RtsCamera.handle_mouse), and the camera's keys are polled, so they keep working.
##
## F1, his pick A on the directions page (2026-10-23, game_design.md): the END CARD. The battle dims, the command overlay hides,
## and a card names the result, why it ended (MatchEnd), what was left on the field, and the two choices. The losing looks
## (the old banner plus why, the broadcast bars, the band) are deleted. Enter plays again (his factions and map, a new seed),
## Esc opens the faction menu (`chosen`). Under the garage loop the results screen follows on its own, so there are no choices
## (`choices = false`).
##
## All animation runs on `advance(delta)` (tests step it), PROCESS_MODE_ALWAYS.

signal chosen(choice: String)
## A click on the field after the end (F2), where it landed.
signal field_clicked(at: Vector2)

const DIM_ALPHA := 0.62
const DIM_SECONDS := 0.5
const SLAM_SECONDS := 0.35
const NOTICE_SECONDS := 1.4
const PULSE_SECONDS := 0.6
## The choices appear this long after the end, so a click already on its way cannot restart the game.
const CHOICES_AFTER := 0.6
const CHOICES := ["again", "factions"]
const CHOICE_TEXT := {"again": "PLAY AGAIN  [ENTER]", "factions": "NEW MATCH  [ESC]"}

var result: Dictionary = {}
var team := Match.Team.GREEN
var spectated := false
var factions := {}
var choices := true
## The RtsCamera (wheel and middle drag look around after the end); null in tests.
var rig: Node
## Nodes the end hides (the command overlay).
var hide_nodes: Array[CanvasItem] = []
## The garage loop (ArmyLoop): once its results screen is up (`results`), keys are its own, not swallowed here.
var yield_to: Node

var headline := ""
var reason := ""
var score := ""
var _clock := 0.0
var _notices: Array[Dictionary] = []
var _pulse := 0.0
var _choice_rects := {}
var _hover := ""
var _done := false
var _font: Font = CyberStyle.font()


func setup(p_result: Dictionary, p_team: int, p_spectated: bool, p_factions: Dictionary) -> void:
	result = p_result
	team = p_team
	spectated = p_spectated
	factions = p_factions
	headline = MatchEnd.headline(result, team, spectated, factions)
	reason = MatchEnd.reason_line(result, team if not spectated else -1, factions)
	score = MatchEnd.score_line(result, team if not spectated else -1, factions)


func _ready() -> void:
	name = "EndCard"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for node in hide_nodes:
		if is_instance_valid(node):
			node.visible = false
	print("END_CARD headline=%s reason=\"%s\" choices=%s" % [headline, reason, choices])


func _process(delta: float) -> void:
	advance(delta)


func advance(seconds: float) -> void:
	_clock += seconds
	_pulse = maxf(_pulse - seconds, 0.0)
	for notice in _notices:
		notice["left"] = float(notice["left"]) - seconds
	_notices = _notices.filter(func(n: Dictionary) -> bool: return float(n["left"]) > 0.0)
	queue_redraw()


func choices_shown() -> bool:
	return choices and _clock >= CHOICES_AFTER


## Pick a choice (Enter / Esc / a click on it). Once only.
func choose(choice: String) -> bool:
	if _done or not choices_shown() or not CHOICES.has(choice):
		return false
	_done = true
	print("END_CARD_CHOSEN %s" % choice)
	chosen.emit(choice)
	return true


## F2: a click on the field after the end. Says so where it landed, and the choices pulse.
func field_click(at: Vector2) -> void:
	_notices.append({"position": at, "left": NOTICE_SECONDS})
	_pulse = PULSE_SECONDS
	print("END_CARD_FIELD_CLICK at=(%d,%d)" % [int(at.x), int(at.y)])
	field_clicked.emit(at)
	queue_redraw()


func notices() -> int:
	return _notices.size()


func _gui_input(event: InputEvent) -> void:
	accept_event()
	if rig != null and rig.has_method("handle_mouse") and bool(rig.call("handle_mouse", event)):
		return
	if event is InputEventMouseMotion:
		_hover = _choice_at((event as InputEventMouseMotion).position)
		return
	var button := event as InputEventMouseButton
	if button == null or not button.pressed:
		return
	if button.button_index == MOUSE_BUTTON_LEFT:
		var choice := _choice_at(button.position)
		if choice != "" and choose(choice):
			return
	if button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		field_click(button.position)


## Every key stops here once the match is over: no order hotkey, group recall or pause reaches the controls (they read
## `_unhandled_key_input`). The camera's keys are polled (Input.is_key_pressed), so it still pans and turns.
func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or (is_instance_valid(yield_to) and yield_to.get("results") != null):
		return
	get_viewport().set_input_as_handled()
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			choose("again")
		KEY_ESCAPE:
			choose("factions")


func _choice_at(at: Vector2) -> String:
	if not choices_shown():
		return ""
	for choice: String in _choice_rects:
		if (_choice_rects[choice] as Rect2).has_point(at):
			return choice
	return ""


## The result's colour: his side's on a win, the enemy's on a loss, yellow for a draw.
func colour() -> Color:
	match MatchEnd.outcome(result, team if not spectated else -1):
		"win":
			return GameTheme.ui.get("friendly", CyberStyle.CYAN)
		"loss":
			return GameTheme.ui.get("enemy", CyberStyle.PINK)
		"draw":
			return CyberStyle.YELLOW
	return CyberStyle.CYAN


# ---- Drawing ----------------------------------------------------------------------------------------------------------

func _draw() -> void:
	var started := HudClock.begin()
	_choice_rects.clear()
	# The SHORTER side sets the scale: a portrait phone (810 x 1800) sized from its height drew everything wider than the screen.
	# A touch device grows it like the rest of the HUD (CyberStyle.touch_boost, 1.5x); lines shrink to fit their boxes.
	var s := (minf(size.x, size.y) / 1080.0 if size.y > 0.0 and size.x > 0.0 else 1.0) * CyberStyle.touch_boost()
	_draw_card(s)
	_draw_notices(s)
	HudClock.end(&"end_card.draw", started)


func _draw_card(s: float) -> void:
	var dim := clampf(_clock / DIM_SECONDS, 0.0, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.03, DIM_ALPHA * dim))
	var card_size := Vector2(minf(940.0 * s, size.x - 32.0), 380.0 * s)
	var card := Rect2((size - card_size) * 0.5, card_size)
	var tint := colour()
	draw_rect(card, Color(CyberStyle.CARD, 0.94 * dim))
	draw_rect(card, Color(tint, dim), false, maxf(3.0 * s, 1.0))
	draw_rect(Rect2(card.position, Vector2(card.size.x, 8.0 * s)), Color(tint, dim))
	var slam := clampf(_clock / SLAM_SECONDS, 0.0, 1.0)
	var title_size := 112.0 * s * lerpf(1.45, 1.0, CyberStyle.decelerate(slam))
	_text(headline, Vector2(card.position.x, card.position.y + 140.0 * s), card.size.x, title_size, Color(tint, slam), 10.0 * s)
	_text(reason, Vector2(card.position.x, card.position.y + 205.0 * s), card.size.x, 32.0 * s, Color(CyberStyle.WHITE, dim), 0.0)
	_text(score, Vector2(card.position.x, card.position.y + 248.0 * s), card.size.x, 22.0 * s, Color(CyberStyle.TEXT, 0.8 * dim), 0.0)
	_draw_choices(Rect2(Vector2(card.position.x + 60.0 * s, card.end.y - 92.0 * s), Vector2(card.size.x - 120.0 * s, 56.0 * s)),
			s, 22.0 * s)


## The two choices side by side in `rect` (nothing until they are shown; they pulse after a field click).
func _draw_choices(rect: Rect2, s: float, font_size: float) -> void:
	if not choices_shown():
		return
	var appear := clampf((_clock - CHOICES_AFTER) / 0.25, 0.0, 1.0)
	var pulse := sin(_pulse / PULSE_SECONDS * PI * 3.0) * 0.5 + 0.5 if _pulse > 0.0 else 0.0
	var gap := 24.0 * s
	var w := (rect.size.x - gap) * 0.5
	for i in CHOICES.size():
		var choice: String = CHOICES[i]
		var box := Rect2(Vector2(rect.position.x + i * (w + gap), rect.position.y), Vector2(w, rect.size.y))
		_choice_rects[choice] = box
		var lit := choice == _hover or (i == 0 and pulse > 0.5)
		var edge := CyberStyle.YELLOW if lit else CyberStyle.BORDER_CYAN
		draw_rect(box, Color(0.02, 0.02, 0.08, 0.85 * appear))
		draw_rect(box, Color(edge, appear), false, maxf(2.0 * s, 1.0))
		_text(String(CHOICE_TEXT[choice]), Vector2(box.position.x, box.position.y + box.size.y * 0.5 + font_size * 0.36), box.size.x,
				font_size, Color(CyberStyle.WHITE if lit else CyberStyle.TEXT, appear), 0.0)


func _draw_notices(s: float) -> void:
	for notice in _notices:
		var left := float(notice["left"]) / NOTICE_SECONDS
		var at: Vector2 = notice["position"]
		var rise := (1.0 - left) * 26.0 * s
		_text("MATCH OVER", Vector2(at.x - 200.0 * s, at.y - 18.0 * s - rise), 400.0 * s, 26.0 * s,
				Color(CyberStyle.YELLOW, clampf(left * 2.0, 0.0, 1.0)), 6.0 * s)


func _text(text: String, baseline: Vector2, width: float, font_size: float, colour_: Color, outline: float,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	if text == "" or colour_.a <= 0.0:
		return
	var px := maxi(int(round(font_size)), 6)
	# Never clipped: a line too long for its box steps down until it fits (a portrait phone, a long faction name).
	while width > 0.0 and px > 8 and _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
		px -= 1
	if outline > 0.0:
		draw_string_outline(_font, baseline, text, align, width, px, int(round(outline)), Color(0, 0, 0, colour_.a))
	draw_string(_font, baseline, text, align, width, px, colour_)
