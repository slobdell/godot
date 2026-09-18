class_name SelectionPanel
extends Control
## Control X6: the bottom panel for the selection, StarCraft-dense. Bottom center, clear of the radar (bottom right).
##   group    a portrait per unit (heavies first): role icon, hull bar, shield bar. Click = select just that unit,
##            shift-click = drop it, ctrl-click = keep only that type
##   unit     one unit's card: type, hull and shield numbers, weapon, what it's doing (its order and queue)
##   enemy    an inspected enemy's card (enemy colors, no commands)
## plus the command card: the rows of TaskPalette.card() (N4) - Stop (S), Hold (H), Attack-move (A), Screen (E),
## Support by Fire (R) and Formation (G) - doing exactly what the keys do. Round 6 X1: no Move or Follow buttons -
## right-click already does both (the lead: "buttons like move and follow are already accessible via mouse click, so we
## shouldn't have buttons for them"); M and F stay as keys because they cost nothing. X2: each button's primary read is
## its tactical task graphic (CommandIcons.draw_task), with its doctrinal name under it and a one-sentence tooltip on
## hover. Hidden when nothing is selected. Behavior is control's; colors
## from GameTheme.ui and CyberStyle (feel).
##
## X3: with a whole element selected, the card issues L1 *tasks* and a line under the header reads back what that
## element's leader decided - "Alpha: wedge, bounding overwatch - contact ahead". Screen and support by fire are
## tasks only: they are greyed out for an ad-hoc handful of units, which has no leader to carry them out.

## X4: above this many units the portraits collapse to one per TYPE with a count, so a 30-unit element reads as
## "5 Tanks, 12 Scouts" instead of thirty identical thumbnails nobody can parse.
const GROUP_ABOVE := 10

## Height at 1080p (scaled with the window).
const HEIGHT := 160.0
## Widest at 1080p.
const MAX_WIDTH := 980.0
const PAD := 8.0
## X3: the strip along the bottom of the panel that the element's doctrine line lives in (at 1080p, scaled).
const FOOTER := 18.0
## [id, name, hotkey] per button, from the N4 palette.
static var COMMANDS: Array = TaskPalette.card().map(func(row: Dictionary) -> Array:
	return [String(row["id"]), String(row["name"]), String(row["hotkey"])])
## Buttons on the card, per row.
const COLUMNS := 3
## X2: a button is this much wider than tall, so the doctrinal name fits under the symbol.
const BUTTON_ASPECT := 1.35
## The card's verbs that only an element can carry out.
static var ELEMENT_ONLY: Array = TaskPalette.element_only()
const ORDER_WORDS := {"move": "Moving", "attack": "Attacking", "attack_move": "Attack-moving", "follow": "Following",
		"hold": "Holding", "stop": "Stopping", "": "Idle"}

var controls: RtsControls

var _command_rects := {}  # id -> Rect2 (local)
## X2: the button under the mouse ("" = none), for its tooltip.
var _hovered := ""
var _portrait_rects := {}  # portrait key -> Rect2 (local)
## X4: unit name -> Tank for this pass. One node lookup per unit instead of one per question, which at 30+
## selected was the panel's whole cost (a sort comparator asking for a role does two lookups per comparison).
var _tanks := {}


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
	var wide := button * BUTTON_ASPECT
	var card_left := size.x - (wide * COLUMNS + PAD * s * (COLUMNS + 1.0))
	for i in COMMANDS.size():
		var column := i % COLUMNS
		var row := i / COLUMNS
		_command_rects[COMMANDS[i][0]] = Rect2(card_left + PAD * s + column * (wide + PAD * s), PAD * s + row * (button + PAD * s),
				wide, button)
	_portrait_rects.clear()
	var units: Array[String] = []
	for entry: Dictionary in portrait_entries():
		units.append(String(entry["key"]))
	if units.size() > 1:
		# A header line for the group's orders, the biggest square portraits that fit in 1–3 rows, and a strip
		# along the bottom for the element's doctrine line (which is a whole sentence and used to run off the
		# panel at 1280x720).
		var header := 22.0 * s
		var area := Rect2(PAD * s, header, card_left - PAD * s * 2.0, size.y - header - PAD * s - FOOTER * s)
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


