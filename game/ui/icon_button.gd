class_name IconButton
extends Button
## C3: a thumb-sized button that shows a pictogram (a drill or a formation, see CommandIcons) with its
## plain-language name, and optionally a short tagline under it (the formation picker's cards).
## Styling comes from the theme's Button style (art); this only draws the content.

enum Kind { DRILL, FORMATION }

var kind := Kind.DRILL
## A drill verb or a formation name.
var id := ""
var label := ""
var tagline := ""
## Small desktop shortcut shown in the corner ("Q"), or "".
var hotkey := ""
## How many vehicles a formation icon shows.
var count := 4


func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	clip_text = true


func _draw() -> void:
	var ui := GameTheme.ui
	var ink := Color.WHITE if not disabled else Color(1, 1, 1, 0.4)
	var accent: Color = ui["commander"] if button_pressed else ui["friendly"]
	var font := get_theme_font("font")
	var h := size.y
	var pad := minf(h, size.x) * 0.08
	var text_size := roundi(clampf(h * (0.2 if tagline != "" else 0.26), 10.0, 18.0))
	var tag_size := roundi(clampf(h * 0.14, 9.0, 13.0))
	var icon_rect: Rect2
	if tagline != "":
		# Card: icon on top, name and tagline below.
		icon_rect = Rect2(pad, pad, size.x - 2.0 * pad, h * 0.5)
		draw_string(font, Vector2(pad, h * 0.5 + pad + text_size), label, HORIZONTAL_ALIGNMENT_CENTER,
				size.x - 2.0 * pad, text_size, ink)
		draw_string(font, Vector2(pad, h * 0.5 + pad + text_size + tag_size * 1.3), tagline,
				HORIZONTAL_ALIGNMENT_CENTER, size.x - 2.0 * pad, tag_size, Color(ink, 0.7))
	elif size.x >= h * 1.9:
		# Wide button: icon left, name right.
		icon_rect = Rect2(pad, pad, h - 2.0 * pad, h - 2.0 * pad)
		draw_string(font, Vector2(h - pad * 0.5, h / 2.0 + text_size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT,
				size.x - h - pad * 0.5, text_size, ink)
	else:
		# Compact button: icon above a small name.
		icon_rect = Rect2(pad, pad * 0.5, size.x - 2.0 * pad, h * 0.62)
		draw_string(font, Vector2(0, h - pad), label, HORIZONTAL_ALIGNMENT_CENTER, size.x, tag_size, ink)
	match kind:
		Kind.DRILL:
			CommandIcons.draw_drill(self, id, icon_rect, accent)
		Kind.FORMATION:
			CommandIcons.draw_formation(self, id, icon_rect, accent, ui["commander"] if not button_pressed else Color.WHITE, count)
	if hotkey != "":
		draw_string(font, Vector2(pad * 0.7, pad * 0.7 + tag_size), hotkey, HORIZONTAL_ALIGNMENT_LEFT, -1, tag_size,
				Color(1, 1, 1, 0.45))
