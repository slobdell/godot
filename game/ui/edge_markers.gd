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
	var started := HudClock.begin()
	_process_timed(delta)
	HudClock.end(&"edge_markers.process", started)


func _process_timed(delta: float) -> void:
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
		result.append({"element": int(element["number"]), "label": String(element["label"]),
				"at": _clear_of_radar(_pin(at, middle, inner)),
				"angle": (at - middle).angle(), "health": float(element["health"]), "state": String(element["state"]),
				"alive": int(element["alive"])})
	return result


## Round 18 (picker): a chip pinned low on the right edge landed on the radar ("Bravo 2" over its corner in the parade
## frames): the bottom strip kept clear for the command card is 22 % of the screen, and the radar is taller than that.
## A chip (with its arrow) that would touch the radar goes up the edge until it sits just above it.
func _clear_of_radar(at: Vector2) -> Vector2:
	var radar := controls.get_node_or_null("Radar") as Control if controls != null else null
	if radar == null or not radar.visible:
		return at
	var s := CyberStyle.ui_scale(size)
	var reach := CHIP * s / 2.0 + Vector2.ONE * ARROW_PX * s
	var keep_out := Rect2(radar.global_position - global_position, radar.size).grow(4.0)
	if not Rect2(at - reach, reach * 2.0).intersects(keep_out):
		return at
	return Vector2(at.x, keep_out.position.y - reach.y)


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
	var started := HudClock.begin()
	_draw_timed()
	HudClock.end(&"edge_markers.draw", started)


func _draw_timed() -> void:
	if controls == null or controls.awareness == null:
		return
	var font := CyberStyle.font()
	var s := CyberStyle.ui_scale(size)
	var chips: Array = []
	for mark: Dictionary in markers():
		chips.append(_chip(mark, font, s))
	# Round 16 (hud H7): kind by kind (every fill, then every outline, arrow and label) is a few draw calls instead of
	# five per chip, and draws the same pixels as chip by chip when no two chips' footprints overlap - each chip's own
	# pieces do not overlap across kinds (the bar sits under the label, inside the outline). Overlapping chips (two
	# elements off the same edge) are drawn chip by chip, as before.
	var apart := true
	for i in chips.size():
		for j in range(i + 1, chips.size()):
			if (chips[i]["footprint"] as Rect2).intersects(chips[j]["footprint"]):
				apart = false
	if apart:
		for chip: Dictionary in chips:
			draw_rect(chip["box"], Color(CyberStyle.HUD_BACKGROUND, 0.88))
			draw_rect(chip["bar"], Color(CyberStyle.TEXT, 0.18))
			draw_rect(chip["strength"], chip["accent"])
		for chip: Dictionary in chips:
			draw_rect(chip["box"], Color(chip["accent"], 0.9), false, 1.5)
		for chip: Dictionary in chips:
			draw_colored_polygon(chip["arrow"], chip["accent"])
		for chip: Dictionary in chips:
			_chip_label(chip, font)
	else:
		for chip: Dictionary in chips:
			_draw_chip(chip, font)
	_draw_alerts(font, s)


## One chip's pieces, placed: {"box", "accent", "arrow", "label", "label_at", "label_width", "label_px", "bar",
## "strength", "footprint" (the box and its arrow)}.
func _chip(mark: Dictionary, font: Font, s: float) -> Dictionary:
	var accent: Color = GameTheme.ui[STATE_COLORS.get(mark["state"], "friendly")]
	var at: Vector2 = mark["at"]
	var box := Rect2(at - CHIP * s / 2.0, CHIP * s)
	box.position = box.position.clamp(Vector2.ZERO, size - box.size)
	# The arrow: a triangle on the box's edge pointing the way the element lies.
	var angle := float(mark["angle"])
	var tip := box.get_center() + Vector2(cos(angle), sin(angle)) * (CHIP.x * s / 2.0 + ARROW_PX * s * 0.7)
	var side := Vector2(cos(angle + PI / 2.0), sin(angle + PI / 2.0)) * ARROW_PX * s * 0.5
	var back := box.get_center() + Vector2(cos(angle), sin(angle)) * (CHIP.x * s / 2.0)
	var arrow := PackedVector2Array([tip, back + side, back - side])
	var text_size := roundi(13.0 * s)
	# A strength bar along the bottom of the chip.
	var bar := Rect2(box.position + Vector2(6.0 * s, box.size.y - 7.0 * s), Vector2(box.size.x - 12.0 * s, 3.0 * s))
	var footprint := box.grow(2.0)  # the outline's half-width and a pixel
	for point in arrow:
		footprint = footprint.expand(point)
	return {"box": box, "accent": accent, "arrow": arrow, "label": "%s %d" % [mark["label"], int(mark["alive"])],
			"label_at": box.position + Vector2(8.0 * s, text_size * 1.15), "label_width": box.size.x - 12.0 * s,
			"label_px": text_size, "bar": bar,
			"strength": Rect2(bar.position, Vector2(bar.size.x * clampf(float(mark["health"]), 0.0, 1.0), bar.size.y)),
			"footprint": footprint.grow(1.0)}