## X4: one entry per portrait: every unit below GROUP_ABOVE, one per type above it.
## [{"key", "role", "health", "shield", "count", "label"}] - `key` is what _portrait_rects and clicks use.
func portrait_entries() -> Array:
	var units := _sorted_units()
	if units.size() <= GROUP_ABOVE:
		var singles: Array = []
		for unit_name in units:
			var tank := _tank(unit_name)
			if tank == null:
				continue
			singles.append({"key": unit_name, "role": CommandIcons.role_of(tank), "count": 1, "label": "",
					"health": float(tank.health) / maxf(tank.max_health, 1.0),
					"shield": tank.shield / tank.max_shield if tank.max_shield > 0.0 else 0.0})
		return singles
	var by_type := {}
	var order: Array[String] = []
	for unit_name in units:
		var tank := _tank(unit_name)
		if tank == null:
			continue
		var id := tank.unit_id
		if not by_type.has(id):
			by_type[id] = {"key": "type:%s" % id, "role": CommandIcons.role_of(tank), "count": 0, "health": 0.0,
					"shield": 0.0, "label": String(Units.stat(id, "display_name", id))}
			order.append(id)
		var entry: Dictionary = by_type[id]
		entry["count"] = int(entry["count"]) + 1
		entry["health"] = float(entry["health"]) + float(tank.health) / maxf(tank.max_health, 1.0)
		entry["shield"] = float(entry["shield"]) + (tank.shield / tank.max_shield if tank.max_shield > 0.0 else 0.0)
	var grouped: Array = []
	for id in order:
		var entry: Dictionary = by_type[id]
		var count := maxf(float(entry["count"]), 1.0)
		entry["health"] = float(entry["health"]) / count
		entry["shield"] = float(entry["shield"]) / count
		grouped.append(entry)
	return grouped


## Selected units, heavies first (then by name).
func _sorted_units() -> Array[String]:
	var result: Array[String] = []
	if controls == null:
		return result
	_refresh_tanks()
	result = controls.selection.units.duplicate()
	var ranks := {}
	for unit_name in result:
		ranks[unit_name] = GroupFormation.ROLE_RANK.get(_role(unit_name), 2)
	result.sort_custom(func(a: String, b: String) -> bool:
		var rank_a: int = ranks[a]
		var rank_b: int = ranks[b]
		return rank_a < rank_b if rank_a != rank_b else a < b)
	return result


## Look every selected unit up once. Called at the top of each pass that touches more than one of them.
func _refresh_tanks() -> void:
	_tanks.clear()
	if controls == null or controls.game_match == null:
		return
	for unit_name in controls.selection.units:
		_tanks[unit_name] = controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


func _tank(unit_name: String) -> Tank:
	if _tanks.has(unit_name):
		return _tanks[unit_name] as Tank
	return controls.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank


func _role(unit_name: String) -> String:
	var tank := _tank(unit_name)
	return CommandIcons.role_of(tank) if tank != null else ""


# ---- Data (tests read it; _draw shows it) -----------------------------------------------------------------

## {"mode": "none" | "group" | "unit" | "enemy", "portraits": [{"unit", "role", "health", "shield"}],
##  "card": {"name", "role", "hull", "shield", "weapon", "orders"}, "orders": String (group summary),
##  "commands": [{"id", "label", "hotkey", "enabled"}]}
func summary() -> Dictionary:
	var result := {"mode": "none", "portraits": [], "card": {}, "orders": "", "commands": [], "count": 0,
			"strength": 1.0, "doctrine": controls.doctrine_line() if controls != null else ""}
	if controls == null:
		return result
	var commandable := not controls.selection.units.is_empty()
	var is_element := controls.can_task()
	for command in COMMANDS:
		var label: String = command[1]
		if command[0] == "formation":
			label = "Formation: %s" % String(controls.formation).capitalize()
		result["commands"].append({"id": command[0], "label": label, "hotkey": command[2],
				"line": String(TaskPalette.row(command[0]).get("line", "")),
				"enabled": commandable and (is_element or not ELEMENT_ONLY.has(command[0]))})
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
	result["portraits"] = portrait_entries()
	for portrait: Dictionary in result["portraits"]:
		portrait["unit"] = String(portrait["key"]) if int(portrait["count"]) == 1 else ""
	result["count"] = units.size()
	result["strength"] = _strength(units)
	var verbs := {}
	for unit_name in units:
		if _tank(unit_name) == null:
			continue
		var words := _order_words(unit_name, false)
		verbs[words] = int(verbs.get(words, 0)) + 1
	var parts: Array[String] = []
	for words: String in verbs:
		parts.append("%s ×%d" % [words, verbs[words]] if verbs.size() > 1 else words)
	result["orders"] = ", ".join(parts)
	return result


