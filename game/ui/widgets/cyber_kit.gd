class_name CyberKit
extends RefCounted
## The UI kit (round 19, G2; `_agents/ui_kit.md`, `make ui-kit-shots`): the HUD language of CyberFrame / CyberUiTheme /
## CyberStyle written down as named sizes and a few elements, so a SCREEN (the garage, the results, the scoreboard,
## whatever comes next) is built from the same chamfer, palette, type scale and spacing as the HUD and the title.
##
## Additive by contract (C19.5): nothing here changes what CyberFrame, CyberUiTheme or CyberStyle draw today, so the
## HUD and the title are unchanged frame for frame. Every size is at the 1080p reference; multiply by `CyberKit.s(c)`
## (screen height / 1080, the HUD's own scale) when laying out.
##
## Elements (each has a gallery frame in `make ui-kit-shots`):
##   box()      the chamfered StyleBox every panel, card, chip and tag is drawn with (45° cuts, neon border)
##   button()   a Button in the kit's states (normal / hover / pressed / toggled / disabled), PRIMARY or plain
##   tag()      a price tag: "40 CR" in a small chamfered box
##   chip()     a small chamfered Button for a thing the player owns (a vehicle in a squad)
##   heading()  a numbered section heading: "1  FACTION"
##   CyberCard  a chamfered card that lights its brackets when selected (cyber_card.gd)
##   CyberMeter a filled chamfered meter with a tick every step (cyber_meter.gd): the credits left
##   CyberCrest a chamfered badge holding a faction's initials in its colour (cyber_crest.gd)

## The type scale at 1080p (Share Tech Mono). The HUD's banners use 25.2; screens use these.
const TITLE := 44.0
const HEADING := 28.0
const BODY := 22.0
const SMALL := 18.0
const MICRO := 15.0
## Spacing at 1080p: the gap inside an element, between elements, between groups.
const GAP_S := 8.0
const GAP_M := 16.0
const GAP_L := 24.0
## The corner cut of the kit's boxes at 1080p (CyberFrame's panels cut 20; boxes are smaller things).
const CUT := 10.0
## The smallest tap target, at 1080p, the size `test_army_screen.gd` pins (a finger, not a cursor).
const TAP := 48.0
## Faction colours (one per faction, readable on the dark panels; the team colours stay cyan / magenta).
const FACTION_COLORS := {"condemned": Color("#FFB000"), "gangs": Color("#FF5A1F"), "law": Color("#4D8DFF"),
		"syndicate": Color("#E8E0FF")}
## Each faction's crest letters.
const FACTION_MARKS := {"condemned": "CN", "gangs": "RG", "law": "LW", "syndicate": "SY"}

## The panel fill a screen uses (CyberStyle.CARD, opaque enough to read text over the arena).
static var PANEL_FILL := Color(CyberStyle.CARD, 0.88)


## Screen height / 1080: the HUD's scale without the touch boost (a screen that wants the boost multiplies it in).
static func s(control: Control) -> float:
	return maxf(control.get_viewport_rect().size.y, 1.0) / 1080.0 if control.is_inside_tree() else 1.0


static func faction_color(faction: String) -> Color:
	return FACTION_COLORS.get(faction, CyberStyle.CYAN)


## A chamfered box: `cut` px 45° corners (corner_detail 1 turns a radius into one straight cut), a `width` px border,
## content margins of `pad` px. The kit's one StyleBox; everything chamfered on a screen is one of these.
static func box(fill: Color, border: Color, width := 1, cut := CUT, pad := GAP_M) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(roundi(cut))
	result.corner_detail = 1
	result.anti_aliasing = true
	result.content_margin_left = pad
	result.content_margin_right = pad
	result.content_margin_top = pad * 0.5
	result.content_margin_bottom = pad * 0.5
	return result


## A panel's box at `scale` (a group's background: the HUD's fill, a dim cyan border).
static func panel_box(scale := 1.0, border := Color(CyberStyle.CYAN, 0.45)) -> StyleBoxFlat:
	return box(PANEL_FILL, border, 1, CUT * 1.6 * scale, GAP_M * scale)


## Apply the kit's button states to `button`: `accent` is the border and the toggled fill (cyan by default; PRIMARY
## actions use CyberStyle.GREEN, destructive ones CyberStyle.ERROR_BORDER). Sizes at `scale`.
static func style_button(button: BaseButton, scale := 1.0, accent := CyberStyle.CYAN, size_1080 := BODY) -> void:
	var cut := CUT * scale
	var pad := GAP_M * scale
	var normal := box(Color(CyberStyle.CARD, 0.88), Color(accent, 0.55), 1, cut, pad)
	var hover := box(Color(CyberStyle.CARD.lightened(0.1), 0.94), accent, 1, cut, pad)
	var pressed := box(Color(accent, 0.24), accent, 2, cut, pad)
	var disabled := box(Color(CyberStyle.CARD, 0.5), Color(CyberStyle.TEXT, 0.18), 1, cut, pad)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_font_override("font", CyberStyle.font())
	button.add_theme_font_size_override("font_size", roundi(size_1080 * scale))
	button.add_theme_color_override("font_color", CyberStyle.TEXT)
	button.add_theme_color_override("font_hover_color", CyberStyle.WHITE)
	button.add_theme_color_override("font_pressed_color", accent)
	button.add_theme_color_override("font_hover_pressed_color", accent)
	button.add_theme_color_override("font_disabled_color", Color(CyberStyle.TEXT, 0.35))
	button.add_theme_color_override("font_outline_color", Color.BLACK)
	button.add_theme_constant_override("outline_size", maxi(1, roundi(3 * scale)))
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, TAP * scale)


## A kit Button: `text`, the accent, at `scale`; at least one tap target tall.
static func button(text: String, scale := 1.0, accent := CyberStyle.CYAN, size_1080 := BODY) -> Button:
	var result := Button.new()
	result.text = text
	style_button(result, scale, accent, size_1080)
	return result


## A price tag: "40 CR" on a small chamfered box in `color`.
static func tag(text: String, scale := 1.0, color := CyberStyle.YELLOW, size_1080 := SMALL) -> Label:
	var result := CyberStyle.label(text, size_1080 * scale, color)
	result.add_theme_stylebox_override("normal", box(Color(color, 0.12), Color(color, 0.7), 1, CUT * 0.6 * scale,
			GAP_S * scale))
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result


## A chip: a small chamfered Button for one owned thing, in `color` (a vehicle in a squad). One tap target tall.
static func chip(text: String, scale := 1.0, color := CyberStyle.CYAN) -> Button:
	var result := Button.new()
	result.text = text
	style_button(result, scale, color, SMALL)
	var normal := box(Color(color, 0.14), Color(color, 0.75), 1, CUT * 0.7 * scale, GAP_S * scale)
	result.add_theme_stylebox_override("normal", normal)
	return result


## A numbered section heading, "1  FACTION": the number in the accent, the words in TEXT.
static func heading(number: int, text: String, scale := 1.0, accent := CyberStyle.CYAN) -> RichTextLabel:
	var result := RichTextLabel.new()
	result.bbcode_enabled = true
	result.fit_content = true
	result.scroll_active = false
	result.autowrap_mode = TextServer.AUTOWRAP_OFF
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("normal_font", CyberStyle.font())
	result.add_theme_font_size_override("normal_font_size", roundi(HEADING * scale))
	result.add_theme_color_override("default_color", CyberStyle.TEXT)
	result.text = "[color=#%s]%d[/color]  %s" % [accent.to_html(false), number, text]
	return result
