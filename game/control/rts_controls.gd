class_name RtsControls
extends Control
## Desktop-first, StarCraft-style control (round 3, control stream). A full-screen overlay under the HUD that turns
## mouse and keyboard into selections (Selection), control groups (ControlGroups), and K1 orders (Orders).
## The whole grammar is in _agents/tactical_map.md "v4".
##
##   SELECT   left-click a unit · drag a box · shift adds/removes · double-click or ctrl-click: every visible unit of
##            that type · Escape clears (or cancels a pending order) · click an enemy to inspect it
##   ORDER    right-click ground = move · right-click an enemy = attack · right-click a friend = follow
##            A then click = attack-move · F then click a friend = follow · M then click = move
##            S = stop · H = hold · shift queues any order (and keeps A/F/M armed for the next click)
##            G cycles the formation (auto by default: the group arranges itself by role and situation)
##            right-clicking an enemy with a mixed selection sends only the guns that can hurt it; the rest escort
##   OTHER    F1 selects idle units · resting the mouse on a unit shows its stats
##   GROUPS   ctrl+1–9 saves · shift+1–9 adds · 1–9 selects (twice quickly: center the camera) · Tab cycles groups
##   CAMERA   screen edges, arrows, middle-drag pan · wheel zoom · , . rotate · C centers on the selection
##   TIME     Space pauses (orders still work while paused)
## The node is named "TacticalMap" in skirmish so the HUD skin lays its message columns out around it.

signal command_issued(command: Dictionary, error: String)

## A left press that moves farther than this (pixels) draws a box instead of clicking.
const DRAG_THRESHOLD_PX := 6.0
## A click this close to a unit's screen position picks it (more when the unit is drawn bigger than that).
const PICK_RADIUS_PX := 22.0
const PICK_BODY_M := 2.6
## Screen positions count as "inside the box" within this margin (hull edges peeking in).
const BOX_MARGIN_PX := 4.0
## Armed orders a key waits for a click to complete (A, F, M), and what each click becomes.
const MODES := {KEY_A: "attack_move", KEY_F: "follow", KEY_M: "move"}
const MODE_HINTS := {"attack_move": "ATTACK-MOVE: click the ground or an enemy", "follow": "FOLLOW: click a friendly unit",
		"move": "MOVE: click the ground"}
## G cycles the formation the next orders ask for (auto = by role and situation, GroupFormation.choose).
const FORMATION_CYCLE := [UnitCommand.AUTO, "wedge", "line", "column", "vee"]
## A right-clicked enemy is attacked only by selected units whose weapon does at least this fraction of its damage
## through the target's side armor (Match.armor_multiplier); the rest escort them. With none, everyone attacks.
const SMART_ATTACK_MULTIPLIER := 0.25
## The mouse resting this long on a unit shows its tooltip (seconds).
const HOVER_SECONDS := 0.35
## Order markers and waypoint lines farther than this outside the screen aren't drawn (pixels).
const OFF_SCREEN_PX := 4000.0
## How long an order's acknowledgement marker shows (seconds).
const ACK_SECONDS := 0.7
## A second tap on the same group number within this long centers the camera on it (seconds, wall time: UI only).
const DOUBLE_TAP_SECONDS := 0.4

var game_match: Match
var orders: Orders
var camera: Camera3D
var rig: RtsCamera
## What our team can see (optional).
var visibility: VisibilityField
var team := Match.Team.GREEN
## Tests without fog of war: every enemy counts as seen.
var reveal_all := false
var selection := Selection.new()
var groups := ControlGroups.new()
## The armed order waiting for a click ("" = none): "attack_move", "follow", or "move".
var mode := ""
## The formation move, attack-move, and hold orders ask for (FORMATION_CYCLE; G cycles it).
var formation: String = UnitCommand.AUTO

var _press_at: Variant = null
var _press_shift := false
var _press_ctrl := false
var _press_double := false
var _box_now := Vector2.ZERO
var _boxing := false
## Order acknowledgements: [{"kind", "position": Vector3, "left": seconds}], newest last.
var _acks: Array = []
## UI clock (seconds since ready, advancing while paused) for double taps.
var _clock := 0.0
var _last_group := 0
var _last_group_at := -10.0
## The pause banner's text ("" = none), shown while the tree is paused.
var _pause_text := ""
var _hover_at := Vector2(-1, -1)
var _hover_time := 0.0
## Draws above the panel, group bar, and radar (children draw over their parent): the tooltip and the armed-order hint.
var _overlay: Control