## X4: the selection's remaining strength, 0..1 - one number instead of thirty bars.
func _strength(units: Array) -> float:
	var total := 0.0
	var counted := 0
	for unit_name: String in units:
		var tank := _tank(unit_name)
		if tank == null:
			continue
		total += clampf(float(tank.health) / maxf(float(tank.max_health), 1.0), 0.0, 1.0)
		counted += 1
	return total / maxf(float(counted), 1.0)


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
	# X5: what nav says about getting there - blocked, giving way, or when it arrives.
	var landing := controls.movement.card_line(unit_name, controls._unit_label) if with_queue else ""
	if landing != "":
		words += " - " + landing
	return words


# ---- Input --------------------------------------------------------------------------------------------------

## Where the command card starts (local x): the portraits, the unit card and the doctrine line stop short of it.
func _card_left() -> float:
	return (_command_rects[COMMANDS[0][0]] as Rect2).position.x


func command_rect(id: String) -> Rect2:
	return _command_rects.get(id, Rect2())


func portrait_rect(unit_name: String) -> Rect2:
	return _portrait_rects.get(unit_name, Rect2())


## A command card button (or its hotkey): the same as the key.
func press_command(id: String) -> void:
	if controls == null or controls.selection.units.is_empty():
		return
	if ELEMENT_ONLY.has(id) and not controls.can_task():
		return
	match id:
		"attack_move", "screen", "support_by_fire":
			controls.arm(id)
		"stop", "hold":
			controls.order_selection(id)
		"formation":
			controls.cycle_formation()


## X2: the tooltip for the button under the mouse: {"id", "title", "line"} or {}.
func tooltip() -> Dictionary:
	if _hovered == "" or not visible:
		return {}
	var row := TaskPalette.row(_hovered)
	var title := String(row.get("name", _hovered))
	if String(row.get("hotkey", "")) != "":
		title += "  [%s]" % row["hotkey"]
	var line := String(row.get("line", ""))
	if ELEMENT_ONLY.has(_hovered) and controls != null and not controls.can_task():
		line += " Select a whole squad (1-5) first."
	return {"id": _hovered, "title": title, "line": line}


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		_hovered = ""


func _gui_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion != null:
		_hovered = ""
		for id in _command_rects:
			if (_command_rects[id] as Rect2).has_point(motion.position):
				_hovered = id
		return
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
	for key in _portrait_rects:
		if not (_portrait_rects[key] as Rect2).has_point(button.position):
			continue
		var members := _members_of(String(key))
		if button.shift_pressed:
			controls.selection.remove(members)
		elif button.ctrl_pressed and members.size() == 1:
			var role := _role(members[0])
			controls.selection.set_units(controls.selection.units.filter(func(n: String) -> bool: return _role(n) == role))
		else:
			controls.selection.set_units(members)
		return


