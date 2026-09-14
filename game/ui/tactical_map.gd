class_name TacticalMap
extends Control
## The tactical map: command squads with few inputs (see _agents/tactical_map.md).
##
##   WHO    left-click a tank → select its squad; click a tank in the selected squad → make it commander;
##          keys 1-4 select squads
##   WHERE  drag on open ground (left OR right button): press = destination, drag direction = facing
##          (a left press ON a tank selects instead; left-drag was added after the lead's first playtest)
##   HOW    drill:     Q move · W bound · E hold (here) · R assault · T break contact
##          formation: Z column · X wedge · C vee · V line · B echelon (again: flips side) · N coil
##   VIEW   with an RtsCamera (skirmish, G4): arrows/edge/middle-drag pan, wheel zoom, , . rotate,
##          F follow the selected squad, Tab overview; on touch, one finger drags the view.
##          Without one (tests): Tab toggles a flat top-down map and a view behind the commander
##   TIME   Space pauses/resumes (tactical pause: give orders while paused). Skirmish starts paused.
##
## Every action becomes a SquadCommand (structured data) sent to Match.command_squad().
## Enemies are drawn only from the team's intel: what someone on your team has seen.

signal command_issued(command: Dictionary, error: String)

const PICK_RADIUS_PX := 18.0
const PING_SECONDS := 0.6
## With the RTS camera, 3D nameplates show below this zoom level.
const NAMEPLATE_ZOOM := 0.45
## Drags shorter than this (meters) mean "no particular facing".
const MIN_FACING_DRAG := 4.0
const VERB_KEYS := {KEY_Q: "move", KEY_W: "bound", KEY_E: "hold", KEY_R: "assault", KEY_T: "break_contact"}
const FORMATION_KEYS := {KEY_Z: "column", KEY_X: "wedge", KEY_C: "vee", KEY_V: "line", KEY_B: "echelon_right", KEY_N: "coil"}
const VERB_LABELS := {"move": "Move", "bound": "Bound", "hold": "Hold", "assault": "Assault", "break_contact": "Break contact"}
const FORMATION_LABELS := {"column": "Column", "wedge": "Wedge", "vee": "Vee", "line": "Line",
		"echelon_right": "Echelon R", "echelon_left": "Echelon L", "coil": "Coil"}

# Colors come from the theme (look-and-feel owns them); this file owns behavior.
var FRIENDLY: Color:
	get: return GameTheme.ui["friendly"]
var ENEMY: Color:
	get: return GameTheme.ui["enemy"]
var COMMANDER: Color:
	get: return GameTheme.ui["commander"]
var GHOST: Color:
	get: return GameTheme.ui["ghost"]

var game_match: Match
var camera: Camera3D
## G1: what our team can see (optional; the map still works without it).
var visibility: VisibilityField
## G4: the RTS camera controller (optional; without it the map uses its legacy flat view).
var rig: RtsCamera
var team := Match.Team.GREEN
## Squad name, or "" for none.
var selected_squad := ""
## The drill a right-drag will issue.
var pending_verb := "move"
var tactical_view := true

var _drag_start: Variant = null
var _drag_end: Variant = null
var _info: Label
var _log: Label
var _hint: Label
var _buttons := {}
var _pause_label: Label
var _toast: Label
var _toast_left := 0.0
## Which button started the current drag (left drags only count once they actually move).
var _drag_button := MOUSE_BUTTON_NONE
var _drag_moved := false
## Order acknowledgement (G3): a ring that expands at the ordered spot the moment an order lands.
var _ping_at: Variant = null
var _ping_left := 0.0


func _ready() -> void:
	# A Control under a CanvasLayer has no parent Control to size it: anchors AND offsets must be set.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	# Keep taking orders (and drawing) while the game is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_panels()
	var squads := game_match.team_squads(team)
	if not squads.is_empty():
		selected_squad = squads[0].squad_name
	set_tactical_view(rig == null)  # legacy flat map without an RTS camera; the tilted view with one


func _process(delta: float) -> void:
	_ping_left = maxf(0.0, _ping_left - delta)
	_update_touch(delta)
	if _toast != null and _toast_left > 0.0:
		_toast_left -= delta
		_toast.visible = _toast_left > 0.0
	_apply_fog_of_war()
	queue_redraw()
	_refresh_panels()


