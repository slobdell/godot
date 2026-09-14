class_name CyberUiTheme
extends RefCounted
## A Godot `Theme` in the HUD language, applied to the whole window by HudSkin so every Control
## (the HUD, the tactical map's buttons and labels, future menus) picks it up without its owner
## restyling anything: Share Tech Mono, chamfered translucent buttons with neon borders
## (StyleBoxFlat with corner_detail 1 = 45° cuts), cyan when toggled, and touch-friendly padding.

static var _theme: Theme


static func get_theme() -> Theme:
	if _theme == null:
		_theme = build()
	return _theme


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = CyberStyle.font()
	theme.default_font_size = 16
	var normal := _box(Color(CyberStyle.CARD, 0.82), Color(CyberStyle.CYAN, 0.45), 1)
	var hover := _box(Color(CyberStyle.CARD.lightened(0.08), 0.9), CyberStyle.CYAN, 1)
	var pressed := _box(Color(CyberStyle.CYAN, 0.22), CyberStyle.CYAN, 2)
	var disabled := _box(Color(CyberStyle.CARD, 0.5), Color(CyberStyle.TEXT, 0.2), 1)
	for type in ["Button", "OptionButton", "MenuButton"]:
		theme.set_stylebox("normal", type, normal)
		theme.set_stylebox("hover", type, hover)
		theme.set_stylebox("pressed", type, pressed)
		theme.set_stylebox("hover_pressed", type, pressed)
		theme.set_stylebox("disabled", type, disabled)
		theme.set_stylebox("focus", type, StyleBoxEmpty.new())
		theme.set_color("font_color", type, CyberStyle.TEXT)
		theme.set_color("font_hover_color", type, CyberStyle.WHITE)
		theme.set_color("font_pressed_color", type, CyberStyle.CYAN)
		theme.set_color("font_hover_pressed_color", type, CyberStyle.CYAN)
		theme.set_color("font_disabled_color", type, Color(CyberStyle.TEXT, 0.35))
		theme.set_color("font_outline_color", type, Color.BLACK)
		theme.set_constant("outline_size", type, 3)
	theme.set_stylebox("panel", "PanelContainer", _box(Color(CyberStyle.CARD, 0.8), Color(CyberStyle.CYAN, 0.5), 1))
	theme.set_stylebox("panel", "Panel", _box(Color(CyberStyle.CARD, 0.8), Color(CyberStyle.CYAN, 0.5), 1))
	theme.set_color("font_color", "Label", CyberStyle.TEXT)
	theme.set_color("font_outline_color", "Label", Color.BLACK)
	return theme


## A chamfered box: corner_detail 1 turns rounded corners into single 45° cuts.
static func _box(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(7)
	box.corner_detail = 1
	box.anti_aliasing = true
	# Touch-friendly padding (buttons grow toward the ~48 px tap target at 1080p).
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