func _ready() -> void:
	# A Control under a CanvasLayer has no parent Control to size it: anchors AND offsets must be set.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.z_index = 50
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)
	_overlay.draw.connect(_draw_overlay)


func _process(delta: float) -> void:
	if game_match == null:
		return
	_clock += delta
	_hover_time += delta
	for ack: Dictionary in _acks:
		ack["left"] = float(ack["left"]) - delta
	_acks = _acks.filter(func(ack: Dictionary) -> bool: return float(ack["left"]) > 0.0)
	if selection.prune(game_match) and selection.units.is_empty():
		disarm()
	groups.prune(game_match)
	mouse_default_cursor_shape = Control.CURSOR_CROSS if mode != "" else Control.CURSOR_ARROW
	_apply_fog_of_war()
	queue_redraw()
	_overlay.queue_redraw()


## Enemies our team can't see are hidden in 3D; nameplates stay off (rings, bars, and the panel carry the info).
func _apply_fog_of_war() -> void:
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null:
			continue
		if tank.team != team:
			tank.visible = can_see(tank)
		tank.nameplate.visible = false
		tank.show_intent = false


func can_see(tank: Tank) -> bool:
	return reveal_all or game_match.is_visible_to(team, tank)


func selection_state() -> Dictionary:
	return {"units": selection.units.duplicate(), "inspected": selection.inspected}


# ---- Mouse ------------------------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if rig != null and rig.handle_mouse(event):
		accept_event()
		return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_left_button(button)
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			if button.pressed:
				if mode != "":
					disarm()  # right-click cancels an armed order, like StarCraft
				else:
					right_click_order(button.position, button.shift_pressed)
			accept_event()
	if event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		if at.distance_to(_hover_at) > 3.0:
			_hover_at = at
			_hover_time = 0.0
	if event is InputEventMouseMotion and _press_at != null:
		_box_now = (event as InputEventMouseMotion).position
		if not _boxing and _box_now.distance_to(_press_at) > DRAG_THRESHOLD_PX:
			_boxing = true
		accept_event()


func _left_button(button: InputEventMouseButton) -> void:
	if button.pressed:
		if mode != "":
			armed_click_order(button.position, button.shift_pressed)
			return
		_press_at = button.position
		_box_now = button.position
		_press_shift = button.shift_pressed
		_press_ctrl = button.ctrl_pressed or button.meta_pressed
		_press_double = button.double_click
		_boxing = false
		return
	if _press_at == null:
		return
	var start: Vector2 = _press_at
	_press_at = null
	if _boxing:
		_boxing = false
		box_select(Rect2(start, button.position - start).abs(), _press_shift)
	else:
		click_select(start, _press_shift, _press_ctrl, _press_double)


## A click: select the unit there (shift toggles it; ctrl or a double-click takes every visible unit of its type).
## An enemy is inspected. Empty ground keeps the selection.
func click_select(at: Vector2, shift := false, ctrl := false, double := false) -> void:
	var tank := pick_unit(at)
	if tank == null:
		return
	var unit_name := String(tank.name)
	if tank.team != team:
		if not shift or selection.units.is_empty():
			selection.inspect(unit_name)
		return
	if ctrl or double:
		var same := visible_of_type(tank.unit_id)
		if shift:
			selection.add(same)
		else:
			selection.set_units(same)
	elif shift:
		selection.toggle(unit_name)
	else:
		selection.set_units([unit_name])


## A box: our units inside it (shift adds them). A box around none of ours keeps the selection.
func box_select(rect: Rect2, shift := false) -> void:
	var inside := units_in_box(rect)
	if inside.is_empty():
		return
	if shift:
		selection.add(inside)
	else:
		selection.set_units(inside)


## The living unit nearest `screen` within reach (ours, or an enemy we can see), or null.
func pick_unit(screen: Vector2) -> Tank:
	var best: Tank = null
	var best_distance := INF
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive() or camera.is_position_behind(tank.global_position):
			continue
		if tank.team != team and not can_see(tank):
			continue
		var at := camera.unproject_position(tank.global_position)
		var distance := at.distance_to(screen)
		var body := camera.unproject_position(tank.global_position + camera.global_basis.x * PICK_BODY_M).distance_to(at)
		# Ties (overlapping units) go to ours, then to the nearer one on screen.
		var score := distance - (0.5 if tank.team == team else 0.0)
		if distance <= maxf(PICK_RADIUS_PX, body) and score < best_distance:
			best = tank
			best_distance = score
	return best


