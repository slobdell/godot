extends Control
## HUD widget gallery (`make hud-gallery`): CyberFrames in each theme, both message banners driven
## by a scripted message stream, and breathing conductors wiring the panels together, on the HUD
## background. Flags: --screenshot=<abs png> [--screenshot-delay=S] [--ui-touch] (phone sizing).

const SCRIPT_LOOP_SECONDS := 14.0
## (time s, text, severity 0 info / 1 warning / 2 error)
const MESSAGES := [
	[0.3, "Squad Alpha: bound to grid 4-7, wedge", 0],
	[0.9, "Enemy armor spotted bearing 045", 1],
	[1.6, "Squad Bravo: hold, line formation", 0],
	[2.4, "Commander ALPHA-1 down: ALPHA-2 takes command", 2],
	[3.0, "Shields recharging (Squad Alpha)", 0],
	[9.0, "Victory in sight: 2 enemy tanks remain", 0],
]

var messages := CyberMessages.new()
var conductors := Conductors.new()
var _time := 0.0
var _next := 0
var _panels: Array[CyberFrame] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = CyberStyle.HUD_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	add_child(conductors)
	conductors.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for spec in [["SQUADS", CyberStyle.THEME_INFO], ["RADAR", CyberStyle.THEME_INFO], ["WARNING", CyberStyle.THEME_WARNING], ["ERROR", CyberStyle.THEME_ERROR]]:
		var frame := CyberFrame.new()
		frame.apply_theme(spec[1])
		add_child(frame)
		var title := CyberStyle.label(spec[0], 22.0, spec[1]["text"])
		title.name = "Title"
		frame.add_child(title)
		_panels.append(frame)
	add_child(messages)
	get_viewport().size_changed.connect(_layout)
	_layout()
	var flags := LaunchFlags.from_environment()
	if flags.has("screenshot"):
		_capture(flags.text("screenshot"), float(flags.text("screenshot-delay", "4")))


func _process(delta: float) -> void:
	_time += delta
	var t := fmod(_time, SCRIPT_LOOP_SECONDS)
	if t < 0.05 and _next >= MESSAGES.size():
		_next = 0
	while _next < MESSAGES.size() and t >= float(MESSAGES[_next][0]):
		messages.post(MESSAGES[_next][1], MESSAGES[_next][2])
		_next += 1


func _layout() -> void:
	var screen := get_viewport_rect().size
	var s := CyberStyle.ui_scale(screen)
	var margin := 24.0 * s
	var squads := Rect2(Vector2(margin, screen.y * 0.2), Vector2(300 * s, 260 * s))
	var radar := Rect2(Vector2(screen.x - margin - 300 * s, screen.y * 0.2), Vector2(300 * s, 300 * s))
	var warn := Rect2(Vector2(screen.x * 0.3, screen.y * 0.36), Vector2(screen.x * 0.18, 90 * s))
	var error := Rect2(Vector2(screen.x * 0.52, screen.y * 0.36), Vector2(screen.x * 0.18, 90 * s))
	for i in _panels.size():
		var rect: Rect2 = [squads, radar, warn, error][i]
		_panels[i].position = rect.position
		_panels[i].size = rect.size
		var title := _panels[i].get_node("Title") as Label
		title.position = Vector2(20 * s, 12 * s)
		title.add_theme_font_size_override("font_size", roundi(22 * s))
	conductors.clear()
	# Squads panel → down into the status banner's top edge (a 3-line bus with a 45° elbow).
	var banner_top := screen.y - 16.0 * s - maxf(screen.y * 0.09, 25.2 * s * 1.25 * 2.2)
	conductors.add_bus(Vector2(squads.end.x, squads.end.y - 40 * s), Vector2.RIGHT,
			Vector2(screen.x * 0.2 + 40 * s + 160 * s, banner_top), Vector2.DOWN, 3)
	# Radar → squads: 4 straight runs across the top.
	for i in 4:
		var y := radar.position.y + 40 * s + i * 24.0 * s
		conductors.add(PackedVector2Array([Vector2(radar.position.x, y), Vector2(squads.end.x + 60 * s, y)]),
				Conductors.FREQUENCIES[(i + 3) % 13], Conductors.PHASES[(i + 3) % 13])
	# Radar → the error panel: two straight runs.
	conductors.add_bus(Vector2(radar.position.x, error.get_center().y), Vector2.LEFT,
			Vector2(error.end.x, error.get_center().y), Vector2.LEFT, 2)


func _capture(path: String, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: " if err == OK else "screenshot failed: ", path)
	get_tree().quit(err)