## The 3D scene would otherwise show every enemy tank: hide enemies our team can't see
## right now, and hide 3D nameplates on the map (the map draws its own labels).
func _apply_fog_of_war() -> void:
	for tank in game_match.sorted_team_tanks(1 - team):
		tank.visible = game_match.is_visible_to(team, tank)
	# Nameplates help up close; from high up the map draws its own labels.
	var show_plates := not tactical_view if rig == null else rig.zoom < NAMEPLATE_ZOOM and not rig.is_overview()
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		tank.nameplate.visible = show_plates
		if rig != null:
			# Short names, and no brain intents: an enemy's would leak its plans through the fog, and
			# the map already prints our selected squad's.
			tank.show_intent = false
			tank.display_name = MatchAnnouncer.short_name(String(tank.name))


# ---- Commands (the only way the map changes the game) -----------------------------

func issue(command: Dictionary) -> String:
	var error := game_match.command_squad(team, command)
	command_issued.emit(command, error)
	if error == "" and command.has("to"):
		_ping_at = Vector3(float(command["to"][0]), 0.0, float(command["to"][1]))
		_ping_left = PING_SECONDS
	_show_toast(describe_command(command) if error == "" else "Can't: " + error, error != "")
	return error


## A player-facing summary of a command, e.g. "Alpha: Bound in Wedge".
func describe_command(command: Dictionary) -> String:
	var squad := _squad(command["squad"])
	var parts: PackedStringArray = [String(command["squad"])]
	if command.has("commander"):
		parts.append("%s takes command" % command["commander"])
	if command.has("verb") or command.has("formation"):
		parts.append("%s in %s" % [VERB_LABELS.get(squad.verb if squad else "", "—"),
				FORMATION_LABELS.get(squad.formation if squad else "", "—")])
	return ": ".join(parts)


func _show_toast(text: String, is_error := false) -> void:
	if _toast == null:
		return
	_toast.text = text
	_toast.add_theme_color_override("font_color", ENEMY if is_error else Color.WHITE)
	_toast.visible = true
	_toast_left = 2.5


func select_squad(squad_name: String) -> void:
	if _squad(squad_name) != null:
		selected_squad = squad_name


func apply_verb(verb: String) -> String:
	pending_verb = verb
	var squad := _squad(selected_squad)
	if squad == null:
		return "no squad selected"
	match verb:
		"hold", "break_contact":
			return issue({"squad": selected_squad, "verb": verb})  # hold here / fall back to base
		_:
			if squad.destination != null and squad.verb != "hold":
				var goal: Vector3 = squad.destination
				return issue({"squad": selected_squad, "verb": verb, "to": [goal.x, goal.z]})
	return ""  # takes effect on the next right-drag


func apply_formation(formation: String) -> String:
	var squad := _squad(selected_squad)
	if squad == null:
		return "no squad selected"
	if formation == "echelon_right" and squad.formation == "echelon_right":
		formation = "echelon_left"  # pressing Echelon again flips the side
	return issue({"squad": selected_squad, "formation": formation})


## A right-drag from `from` to `to` (world points on the ground).
func order_drag(from: Vector3, to: Vector3) -> String:
	if _squad(selected_squad) == null:
		return "no squad selected"
	var command := {"squad": selected_squad, "verb": pending_verb, "to": [from.x, from.z]}
	var drag := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if drag.length() >= MIN_FACING_DRAG:
		command["facing"] = [drag.x, drag.z]
	return issue(command)


## Left click on the map at a world point.
func click(world: Vector3, screen: Vector2, finger := false) -> void:
	var picked := _pick_tank(screen, finger)
	if picked == null:
		return
	var squad_name := game_match.squad_of(picked)
	if squad_name == selected_squad and _squad(squad_name).commander != String(picked.name):
		issue({"squad": squad_name, "commander": String(picked.name)})
	else:
		select_squad(squad_name)


func set_paused(paused: bool, message := "PAUSED: give orders, then Resume (Space)") -> void:
	get_tree().paused = paused
	if _pause_label != null:
		_pause_label.text = message
		_pause_label.visible = paused