## Our living units whose screen position lies inside `rect`.
func units_in_box(rect: Rect2) -> Array[String]:
	var grown := rect.grow(BOX_MARGIN_PX)
	var result: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and not camera.is_position_behind(tank.global_position) \
				and grown.has_point(camera.unproject_position(tank.global_position)):
			result.append(String(tank.name))
	return result


## Our living units of `unit_id` that are on screen.
func visible_of_type(unit_id: String) -> Array[String]:
	var screen := get_viewport_rect()
	var result: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and tank.unit_id == unit_id and not camera.is_position_behind(tank.global_position) \
				and screen.has_point(camera.unproject_position(tank.global_position)):
			result.append(String(tank.name))
	return result


# ---- Keyboard ---------------------------------------------------------------------------------------------

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode >= KEY_1 and key.keycode <= KEY_9:
		var number := int(key.keycode - KEY_0)
		if key.ctrl_pressed or key.meta_pressed:
			if not selection.units.is_empty():
				groups.save(number, selection.units)
		elif key.shift_pressed:
			if not selection.units.is_empty():
				groups.add(number, selection.units)
		else:
			recall_group(number)
		get_viewport().set_input_as_handled()
		return
	if key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
		return
	match key.keycode:
		KEY_ESCAPE:
			if mode != "":
				disarm()
			else:
				selection.clear()
		KEY_A, KEY_F, KEY_M:
			arm(MODES[key.keycode])
		KEY_S:
			order_selection("stop")
		KEY_H:
			order_selection("hold", {"queue": key.shift_pressed})
		KEY_TAB:
			var next := groups.next_after(_last_group)
			if next > 0:
				recall_group(next, true)
		KEY_C:
			center_on(selection.units)
		KEY_G:
			cycle_formation()
		KEY_F1:
			select_idle()
		KEY_SPACE:
			set_paused(not get_tree().paused)
		_:
			return
	get_viewport().set_input_as_handled()


## Tactical pause: the simulation stops, the controls keep working (orders land when it resumes).
func set_paused(paused: bool, message := "PAUSED: give orders, then Space to resume") -> void:
	get_tree().paused = paused
	_pause_text = message if paused else ""


# ---- Groups and camera ----------------------------------------------------------------------------------

## Select group `number`; a quick second tap (or `center`) also centers the camera on it.
func recall_group(number: int, center := false) -> void:
	var members := groups.members(number)
	if members.is_empty():
		return
	var double := number == _last_group and _clock - _last_group_at <= DOUBLE_TAP_SECONDS
	selection.set_units(members)
	disarm()
	_last_group = number
	_last_group_at = _clock
	if double or center:
		center_on(members)


## Aim the camera at the middle of these units.
func center_on(names: Array) -> void:
	if rig == null or names.is_empty():
		return
	var middle := Vector3.ZERO
	var count := 0
	for unit_name: String in names:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank != null and tank.is_alive():
			middle += tank.global_position
			count += 1
	if count > 0:
		rig.focus_on(middle / count)


# ---- Orders -----------------------------------------------------------------------------------------------

## Issue a K1 command for our team, acknowledge it, and tell listeners. Returns "" or the error.
func issue(command: Dictionary) -> String:
	var error := orders.issue(command, team) if orders != null else "no orders"
	command_issued.emit(command, error)
	if error == "":
		_acknowledge(command)
	return error


## A verb for the whole selection ("" when there is nothing to command).
func order_selection(verb: String, extra: Dictionary = {}) -> String:
	if selection.units.is_empty():
		return ""
	var command := UnitCommand.make(selection.units, verb, extra)
	if formation != UnitCommand.AUTO and verb in ["move", "attack_move", "hold"]:
		command["formation"] = formation
	return issue(command)


func cycle_formation() -> void:
	formation = FORMATION_CYCLE[(FORMATION_CYCLE.find(formation) + 1) % FORMATION_CYCLE.size()]


## Right-click: an enemy = attack, a friend outside the selection = follow, anything else = move there.
func right_click_order(at: Vector2, queue := false) -> String:
	if selection.units.is_empty():
		return ""
	var tank := pick_unit(at)
	if tank != null and tank.team != team:
		return smart_attack(tank, queue)
	if tank != null and not selection.units.has(String(tank.name)):
		return order_selection("follow", {"target": String(tank.name), "queue": queue})
	var world: Variant = screen_to_world(at)
	if world == null:
		return ""
	return order_selection("move", {"to": [world.x, world.z], "queue": queue})


