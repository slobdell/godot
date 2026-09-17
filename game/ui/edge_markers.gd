class_name EdgeMarkers
extends Control
## Control X2: the rest of your force, on the edge of the screen.
##
## The camera frames one element at a time (X1), so every other element gets a chip pinned to the screen edge:
## an arrow pointing at it, its name, how much of it is left, and a colour for what it is doing. Clicking a chip
## selects that element and takes the camera to it. Under them runs the alert strip - the last few things that
## went wrong, newest first, with the unseen ones lit; `Q` jumps to the newest.
##
## Drawn above the tactical overlay, so it sits over the panel and the radar but under nothing.

## Chips sit this far in from the edge of the screen, and are this big…
const EDGE_PX := 34.0
const CHIP := Vector2(112.0, 30.0)
## …except along the bottom, where the command card and the group chips own this fraction of the screen.
const BOTTOM_FRACTION := 0.22
## An element whose middle is further than this outside the screen still only pins to the edge.
const ARROW_PX := 11.0
## The alert prompt gives up on an alert nobody jumped to after this long (seconds), and sits this far up the
## screen: just above the group chips, the one strip of screen the HUD leaves empty (the message column runs down
## the left, the command card owns the bottom, the announcer's banners the right).
const ALERT_SECONDS := 12.0
const ALERT_Y := 0.79
## What each element state says about itself.
const STATE_COLORS := {"under_fire": "enemy", "lost": "enemy", "contact": "commander", "moving": "friendly",
		"idle": "friendly"}

var controls: RtsControls
## Control X3 (the lead's dial): how many unseen alerts show at once, newest at the bottom (1–3, `--alert-lines`).
var alert_lines := 1

var _clock := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # RtsControls hit-tests the chips itself, before box select
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 60


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## The chips to draw, as data (checked by tests):
## [{"element": int, "label", "at": Vector2, "angle": float, "health": float, "state", "alive": int}].
## An element whose middle is on screen gets none: you can already see it.
func markers() -> Array:
	var result: Array = []
	if controls == null or controls.awareness == null or controls.camera == null:
		return result
	var screen := Rect2(Vector2.ZERO, size)
	var inner := screen.grow(-EDGE_PX)
	inner.size.y -= size.y * BOTTOM_FRACTION - EDGE_PX
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return result
	var middle := screen.get_center()
	for element: Dictionary in controls.awareness.elements():
		if int(element["alive"]) == 0 or _is_watched(element):
			continue  # gone, or the element the camera is already framing
		var world: Vector3 = element["position"]
		var behind := controls.camera.is_position_behind(world)
		var at := controls.camera.unproject_position(world)
		if not at.is_finite():
			continue
		if behind:
			at = middle + (middle - at)  # a point behind the camera projects mirrored: flip it back
		elif inner.has_point(at) and screen.has_point(at):
			continue  # comfortably on screen already: its selection rings and nameplate carry it
		result.append({"element": int(element["number"]), "label": String(element["label"]), "at": _pin(at, middle, inner),
				"angle": (at - middle).angle(), "health": float(element["health"]), "state": String(element["state"]),
				"alive": int(element["alive"])})
	return result


## Whether this element is the one the camera is framing.
func _is_watched(element: Dictionary) -> bool:
	var commanded := controls.commanded_units()
	for unit_name: String in element["units"]:
		if not commanded.has(unit_name):
			return false
	return not (element["units"] as Array).is_empty()


## Where the ray from the middle of the screen towards `at` leaves `inner`. The rect is not centred on the middle
## (the command card eats the bottom), so each edge is solved separately.
static func _pin(at: Vector2, middle: Vector2, inner: Rect2) -> Vector2:
	var away := at - middle
	if away.length() < 0.001:
		return inner.get_center()
	var scale := INF
	if away.x > 0.001:
		scale = minf(scale, (inner.end.x - middle.x) / away.x)
	elif away.x < -0.001:
		scale = minf(scale, (inner.position.x - middle.x) / away.x)
	if away.y > 0.001:
		scale = minf(scale, (inner.end.y - middle.y) / away.y)
	elif away.y < -0.001:
		scale = minf(scale, (inner.position.y - middle.y) / away.y)
	if scale == INF or scale < 0.0:
		return inner.get_center()
	return middle + away * scale


