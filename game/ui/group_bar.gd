class_name GroupBar
extends Control
## Control X4: a compact bar of control groups (replaces round 2's squad bar). One small chip per group that has
## units: its number, a pictogram per unit, and an average hull bar; lit when the selection is exactly that group.
## Click a chip = press its number key (select; again quickly = center the camera). Sits just above the selection
## panel, bottom center. Behavior is control's; colors come from GameTheme.ui and CyberStyle (feel).
##
## Round 6 X6 (the lead thinks in squads): each chip also says what that squad is doing - IDLE (lit, so a squad with
## nothing to do is the one the eye finds), MOVING, CONTACT, UNDER FIRE - from ElementAwareness, and "selected" means
## the selection is that group's living members in any order (a dead member used to unlight the chip).
##
## Round 22 (orders O2): ten groups. The chips keep their size (his icons and the IDLE word stay as readable as at
## five); when one row of them is wider than the room between the radar and its mirror on the left (the selection
## panel's own bound), they stand in two rows in key order, 1–5 over 6–0. One row of ten is 1765 px at his
## 1854x1011 window against 1206 px of room. Each chip shows the KEY that recalls it ("0" for group 10), and a squad
## that is wholly inside a bigger selection (Ctrl+A) is lit as well, so ten selected squads read as ten lit chips.

## The chip's state tag, from ElementAwareness states: [word, colour key].
const STATE_WORDS := {"idle": ["IDLE", "idle"], "moving": ["MOVING", "calm"], "contact": ["CONTACT", "warn"],
		"under_fire": ["UNDER FIRE", "danger"]}
const STATE_WIDTH := 64.0

## Chip height at 1080p (scaled with the screen).
const CHIP_HEIGHT := 34.0
const GLYPH := 14.0
const GAP := 6.0

var controls: RtsControls
## The panel it sits on; the bar stays just above it (optional: without it, the bar sits at the bottom).
var panel: Control

var _rects := {}  # number -> Rect2 (local), from the last layout
## Chips per row, from the last layout (one entry per row).
var _rows: Array[int] = []
## Round 16 (hud H3): summary() once a frame, and a redraw only when what the bar draws changed.
var _shown: Array = []
var _shown_frame := -1
var _drawn: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var started := HudClock.begin()
	_process_timed(_delta)
	HudClock.end(&"group_bar.process", started)


func _process_timed(_delta: float) -> void:
	_layout()
	var drawn := [size, _scale(), _current()]
	if drawn != _drawn:
		HudClock.changed(&"group_bar.draw")
		_drawn = drawn
		queue_redraw()


func _current() -> Array:
	var frame := Engine.get_process_frames()
	if _shown_frame != frame:
		_shown = summary()
		_shown_frame = frame
	return _shown


## What the bar shows, as data (tests read it): [{"number", "roles": [role per living unit], "health": 0..1 average
## hull, "selected": bool, "state": ElementAwareness state}], one per non-empty group in number order.
func summary() -> Array:
	var result: Array = []
	if controls == null:
		return result
	var states := {}
	for element: Dictionary in controls.awareness.elements():
		states[int(element["number"])] = String(element["state"])
	var selected := controls.selected_group()
	var chosen := {}
	for unit_name in controls.selection.units:
		chosen[unit_name] = true
	for number in controls.groups.numbers():
		var members := controls.groups.members(number)
		var roles: Array = []
		var health := 0.0
		for unit_name in members:
			var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank == null or not tank.is_alive():
				continue
			roles.append(CommandIcons.role_of(tank))
			health += float(tank.health) / maxf(tank.max_health, 1.0)
		if roles.is_empty():
			continue
		var included := selected == number or (chosen.size() > members.size() and _living_in(members, chosen))
		result.append({"number": number, "key": ControlGroups.key_label(number), "roles": roles,
				"health": health / roles.size(), "selected": selected == number, "included": included,
				"state": String(states.get(number, "idle"))})
	return result


func _living_in(members: Array[String], chosen: Dictionary) -> bool:
	var any := false
	for unit_name in members:
		var tank := controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive():
			continue
		if not chosen.has(unit_name):
			return false
		any = true
	return any


## How many chips stand in each row: all in one while their width fits `room`, else two rows in key order (the first
## holding the extra one when the count is odd). `widths` are the chips' widths, `gap` the space between two.
static func rows_for(widths: Array, gap: float, room: float) -> Array[int]:
	var count := widths.size()
	if count == 0:
		return []
	var total := -gap
	for w: float in widths:
		total += w + gap
	if total <= room or count < 2:
		return [count]
	var first := ceili(count / 2.0)
	return [first, count - first]


