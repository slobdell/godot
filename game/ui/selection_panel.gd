class_name SelectionPanel
extends Control
## Control X6: the bottom panel for the selection, StarCraft-dense. Bottom center, clear of the radar (bottom right).
##   group    a portrait per unit (heavies first): role icon, hull bar, shield bar. Click = select just that unit,
##            shift-click = drop it, ctrl-click = keep only that type
##   unit     one unit's card: type, hull and shield numbers, weapon, what it's doing (its order and queue)
##   enemy    an inspected enemy's card (enemy colors, no commands)
## plus the command card: Move (M), Stop (S), Hold (H), Attack-move (A), Follow (F), Formation (G), doing exactly what
## the keys do. Hidden when nothing is selected. Behavior is control's; colors from GameTheme.ui and CyberStyle (feel).

## Height at 1080p (scaled with the window).
const HEIGHT := 160.0
## Widest at 1080p.
const MAX_WIDTH := 980.0
const PAD := 8.0
const COMMANDS := [["move", "Move", "M"], ["stop", "Stop", "S"], ["hold", "Hold", "H"],
		["attack_move", "Attack-move", "A"], ["follow", "Follow", "F"], ["formation", "Formation", "G"]]
const ORDER_WORDS := {"move": "Moving", "attack": "Attacking", "attack_move": "Attack-moving", "follow": "Following",
		"hold": "Holding", "stop": "Stopping", "": "Idle"}

var controls: RtsControls

var _command_rects := {}  # id -> Rect2 (local)
var _portrait_rects := {}  # unit name -> Rect2 (local)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_layout()
	visible = controls != null and not controls.selection.is_empty()
	queue_redraw()


func _scale() -> float:
	return maxf(get_viewport_rect().size.y / 1080.0, 0.6)


## Where the panel goes: bottom center, as wide as fits between the radar and its mirror on the left.
func _layout() -> void:
	var screen := get_viewport_rect().size
	var s := _scale()
	var radar_side := clampf(screen.y * Radar.HEIGHT_FRACTION, Radar.MIN_SIZE, Radar.MAX_SIZE) + Radar.MARGIN * 2.0
	var width := minf(MAX_WIDTH * s, screen.x - radar_side * 2.0)
	size = Vector2(maxf(width, 200.0), HEIGHT * s)
	position = Vector2((screen.x - size.x) / 2.0, screen.y - size.y - PAD * s)
	_command_rects.clear()
	var button := (size.y - PAD * s * 3.0) / 2.0
	var card_left := size.x - (button * 3.0 + PAD * s * 4.0)
	for i in COMMANDS.size():
		var column := i % 3
		var row := i / 3
		_command_rects[COMMANDS[i][0]] = Rect2(card_left + PAD * s + column * (button + PAD * s), PAD * s + row * (button + PAD * s),
				button, button)
	_portrait_rects.clear()
	var units := _sorted_units()
	if units.size() > 1:
		# A header line for the group's orders, then the biggest square portraits that fit in 1–3 rows.
		var header := 22.0 * s
		var area := Rect2(PAD * s, header, card_left - PAD * s * 2.0, size.y - header - PAD * s)
		var cell := 0.0
		var columns := 1
		for rows in range(1, 4):
			var per_row := ceili(units.size() / float(rows))
			var fit := minf(area.size.y / rows, area.size.x / per_row)
			if fit > cell:
				cell = fit
				columns = per_row
		for i in units.size():
			_portrait_rects[units[i]] = Rect2(area.position + Vector2((i % columns) * cell, (i / columns) * cell), Vector2(cell, cell)).grow(-2.0)


## Selected units, heavies first (then by name).
func _sorted_units() -> Array[String]:
	var result: Array[String] = []
	if controls == null:
		return result
	result = controls.selection.units.duplicate()
	result.sort_custom(func(a: String, b: String) -> bool:
		var rank_a: int = GroupFormation.ROLE_RANK.get(_role(a), 2)
		var rank_b: int = GroupFormation.ROLE_RANK.get(_role(b), 2)
		return rank_a < rank_b if rank_a != rank_b else a < b)
	return result


func _tank(unit_name: String) -> Tank:
	return controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


func _role(unit_name: String) -> String:
	var tank := _tank(unit_name)
	return CommandIcons.role_of(tank) if tank != null else ""


# ---- Data (tests read it; _draw shows it) -----------------------------------------------------------------

