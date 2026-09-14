class_name HudSkin
extends Control
## Look & feel's layer of the HUD (hud.tscn): applies the cyber UI theme to the window (so gameplay's
## tactical map is restyled without code changes), frames the status/score block top-left in a
## CyberFrame sized to leave the top banner lane (20–80% of the width) clear, frames the center
## banner (VICTORY / DEFEAT / Destroyed) while it shows, and keeps the message banners clear of the
## tactical map's command bar. hud.gd keeps owning the text; this only styles and lays out.

## Width of the top-left block as a fraction of the screen: stops short of the warning banner (20%).
const BLOCK_FRACTION := 0.19

var status_frame := CyberFrame.new()
var banner_frame := CyberFrame.new()
## Bottom-right: tap to cycle the FX quality tier (saved per device). Hidden where nothing renders.
var fx_button := Button.new()

var _hud: CanvasLayer
var _status: Label
var _scoreboard: Label
var _banner: Label
var _messages: CyberMessages
var _last_screen := Vector2.ZERO
var _last_banner_text := ""
var _previous_theme: Theme
var _previous_fallback_font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_previous_theme = get_window().theme
	_previous_fallback_font = ThemeDB.fallback_font
	get_window().theme = CyberUiTheme.get_theme()
	# Custom-drawn text (the tactical map's labels on units) uses the fallback font.
	ThemeDB.fallback_font = CyberStyle.font()
	_hud = get_parent() as CanvasLayer
	_status = _hud.get_node_or_null("Status") as Label
	_scoreboard = _hud.get_node_or_null("Scoreboard") as Label
	_banner = _hud.get_node_or_null("Banner") as Label
	_messages = _hud.get_node_or_null("CyberMessages") as CyberMessages
	for frame in [status_frame, banner_frame]:
		frame.chamfer_1080 = 16.0
		frame.arm_1080 = 22.0
		frame.stroke_px = 2.0
		frame.glow_px = 6.0
		add_child(frame)
	banner_frame.apply_theme({"fill": Color(CyberStyle.CARD, 0.75), "border": CyberStyle.PINK})
	banner_frame.visible = false
	fx_button.name = "FxButton"
	fx_button.focus_mode = Control.FOCUS_NONE
	fx_button.theme = CyberUiTheme.get_theme()
	fx_button.pressed.connect(cycle_fx_quality)
	fx_button.visible = DisplayServer.get_name() != "headless"
	add_child(fx_button)
	_refresh_fx_button()
	for label in [_status, _scoreboard, _banner]:
		if label != null:
			label.add_theme_font_override("font", CyberStyle.font())
			label.add_theme_constant_override("outline_size", 4)
	if LaunchFlags.from_environment().has("hud-demo"):
		_run_demo()


## `--hud-demo`: post sample messages and a center banner so the styling can be screenshotted in
## the real game (visual only; nothing reaches the simulation).
func _run_demo() -> void:
	var script := [[0.5, "Squad ALPHA: bound to grid 4-7 in wedge", 0], [1.2, "Enemy armor spotted bearing 045", 1],
			[2.0, "Squad BRAVO: hold in line", 0], [2.6, "Commander ALPHA-1 down: ALPHA-2 takes command", 2]]
	for entry in script:
		await get_tree().create_timer(entry[0] - (0.0 if entry == script[0] else 0.0), true, false, true).timeout
		if _hud.has_method("post_message"):
			_hud.call("post_message", entry[1], entry[2])
	await get_tree().create_timer(0.5, true, false, true).timeout
	if _hud.has_method("show_banner"):
		_hud.call("show_banner", "VICTORY")


## Cycle LOW → MEDIUM → HIGH → LOW and remember it on this device.
func cycle_fx_quality() -> void:
	FxQuality.apply((FxQuality.tier() + 1) % 3, "player", true)
	var fx := FxWorld.existing()
	if fx != null:
		fx.sfx.play_ui("ui_blip")
	_refresh_fx_button()


func _refresh_fx_button() -> void:
	fx_button.text = "FX %s" % FxQuality.tier_name().to_upper()


## Window-wide styling is undone when the HUD goes away (tests build many HUDs in one process).
func _exit_tree() -> void:
	if get_window() != null and get_window().theme == CyberUiTheme.get_theme():
		get_window().theme = _previous_theme
	if _previous_fallback_font != null:
		ThemeDB.fallback_font = _previous_fallback_font


func _process(_delta: float) -> void:
	var screen := get_viewport_rect().size
	if fx_button.visible and not fx_button.text.ends_with(FxQuality.tier_name().to_upper()):
		_refresh_fx_button()  # the tier changed elsewhere (auto step-down, a flag)
	if screen != _last_screen:
		_last_screen = screen
		_layout(screen)
	_fit_status_frame(screen)
	_fit_banner_frame(screen)
	if _messages != null:
		_place_messages(screen)


