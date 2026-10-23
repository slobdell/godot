class_name HudLayout
extends RefCounted
## Round 38 (feedback F5, his note 2026-10-22 evening, game_design.md): "the most important part of the view is the top of the
## screen since that corresponds to units in the distance ... move the scoreboard to the lower left corner of the screen and
## refit the bottom UX elements as necessary". Where the bottom of the HUD goes, in one place (pure; every element asks):
##
##   landscape   [ hints over the score bug | command bar | radar ]  along the bottom; the group chips over the command bar
##   portrait    the command bar across the width over [ hints over the score bug | radar ]
##
## The top third holds nothing during play but world markers: the status block and the FX / QUALITY / LOOK buttons show only
## while paused (HudSkin), the message columns start below it, the announcer's captions are gone (Hud), the camera readout is a
## debug flag (CameraReadout), and the pause line sits over the bottom HUD (`pause_line_y`).
##
## The bug keeps its own size where it fits and shrinks only as much as the command bar needs (never below MIN_BUG_SCALE of it).

const MARGIN := 12.0
const GAP := 12.0
## The smallest the score bug draws, as a share of its full size: below this its zone letters stop reading.
const MIN_BUG_SCALE := 0.55
## Where the message columns may start: below the top third.
const TOP_CLEAR := 1.0 / 3.0


static func portrait(screen: Vector2) -> bool:
	return screen.x < screen.y


## The radar, bottom right (Radar's own size rule).
static func radar_rect(screen: Vector2) -> Rect2:
	var side := clampf(screen.y * Radar.HEIGHT_FRACTION, Radar.MIN_SIZE, Radar.MAX_SIZE)
	if portrait(screen):
		side = minf(side, screen.x * 0.36)
	return Rect2(Vector2(screen.x - side - Radar.MARGIN, screen.y - side - Radar.MARGIN), Vector2(side, side))


## The command bar's scale: from the height in landscape (as it always was), from the width in portrait.
static func panel_scale(screen: Vector2) -> float:
	return maxf((screen.x if portrait(screen) else screen.y) / 1080.0, 0.6)


## The bug's scale: the HUD's, from the SHORTER side (a portrait phone's height would make it wider than the screen).
static func bug_ui_scale(screen: Vector2) -> float:
	return minf(screen.x, screen.y) / 1080.0 * CyberStyle.touch_boost()


## The score bug at full size (its panel; the kills line and lower third hang below it, ScoreBug.FOOTPRINT_1080).
static func bug_full(screen: Vector2) -> Vector2:
	return ScoreBug.SIZE_1080 * bug_ui_scale(screen)


## The command bar's rect (SelectionPanel's size rule: as wide as fits, SelectionPanel.HEIGHT tall).
static func panel_rect(screen: Vector2) -> Rect2:
	var s := panel_scale(screen)
	var height := SelectionPanel.HEIGHT * s
	var radar := radar_rect(screen)
	if portrait(screen):
		var bottom := radar.position.y - GAP
		return Rect2(Vector2(MARGIN, bottom - height), Vector2(screen.x - MARGIN * 2.0, height))
	var natural := minf(SelectionPanel.MAX_WIDTH * s, screen.x - (radar.size.x + Radar.MARGIN * 2.0) * 2.0)
	var right := radar.position.x - GAP
	var bug_w := bug_scale(screen) * bug_full(screen).x
	var left := MARGIN + bug_w + GAP
	var width := maxf(minf(natural, right - left), 200.0)
	var centred := (screen.x - width) / 2.0
	var x := clampf(centred, left, maxf(left, right - width))
	return Rect2(Vector2(x, screen.y - height - SelectionPanel.PAD * s), Vector2(width, height))


## How much the bug shrinks to share the bottom row (1 = full size).
static func bug_scale(screen: Vector2) -> float:
	var full := bug_full(screen)
	if full.x <= 0.0:
		return 1.0
	var radar := radar_rect(screen)
	if portrait(screen):
		return clampf((radar.position.x - GAP - MARGIN) / full.x, MIN_BUG_SCALE, 1.0)
	var s := panel_scale(screen)
	var natural := minf(SelectionPanel.MAX_WIDTH * s, screen.x - (radar.size.x + Radar.MARGIN * 2.0) * 2.0)
	var room := radar.position.x - GAP - natural - GAP - MARGIN
	return clampf(room / full.x, MIN_BUG_SCALE, 1.0)