## The element under a screen point, or 0. RtsControls asks before it treats a click as a selection.
func marker_at(screen: Vector2) -> int:
	for mark: Dictionary in markers():
		if Rect2((mark["at"] as Vector2) - CHIP / 2.0, CHIP).has_point(screen):
			return int(mark["element"])
	return 0


func _draw() -> void:
	if controls == null or controls.awareness == null:
		return
	var font := CyberStyle.font()
	var s := CyberStyle.ui_scale(size)
	for mark: Dictionary in markers():
		_draw_chip(mark, font, s)
	_draw_alerts(font, s)


func _draw_chip(mark: Dictionary, font: Font, s: float) -> void:
	var accent: Color = GameTheme.ui[STATE_COLORS.get(mark["state"], "friendly")]
	var at: Vector2 = mark["at"]
	var box := Rect2(at - CHIP * s / 2.0, CHIP * s)
	box.position = box.position.clamp(Vector2.ZERO, size - box.size)
	draw_rect(box, Color(CyberStyle.HUD_BACKGROUND, 0.88))
	draw_rect(box, Color(accent, 0.9), false, 1.5)
	# The arrow: a triangle on the box's edge pointing the way the element lies.
	var angle := float(mark["angle"])
	var tip := box.get_center() + Vector2(cos(angle), sin(angle)) * (CHIP.x * s / 2.0 + ARROW_PX * s * 0.7)
	var side := Vector2(cos(angle + PI / 2.0), sin(angle + PI / 2.0)) * ARROW_PX * s * 0.5
	var back := box.get_center() + Vector2(cos(angle), sin(angle)) * (CHIP.x * s / 2.0)
	draw_colored_polygon(PackedVector2Array([tip, back + side, back - side]), accent)
	var text_size := roundi(13.0 * s)
	draw_string(font, box.position + Vector2(8.0 * s, text_size * 1.15), "%s %d" % [mark["label"], int(mark["alive"])],
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - 12.0 * s, text_size, CyberStyle.TEXT)
	# A strength bar along the bottom of the chip.
	var bar := Rect2(box.position + Vector2(6.0 * s, box.size.y - 7.0 * s), Vector2(box.size.x - 12.0 * s, 3.0 * s))
	draw_rect(bar, Color(CyberStyle.TEXT, 0.18))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(float(mark["health"]), 0.0, 1.0), bar.size.y)), accent)


## Centred above the group chips: the newest things you have not looked at (one line by default, up to three with
## `alert_lines`), and how many are queued behind them. The HUD message column already narrates the match; this is
## the part you can act on. Older lines stack upward and dim.
func _draw_alerts(font: Font, s: float) -> void:
	var shown := prompts()
	if shown.is_empty():
		return
	var pending := controls.awareness.unseen_count()
	var text_size := roundi(17.0 * s)
	var y := size.y * ALERT_Y
	for i in shown.size():
		var alert: Dictionary = shown[i]
		var text := String(alert["text"])
		if i == 0:
			var behind := pending - shown.size()
			text = "%s%s   [Q]" % [text, "  (+%d)" % behind if behind > 0 else ""]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var at := Vector2((size.x - width) / 2.0, y)
		var accent: Color = GameTheme.ui[STATE_COLORS.get(alert["kind"], "enemy")]
		var fade := 1.0 if i == 0 else 0.7
		var box := Rect2(at - Vector2(14.0 * s, text_size * 1.1), Vector2(width + 28.0 * s, text_size * 1.6))
		draw_rect(box, Color(CyberStyle.HUD_BACKGROUND, 0.9 * fade))
		draw_rect(box, Color(accent, 0.9 * fade), false, 1.5)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(accent, fade))
		y -= text_size * 1.8


## The newest unseen alerts still worth showing, newest first, at most `alert_lines` of them.
func prompts() -> Array:
	var result: Array = []
	var alerts: Array = controls.awareness.alerts
	for i in range(alerts.size() - 1, -1, -1):
		var alert: Dictionary = alerts[i]
		if not bool(alert["seen"]) and controls.awareness.age_of(alert) <= ALERT_SECONDS:
			result.append(alert)
			if result.size() >= clampi(alert_lines, 1, 3):
				break
	return result