func _chip_label(chip: Dictionary, font: Font) -> void:
	draw_string(font, chip["label_at"], chip["label"], HORIZONTAL_ALIGNMENT_LEFT, chip["label_width"], chip["label_px"],
			CyberStyle.TEXT)


## One chip, piece by piece (the order before round 16; used when chips overlap).
func _draw_chip(chip: Dictionary, font: Font) -> void:
	draw_rect(chip["box"], Color(CyberStyle.HUD_BACKGROUND, 0.88))
	draw_rect(chip["box"], Color(chip["accent"], 0.9), false, 1.5)
	draw_colored_polygon(chip["arrow"], chip["accent"])
	_chip_label(chip, font)
	draw_rect(chip["bar"], Color(CyberStyle.TEXT, 0.18))
	draw_rect(chip["strength"], chip["accent"])


## Centred above the group chips: the newest things you have not looked at (one line by default, up to three with
## `alert_lines`), and how many are queued behind them. The HUD message column already narrates the match; this is
## the part you can act on. Older lines stack upward and dim.
func _draw_alerts(font: Font, s: float) -> void:
	var shown := prompts()
	if shown.is_empty():
		return
	var pending := controls.awareness.unseen_count()
	var text_size := roundi(17.0 * s)
	var y := EdgeMarkers.alert_y(size.y, text_size, s, _floor_top(s))
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
		var box := EdgeMarkers.strip_box(size.x, y, text_size, s, width)
		draw_rect(box, Color(CyberStyle.HUD_BACKGROUND, 0.9 * fade))
		draw_rect(box, Color(accent, 0.9 * fade), false, 1.5)
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color(accent, fade))
		y -= text_size * 1.8


## Round 22 (orders' request): at ten squads the group bar has two rows and the strip sat over the second (chips 7-9).
## The first line's baseline: ALERT_Y of the view, or higher so its box (which ends half a text line below the
## baseline) clears `floor_top` (local y; < 0 = nothing below) by ALERT_GAP. Pure.
## Round 23 (orders O2, C23.4): `floor_top` is the top of WHATEVER is below the strip (`_floor_top`): the bottom
## edge's chips, the group bar, the selection panel.
const ALERT_GAP := 6.0


static func alert_y(view_height: float, text_size: float, s: float, floor_top: float) -> float:
	var y := view_height * ALERT_Y
	if floor_top < 0.0:
		return y
	return minf(y, floor_top - text_size * 0.5 - ALERT_GAP * s)


## One alert line's box, as drawn: the text baseline at `y`, centred across a view `view_width` wide, 1.1 text lines
## above the baseline to half a line below it, 14 px of padding each side. Pure (the strip test reads it).
static func strip_box(view_width: float, y: float, text_size: float, s: float, text_width: float) -> Rect2:
	var at := Vector2((view_width - text_width) / 2.0, y)
	return Rect2(at - Vector2(14.0 * s, text_size * 1.1), Vector2(text_width + 28.0 * s, text_size * 1.6))


## Round 23 (orders O2, C23.4): the chips along the bottom edge stand at (1 - BOTTOM_FRACTION) of the view, and
## ALERT_Y put the strip's first line right on them (perf's frame at ten squads: India's chip under "Bravo under
## fire"); the strip only cleared them while the selection panel happened to be up (it lifts the group bar, and the
## bar lifted the strip). The top of the band those chips occupy: a chip's box (and its outline) centred on the
## bottom chip line. Where the strip's box must end, always: the band is the floor whether or not a chip is on it
## now, so the strip does not hop as chips come and go with the camera. Pure.
static func chip_band_top(view_height: float, s: float) -> float:
	return view_height * (1.0 - BOTTOM_FRACTION) - CHIP.y * s / 2.0 - 2.0


## A chip pinned to the bottom edge, as `_chip` lays it (its box; the arrow below it points off screen): for the
## strip test, at any `x`. Pure.
static func bottom_chip_box(view: Vector2, s: float, x: float) -> Rect2:
	var at := Vector2(x, view.y * (1.0 - BOTTOM_FRACTION))
	var box := Rect2(at - CHIP * s / 2.0, CHIP * s)
	box.position = box.position.clamp(Vector2.ZERO, view - box.size)
	return box


## The top of whatever is below the strip, in this control's coordinates: the bottom chips' band (always), the
## group bar's top and the selection panel's top (orders' siblings under the controls) when they are shown. -1 when
## the view has no height yet.
func _floor_top(s: float) -> float:
	if size.y <= 0.0:
		return -1.0
	var top := chip_band_top(size.y, s)
	for node_name in ["GroupBar", "SelectionPanel"]:
		var node := controls.get_node_or_null(node_name) as Control if controls != null else null
		if node == null or not node.is_visible_in_tree():
			continue
		top = minf(top, node.get_global_rect().position.y - get_global_rect().position.y)
	return top


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