## The selected units a portrait stands for: one unit, or every unit of that type when portraits are grouped.
func _members_of(key: String) -> Array[String]:
	if not key.begins_with("type:"):
		return [key] as Array[String]
	var id := key.substr(5)
	var members: Array[String] = []
	for unit_name in _sorted_units():
		var tank := _tank(unit_name)
		if tank != null and tank.unit_id == id:
			members.append(unit_name)
	return members


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
	var batch := DrawBatch.new()  # X4: drawn kind by kind, so the panel is a handful of draw calls
	batch.fill(rect, Color(CyberStyle.HUD_BACKGROUND, 0.9))
	batch.outline(rect, Color(CyberStyle.CYAN, 0.5), 1.5)
	var info := summary()
	match String(info["mode"]):
		"group":
			for portrait: Dictionary in info["portraits"]:
				var cell: Rect2 = _portrait_rects.get(portrait["key"], Rect2())
				if cell.size.x <= 0.0:
					continue
				batch.fill(cell, Color(CyberStyle.CARD, 0.95))
				batch.outline(cell, Color(friendly, 0.35), 1.0)
				batch.icon(portrait["role"], cell.get_center() - Vector2(0, cell.size.y * 0.1), cell.size.y * 0.5, friendly)
				var bar_height := clampf(cell.size.y * 0.1, 5.0 * s, 12.0 * s)
				_bars(batch, Rect2(cell.position + Vector2(4, cell.size.y - bar_height - 4.0), Vector2(cell.size.x - 8, bar_height)),
						float(portrait["health"]), float(portrait["shield"]), friendly, enemy)
				# X4: a grouped portrait carries how many it stands for, top-right of the cell.
				if int(portrait["count"]) > 1:
					var tag := "x%d" % int(portrait["count"])
					var tag_size := clampf(cell.size.y * 0.3, 11.0 * s, 20.0 * s)
					var tag_width := font.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(tag_size)).x
					_text(batch, font, cell.position + Vector2(cell.size.x - tag_width - 3.0, tag_size + 1.0), tag, tag_size, CyberStyle.YELLOW)
			# X4: one header for the whole selection - how many, what they are doing, how much of them is left.
			_text(batch, font, Vector2(PAD * s, 16.0 * s), "%d UNITS   %s   %d%%" % [int(info["count"]),
					String(info["orders"]).to_upper(), roundi(float(info["strength"]) * 100.0)], 15.0 * s, CyberStyle.CYAN)
		"unit", "enemy":
			var card: Dictionary = info["card"]
			var color := enemy if card.get("enemy", false) else friendly
			# The footer strip belongs to the doctrine line (X3), so the card stops above it.
			var icon := size.y - PAD * s * 2.0 - FOOTER * s
			var icon_rect := Rect2(PAD * s, PAD * s, icon, icon)
			batch.fill(icon_rect, Color(CyberStyle.CARD, 0.95))
			batch.icon(card["role"], icon_rect.get_center(), icon * 0.6, color)
			var x := icon_rect.end.x + PAD * s * 2.0
			var line := 24.0 * s
			_text(batch, font, Vector2(x, PAD * s + line * 0.9), ("ENEMY " if card["enemy"] else "") + String(card["name"]).to_upper(), 22.0 * s, color)
			_text(batch, font, Vector2(x, PAD * s + line * 1.9), "%s   %s" % [card["hull"], card["shield"]], 16.0 * s, CyberStyle.TEXT)
			_text(batch, font, Vector2(x, PAD * s + line * 2.8), "Weapon: %s" % card["weapon"], 16.0 * s, Color(CyberStyle.TEXT, 0.8))
			if not card["enemy"]:
				_text(batch, font, Vector2(x, PAD * s + line * 3.7), "Orders: %s" % card["orders"], 16.0 * s, CyberStyle.CYAN)
			_bars(batch, Rect2(x, size.y - PAD * s - FOOTER * s - 12.0 * s, minf(260.0 * s, _card_left() - x - PAD * s), 10.0 * s),
					float(card["health"]), float(card["shield_fraction"]), color, enemy)
	# X3: what the element's leader decided, under the header, where the player reads it without looking away.
	var doctrine := String(info["doctrine"])
	if doctrine != "":
		var width: float = _card_left() - PAD * s * 2.0
		batch.text(font, Vector2(PAD * s, size.y - PAD * s - FOOTER * s * 0.25), doctrine, roundi(13.0 * s),
				Color(CyberStyle.YELLOW, 0.95), width)
	for command: Dictionary in info["commands"]:
		var button: Rect2 = _command_rects[command["id"]]
		var enabled: bool = command["enabled"]
		var armed: bool = controls.mode == command["id"]
		batch.fill(button, Color(CyberStyle.CARD, 0.95 if enabled else 0.5))
		batch.outline(button, Color(CyberStyle.YELLOW if armed else CyberStyle.CYAN, 0.9 if enabled else 0.2), 2.0 if armed else 1.0)
		var ink := Color(CyberStyle.TEXT, 1.0 if enabled else 0.3)
		_text(batch, font, button.position + Vector2(4.0 * s, 15.0 * s), command["hotkey"], 13.0 * s, Color(CyberStyle.YELLOW, 0.9 if enabled else 0.3))
		# X2: the symbol is the primary read; the doctrinal name sits under it.
		var label: String = command["label"]
		var glyph := Rect2(button.position + Vector2((button.size.x - button.size.y * 0.62) / 2.0, button.size.y * 0.06),
				Vector2.ONE * button.size.y * 0.62)
		var tint := Color(CyberStyle.CYAN if not armed else CyberStyle.YELLOW, 1.0 if enabled else 0.3)
		if command["id"] == "formation":
			label = String(controls.formation).capitalize()
			batch.texture(CommandIcons.formation_texture(String(controls.formation)), glyph, tint)
		else:
			batch.texture(CommandIcons.task_texture(command["id"]), glyph, tint)
		_label(batch, font, button, label, 12.0 * s, ink)
	var tip := tooltip()
	if not tip.is_empty():
		_tooltip(batch, font, _command_rects[tip["id"]], tip, s)
	batch.flush(self)


