class_name CyberBanner
extends Control
## The mavlink-hud message banner (_agents/streams/references/hud_message_banner.md): a CyberFrame
## that enters as a glowing beam, opens like a shutter (warnings add a glitch strobe and a bounce),
## types each message with a █ cursor, keeps a history below, and closes 5 s after the last one.
##
## Two instances make the HUD's message system (see CyberMessages): STATUS at the bottom (info,
## cyan) and WARNING at the top (yellow warnings, red errors). All animation runs in advance(delta)
## on a manual timeline (not Tweens), so tests can step it exactly and it runs during the tactical
## pause. Layout follows the spec: 60% × 9% of the screen, 16 px (×scale) from the edge.

enum Kind { STATUS, WARNING }
enum Severity { INFO, WARNING, ERROR }
enum State { HIDDEN, ENTERING, SHOWN, EXITING }

const DISMISS_SECONDS := 5.0
const TYPE_MIN_SECONDS := 0.25
const TYPE_MAX_SECONDS := 0.6
const TYPE_TICK := 1.0 / 30.0
const BLINK_SECONDS := 0.3
const BEAM_HEIGHT := 0.05
const CURSOR := "█"
const WIDTH_FRACTION := 0.6
const HEIGHT_FRACTION := 0.09
const MARGIN_1080 := 16.0
const FONT_1080 := 25.2
const PADDING_1080 := 24.0

@export var kind := Kind.STATUS

var state := State.HIDDEN
## Previous messages, newest first, one per line (persists across appearances).
var history := ""
var frame := CyberFrame.new()
## Returns the timestamp prefix ("HH:MM:SS"). Tests and replays can substitute a fixed clock.
var clock: Callable = func() -> String: return Time.get_time_string_from_system()

var _text_box := Control.new()
var _current_label: Label
var _history_label: Label
var _severity := Severity.INFO
var _last_text := ""
var _pending := ""
var _dismiss_left := -1.0
# Timeline: [{duration, step: Callable(t 0..1)}], then _on_timeline_done.
var _timeline: Array[Dictionary] = []
var _segment_elapsed := 0.0
var _on_timeline_done := Callable()
# Typewriter.
var _full := ""
var _typing := false
var _type_elapsed := 0.0
var _type_duration := 0.4
var _type_tick := 0.0
var _shown_chars := -1
var _blink_elapsed := 0.0
var _cursor_on := true
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 20260914


func _ready() -> void:
	frame.name = "Frame"
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)
	_text_box.name = "Text"
	_text_box.clip_contents = true
	_text_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_text_box)
	_current_label = CyberStyle.label()
	_current_label.name = "Current"
	_history_label = CyberStyle.label()
	_history_label.name = "History"
	_history_label.modulate = Color(1, 1, 1, 0.55)
	for label in [_current_label, _history_label]:
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_text_box.add_child(label)
	frame.apply_theme(CyberStyle.THEME_INFO)
	_set_box(0.0, BEAM_HEIGHT, 0.0)
	_text_box.visible = false
	get_viewport().size_changed.connect(layout)
	layout()


func _process(delta: float) -> void:
	advance(delta)


## Place and size the banner for the current screen (spec §2 and §4).
func layout() -> void:
	var screen := get_viewport_rect().size
	var scale_1080 := CyberStyle.ui_scale(screen)
	var font_size := roundi(FONT_1080 * scale_1080)
	var line := font_size * 1.25
	# 9% of the screen, but always room for the current line plus a peek at history (touch boost).
	var box := Vector2(screen.x * WIDTH_FRACTION, maxf(screen.y * HEIGHT_FRACTION, line * 2.2))
	var margin := MARGIN_1080 * scale_1080
	var top := margin if kind == Kind.WARNING else screen.y - margin - box.y
	position = Vector2((screen.x - box.x) / 2.0, top)
	size = box
	var padding := PADDING_1080 * scale_1080
	for label in [_current_label, _history_label]:
		label.add_theme_font_size_override("font_size", font_size)
		label.size = Vector2(box.x - padding * 2.0, line)
	_current_label.position = Vector2(padding, (box.y - line) / 2.0 - line * 0.35)
	_history_label.position = Vector2(padding, _current_label.position.y + line)
	_history_label.size.y = maxf(box.y - _history_label.position.y, line)