## The score bug's control rect, lower left: its footprint (panel, kills line, lower third) ends MARGIN above the bottom.
static func bug_rect(screen: Vector2) -> Rect2:
	var k := bug_scale(screen)
	var size := bug_full(screen) * k
	var footprint := ScoreBug.FOOTPRINT_1080 * bug_ui_scale(screen) * k
	return Rect2(Vector2(MARGIN, round(screen.y - MARGIN - footprint)), size.round())


## The top of the lower-left stack (the bug); the control hints sit on it.
static func bug_top(screen: Vector2) -> float:
	return bug_rect(screen).position.y


## The message columns: info on the left over the hints and the bug, warnings on the right over the radar, both below the
## top third. `width` is HudSkin's column width.
static func message_columns(screen: Vector2, width: float, hints_room: float) -> Array[Rect2]:
	var top := screen.y * TOP_CLEAR + MARGIN
	if portrait(screen):
		# No room for side columns: info over warnings, the width of the screen, between the top third and the command bar.
		var room := maxf(panel_rect(screen).position.y - GAP - top, 0.0)
		var half := (room - GAP) / 2.0
		return [Rect2(MARGIN, top, screen.x - MARGIN * 2.0, half),
				Rect2(MARGIN, top + half + GAP, screen.x - MARGIN * 2.0, half)]
	var left_bottom := bug_top(screen) - GAP - hints_room
	var right_bottom := radar_rect(screen).position.y - GAP
	if portrait(screen):
		right_bottom = minf(right_bottom, panel_rect(screen).position.y - GAP)
		left_bottom = minf(left_bottom, panel_rect(screen).position.y - GAP)
	return [Rect2(MARGIN, top, width, maxf(left_bottom - top, 0.0)),
			Rect2(screen.x - MARGIN - width, top, width, maxf(right_bottom - top, 0.0))]


## The pause line's baseline (the planning pause, Space): over the bottom HUD and the alert strip above it, never in the top
## third. `floor_top` is the top of whatever sits below (the group bar or the command bar), `alert_lines` the strip's lines.
static func pause_line_y(screen: Vector2, floor_top: float, alert_lines: int, text_size: float) -> float:
	var y := floor_top - text_size * 1.6 * float(maxi(alert_lines, 1)) - text_size * 1.2
	return maxf(y, screen.y * TOP_CLEAR + text_size * 1.6)


## The same for a control laid out on the HUD (RtsControls): the floor from its GroupBar / SelectionPanel children, the
## strip's lines from its EdgeMarkers.
static func pause_line_y_for(controls: Control, text_size: float) -> float:
	var screen := controls.size
	var floor_top := screen.y
	for node_name in ["GroupBar", "SelectionPanel"]:
		var node := controls.get_node_or_null(node_name) as Control
		if node != null and node.is_visible_in_tree() and node.size.y > 0.0:
			floor_top = minf(floor_top, node.position.y)
			var tip: Variant = node.get("tooltip_rect")  # the command bar's tooltip (the planning intro) rises above it
			if tip is Rect2 and (tip as Rect2).has_area():
				floor_top = minf(floor_top, node.position.y + (tip as Rect2).position.y)
	var edge := controls.get_node_or_null("EdgeMarkers")
	var lines := int(edge.get("alert_lines")) if edge != null and edge.get("alert_lines") != null else 2
	return pause_line_y(screen, floor_top, lines, text_size)


## The control hints' widest (ControlHints.panel_rect's rule), for what may sit beside them.
static func hints_width(screen: Vector2) -> float:
	var px := maxf(float(ControlHints.MIN_FONT), round(ControlHints.FONT_1080 * bug_ui_scale(screen)))
	return minf(minf(screen.x * 0.23, px * 22.0), bug_rect(screen).size.x)


## The group chips' row: from right of the hints to left of the radar in landscape (the chips sit over the command bar and
## may reach left past it, over the bug's column); the command bar's width in portrait.
static func chips_span(screen: Vector2) -> Vector2:
	if portrait(screen):
		var panel := panel_rect(screen)
		return Vector2(panel.position.x, panel.end.x)
	return Vector2(MARGIN + hints_width(screen) + GAP, radar_rect(screen).position.x - GAP)


## Where a chip row `width` wide starts: centred over the command bar when it fits there, else slid inside `chips_span`.
static func chips_x(screen: Vector2, width: float) -> float:
	var span := chips_span(screen)
	var centred := panel_rect(screen).get_center().x - width / 2.0
	return clampf(centred, span.x, maxf(span.x, span.y - width))
