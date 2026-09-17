class_name GroupBar
extends Control
## Control X4: a compact bar of control groups (replaces round 2's squad bar). One small chip per group that has
## units: its number, a pictogram per unit, and an average hull bar; lit when the selection is exactly that group.
## Click a chip = press its number key (select; again quickly = center the camera). Sits just above the selection
## panel, bottom center. Behavior is control's; colors come from GameTheme.ui and CyberStyle (feel).

## Chip height at 1080p (scaled with the screen).
const CHIP_HEIGHT := 34.0
const GLYPH := 14.0
const GAP := 6.0

var controls: RtsControls
## The panel it sits on; the bar stays just above it (optional: without it, the bar sits at the bottom).
var panel: Control

var _rects := {}  # number -> Rect2 (local), from the last draw


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_layout()
	queue_redraw()


## What the bar shows, as data (tests read it): [{"number", "roles": [role per living unit], "health": 0..1 average
## hull, "selected": bool}], one per non-empty group in number order.
func summary() -> Array:
	var result: Array = []
	if controls == null:
		return result
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
		result.append({"number": number, "roles": roles, "health": health / roles.size(),
				"selected": members == controls.selection.units})
	return result


func chip_pressed(number: int) -> void:
	if controls != null:
		controls.recall_group(number)


func _scale() -> float:
	return CyberStyle.ui_scale(get_viewport_rect().size)


func _chip_width(roles: int, s: float) -> float:
	return (26.0 + roles * (GLYPH + 3.0) + 8.0) * s


func _layout() -> void:
	var s := _scale()
	var shown := summary()
	var width := 0.0
	for group: Dictionary in shown:
		width += _chip_width((group["roles"] as Array).size(), s) + GAP * s
	var screen := get_viewport_rect().size
	size = Vector2(maxf(width - GAP * s, 1.0), CHIP_HEIGHT * s)
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
	_rects.clear()
	var s := _scale()
	var font := CyberStyle.font()
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var x := 0.0
	var batch := DrawBatch.new()  # X4: kind by kind, so five chips are a few draw calls, not five times as many
	for group: Dictionary in summary():
		var roles: Array = group["roles"]
		var rect := Rect2(x, 0.0, _chip_width(roles.size(), s), CHIP_HEIGHT * s)
		_rects[group["number"]] = rect
		var lit: bool = group["selected"]
		batch.fill(rect, Color(CyberStyle.CARD, 0.92))
		batch.outline(rect, Color(CyberStyle.CYAN, 0.95 if lit else 0.35), 2.0 if lit else 1.0)
		batch.text(font, rect.position + Vector2(6.0 * s, rect.size.y * 0.62), str(group["number"]), roundi(16.0 * s),
				CyberStyle.WHITE if lit else CyberStyle.TEXT)
		for i in roles.size():
			var at := rect.position + Vector2((26.0 + i * (GLYPH + 3.0) + GLYPH * 0.5) * s, rect.size.y * 0.42)
			batch.icon(roles[i], at, GLYPH * s, friendly)
		var health := float(group["health"])
		var bar := Rect2(rect.position + Vector2(24.0 * s, rect.size.y - 7.0 * s), Vector2(rect.size.x - 30.0 * s, 3.0 * s))
		batch.fill(bar, Color(0, 0, 0, 0.6))
		batch.fill(Rect2(bar.position, Vector2(bar.size.x * health, bar.size.y)), friendly if health >= 0.5 else friendly.lerp(enemy, 1.0 - health))
		x += rect.size.x + GAP * s
	batch.flush(self)