## Banners stay out of the way of play and of the tactical map's own panels. With the tactical map
## up (any camera) they live in side columns at mid height: info on the left under the status block,
## warnings on the right under the orders log and above the radar, clear of the top button row and the
## bottom command bar (gameplay's layout, 2026-09-14). On a top-down view those columns are the dark
## margins beside the square arena. Without the map (offline driving) the spec's top/bottom strips
## return.
func _place_messages(screen: Vector2) -> void:
	var tactical := _hud.get_node_or_null("TacticalMap")
	var map_up: bool = tactical != null and tactical.visible
	# Theme inheritance stops at the HUD's CanvasLayer, so style the map's Control directly.
	if tactical is Control and (tactical as Control).theme == null:
		(tactical as Control).theme = CyberUiTheme.get_theme()
	var s := CyberStyle.ui_scale(screen)
	var margin := 12.0 * s
	var column_width := clampf((screen.x - screen.y) / 2.0 - margin * 2.0, 220.0 * s, screen.x * 0.26)
	if map_up and column_width < screen.x * 0.4:
		var info_top := maxf(screen.y * 0.22, fx_button.position.y + fx_button.size.y + margin)
		_messages.set_columns(Rect2(margin, info_top, column_width, screen.y * 0.4),
				Rect2(screen.x - margin - column_width, screen.y * 0.25, column_width, screen.y * 0.35))
	else:
		_messages.set_columns(Rect2(), Rect2())
		_messages.status.bottom_inset = 0.0


func _layout(screen: Vector2) -> void:
	var s := CyberStyle.ui_scale(screen)
	var pad := 14.0 * s
	# A ≥ 48 px (at 1080p) tap target top-left, under the status block (the tactical map uses the top
	# center, top right, and both bottom corners).
	fx_button.add_theme_font_size_override("font_size", maxi(12, roundi(20.0 * s)))
	fx_button.custom_minimum_size = Vector2(130.0 * s, 52.0 * s)
	fx_button.size = fx_button.custom_minimum_size
	var width := screen.x * BLOCK_FRACTION - pad * 2.0
	if _status != null:
		_status.add_theme_font_size_override("font_size", maxi(12, roundi(20.0 * s)))
		_status.add_theme_color_override("font_color", Color(CyberStyle.TEXT, 0.85))
		_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_status.position = Vector2(pad * 1.6, pad)
		_status.size = Vector2(width, 0)
	if _scoreboard != null:
		_scoreboard.add_theme_font_size_override("font_size", maxi(14, roundi(26.0 * s)))
		_scoreboard.add_theme_color_override("font_color", CyberStyle.CYAN)
		_scoreboard.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_scoreboard.size = Vector2(width, 0)
	if _banner != null:
		_banner.add_theme_font_size_override("font_size", maxi(24, roundi(52.0 * s)))
		_banner.add_theme_color_override("font_color", CyberStyle.WHITE)
		_banner.add_theme_color_override("font_outline_color", Color(CyberStyle.PINK, 0.6))


func _fit_status_frame(screen: Vector2) -> void:
	var s0 := CyberStyle.ui_scale(screen)
	if _status == null or _scoreboard == null or (_status.text == "" and _scoreboard.text == ""):
		status_frame.visible = false
		fx_button.position = Vector2(10.0, 10.0) * maxf(s0, 1.0)
		return
	status_frame.visible = true
	fx_button.position = Vector2(status_frame.position.x + 6.0 * s0, status_frame.position.y + status_frame.size.y + 8.0 * s0)
	var s := CyberStyle.ui_scale(screen)
	var pad := 14.0 * s
	# Labels outside containers grow to fit their text when it changes; pin the width every frame
	# so autowrap keeps the block inside its column.
	var width := screen.x * BLOCK_FRACTION - pad * 2.0
	_status.size = Vector2(width, 0.0)
	_scoreboard.position = Vector2(_status.position.x, _status.position.y + _status.get_combined_minimum_size().y + 2.0 * s)
	_scoreboard.size = Vector2(width, 0.0)
	var bottom := _scoreboard.position.y + _scoreboard.get_combined_minimum_size().y
	var rect := Rect2(Vector2(pad * 0.5, pad * 0.35), Vector2(screen.x * BLOCK_FRACTION, bottom + pad * 0.6 - pad * 0.35))
	if status_frame.position != rect.position or status_frame.size != rect.size:
		status_frame.position = rect.position
		status_frame.size = rect.size


func _fit_banner_frame(screen: Vector2) -> void:
	if _banner == null:
		return
	banner_frame.visible = _banner.visible
	if not _banner.visible:
		_last_banner_text = ""
		return
	if _banner.text == _last_banner_text:
		return
	_last_banner_text = _banner.text
	var s := CyberStyle.ui_scale(screen)
	var text_size := _banner.get_theme_font("font").get_string_size(_banner.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			_banner.get_theme_font_size("font_size"))
	var box := Vector2(text_size.x + 120.0 * s, text_size.y + 44.0 * s)
	banner_frame.size = box
	banner_frame.position = screen / 2.0 - box / 2.0
	_banner.size = box
	_banner.position = banner_frame.position
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