## A right click on the radar (a world point): move there (queued with shift).
func world_order(world: Vector3, queue := false) -> String:
	if mode != "":
		disarm()
		return ""
	return order_selection("move", {"to": [world.x, world.z], "queue": queue})


## A left click on the radar while an order is armed: attack-move or move to that point.
func armed_world_order(world: Vector3, queue := false) -> String:
	var armed := mode
	if not queue:
		disarm()
	if armed in ["attack_move", "move"]:
		return order_selection(armed, {"to": [world.x, world.z], "queue": queue})
	return ""


## Right-click an enemy: the selected units whose guns can hurt it attack; the others follow the nearest attacker.
func smart_attack(target: Tank, queue := false) -> String:
	var attackers: Array[String] = []
	var escorts: Array[String] = []
	for unit_name in selection.units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null:
			continue
		if Match.armor_multiplier(tank.weapon, target.unit_id, "side") >= SMART_ATTACK_MULTIPLIER:
			attackers.append(unit_name)
		else:
			escorts.append(unit_name)
	if attackers.is_empty():
		return order_selection("attack", {"target": String(target.name), "queue": queue})
	var error := issue(UnitCommand.make(attackers, "attack", {"target": String(target.name), "queue": queue}))
	if error != "" or escorts.is_empty():
		return error
	var lead: String = attackers[0]
	var lead_tank := game_match.tanks.get_node(NodePath(lead)) as Tank
	for unit_name in attackers:
		var candidate := game_match.tanks.get_node(NodePath(unit_name)) as Tank
		if candidate.global_position.distance_to(target.global_position) < lead_tank.global_position.distance_to(target.global_position):
			lead = unit_name
			lead_tank = candidate
	return issue(UnitCommand.make(escorts, "follow", {"target": lead, "queue": queue}))


## F1: select every one of our units that has no orders (never ordered, or done). Keeps the selection if none.
func select_idle() -> void:
	var idle: Array[String] = []
	for tank in game_match.sorted_team_tanks(team):
		if tank.is_alive() and (orders == null or orders.is_idle(String(tank.name))):
			idle.append(String(tank.name))
	if not idle.is_empty():
		selection.set_units(idle)
		disarm()


## The tooltip for the unit under a resting mouse: {"unit", "title", "lines": [String], "enemy": bool}, or {}.
func tooltip() -> Dictionary:
	if _hover_time < HOVER_SECONDS or _press_at != null or _hover_at.x < 0.0 or game_match == null:
		return {}
	if get_viewport().gui_get_hovered_control() != self:
		return {}  # the mouse is over the panel, the radar, or other UI
	var tank := pick_unit(_hover_at)
	if tank == null:
		return {}
	var id := tank.unit_id
	var weapon := Weapons.profile(tank.weapon_id)
	var words := func(roles: Variant) -> String:
		return ", ".join((roles if roles is Array else []).map(func(r: Variant) -> String: return String(r).capitalize())) if roles is Array and not (roles as Array).is_empty() else "-"
	return {"unit": String(tank.name), "enemy": tank.team != team,
			"title": ("Enemy " if tank.team != team else "") + String(Units.stat(id, "display_name", id)),
			"lines": [String(Units.stat(id, "blurb", "")),
				"Hull %d/%d   Shield %d/%d" % [tank.health, tank.max_health, roundi(tank.shield), roundi(tank.max_shield)],
				"Weapon %s   Range %d m   Speed %d m/s" % [String(weapon.get("display_name", tank.weapon_id)).capitalize(),
						roundi(float(weapon.get("range", 0.0))), roundi(tank.max_forward_speed)],
				"Strong vs %s   Weak vs %s" % [words.call(Units.stat(id, "good_vs", [])), words.call(Units.stat(id, "weak_vs", []))]]}


## A left click while an order is armed. Shift keeps it armed for the next click (queue a chain).
func armed_click_order(at: Vector2, queue := false) -> String:
	var armed := mode
	if not queue:
		disarm()
	var tank := pick_unit(at)
	var world: Variant = screen_to_world(at)
	match armed:
		"attack_move":
			if tank != null and tank.team != team:
				return order_selection("attack", {"target": String(tank.name), "queue": queue})
			if world != null:
				return order_selection("attack_move", {"to": [world.x, world.z], "queue": queue})
		"follow":
			if tank != null and tank.team == team and not selection.units.has(String(tank.name)):
				return order_selection("follow", {"target": String(tank.name), "queue": queue})
			return "click a friendly unit to follow"
		"move":
			if world != null:
				return order_selection("move", {"to": [world.x, world.z], "queue": queue})
	return ""


