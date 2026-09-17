class_name CaptionLine
extends Control
## Control X2 (round 5): the booth's subtitles on their own line, so the message log stays for what the player must
## act on (kills, losses, orders, the control point). Audio's evidence: three of four visible log lines were the
## announcer on desktop, and a kill message was buried on a phone.
##
## One caption at a time, top centre, like a broadcast lower-third turned upside down (the bottom of the screen is
## the command card's): the speaker in their colour, the line in white on a dark strip, wrapping to at most two
## lines. A new line replaces the old one at once; a line holds for as long as it takes to read, then fades.

## Seconds a caption stays up: a floor, plus reading time per character, up to a ceiling.
const HOLD_MIN := 2.5
const HOLD_PER_CHAR := 0.055
const HOLD_MAX := 7.0
const FADE_SECONDS := 0.4
## Text size at 1080p; never below MIN_FONT px so it reads at 1280×720.
const FONT_1080 := 26.0
const MIN_FONT := 18
const WIDTH_FRACTION := 0.56
const TOP_FRACTION := 0.075
const SPEAKER_COLORS := {"CALLER": CyberStyle.YELLOW, "VETERAN": CyberStyle.CYAN, "PA": CyberStyle.PINK}

var speaker := ""
var text := ""
## Seconds left on screen (fading through the last FADE_SECONDS).
var left := 0.0

var _speaker_label := Label.new()
var _text_label := Label.new()


func _init() -> void:
	name = "CaptionLine"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	for label: Label in [_speaker_label, _text_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_override("font", CyberStyle.font())
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		label.add_theme_constant_override("outline_size", 4)
		add_child(label)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.max_lines_visible = 2
	_text_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_text_label.add_theme_color_override("font_color", CyberStyle.WHITE)
	visible = false


func _ready() -> void:
	get_viewport().size_changed.connect(layout)


func show_line(p_speaker: String, p_text: String) -> void:
	speaker = p_speaker
	text = p_text
	left = clampf(HOLD_MIN + HOLD_PER_CHAR * p_text.length(), HOLD_MIN, HOLD_MAX)
	_speaker_label.text = speaker
	_speaker_label.add_theme_color_override("font_color", SPEAKER_COLORS.get(speaker, CyberStyle.CYAN))
	_text_label.text = text
	visible = true
	modulate.a = 1.0
	layout()


func font_size() -> int:
	return maxi(MIN_FONT, roundi(FONT_1080 * CyberStyle.ui_scale(get_viewport_rect().size)))


## The strip's rectangle on screen (for tests and for anyone laying out around it).
func strip() -> Rect2:
	return Rect2(position, size)


func layout() -> void:
	var screen := get_viewport_rect().size
	var px := font_size()
	var pad := px * 0.5
	var width := screen.x * WIDTH_FRACTION
	var speaker_width := CyberStyle.font().get_string_size(speaker + " ", HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	_speaker_label.add_theme_font_size_override("font_size", px)
	_text_label.add_theme_font_size_override("font_size", px)
	_speaker_label.position = Vector2(pad, pad * 0.6)
	_speaker_label.size = Vector2(speaker_width, px * 1.3)
	var text_width := width - speaker_width - pad * 2.0
	_text_label.position = Vector2(pad + speaker_width, pad * 0.6)
	_text_label.size = Vector2(text_width, 0.0)
	var lines := mini(2, maxi(1, ceili(CyberStyle.font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x / maxf(text_width, 1.0))))
	_text_label.size = Vector2(text_width, px * 1.3 * lines)
	size = Vector2(width, px * 1.3 * lines + pad * 1.2)
	position = Vector2((screen.x - width) / 2.0, screen.y * TOP_FRACTION)
	queue_redraw()


func advance(delta: float) -> void:
	if not visible:
		return
	left -= delta
	if left <= 0.0:
		visible = false
		return
	modulate.a = clampf(left / FADE_SECONDS, 0.0, 1.0)


func _process(delta: float) -> void:
	advance(delta)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(CyberStyle.HUD_BACKGROUND, 0.72))
	draw_rect(Rect2(Vector2.ZERO, Vector2(3.0, size.y)), Color(SPEAKER_COLORS.get(speaker, CyberStyle.CYAN), 0.9))