## G4: point the camera at the selected squad's commander and ride along.
func follow_selected() -> void:
	var squad := _squad(selected_squad)
	var lead := game_match.tanks.get_node_or_null(NodePath(squad.commander)) as Tank if squad != null else null
	if rig != null and lead != null and lead.is_alive():
		rig.follow(lead)


func set_tactical_view(enabled: bool) -> void:
	tactical_view = enabled
	if rig != null:
		if enabled != rig.is_overview():
			rig.toggle_overview(team)
		return
	if camera == null:
		return
	if enabled:
		if camera is FollowCamera:
			(camera as FollowCamera).target = null
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = Match.ARENA_HALF_SIZE * 2.0 + 12.0
		camera.global_position = Vector3(0.0, 200.0, 0.0)
		camera.look_at(Vector3.ZERO, Vector3.FORWARD)  # north (the enemy) is up the screen
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		var squad := _squad(selected_squad)
		var lead := game_match.tanks.get_node_or_null(NodePath(squad.commander)) as Tank if squad != null else null
		if lead != null and camera is FollowCamera:
			camera.rotation = Vector3.ZERO
			(camera as FollowCamera).follow(lead)


# ---- Input --------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	# Two-finger camera gestures come straight from the touch stream; they cancel any one-finger drag.
	if rig != null and (event is InputEventScreenTouch or event is InputEventScreenDrag):
		if rig.handle_touch(event):
			_drag_start = null
			_drag_end = null
			_drag_button = MOUSE_BUTTON_NONE


func _gui_input(event: InputEvent) -> void:
	if rig != null:
		if rig.handle_mouse(event):
			accept_event()
			return
		if rig.finger_count() >= 2:
			accept_event()  # a pinch/twist is in progress: its emulated mouse events aren't orders
			return
		if _is_touch(event) and _touch_gesture(event):
			accept_event()
			return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index != MOUSE_BUTTON_LEFT and button.button_index != MOUSE_BUTTON_RIGHT:
			return
		var world: Variant = screen_to_world(button.position)
		if button.pressed and world != null:
			if button.button_index == MOUSE_BUTTON_LEFT and _pick_tank(button.position, _is_touch(event)) != null:
				click(world, button.position, _is_touch(event))  # a press on a tank selects / elects
			else:
				_drag_start = world
				_drag_end = world
				_drag_button = button.button_index
				_drag_moved = button.button_index == MOUSE_BUTTON_RIGHT  # a right click alone is still an order
			accept_event()
		elif not button.pressed and _drag_start != null and button.button_index == _drag_button:
			if _drag_moved:
				order_drag(_drag_start, _drag_end if _drag_end != null else _drag_start)
			_drag_start = null
			_drag_end = null
			_drag_button = MOUSE_BUTTON_NONE
			accept_event()
	elif event is InputEventMouseMotion and _drag_start != null:
		var world: Variant = screen_to_world((event as InputEventMouseMotion).position)
		if world != null:
			_drag_end = world
			if (world as Vector3).distance_to(_drag_start) > 1.5:
				_drag_moved = true