## Arm an order that waits for a click (A, F, M). Needs a selection.
func arm(p_mode: String) -> void:
	if selection.units.is_empty():
		return
	mode = p_mode
	_press_at = null
	_boxing = false


func disarm() -> void:
	mode = ""


func screen_to_world(screen: Vector2) -> Variant:
	if camera == null:
		return null
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))
	if hit == null:
		return null
	var point: Vector3 = hit
	return Vector3(clampf(point.x, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), 0.0, clampf(point.z, -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))


## The most recent acknowledgement marker ({} when none is showing): {"kind", "position", "left"}.
func last_ack() -> Dictionary:
	return _acks.back() if not _acks.is_empty() else {}


## A unit's route for waypoint markers: its current order, then its queue, as [{"kind": verb, "position"}]
## (attack and follow point at their target's position; orders without a place are skipped).
func waypoints(unit_name: String) -> Array:
	var route: Array = []
	if orders == null:
		return route
	for order: Dictionary in [orders.current(unit_name)] + orders.queue(unit_name):
		if order.is_empty():
			continue
		var at: Variant = null
		if order.has("target"):
			var target := game_match.tanks.get_node_or_null(NodePath(String(order["target"]))) as Tank
			if target != null and target.is_alive():
				at = Vector3(target.global_position.x, 0.0, target.global_position.z)
		elif order.has("goal") and order["verb"] != "hold":
			at = Vector3(float(order["goal"][0]), 0.0, float(order["goal"][1]))
		if at != null:
			route.append({"kind": String(order["verb"]), "position": at})
	return route


func _acknowledge(command: Dictionary) -> void:
	var at: Variant = null
	var kind: String = command["verb"]
	if command.has("to"):
		at = Vector3(clampf(float(command["to"][0]), -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT), 0.0,
				clampf(float(command["to"][1]), -Match.DRIVABLE_LIMIT, Match.DRIVABLE_LIMIT))
	elif command.has("target"):
		var target := game_match.tanks.get_node_or_null(NodePath(String(command["target"]))) as Tank
		if target != null:
			at = Vector3(target.global_position.x, 0.0, target.global_position.z)
	else:
		# Stop and hold: a marker under the group's middle.
		var middle := Vector3.ZERO
		for unit_name: String in command["units"]:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			if tank != null:
				middle += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		at = middle / maxf((command["units"] as Array).size(), 1.0)
	if at != null:
		_acks.append({"kind": kind, "position": at, "left": ACK_SECONDS})


# ---- Drawing ----------------------------------------------------------------------------------------------