## Show a message. INFO goes to a STATUS banner; WARNING/ERROR restyle a WARNING banner.
func post(text: String, severity := Severity.INFO) -> void:
	if text == _last_text:
		return  # consecutive duplicates are dropped (spec §7)
	_last_text = text
	_dismiss_left = DISMISS_SECONDS
	if kind == Kind.WARNING and severity != _severity:
		_severity = severity
		frame.apply_theme(CyberStyle.THEME_ERROR if severity == Severity.ERROR else CyberStyle.THEME_WARNING)
		var theme := CyberStyle.THEME_ERROR if severity == Severity.ERROR else CyberStyle.THEME_WARNING
		_current_label.add_theme_color_override("font_color", theme["text"])
		_history_label.add_theme_color_override("font_color", theme["text"])
	var line := "%s: %s" % [clock.call(), text]
	match state:
		State.HIDDEN:
			_pending = line
			_enter()
		State.ENTERING:
			# A burst during the entrance: the older pending line goes straight to history.
			if _pending != "":
				_push_history(_pending)
			_pending = line
		State.SHOWN, State.EXITING:
			# Don't replay the entrance (spec §6.5): snap open and type.
			_timeline.clear()
			state = State.SHOWN
			_set_box(1.0, 1.0, 1.0)
			_text_box.visible = true
			_type(line)


## Step every animation by `delta` seconds (called from _process; tests call it directly).
func advance(delta: float) -> void:
	_advance_timeline(delta)
	_advance_typewriter(delta)
	if state == State.SHOWN and _dismiss_left > 0.0:
		_dismiss_left -= delta
		if _dismiss_left <= 0.0:
			_exit()


## What the current line shows right now (with the cursor when it's on).
func displayed_text() -> String:
	return _current_label.text if _current_label != null else ""


func current_text() -> String:
	return _full


# ---- Choreography (spec §6) ----------------------------------------------------------------

func _enter() -> void:
	state = State.ENTERING
	_text_box.visible = false
	if kind == Kind.STATUS:
		_set_box(0.0, BEAM_HEIGHT, 0.0)
		_run([
			{"duration": 0.2, "step": func(t: float) -> void: _set_box(CyberStyle.decelerate(t), BEAM_HEIGHT, 1.0)},
			{"duration": 0.15, "step": func(t: float) -> void: _set_box(1.0, lerpf(BEAM_HEIGHT, 1.0, CyberStyle.ease_in_out(t)), 1.0)},
		], _entered)
	else:
		_set_box(0.0, BEAM_HEIGHT, 1.0)
		_run([
			{"duration": 0.5, "step": func(t: float) -> void: _set_box(CyberStyle.decelerate(t), BEAM_HEIGHT, 1.0)},
			{"duration": 0.4, "step": func(t: float) -> void: _set_box(1.0, lerpf(BEAM_HEIGHT, 1.0, CyberStyle.ease_in_out(t)), 1.0)},
			{"duration": 0.4, "step": func(t: float) -> void: _set_box(1.0, 1.0, glitch_alpha(CyberStyle.ease_in_out(t)))},
			{"duration": 0.3, "step": func(t: float) -> void:
				var s := lerpf(1.1, 1.0, CyberStyle.bounce(t))
				_set_box(s, s, 1.0)},
		], _entered)


func _entered() -> void:
	state = State.SHOWN
	_set_box(1.0, 1.0, 1.0)
	_text_box.visible = true
	if _pending != "":
		_type(_pending)
		_pending = ""


