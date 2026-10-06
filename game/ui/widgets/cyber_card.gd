class_name CyberCard
extends Button
## A kit element (G2, `_agents/ui_kit.md`): a chamfered card the player taps. Its content is whatever Controls are put
## in `content` (a VBoxContainer that ignores the mouse, so the whole card is one tap target). Selected, it lights its
## four corner brackets the way CyberFrame does (the HUD's panel language); disabled, it dims.
## `accent` is the border and the brackets' colour (a faction's colour on a faction card).

@export var accent := CyberStyle.CYAN:
	set(v):
		accent = v
		_restyle()
@export var selected := false:
	set(v):
		selected = v
		_restyle()

var content := VBoxContainer.new()
var _scale := 1.0


func _init() -> void:
	clip_contents = false
	focus_mode = Control.FOCUS_NONE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(content)
	_restyle()


## Lay the card out at `scale` (screen height / 1080): its boxes, padding and the content's gap.
func set_scale_1080(scale: float) -> void:
	_scale = scale
	_restyle()


func _restyle() -> void:
	var cut := CyberKit.CUT * 1.4 * _scale
	var pad := CyberKit.GAP_M * _scale
	var border_alpha := 1.0 if selected else 0.5
	var fill := Color(accent, 0.16) if selected else Color(CyberStyle.CARD, 0.9)
	add_theme_stylebox_override("normal", CyberKit.box(fill, Color(accent, border_alpha), 2 if selected else 1, cut, pad))
	add_theme_stylebox_override("hover", CyberKit.box(Color(accent, 0.2) if selected else Color(CyberStyle.CARD.lightened(0.1),
			0.94), accent, 2 if selected else 1, cut, pad))
	add_theme_stylebox_override("pressed", CyberKit.box(Color(accent, 0.26), accent, 2, cut, pad))
	add_theme_stylebox_override("hover_pressed", CyberKit.box(Color(accent, 0.26), accent, 2, cut, pad))
	add_theme_stylebox_override("disabled", CyberKit.box(Color(CyberStyle.CARD, 0.5), Color(CyberStyle.TEXT, 0.18), 1, cut,
			pad))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	content.offset_left = pad
	content.offset_right = -pad
	content.offset_top = pad * 0.6
	content.offset_bottom = -pad * 0.6
	content.add_theme_constant_override("separation", roundi(CyberKit.GAP_S * 0.5 * _scale))
	custom_minimum_size.y = maxf(custom_minimum_size.y, CyberKit.TAP * _scale)
	modulate.a = 0.55 if disabled else 1.0
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	if not selected:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var cut := CyberFrame.clamp_chamfer(CyberKit.CUT * 1.4 * _scale, rect.size)
	var arm := CyberFrame.clamp_arm(18.0 * _scale, cut, rect.size)
	var segments := PackedVector2Array()
	for path in CyberFrame.bracket_paths(rect, cut, arm):
		for i in path.size() - 1:
			segments.append_array([path[i], path[i + 1]])
	draw_multiline(segments, Color(accent, 0.25), 8.0, true)
	draw_multiline(segments, accent, 3.0, true)