## {"mode": "none" | "group" | "unit" | "enemy", "portraits": [{"unit", "role", "health", "shield"}],
##  "card": {"name", "role", "hull", "shield", "weapon", "orders"}, "orders": String (group summary),
##  "commands": [{"id", "label", "hotkey", "enabled"}]}
func summary() -> Dictionary:
	var result := {"mode": "none", "portraits": [], "card": {}, "orders": "", "commands": []}
	if controls == null:
		return result
	var commandable := not controls.selection.units.is_empty()
	for command in COMMANDS:
		var label: String = command[1]
		if command[0] == "formation":
			label = "Formation: %s" % String(controls.formation).capitalize()
		result["commands"].append({"id": command[0], "label": label, "hotkey": command[2], "enabled": commandable})
	if controls.selection.inspected != "":
		result["mode"] = "enemy"
		result["card"] = _card(controls.selection.inspected)
		return result
	var units := _sorted_units()
	if units.is_empty():
		return result
	if units.size() == 1:
		result["mode"] = "unit"
		result["card"] = _card(units[0])
		result["orders"] = result["card"]["orders"]
		return result
	result["mode"] = "group"
	var verbs := {}
	for unit_name in units:
		var tank := _tank(unit_name)
		if tank == null:
			continue
		result["portraits"].append({"unit": unit_name, "role": CommandIcons.role_of(tank),
				"health": float(tank.health) / maxf(tank.max_health, 1.0),
				"shield": tank.shield / tank.max_shield if tank.max_shield > 0.0 else 0.0})
		var words := _order_words(unit_name, false)
		verbs[words] = int(verbs.get(words, 0)) + 1
	var parts: Array[String] = []
	for words: String in verbs:
		parts.append("%s ×%d" % [words, verbs[words]] if verbs.size() > 1 else words)
	result["orders"] = ", ".join(parts)
	return result


func _card(unit_name: String) -> Dictionary:
	var tank := _tank(unit_name)
	if tank == null:
		return {}
	var weapon := Weapons.profile(tank.weapon_id)
	return {"name": String(Units.stat(tank.unit_id, "display_name", tank.unit_id)), "role": CommandIcons.role_of(tank),
			"hull": "Hull %d / %d" % [tank.health, tank.max_health],
			"shield": "Shield %d / %d" % [roundi(tank.shield), roundi(tank.max_shield)],
			"health": float(tank.health) / maxf(tank.max_health, 1.0),
			"shield_fraction": tank.shield / tank.max_shield if tank.max_shield > 0.0 else 0.0,
			"weapon": String(weapon.get("display_name", tank.weapon_id)).capitalize(),
			"enemy": tank.team != controls.team, "orders": _order_words(unit_name, true) if tank.team == controls.team else ""}


func _order_words(unit_name: String, with_queue: bool) -> String:
	if controls.orders == null:
		return "Idle"
	var order := controls.orders.current(unit_name)
	var words: String = ORDER_WORDS.get(order.get("verb", ""), "Idle")
	var waiting := controls.orders.queue(unit_name).size()
	if with_queue and waiting > 0:
		words += " (+%d queued)" % waiting
	return words


# ---- Input --------------------------------------------------------------------------------------------------

func command_rect(id: String) -> Rect2:
	return _command_rects.get(id, Rect2())


func portrait_rect(unit_name: String) -> Rect2:
	return _portrait_rects.get(unit_name, Rect2())


## A command card button (or its hotkey): the same as the key.
func press_command(id: String) -> void:
	if controls == null or controls.selection.units.is_empty():
		return
	match id:
		"move", "attack_move", "follow":
			controls.arm(id)
		"stop", "hold":
			controls.order_selection(id)
		"formation":
			controls.cycle_formation()


func _gui_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button == null:
		return
	accept_event()  # nothing on the panel reaches the map behind it
	if not button.pressed or button.button_index != MOUSE_BUTTON_LEFT:
		return
	for id in _command_rects:
		if (_command_rects[id] as Rect2).has_point(button.position):
			press_command(id)
			return
	for unit_name in _portrait_rects:
		if (_portrait_rects[unit_name] as Rect2).has_point(button.position):
			if button.shift_pressed:
				controls.selection.remove([unit_name])
			elif button.ctrl_pressed:
				var role := _role(unit_name)
				controls.selection.set_units(controls.selection.units.filter(func(n: String) -> bool: return _role(n) == role))
			else:
				controls.selection.set_units([unit_name])
			return


# ---- Drawing ------------------------------------------------------------------------------------------------