## The room the bar may take across: the screen between the radar and its mirror (as the selection panel).
static func room_for(screen: Vector2) -> float:
	var radar_side := clampf(screen.y * Radar.HEIGHT_FRACTION, Radar.MIN_SIZE, Radar.MAX_SIZE) + Radar.MARGIN * 2.0
	return screen.x - radar_side * 2.0


## The chips' rects (local to the bar), number -> Rect2, laid out as `_layout` places them (tests read it).
func chip_rects() -> Dictionary:
	return _rects.duplicate()


func chip_pressed(number: int) -> void:
	if controls != null:
		controls.recall_group(number)


func _scale() -> float:
	return CyberStyle.ui_scale(get_viewport_rect().size)


func _chip_width(roles: int, s: float) -> float:
	return (26.0 + roles * (GLYPH + 3.0) + 8.0 + STATE_WIDTH) * s


func _layout() -> void:
	var s := _scale()
	var shown := _current()
	var screen := get_viewport_rect().size
	var widths: Array = []
	for group: Dictionary in shown:
		widths.append(_chip_width((group["roles"] as Array).size(), s))
	_rows = rows_for(widths, GAP * s, room_for(screen))
	_rects.clear()
	var row_widths: Array[float] = []
	var index := 0
	for count in _rows:
		var w := -GAP * s
		for i in count:
			w += float(widths[index + i]) + GAP * s
		row_widths.append(w)
		index += count
	var width: float = row_widths.max() if not row_widths.is_empty() else 1.0
	index = 0
	for row in _rows.size():
		var x := (width - row_widths[row]) / 2.0
		for i in _rows[row]:
			_rects[shown[index]["number"]] = Rect2(x, row * (CHIP_HEIGHT + GAP) * s, float(widths[index]), CHIP_HEIGHT * s)
			x += float(widths[index]) + GAP * s
			index += 1
	var rows := maxi(_rows.size(), 1)
	size = Vector2(maxf(width, 1.0), (CHIP_HEIGHT * rows + GAP * (rows - 1)) * s)
	var bottom := panel.position.y if panel != null and panel.visible else screen.y
	position = Vector2((screen.x - size.x) / 2.0, bottom - size.y - 6.0 * s)


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null or not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	for number in _rects:
		if (_rects[number] as Rect2).has_point(button.position):
			chip_pressed(number)
			accept_event()
			return


func _draw() -> void:
	var started := HudClock.begin()
	_draw_timed()
	HudClock.end(&"group_bar.draw", started)


func _draw_timed() -> void:
	var s := _scale()
	var font := CyberStyle.font()
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var batch := DrawBatch.new()  # X4: kind by kind, so five chips are a few draw calls, not five times as many
	for group: Dictionary in _current():
		var roles: Array = group["roles"]
		if not _rects.has(group["number"]):
			continue
		var rect: Rect2 = _rects[group["number"]]
		var lit: bool = group["selected"] or group["included"]
		batch.fill(rect, Color(CyberStyle.CARD, 0.92))
		batch.outline(rect, Color(CyberStyle.CYAN, 0.95 if lit else 0.35), 2.0 if lit else 1.0)
		batch.text(font, rect.position + Vector2(6.0 * s, rect.size.y * 0.62), String(group["key"]), roundi(16.0 * s),
				CyberStyle.WHITE if lit else CyberStyle.TEXT)
		for i in roles.size():
			var at := rect.position + Vector2((26.0 + i * (GLYPH + 3.0) + GLYPH * 0.5) * s, rect.size.y * 0.42)
			batch.icon(roles[i], at, GLYPH * s, friendly)
		var word: Array = STATE_WORDS.get(group["state"], ["", "calm"])
		if word[0] != "":
			var tag_color: Color = {"idle": CyberStyle.YELLOW, "calm": Color(CyberStyle.TEXT, 0.7), "warn": CyberStyle.CYAN,
					"danger": enemy}[word[1]]
			batch.text(font, rect.position + Vector2(rect.size.x - (STATE_WIDTH + 2.0) * s, rect.size.y * 0.58), String(word[0]),
					roundi(11.0 * s), tag_color, STATE_WIDTH * s)
		var health := float(group["health"])
		var bar := Rect2(rect.position + Vector2(24.0 * s, rect.size.y - 7.0 * s), Vector2(rect.size.x - 30.0 * s, 3.0 * s))
		batch.fill(bar, Color(0, 0, 0, 0.6))
		batch.fill(Rect2(bar.position, Vector2(bar.size.x * health, bar.size.y)), friendly if health >= 0.5 else friendly.lerp(enemy, 1.0 - health))
	batch.flush(self)