func _draw() -> void:
	_draw_waypoints()
	_draw_acks()
	if _pause_text != "" and get_tree().paused:
		var font := CyberStyle.font()
		var text_size := roundi(22.0 * CyberStyle.ui_scale(size))
		var width := font.get_string_size(_pause_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
		var at := Vector2((size.x - width) / 2.0, size.y * 0.14)
		draw_rect(Rect2(at - Vector2(16, text_size * 1.1), Vector2(width + 32, text_size * 1.6)), Color(CyberStyle.CARD, 0.85))
		draw_string(font, at, _pause_text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, CyberStyle.YELLOW)
	if mode != "":
		var mouse := get_local_mouse_position()
		var font := get_theme_default_font()
		draw_string_outline(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		draw_string(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, _order_color(mode))
	if _boxing and _press_at != null:
		var rect := Rect2(_press_at, _box_now - (_press_at as Vector2)).abs()
		var color: Color = GameTheme.ui["friendly"]
		draw_rect(rect, Color(color, 0.12))
		draw_rect(rect, Color(color, 0.9), false, 1.5)


## Marker colors by verb: moves in the team color, attacks in the enemy color, attack-moves in the commander gold.
func _order_color(verb: String) -> Color:
	match verb:
		"attack":
			return GameTheme.ui["enemy"]
		"attack_move":
			return GameTheme.ui["commander"]
	return GameTheme.ui["friendly"]


## Selected units' routes: a line from each unit through its current and queued stops, a small mark at each stop.
func _draw_waypoints() -> void:
	for unit_name in selection.units:
		var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		var route := waypoints(unit_name)
		if tank == null or route.is_empty():
			continue
		var from := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		for stop: Dictionary in route:
			var to: Vector3 = stop["position"]
			var color := _order_color(stop["kind"])
			var a: Variant = _screen_point(from)
			var b: Variant = _screen_point(to)
			if a != null and b != null:
				draw_dashed_line(a, b, Color(color, 0.55), 1.5, 8.0)
				draw_circle(b, 3.0, Color(color, 0.8))
			from = to


## Order acknowledgements: a ring on the ground that shrinks onto the spot as it fades.
func _draw_acks() -> void:
	for ack: Dictionary in _acks:
		var t := clampf(float(ack["left"]) / ACK_SECONDS, 0.0, 1.0)
		_draw_ground_ring(ack["position"], lerpf(1.0, 4.0, t), Color(_order_color(ack["kind"]), t), 2.5)


func _draw_ground_ring(center: Vector3, radius: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for i in 25:
		var angle := TAU * i / 24.0
		var world := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		var at: Variant = _screen_point(world)
		if at == null:
			return
		points.append(at)
	draw_polyline(points, color, width, true)


## Where a ground point is on screen, or null when it can't be drawn sensibly: behind the camera, not finite (a camera
## not set up yet unprojects to NaN), or far off screen (points near the camera plane project 30k–100k px out, where
## the renderer loses precision: main 8dbe23e, the army-loop-smoke triangulation flake).
func _screen_point(world: Vector3) -> Variant:
	if camera == null or camera.is_position_behind(world):
		return null
	var at := camera.unproject_position(world)
	if not at.is_finite() or not Rect2(Vector2.ZERO, size).grow(OFF_SCREEN_PX).has_point(at):
		return null
	return at


## A player-facing summary of a command for the HUD ("Tank: attack-move", "3 units: follow Scout").
func describe(command: Dictionary) -> String:
	var units: Array = command.get("units", [])
	var who := "%d units" % units.size()
	if units.size() == 1:
		who = _unit_label(String(units[0]))
	var words: String = {"move": "move", "attack": "attack", "attack_move": "attack-move", "follow": "follow",
			"hold": "hold position", "stop": "stop"}.get(command.get("verb", ""), "?")
	if command.has("target"):
		words += " " + _unit_label(String(command["target"]))
	if command.get("queue", false) and command.get("verb") != "stop":
		words += " (queued)"
	return "%s: %s" % [who, words]


func _unit_label(unit_name: String) -> String:
	var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
	if tank == null:
		return unit_name
	return ("%s %s" % ["enemy" if tank.team != team else "", String(Units.stat(tank.unit_id, "display_name", tank.unit_id))]).strip_edges()


func _draw_overlay() -> void:
	if mode != "":
		var mouse := _overlay.get_local_mouse_position()
		var font := get_theme_default_font()
		_overlay.draw_string_outline(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, Color.BLACK)
		_overlay.draw_string(font, mouse + Vector2(18, -8), MODE_HINTS[mode], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, _order_color(mode))
	_draw_tooltip(_overlay)


func _draw_tooltip(canvas: Control) -> void:
	var tip := tooltip()
	if tip.is_empty():
		return
	var font := CyberStyle.font()
	var s := CyberStyle.ui_scale(size)
	var title_size := roundi(17.0 * s)
	var line_size := roundi(14.0 * s)
	var lines: Array = tip["lines"]
	var width := font.get_string_size(tip["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size).x)
	var box := Rect2(_hover_at + Vector2(18, 18), Vector2(width + 20.0 * s, title_size * 1.6 + lines.size() * line_size * 1.35 + 8.0 * s))
	box.position.x = minf(box.position.x, size.x - box.size.x - 4.0)
	box.position.y = minf(box.position.y, size.y - box.size.y - 4.0)
	var accent: Color = GameTheme.ui["enemy"] if tip["enemy"] else GameTheme.ui["friendly"]
	canvas.draw_rect(box, Color(CyberStyle.HUD_BACKGROUND, 0.92))
	canvas.draw_rect(box, Color(accent, 0.8), false, 1.5)
	var y := box.position.y + title_size * 1.2
	canvas.draw_string(font, Vector2(box.position.x + 10.0 * s, y), tip["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, title_size, accent)
	for line: String in lines:
		y += line_size * 1.35
		canvas.draw_string(font, Vector2(box.position.x + 10.0 * s, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, line_size, CyberStyle.TEXT)