## Mouse events Godot emulates from a touchscreen (the first finger).
static func _is_touch(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


## Touch grammar (G0): a finger's press is PENDING until it moves (PAN the camera) or rests for
## LONG_PRESS_SECONDS (ORDER: drag sets the facing, like a mouse drag). Lifting a pending finger is a
## TAP: on one of our tanks it selects (the normal click path); on the ground it orders the selected
## squad there. The common order is one gesture; facing is a hold-and-drag.
enum Touch { NONE, PENDING, PAN, ORDER }
const LONG_PRESS_SECONDS := 0.35
## A finger that moves less than this (pixels) is still a tap.
const TOUCH_SLOP_PX := 14.0

var _touch := Touch.NONE
var _touch_start := Vector2.ZERO
var _touch_last := Vector2.ZERO
var _touch_held := 0.0


## Consumes emulated-from-touch mouse events that start on open ground. Returns true when handled.
func _touch_gesture(event: InputEvent) -> bool:
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			if _pick_tank(button.position, true) != null:
				_touch = Touch.NONE
				return false  # a tap on one of our tanks selects / elects (the normal click path)
			_touch = Touch.PENDING
			_touch_start = button.position
			_touch_last = button.position
			_touch_held = 0.0
			return true
		var ended := _touch
		_touch = Touch.NONE
		match ended:
			Touch.PENDING:
				var spot: Variant = screen_to_world(_touch_start)
				if spot != null and _squad(selected_squad) != null:
					order_drag(spot, spot)  # tap on the ground: go there
				return true
			Touch.ORDER:
				if _drag_start != null:
					order_drag(_drag_start, _drag_end if _drag_end != null else _drag_start)
				_drag_start = null
				_drag_end = null
				_drag_button = MOUSE_BUTTON_NONE
				return true
			Touch.PAN:
				return true
		return false
	if event is InputEventMouseMotion and _touch != Touch.NONE:
		var at := (event as InputEventMouseMotion).position
		match _touch:
			Touch.PENDING:
				if at.distance_to(_touch_start) > TOUCH_SLOP_PX:
					_touch = Touch.PAN
					if rig != null:
						rig.pan_screen(_touch_last, at)
			Touch.PAN:
				if rig != null:
					rig.pan_screen(_touch_last, at)
			Touch.ORDER:
				var world: Variant = screen_to_world(at)
				if world != null:
					_drag_end = world
		_touch_last = at
		return true
	return false


## Called every frame: a pending finger that rests long enough becomes an order drag (the ghost shows).
func _update_touch(delta: float) -> void:
	if _touch != Touch.PENDING:
		return
	_touch_held += delta
	if _touch_held >= LONG_PRESS_SECONDS:
		var world: Variant = screen_to_world(_touch_start)
		if world == null:
			return
		_touch = Touch.ORDER
		_drag_start = world
		_drag_end = world
		_drag_button = MOUSE_BUTTON_LEFT
		_drag_moved = true


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var squads := game_match.team_squads(team)
	if key.keycode >= KEY_1 and key.keycode <= KEY_4 and key.keycode - KEY_1 < squads.size():
		select_squad(squads[key.keycode - KEY_1].squad_name)
	elif VERB_KEYS.has(key.keycode):
		apply_verb(VERB_KEYS[key.keycode])
	elif FORMATION_KEYS.has(key.keycode):
		apply_formation(FORMATION_KEYS[key.keycode])
	elif key.keycode == KEY_TAB:
		set_tactical_view(not tactical_view)
	elif key.keycode == KEY_F and rig != null:
		follow_selected()
	elif key.keycode == KEY_SPACE:
		set_paused(not get_tree().paused)
	else:
		return
	get_viewport().set_input_as_handled()


func screen_to_world(screen: Vector2) -> Variant:
	if camera == null:
		return null
	return Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


func _pick_tank(screen: Vector2, finger := false) -> Tank:
	var best: Tank = null
	# Fingers are fat (G0): for a touch, anything within 60% of a tap target's height counts.
	var best_distance := maxf(PICK_RADIUS_PX, button_height() * 0.6) if finger or _touch_first() else PICK_RADIUS_PX
	for tank in game_match.sorted_team_tanks(team):
		if not tank.is_alive() or camera.is_position_behind(tank.global_position):
			continue
		var distance := camera.unproject_position(tank.global_position).distance_to(screen)
		if distance <= best_distance:
			best = tank
			best_distance = distance
	return best


func _squad(squad_name: String) -> Squad:
	for squad in game_match.team_squads(team):
		if squad.squad_name == squad_name:
			return squad
	return null


# ---- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	if game_match == null or camera == null:
		return
	var font := ThemeDB.fallback_font
	var by_name := game_match.tanks_by_name()

	# Enemies, only as our intel knows them: solid = in sight now, hollow and fading = remembered.
	var intel: Dictionary = game_match.intel[team]
	for contact_name in intel:
		var contact: Dictionary = intel[contact_name]
		var fade := 1.0 - clampf(float(game_match.tick - int(contact["seen_tick"])) / Match.CONTACT_MEMORY_TICKS, 0.0, 0.8)
		var at := _screen(contact["position"])
		var color := Color(ENEMY, fade)
		var triangle := PackedVector2Array([at + Vector2(0, -9), at + Vector2(8, 6), at + Vector2(-8, 6)])
		if contact["visible"]:
			draw_colored_polygon(triangle, color)
		else:
			triangle.append(triangle[0])
			draw_polyline(triangle, color, 2.0)

	for squad in game_match.team_squads(team):
		var selected := squad.squad_name == selected_squad
		var order := squad.formation_order(by_name)
		# Destination, facing, and the ghost formation for the selected squad.
		if selected and squad.destination != null:
			var lead := by_name.get(squad.commander) as Tank
			if lead != null and lead.is_alive():
				draw_dashed_line(_screen(lead.global_position), _screen(squad.destination), GHOST, 2.0, 8.0)
			for member in order:
				var context := squad.context_for(member, by_name)
				if context["slot"] != null:
					draw_arc(_screen(context["slot"]), 7.0, 0.0, TAU, 20, GHOST, 1.5)
			if squad.facing_on_arrival != Vector3.ZERO:
				_draw_arrow(squad.destination, squad.destination + squad.facing_on_arrival * 10.0, GHOST)
		# The tanks.
		for member in squad.roster:
			var tank := by_name.get(member) as Tank
			if tank == null or not tank.is_alive():
				continue
			var at := _screen(tank.global_position)
			var forward := _screen(tank.global_position - tank.global_basis.z * 5.0)
			draw_circle(at, 8.0, FRIENDLY.darkened(0.0 if selected else 0.35))
			draw_line(at, forward, Color.WHITE, 2.0)
			if member == squad.commander:
				var diamond := PackedVector2Array([at + Vector2(0, -14), at + Vector2(14, 0), at + Vector2(0, 14),
						at + Vector2(-14, 0), at + Vector2(0, -14)])
				draw_polyline(diamond, COMMANDER, 2.0)
				var tag := squad.squad_name.to_upper()
				if selected:
					tag = "%s · %s · %s" % [tag, VERB_LABELS.get(squad.verb, "—"), FORMATION_LABELS.get(squad.formation, "—")]
				draw_string(font, at + Vector2(16, -10), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
						Color.WHITE if selected else Color(1, 1, 1, 0.6))
			if selected:
				draw_arc(at, 11.0, 0.0, TAU, 24, Color.WHITE, 1.5)
				draw_string(font, at + Vector2(-20, 24), tank.intent, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 1, 1, 0.8))

	if _ping_left > 0.0 and _ping_at != null:
		var t := 1.0 - _ping_left / PING_SECONDS
		draw_arc(_screen(_ping_at), lerpf(6.0, 34.0, t), 0.0, TAU, 32, Color(COMMANDER, 1.0 - t), 3.0)

	# Live drag preview: where the formation will stand and which way it will face.
	var squad := _squad(selected_squad)
	if _drag_start != null and squad != null:
		var drag: Vector3 = (_drag_end as Vector3) - (_drag_start as Vector3)
		var heading := drag.normalized() if drag.length() >= MIN_FACING_DRAG else Vector3.FORWARD
		var offsets := Formations.offsets(squad.formation if squad.formation != "" else Formations.DEFAULT,
				squad.formation_order(by_name).size(), squad.spacing)
		for offset in offsets:
			draw_arc(_screen(Formations.to_world(_drag_start, heading, offset)), 8.0, 0.0, TAU, 20, COMMANDER, 2.0)
		if drag.length() >= MIN_FACING_DRAG:
			_draw_arrow(_drag_start, _drag_end, COMMANDER)