## X2: the name under a button's symbol - one line if it fits, else two ("Support / by Fire"), shrinking only if a
## single word is too long.
func _label(batch: DrawBatch, font: Font, box: Rect2, text: String, font_size: float, color: Color) -> void:
	var px := maxi(9, roundi(font_size))
	var lines: Array[String] = [text]
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x - 6.0 and text.contains(" "):
		var cut := text.find(" ")
		lines = [text.substr(0, cut), text.substr(cut + 1)]
	for line in lines:
		while px > 8 and font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x - 6.0:
			px -= 1
	var bottom := box.end.y - box.size.y * 0.07
	for i in lines.size():
		var width := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var y := bottom - (lines.size() - 1 - i) * px * 1.05
		batch.text(font, Vector2(box.get_center().x - width / 2.0, y), lines[i], px, color)


## X2: the hovered button's name and its one sentence, in a box above the card.
func _tooltip(batch: DrawBatch, font: Font, button: Rect2, tip: Dictionary, s: float) -> void:
	var title_px := roundi(15.0 * s)
	var line_px := roundi(13.0 * s)
	var width := 360.0 * s
	var lines := _wrap(font, String(tip["line"]), line_px, width - 16.0 * s)
	var height := (title_px + 8.0 * s) + lines.size() * line_px * 1.3 + 10.0 * s
	var box := Rect2(Vector2(clampf(button.get_center().x - width / 2.0, -position.x + 4.0, size.x - width), -height - 6.0 * s),
			Vector2(width, height))
	batch.fill(box, Color(CyberStyle.HUD_BACKGROUND, 0.97))
	batch.outline(box, Color(CyberStyle.YELLOW, 0.8), 1.5)
	batch.text(font, box.position + Vector2(8.0 * s, 6.0 * s + title_px), String(tip["title"]), title_px, CyberStyle.YELLOW)
	for i in lines.size():
		batch.text(font, box.position + Vector2(8.0 * s, title_px + 14.0 * s + line_px * (1.0 + i * 1.3)), lines[i], line_px,
				CyberStyle.TEXT)


func _wrap(font: Font, text: String, px: int, width: float) -> Array[String]:
	var lines: Array[String] = []
	var current := ""
	for word in text.split(" "):
		var trial := word if current == "" else current + " " + word
		if current != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > width:
			lines.append(current)
			current = word
		else:
			current = trial
	if current != "":
		lines.append(current)
	return lines


func _bars(batch: DrawBatch, area: Rect2, health: float, shield: float, friendly: Color, enemy: Color) -> void:
	var hull := Rect2(area.position + Vector2(0, area.size.y * 0.45), Vector2(area.size.x, area.size.y * 0.55))
	batch.fill(hull, Color(0, 0, 0, 0.6))
	batch.fill(Rect2(hull.position, Vector2(hull.size.x * clampf(health, 0.0, 1.0), hull.size.y)),
			friendly if health >= 0.5 else friendly.lerp(enemy, 1.0 - health))
	var shield_bar := Rect2(area.position, Vector2(area.size.x * clampf(shield, 0.0, 1.0), area.size.y * 0.35))
	batch.fill(shield_bar, Color(0.75, 0.9, 1.0, 0.85))


func _text(batch: DrawBatch, font: Font, at: Vector2, text: String, font_size: float, color: Color) -> void:
	batch.text(font, at, text, maxi(9, roundi(font_size)), color)


func _centered(batch: DrawBatch, font: Font, box: Rect2, text: String, font_size: float, color: Color) -> void:
	var px := maxi(9, roundi(font_size))
	while px > 8 and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > box.size.x - 6.0:
		px -= 1
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	batch.text(font, Vector2(box.get_center().x - width / 2.0, box.end.y - box.size.y * 0.28), text, px, color)