func _draw() -> void:
	if controls == null or controls.selection.is_empty():
		return
	if _command_rects.is_empty():
		_layout()
	var s := _scale()
	var font := CyberStyle.font()
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, Color(CyberStyle.HUD_BACKGROUND, 0.9))
	draw_rect(rect, Color(CyberStyle.CYAN, 0.5), false, 1.5)
	var info := summary()
	match String(info["mode"]):
		"group":
			for portrait: Dictionary in info["portraits"]:
				var cell: Rect2 = _portrait_rects.get(portrait["unit"], Rect2())
				if cell.size.x <= 0.0:
					continue
				draw_rect(cell, Color(CyberStyle.CARD, 0.95))
				draw_rect(cell, Color(friendly, 0.35), false, 1.0)
				CommandIcons.draw_unit(self, portrait["role"], cell.get_center() - Vector2(0, cell.size.y * 0.1), cell.size.y * 0.5, friendly)
				var bar_height := clampf(cell.size.y * 0.1, 5.0 * s, 12.0 * s)
				_bars(Rect2(cell.position + Vector2(4, cell.size.y - bar_height - 4.0), Vector2(cell.size.x - 8, bar_height)),
						float(portrait["health"]), float(portrait["shield"]), friendly, enemy)
			_text(font, Vector2(PAD * s, 16.0 * s), "%d UNITS   %s" % [(info["portraits"] as Array).size(), String(info["orders"]).to_upper()],
					15.0 * s, CyberStyle.CYAN)
		"unit", "enemy":
			var card: Dictionary = info["card"]
			var color := enemy if card.get("enemy", false) else friendly
			var icon := size.y - PAD * s * 2.0
			var icon_rect := Rect2(PAD * s, PAD * s, icon, icon)
			draw_rect(icon_rect, Color(CyberStyle.CARD, 0.95))
			CommandIcons.draw_unit(self, card["role"], icon_rect.get_center(), icon * 0.6, color)
			var x := icon_rect.end.x + PAD * s * 2.0
			var line := 24.0 * s
			_text(font, Vector2(x, PAD * s + line * 0.9), ("ENEMY " if card["enemy"] else "") + String(card["name"]).to_upper(), 22.0 * s, color)
			_text(font, Vector2(x, PAD * s + line * 1.9), "%s   %s" % [card["hull"], card["shield"]], 16.0 * s, CyberStyle.TEXT)
			_text(font, Vector2(x, PAD * s + line * 2.8), "Weapon: %s" % card["weapon"], 16.0 * s, Color(CyberStyle.TEXT, 0.8))
			if not card["enemy"]:
				_text(font, Vector2(x, PAD * s + line * 3.7), "Orders: %s" % card["orders"], 16.0 * s, CyberStyle.CYAN)
			_bars(Rect2(x, size.y - PAD * s - 12.0 * s, minf(260.0 * s, _command_rects["move"].position.x - x - PAD * s), 10.0 * s),
					float(card["health"]), float(card["shield_fraction"]), color, enemy)
	for command: Dictionary in info["commands"]:
		var button: Rect2 = _command_rects[command["id"]]
		var enabled: bool = command["enabled"]
		var armed: bool = controls.mode == command["id"]
		draw_rect(button, Color(CyberStyle.CARD, 0.95 if enabled else 0.5))
		draw_rect(button, Color(CyberStyle.YELLOW if armed else CyberStyle.CYAN, 0.9 if enabled else 0.2), false, 2.0 if armed else 1.0)
		var ink := Color(CyberStyle.TEXT, 1.0 if enabled else 0.3)
		_text(font, button.position + Vector2(4.0 * s, 16.0 * s), command["hotkey"], 14.0 * s, Color(CyberStyle.YELLOW, 0.9 if enabled else 0.3))
		var label: String = command["label"]
		if command["id"] == "formation":
			label = String(controls.formation).capitalize()
		_centered(font, button, label, 13.0 * s, ink)


func _bars(area: Rect2, health: float, shield: float, friendly: Color, enemy: Color) -> void:
	var hull := Rect2(area.position + Vector2(0, area.size.y * 0.45), Vector2(area.size.x, area.size.y * 0.55))
	draw_rect(hull, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(hull.position, Vector2(hull.size.x * clampf(health, 0.0, 1.0), hull.size.y)),
			friendly if health >= 0.5 else friendly.lerp(enemy, 1.0 - health))
	var shield_bar := Rect2(area.position, Vector2(area.size.x * clampf(shield, 0.0, 1.0), area.size.y * 0.35))
	draw_rect(shield_bar, Color(0.75, 0.9, 1.0, 0.85))


func _text(font: Font, at: Vector2, text: String, font_size: float, color: Color) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, maxi(9, roundi(font_size)), color)


func _centered(font: Font, box: Rect2, text: String, font_size: float, color: Color) -> void:
	var px := maxi(9, roundi(font_size))
	while px > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x - 6.0:
		px -= 1
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, Vector2(box.get_center().x - width / 2.0, box.end.y - box.size.y * 0.28), text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