func _draw_arrow(from: Vector3, to: Vector3, color: Color) -> void:
	var a := _screen(from)
	var b := _screen(to)
	draw_line(a, b, color, 2.5)
	var back := (a - b).normalized() * 10.0
	draw_line(b, b + back.rotated(0.5), color, 2.5)
	draw_line(b, b + back.rotated(-0.5), color, 2.5)


func _screen(world: Vector3) -> Vector2:
	if camera.is_position_behind(world):
		return Vector2(-10000, -10000)  # off screen: perspective views can put points behind the camera
	return camera.unproject_position(world)


# ---- Panels ------------------------------------------------------------------------
# G0 (mobile first): every action has an on-screen control sized for a thumb. Bottom left: the five
# drills and a Formation button that opens the formation row. Top center: squad chips (tap = select,
# tap the selected chip = follow it), Pause, Overview, Follow. Keys stay as desktop shortcuts.

## Tap targets are this fraction of the screen height (48 px at 1080p is ~4.4%; we go a bit larger),
## clamped to [BUTTON_MIN_PX, BUTTON_MAX_PX] logical pixels.
const BUTTON_HEIGHT_FRACTION := 0.07
const BUTTON_MIN_PX := 40.0
const BUTTON_MAX_PX := 60.0
## Hide the long desktop hint on screens narrower than this.
const HINT_MIN_WIDTH := 1500.0

