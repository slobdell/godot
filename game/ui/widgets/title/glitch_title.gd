class_name GlitchTitle
extends Control
## Big title text in the HUD language: types in with a block cursor, then idles with a faint neon
## breathe and, every few seconds, a glitch burst (cyan/magenta channel split that jitters, a flicker,
## and a horizontal slice shoved sideways). Drawn with the font directly; redraws only while
## something moves.

@export var text := "TANK SQUAD"
@export var size_1080 := 150.0
@export var type_seconds := 0.9

var color := CyberStyle.WHITE
var _time := 0.0
var _glitch_left := 0.0
var _next_glitch := 2.5
var _rng := RandomNumberGenerator.new()
var _split := Vector2.ZERO
var _slice := 0.0
var _slice_y := 0.5


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 42


func _process(delta: float) -> void:
	_time += delta
	_next_glitch -= delta
	if _next_glitch <= 0.0:
		_glitch_left = _rng.randf_range(0.12, 0.35)
		_next_glitch = _rng.randf_range(2.5, 5.5)
	if _glitch_left > 0.0:
		_glitch_left -= delta
		_split = Vector2(_rng.randf_range(-9.0, 9.0), _rng.randf_range(-2.0, 2.0))
		_slice = _rng.randf_range(-40.0, 40.0) if _rng.randf() < 0.6 else 0.0
		_slice_y = _rng.randf_range(0.2, 0.8)
	else:
		_split = Vector2(1.5, 0.0)
		_slice = 0.0
	queue_redraw()


func _draw() -> void:
	var font := CyberStyle.font()
	var font_size := roundi(size_1080 * CyberStyle.ui_scale(get_viewport_rect().size))
	var shown := mini(text.length(), int(text.length() * _time / type_seconds))
	var visible_text := text.substr(0, shown) + (CyberBanner.CURSOR if _time < type_seconds + 0.6 and fmod(_time, 0.3) < 0.18 else "")
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var origin := Vector2((size.x - width) / 2.0, size.y / 2.0 + font_size * 0.35)
	var flicker := 0.55 if _glitch_left > 0.0 and _rng.randf() < 0.3 else 1.0
	var breathe := 0.85 + 0.15 * sin(_time * 1.3)
	# Channel split: magenta and cyan ghosts under the white core.
	draw_string(font, origin - _split, visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CyberStyle.PINK, 0.75 * flicker))
	draw_string(font, origin + _split, visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CyberStyle.CYAN, 0.75 * flicker))
	draw_string(font, origin, visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(color, breathe * flicker))
	if _slice != 0.0:
		# A displaced slice: redraw the text shifted, masked to a thin band by a dark bar above/below.
		var band := Rect2(0, origin.y - font_size * (1.0 - _slice_y) - 6.0, size.x, 12.0)
		draw_rect(band, Color(CyberStyle.HUD_BACKGROUND, 0.85))
		draw_string(font, origin + Vector2(_slice, 0), visible_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(CyberStyle.CYAN, 0.5))
