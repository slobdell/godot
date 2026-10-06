class_name CyberPictureChip
extends Button
## A kit element (round 20, garage R2; `_agents/ui_kit.md`): `CyberKit.chip` with a picture. One owned thing (a
## vehicle in a squad) as its picture over its name, in a fixed width so a row of five lines up; a long name takes two
## lines rather than widening the chip. Same chamfered box, tint and states as `CyberKit.chip`; the whole chip is one
## tap target (its picture and label ignore the mouse). The lead: *"We should incorporate the graphics of the vehicles
## we're adding to the squads"* (2026-10-06).

## The chip's width and the picture's height at 1080 (the picture keeps its aspect inside them).
const WIDTH := 100.0
const PICTURE_HEIGHT := 46.0

var picture := TextureRect.new()
var caption := Label.new()
var _box := VBoxContainer.new()
var _scale := 1.0


## A chip for `text` showing `texture` (null: the name alone, as `CyberKit.chip`), at `scale`, tinted `color`.
func _init(texture: Texture2D = null, p_text := "", scale := 1.0, color := CyberStyle.CYAN) -> void:
	_scale = scale
	focus_mode = Control.FOCUS_NONE
	CyberKit.style_button(self, scale, color, CyberKit.SMALL)
	add_theme_stylebox_override("normal", CyberKit.box(Color(color, 0.14), Color(color, 0.75), 1, CyberKit.CUT * 0.7 * scale,
			CyberKit.GAP_S * scale))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pad := CyberKit.GAP_S * scale * 0.6
	_box.offset_left = pad
	_box.offset_right = -pad
	_box.offset_top = pad
	_box.offset_bottom = -pad
	_box.add_theme_constant_override("separation", 0)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)
	picture.name = "Picture"
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(0, PICTURE_HEIGHT * scale)
	picture.visible = texture != null
	_box.add_child(picture)
	caption.name = "Caption"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text = p_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_override("font", CyberStyle.font())
	caption.add_theme_font_size_override("font_size", roundi(CyberKit.MICRO * scale))
	caption.add_theme_color_override("font_color", get_theme_color("font_color"))
	_box.add_child(caption)
	custom_minimum_size = Vector2(WIDTH * scale, CyberKit.TAP * scale)
	toggled.connect(func(_on: bool) -> void: _recolor())


func _ready() -> void:
	_box.minimum_size_changed.connect(_fit)
	_fit()
	_recolor()


## The caption: what the chip says (also the Button's tooltip, so a hover shows it whole).
func set_caption(value: String) -> void:
	caption.text = value
	tooltip_text = value


## As tall as its picture and its (one or two line) caption.
func _fit() -> void:
	var pad := CyberKit.GAP_S * _scale * 0.6
	var needed := _box.get_combined_minimum_size().y + pad * 2.0
	custom_minimum_size = Vector2(WIDTH * _scale, maxf(needed, CyberKit.TAP * _scale))


## The caption follows the Button's text colour for its state (pressed reads in the accent, like a chip's text).
func _recolor() -> void:
	caption.add_theme_color_override("font_color", get_theme_color("font_pressed_color" if button_pressed else "font_color"))