var _command_bar: HBoxContainer
var _formation_row: HBoxContainer
var _top_row: HBoxContainer
var _squad_chips := {}


func button_height() -> float:
	return clampf(get_viewport().get_visible_rect().size.y * BUTTON_HEIGHT_FRACTION, BUTTON_MIN_PX, BUTTON_MAX_PX)


static func _touch_first() -> bool:
	return DisplayServer.is_touchscreen_available()


func _key_hint(key: Key) -> String:
	return "" if _touch_first() else OS.get_keycode_string(key) + " "


func _build_panels() -> void:
	_command_bar = HBoxContainer.new()
	_command_bar.add_theme_constant_override("separation", 4)
	add_child(_command_bar)
	for key in VERB_KEYS:
		var verb: String = VERB_KEYS[key]
		_add_button(_command_bar, _key_hint(key) + VERB_LABELS[verb], func() -> void: apply_verb(verb), "verb:" + verb)
	_add_button(_command_bar, "Formation", func() -> void: toggle_formation_row(), "formations", false)

	_formation_row = HBoxContainer.new()
	_formation_row.add_theme_constant_override("separation", 4)
	_formation_row.visible = false
	add_child(_formation_row)
	for key in FORMATION_KEYS:
		var formation: String = FORMATION_KEYS[key]
		_add_button(_formation_row, _key_hint(key) + FORMATION_LABELS[formation], func() -> void:
			apply_formation(formation)
			_formation_row.visible = false, "formation:" + formation)

	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", 4)
	add_child(_top_row)
	for squad in game_match.team_squads(team):
		var squad_name := squad.squad_name
		_add_button(_top_row, squad_name, func() -> void: tap_squad_chip(squad_name), "squad:" + squad_name)
		_squad_chips[squad_name] = _buttons["squad:" + squad_name]
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(12, 0)
	_top_row.add_child(gap)
	_add_button(_top_row, "Pause", func() -> void: set_paused(not get_tree().paused), "pause", false)
	if rig != null:
		_add_button(_top_row, "Overview", func() -> void: set_tactical_view(not tactical_view), "overview", false)
		_add_button(_top_row, "Follow", func() -> void: follow_selected(), "follow", false)

	_info = _label(Vector2.ZERO, 15)
	_hint = _label(Vector2.ZERO, 12)
	_hint.text = "Click a tank: select its squad (again: make it commander) · Drag on the ground: go there, drag direction = facing · 1-4 squads · Space: pause · Tab: overview · F: follow · arrows/wheel/, .: camera"
	if _touch_first():
		_hint.text = "Tap a tank: select (again: commander) · Tap ground: go · Hold then drag: go + face · Drag: look around · Pinch: zoom · Twist: turn"
	_toast = _label(Vector2.ZERO, 20)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_pause_label = _label(Vector2.ZERO, 26)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.add_theme_color_override("font_color", COMMANDER)
	_pause_label.visible = false
	_log = _label(Vector2.ZERO, 12)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_layout_panels()
	get_viewport().size_changed.connect(_layout_panels)


