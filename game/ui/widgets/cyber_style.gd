class_name CyberStyle
extends RefCounted
## The HUD design language ported from mavlink-hud (_agents/streams/references/): palette, font,
## and the 1080p reference scale. Every widget in game/ui/widgets reads from here.

## mavlink-hud colors.xml + the banner/conductor specs.
const BACKGROUND := Color("#050510")
const HUD_BACKGROUND := Color("#000510")
const CARD := Color("#121225")
const CYAN := Color("#00F3FF")
const BORDER_CYAN := Color("#00FFFF")
const GLOW_CYAN := Color("#00E5FF")
const PURPLE := Color("#D900FF")
const PINK := Color("#FF0099")
const GREEN := Color("#39FF14")
const TEXT := Color("#E0E0E0")
const WHITE := Color("#FFFFFF")
const YELLOW := Color("#FFFF00")
const ERROR_FILL := Color("#D50000")
const ERROR_BORDER := Color("#FF1744")
const CONDUCTOR_OFF := Color("#004D40")
const CONDUCTOR_ON := Color("#008D9F")

## Banner themes (spec §5): fill (with its alpha), border (+glow), text.
const THEME_INFO := {"fill": Color(0x20 / 255.0, 0x20 / 255.0, 0x30 / 255.0, 220 / 255.0), "border": BORDER_CYAN, "text": TEXT}
const THEME_WARNING := {"fill": Color(1.0, 1.0, 0.0, 50 / 255.0), "border": YELLOW, "text": WHITE}
const THEME_ERROR := {"fill": Color(ERROR_FILL.r, ERROR_FILL.g, ERROR_FILL.b, 50 / 255.0), "border": ERROR_BORDER, "text": WHITE}

const FONT_PATH := "res://assets/fonts/ShareTechMono-Regular.ttf"
const FALLBACK_FONT_PATH := "res://assets/fonts/JetBrainsMono-Blocks.ttf"

static var _font: Font
static var _touch_boost := -1.0


## Share Tech Mono with a JetBrains Mono fallback for block/box glyphs (█ ▲ ─), loaded once.
static func font() -> Font:
	if _font == null:
		var main := load(FONT_PATH) as FontFile
		var fallback := load(FALLBACK_FONT_PATH) as FontFile
		if main == null:
			_font = ThemeDB.fallback_font
		else:
			var variation := FontVariation.new()
			variation.base_font = main
			if fallback != null:
				variation.fallbacks = [fallback]
			_font = variation
	return _font


## Geometry scale: screen height / 1080 (spec §2) × the touch boost. Stroke widths and glow radii
## do NOT scale.
static func ui_scale(viewport_size: Vector2) -> float:
	return maxf(viewport_size.y, 1.0) / 1080.0 * touch_boost()


## Phones show a 1080-px-tall screen ~6 cm tall, so the spec's 25 px text would be ~1.5 mm: HUD
## geometry and text grow 1.5× on touch devices (mobile first). `--ui-touch` previews it on desktop.
static func touch_boost() -> float:
	if _touch_boost < 0.0:
		var touch := OS.has_feature("mobile") or LaunchFlags.from_environment().has("ui-touch") \
				or (OS.has_feature("web") and DisplayServer.is_touchscreen_available())
		_touch_boost = 1.5 if touch else 1.0
	return _touch_boost


static func set_touch_boost(boost: float) -> void:
	_touch_boost = boost


## A Label styled for the HUD: monospace, sized at the 1080p reference.
static func label(text := "", size_1080 := 25.2, color := TEXT) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_override("font", font())
	result.add_theme_font_size_override("font_size", roundi(size_1080))
	result.add_theme_color_override("font_color", color)
	return result


## Interpolators with Android semantics (banner spec §6).
static func decelerate(t: float) -> float:
	return 1.0 - (1.0 - t) * (1.0 - t)


static func ease_in_out(t: float) -> float:
	return 0.5 - 0.5 * cos(PI * t)


static func bounce(t: float) -> float:
	var b := func(x: float) -> float: return 8.0 * x * x
	var tt := t * 1.1226
	if tt < 0.3535:
		return b.call(tt)
	if tt < 0.7408:
		return b.call(tt - 0.54719) + 0.7
	if tt < 0.9644:
		return b.call(tt - 0.8526) + 0.9
	return b.call(tt - 1.0435) + 0.95