func _exit() -> void:
	state = State.EXITING
	_text_box.visible = false
	var fades := kind == Kind.STATUS
	_run([
		{"duration": 0.8, "step": func(t: float) -> void: _set_box(1.0, lerpf(1.0, BEAM_HEIGHT, CyberStyle.ease_in_out(t)), 1.0)},
		{"duration": 0.8, "step": func(t: float) -> void:
			var k := 1.0 - CyberStyle.ease_in_out(t)
			_set_box(k, BEAM_HEIGHT, k if fades else 1.0)},
	], _exited)


func _exited() -> void:
	state = State.HIDDEN
	_set_box(0.0, BEAM_HEIGHT, 0.0)
	# The in-flight line joins the history; the views clear, the history string stays (spec §6.4).
	if _full != "":
		_push_history(_full)
	_full = ""
	_typing = false
	_last_text = ""
	_current_label.text = ""
	_history_label.text = history


## Glitch strobe keyframes 1 → 0.2 → 1 → 0.5 → 1 at quarters, linear between.
static func glitch_alpha(u: float) -> float:
	var keys := [1.0, 0.2, 1.0, 0.5, 1.0]
	var position := clampf(u, 0.0, 1.0) * 4.0
	var i := mini(int(position), 3)
	return lerpf(keys[i], keys[i + 1], position - i)


func _run(segments: Array[Dictionary], done: Callable) -> void:
	_timeline = segments
	_segment_elapsed = 0.0
	_on_timeline_done = done


func _advance_timeline(delta: float) -> void:
	var remaining := delta
	while not _timeline.is_empty() and remaining > 0.0:
		var segment := _timeline[0]
		var duration: float = segment["duration"]
		var used := minf(remaining, duration - _segment_elapsed)
		_segment_elapsed += used
		remaining -= used
		(segment["step"] as Callable).call(clampf(_segment_elapsed / duration, 0.0, 1.0))
		if _segment_elapsed >= duration - 0.00001:
			_timeline.pop_front()
			_segment_elapsed = 0.0
			if _timeline.is_empty() and _on_timeline_done.is_valid():
				var done := _on_timeline_done
				_on_timeline_done = Callable()
				done.call()


func _set_box(width: float, height: float, alpha: float) -> void:
	frame.anim_width = width
	frame.anim_height = height
	frame.anim_alpha = alpha


# ---- Typewriter + history (spec §4) ----------------------------------------------------------

func _type(line: String) -> void:
	if _full != "":
		_push_history(_full)  # the in-flight message force-finishes into history
	_full = line
	_typing = true
	_type_elapsed = 0.0
	_type_tick = TYPE_TICK  # draw the first frame immediately
	_type_duration = _rng.randf_range(TYPE_MIN_SECONDS, TYPE_MAX_SECONDS)
	_shown_chars = -1
	_blink_elapsed = 0.0
	_cursor_on = true
	_history_label.text = history


func _advance_typewriter(delta: float) -> void:
	if _full == "":
		return
	if _typing:
		_type_elapsed += delta
		_type_tick += delta
		if _type_tick < TYPE_TICK:
			return
		_type_tick = 0.0
		var count := mini(_full.length(), int(floor(_full.length() * _type_elapsed / _type_duration)))
		if _type_elapsed >= _type_duration:
			count = _full.length()
			_typing = false
		if count != _shown_chars:
			_shown_chars = count
			_current_label.text = _full.substr(0, count) + CURSOR
	else:
		_blink_elapsed += delta
		if _blink_elapsed >= BLINK_SECONDS:
			_blink_elapsed -= BLINK_SECONDS
			_cursor_on = not _cursor_on
			_current_label.text = _full + (CURSOR if _cursor_on else "")


func _push_history(line: String) -> void:
	if not history.begins_with(line):
		history = line + ("\n" + history if history != "" else "")
	var cap := 500 if kind == Kind.WARNING else 1000
	if history.length() > cap:
		history = history.substr(0, cap)
	if _history_label != null:
		_history_label.text = history