## Place everything for the current screen size (phones and desktops share one layout).
func _layout_panels() -> void:
	var screen := get_viewport().get_visible_rect().size
	var h := button_height()
	for id in _buttons:
		(_buttons[id] as Button).custom_minimum_size = Vector2(h * 1.3, h)
		(_buttons[id] as Button).add_theme_font_size_override("font_size", roundi(clampf(h * 0.36, 13.0, 20.0)))
	_command_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_command_bar.offset_left = 10.0
	_command_bar.offset_top = -h - 10.0
	_command_bar.offset_bottom = -10.0
	_formation_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_formation_row.offset_left = 10.0
	_formation_row.offset_top = -2.0 * h - 16.0
	_formation_row.offset_bottom = -h - 16.0
	_top_row.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_top_row.offset_top = 8.0
	_top_row.offset_bottom = 8.0 + h
	_top_row.offset_left = -_top_row.get_combined_minimum_size().x / 2.0
	_top_row.offset_right = _top_row.get_combined_minimum_size().x / 2.0
	var above_bar := h + 16.0
	_hint.visible = screen.x >= HINT_MIN_WIDTH or _touch_first()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 12.0
	_hint.offset_top = -above_bar - 20.0
	_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_info.offset_left = 12.0
	_info.offset_top = -above_bar - (66.0 if _hint.visible else 46.0) - (h + 6.0 if _formation_row.visible else 0.0)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -360.0
	_toast.offset_right = 360.0
	_toast.offset_top = h + 58.0
	_pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pause_label.offset_left = -360.0
	_pause_label.offset_right = 360.0
	_pause_label.offset_top = h + 18.0
	_log.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_log.offset_left = -430.0
	_log.offset_right = -12.0
	_log.offset_top = h + 16.0


func toggle_formation_row() -> void:
	_formation_row.visible = not _formation_row.visible
	_layout_panels()


## Squad chip: tap selects; tapping the already-selected squad's chip follows its commander.
func tap_squad_chip(squad_name: String) -> void:
	if selected_squad == squad_name and rig != null:
		follow_selected()
	else:
		select_squad(squad_name)


func _add_button(row: HBoxContainer, text: String, action: Callable, id: String, toggles := true) -> void:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE  # keep keyboard shortcuts working
	button.toggle_mode = toggles
	button.pressed.connect(action)
	row.add_child(button)
	_buttons[id] = button


func _label(at: Vector2, size: int) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _refresh_panels() -> void:
	var squad := _squad(selected_squad)
	var by_name := game_match.tanks_by_name()
	if squad == null:
		_info.text = "No squad selected (press 1)"
	else:
		var members: PackedStringArray = []
		for member in squad.roster:
			var tank := by_name.get(member) as Tank
			var short := member.get_slice("_", 1).left(1) + member.get_slice("_", 2)
			var readout := "--"
			if tank != null and tank.is_alive():
				readout = str(tank.health)
				if tank.max_shield > 0.0:
					readout += "+%d" % tank.sync_shield  # shield (G6)
				if tank.sync_ammo >= 0:
					readout += " a%d" % tank.sync_ammo  # shells left (G7)
				if float(tank.weapon.get("heat_per_shot", 0.0)) > 0.0:
					readout += " h%d%%" % roundi(tank.sync_heat * 100.0)  # heat (G7)
			members.append(("*" if member == squad.commander else "") + short + " " + readout)
		_info.text = "%s  |  %s in %s  |  next order: %s\n%s" % [squad.squad_name.to_upper(),
				VERB_LABELS.get(squad.verb, "no orders"), FORMATION_LABELS.get(squad.formation, "no formation"),
				VERB_LABELS[pending_verb], "   ".join(members)]
	var lines: PackedStringArray = []
	for s in game_match.team_squads(team):
		for event in s.events.slice(maxi(0, s.events.size() - 3)):
			lines.append(event)
	_log.text = "\n".join(lines.slice(maxi(0, lines.size() - 6)))
	for id in _buttons:
		var parts: PackedStringArray = String(id).split(":")
		var active := false
		match parts[0]:
			"verb":
				active = squad != null and pending_verb == parts[1]
			"formation":
				active = squad != null and (squad.formation == parts[1] \
						or (parts[1] == "echelon_right" and squad.formation == "echelon_left"))
			"squad":
				active = selected_squad == parts[1]
			"formations":
				active = _formation_row.visible
			"pause":
				(_buttons[id] as Button).text = "Resume" if get_tree().paused else "Pause"
			"overview":
				active = tactical_view
		(_buttons[id] as Button).set_pressed_no_signal(active)
