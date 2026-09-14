class_name TacticalMap
extends Control
## The tactical map: command squads with few inputs (see _agents/tactical_map.md).
##
## C1 one-tap grammar: a finger and the left mouse button behave the same; nothing needs right-click.
##   WHO    tap a squad chip or any of its units → select it; tap a unit of the selected squad → commander
##   WHERE  tap the ground (or the radar) → the selected squad goes there
##          hold 0.35 s, then drag → go there and face the drag direction (advanced)
##   HOW    drill and formation buttons (keys: Q move · W bound · E hold · R assault · T break contact;
##          Z column · X wedge · C vee · V line · B echelon (again: flips side) · N coil)
##   VIEW   drag the ground to pan; pinch zooms, twist rotates; wheel, middle-drag, arrows, , . on desktop;
##          F / Follow tracks the selected squad, Tab / Overview. Without an RtsCamera (tests) Tab toggles
##          a flat top-down map and a view behind the commander
##   TIME   Space / Pause (tactical pause: give orders while paused). Skirmish starts paused.
##   Desktop shortcuts: 1-5 select squads; right-drag orders with a facing in one motion.
##
## Every action becomes a SquadCommand (structured data) sent to Match.command_squad().
## Enemies are drawn only from the team's intel: what someone on your team has seen.

signal command_issued(command: Dictionary, error: String)
## C7: the player selected a squad (key "<team>/<name>", as in Match.squads).
signal squad_selected(squad_key: String)

const PICK_RADIUS_PX := 18.0
## A tap within this many meters of a vehicle's center picks it, when that's more than the pixel radius.
const PICK_BODY_M := 2.5
const PING_SECONDS := 0.6
## With the RTS camera, 3D nameplates show only this close (C5: squad chips, rings, and health bars carry the
## information, so names no longer clutter the play view).
const NAMEPLATE_ZOOM := 0.12
## C5: below this zoom the map leaves vehicles to their 3D models and ground rings; above it, 2D markers.
const ICON_ZOOM := 0.5
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
var _hint: Label
var _buttons := {}
var _pause_label: Label
var _toast: Label
var _toast_left := 0.0
## Which button started the current drag (left drags only count once they actually move).
var _drag_button := MOUSE_BUTTON_NONE
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
	if rig != null:
		tactical_view = rig.is_overview()  # tracking can leave the overview on its own
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
	if error == "":
		_camera_after_order(command)
	return error


# ---- C4: the camera follows orders ----------------------------------------------------

## Drills that travel somewhere (tracked until the squad arrives).
const TRAVEL_VERBS := ["move", "bound", "assault", "break_contact"]
## A point counts as on screen inside this fraction of the screen (the rest is under the HUD).
const ON_SCREEN_INSET := 0.85


## After an order, if the squad or its destination is off screen, the camera frames both and tracks the
## squad until it arrives, the player moves the camera, or another squad is selected.
func _camera_after_order(command: Dictionary) -> void:
	if rig == null or not command.has("verb") or rig.tracking_mode() == RtsCamera.Track.FOLLOW:
		return
	var points := order_points(String(command["squad"]))
	if points.is_empty() or all_on_screen(points):
		return
	rig.track(order_points.bind(String(command["squad"])), RtsCamera.Track.ORDER)


## What order tracking keeps in view: the squad's vehicles and where it's going. Empty once it has
## arrived (or stopped travelling, or is gone).
func order_points(squad_name: String) -> Array:
	var squad := _squad(squad_name)
	if squad == null or squad.arrived or not TRAVEL_VERBS.has(squad.verb) or squad.destination == null:
		return []
	var points := squad_points(squad_name)
	if points.is_empty():
		return []
	points.append(squad.destination)
	return points


## Where a squad's surviving vehicles are.
func squad_points(squad_name: String) -> Array:
	var squad := _squad(squad_name)
	var points: Array = []
	if squad == null:
		return points
	var by_name := game_match.tanks_by_name()
	for member in squad.alive_members(by_name):
		points.append((by_name[member] as Tank).global_position)
	return points


func all_on_screen(points: Array) -> bool:
	var screen := get_viewport().get_visible_rect()
	var inner := screen.grow_individual(-screen.size.x * (1.0 - ON_SCREEN_INSET) / 2.0, -screen.size.y * (1.0 - ON_SCREEN_INSET) / 2.0,
			-screen.size.x * (1.0 - ON_SCREEN_INSET) / 2.0, -screen.size.y * (1.0 - ON_SCREEN_INSET) / 2.0)
	for p in points:
		if camera.is_position_behind(p) or not inner.has_point(camera.unproject_position(p)):
			return false
	return true


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
	if _squad(squad_name) != null and squad_name != selected_squad:
		selected_squad = squad_name
		if rig != null:
			match rig.tracking_mode():
				RtsCamera.Track.ORDER:
					rig.stop_tracking("replaced")  # C4: another selection ends order tracking
				RtsCamera.Track.FOLLOW:
					rig.track(squad_points.bind(squad_name), RtsCamera.Track.FOLLOW)  # "follow selected" moves on
		squad_selected.emit("%d/%s" % [team, squad_name])


## The selected Squad, or null.
func selected() -> Squad:
	return _squad(selected_squad)


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


func apply_formation(formation: String, flip_echelon := true) -> String:
	var squad := _squad(selected_squad)
	if squad == null:
		return "no squad selected"
	if flip_echelon and formation == "echelon_right" and squad.formation == "echelon_right":
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


## C4 "follow selected" toggle: keep the selected squad framed (it follows new selections) until toggled
## off or the player moves the camera.
func follow_selected() -> void:
	if rig == null:
		return
	if rig.tracking_mode() == RtsCamera.Track.FOLLOW:
		rig.stop_tracking("stopped")
	elif not squad_points(selected_squad).is_empty():
		rig.track(squad_points.bind(selected_squad), RtsCamera.Track.FOLLOW)


## C2: a second tap on the selected squad's chip centers the camera on the squad (one frame, no tracking).
func center_on_selected() -> void:
	var points := squad_points(selected_squad)
	if rig != null and not points.is_empty():
		rig.frame(points)


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
			_cancel_press()


func _gui_input(event: InputEvent) -> void:
	if rig != null:
		if rig.handle_mouse(event):
			accept_event()
			return
		if rig.finger_count() >= 2:
			_cancel_press()
			accept_event()  # a pinch/twist is in progress: its emulated mouse events aren't orders
			return
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		if button.button_index == MOUSE_BUTTON_LEFT:
			_press_button(button.pressed, button.position, _is_touch(event))
			accept_event()
		elif button.button_index == MOUSE_BUTTON_RIGHT:
			_right_button(button.pressed, button.position)
			accept_event()
	elif event is InputEventMouseMotion:
		var at := (event as InputEventMouseMotion).position
		if _press != Press.NONE:
			_press_motion(at)
			accept_event()
		elif _drag_button == MOUSE_BUTTON_RIGHT and _drag_start != null:
			var world: Variant = screen_to_world(at)
			if world != null:
				_drag_end = world


## Mouse events Godot emulates from a touchscreen (the first finger).
static func _is_touch(event: InputEvent) -> bool:
	return event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION


## C1 one-tap grammar, identical for a finger and the left mouse button. A press on open ground is
## PENDING until it moves (PAN the camera: grab the ground) or rests for LONG_PRESS_SECONDS (ORDER: the
## ghost formation appears and the drag sets the facing). Releasing a pending press is a TAP: on one of
## our tanks it selects its squad (again: elects it commander); on the ground it orders the selected
## squad there. The right mouse button stays as a desktop shortcut: press = destination, drag = facing.
enum Press { NONE, PENDING, PAN, ORDER }
const LONG_PRESS_SECONDS := 0.35
## A press that moves less than this (pixels) is still a tap.
const TOUCH_SLOP_PX := 14.0

var _press := Press.NONE
var _press_start := Vector2.ZERO
var _press_last := Vector2.ZERO
var _press_held := 0.0
var _press_finger := false
## The tank under the press, if any: released without moving, it's a tap on that tank.
var _press_tank: Tank = null


func _press_button(pressed: bool, at: Vector2, finger: bool) -> void:
	if pressed:
		_press = Press.PENDING
		_press_start = at
		_press_last = at
		_press_held = 0.0
		_press_finger = finger
		_press_tank = _pick_tank(at, finger)
		return
	var ended := _press
	var tank := _press_tank
	_press = Press.NONE
	_press_tank = null
	match ended:
		Press.PENDING:
			tap(_press_start, finger, tank)
		Press.ORDER:
			if _drag_start != null:
				order_drag(_drag_start, _drag_end if _drag_end != null else _drag_start)
			_clear_drag()


func _press_motion(at: Vector2) -> void:
	match _press:
		Press.PENDING:
			if at.distance_to(_press_start) > TOUCH_SLOP_PX:
				_press = Press.PAN
				if rig != null:
					rig.pan_screen(_press_start, at)
		Press.PAN:
			if rig != null:
				rig.pan_screen(_press_last, at)
		Press.ORDER:
			var world: Variant = screen_to_world(at)
			if world != null:
				_drag_end = world
	_press_last = at


## A tap at a screen point: select (or elect) the tank there, else send the selected squad to the ground.
func tap(screen: Vector2, finger := false, tank: Tank = null) -> void:
	if tank == null:
		tank = _pick_tank(screen, finger)
	var world: Variant = screen_to_world(screen)
	if tank != null:
		click(world, screen, finger)
	elif world != null and _squad(selected_squad) != null:
		order_drag(world, world)


func _right_button(pressed: bool, at: Vector2) -> void:
	var world: Variant = screen_to_world(at)
	if pressed and world != null:
		_drag_start = world
		_drag_end = world
		_drag_button = MOUSE_BUTTON_RIGHT
	elif not pressed and _drag_button == MOUSE_BUTTON_RIGHT and _drag_start != null:
		order_drag(_drag_start, _drag_end if _drag_end != null else _drag_start)
		_clear_drag()


func _cancel_press() -> void:
	_press = Press.NONE
	_press_tank = null
	_clear_drag()


func _clear_drag() -> void:
	_drag_start = null
	_drag_end = null
	_drag_button = MOUSE_BUTTON_NONE


## Called every frame: a pending press on open ground that rests long enough becomes an order drag.
func _update_touch(delta: float) -> void:
	if _press != Press.PENDING or _press_tank != null:
		return
	_press_held += delta
	if _press_held >= LONG_PRESS_SECONDS:
		var world: Variant = screen_to_world(_press_start)
		if world == null:
			return
		_press = Press.ORDER
		_drag_start = world
		_drag_end = world
		_drag_button = MOUSE_BUTTON_LEFT


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var squads := game_match.team_squads(team)
	if key.keycode >= KEY_1 and key.keycode <= KEY_5 and key.keycode - KEY_1 < squads.size():
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
	var reach := maxf(PICK_RADIUS_PX, button_height() * 0.6) if finger or _touch_first() else PICK_RADIUS_PX
	var best_distance := INF
	for tank in game_match.sorted_team_tanks(team):
		if not tank.is_alive() or camera.is_position_behind(tank.global_position):
			continue
		var at := camera.unproject_position(tank.global_position)
		var distance := at.distance_to(screen)
		# Up close a vehicle is bigger than the finger: anywhere on its (rough) footprint counts.
		var body := camera.unproject_position(tank.global_position + camera.global_basis.x * PICK_BODY_M).distance_to(at)
		if distance <= maxf(reach, body) and distance < best_distance:
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
	var close_up := is_close_up()

	# The control point (stretch): a ring on the ground in the holder's color, filling with capture progress.
	if game_match.control_point:
		var ring := PackedVector2Array()
		for i in 33:
			var angle := TAU * i / 32.0
			ring.append(_screen(Match.CONTROL_CENTER + Vector3(cos(angle), 0.0, sin(angle)) * Match.CONTROL_RADIUS))
		var holder := Color(1, 1, 1, 0.8) if game_match.control_owner < 0 else (FRIENDLY if game_match.control_owner == team else ENEMY)
		draw_polyline(ring, holder, 3.0)
		var ours := game_match.control_progress if team == Match.Team.GREEN else -game_match.control_progress
		var progress_color := FRIENDLY if ours > 0.0 else ENEMY
		var arc := PackedVector2Array()
		for i in int(absf(ours) * 32.0) + 1:
			var angle := TAU * i / 32.0
			arc.append(_screen(Match.CONTROL_CENTER + Vector3(cos(angle), 0.0, sin(angle)) * (Match.CONTROL_RADIUS - 2.0)))
		if arc.size() > 1:
			draw_polyline(arc, progress_color, 4.0)

	# Enemies, only as our intel knows them. Remembered contacts: a hollow triangle fading with age. Contacts
	# in sight: their unit-type icon from far out; up close the model and its red ground ring show them.
	var intel: Dictionary = game_match.intel[team]
	var glyph := marker_size()
	for contact_name in intel:
		var contact: Dictionary = intel[contact_name]
		var fade := 1.0 - clampf(float(game_match.tick - int(contact["seen_tick"])) / Match.CONTACT_MEMORY_TICKS, 0.0, 0.8)
		var at := _screen(contact["position"])
		var color := Color(ENEMY, fade)
		var enemy := by_name.get(contact_name) as Tank
		if contact["visible"] and enemy != null:
			if close_up:
				_draw_health_bar(enemy, false)
			else:
				CommandIcons.draw_unit(self, CommandIcons.role_of(enemy), at, glyph, ENEMY, _screen_heading(enemy))
		elif not contact["visible"]:
			var triangle := PackedVector2Array([at + Vector2(0, -9), at + Vector2(8, 6), at + Vector2(-8, 6), at + Vector2(0, -9)])
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
		# The vehicles. Up close the models and 3D ground rings (SelectionMarkers) show them, plus a small
		# health bar over the selected squad; from far out, unit-type icons (the selected squad ringed).
		for member in squad.roster:
			var tank := by_name.get(member) as Tank
			if tank == null or not tank.is_alive():
				continue
			if close_up:
				if selected:
					_draw_health_bar(tank, true)
				continue
			var at := _screen(tank.global_position)
			if selected:
				draw_circle(at, glyph * 0.8, Color(0, 0, 0, 0.45))
				draw_arc(at, glyph * 0.8, 0.0, TAU, 24, COMMANDER if member == squad.commander else Color.WHITE, 2.0)
			CommandIcons.draw_unit(self, CommandIcons.role_of(tank), at, glyph,
					FRIENDLY if selected else FRIENDLY.darkened(0.3), _screen_heading(tank))
			if member == squad.commander:
				draw_string(font, at + Vector2(glyph * 0.9, -glyph * 0.4), squad.squad_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT,
						-1, 13, Color.WHITE if selected else Color(1, 1, 1, 0.6))

	if _ping_left > 0.0 and _ping_at != null:
		var t := 1.0 - _ping_left / PING_SECONDS
		draw_arc(_screen(_ping_at), lerpf(6.0, 34.0, t), 0.0, TAU, 32, Color(COMMANDER, 1.0 - t), 3.0)

	if game_match.control_point:
		_draw_control_meter(font)

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


## C6: the control point score under the squad bar: our points fill from the left, theirs from the right,
## the label shows who holds the center.
func _draw_control_meter(font: Font) -> void:
	var bar_rect := _squad_bar.get_global_rect()
	var width := clampf(bar_rect.size.x, 200.0, 420.0)
	var at := Vector2(bar_rect.get_center().x - width / 2.0, bar_rect.end.y + 6.0)
	var height := 6.0
	var ours := float(game_match.control_score[team]) / Match.CONTROL_POINTS_TO_WIN
	var theirs := float(game_match.control_score[1 - team]) / Match.CONTROL_POINTS_TO_WIN
	draw_rect(Rect2(at, Vector2(width, height)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(at, Vector2(width / 2.0 * ours, height)), FRIENDLY)
	draw_rect(Rect2(at + Vector2(width - width / 2.0 * theirs, 0), Vector2(width / 2.0 * theirs, height)), ENEMY)
	draw_line(at + Vector2(width / 2.0, -2), at + Vector2(width / 2.0, height + 2), Color.WHITE, 1.0)
	var holder := "CENTER: neutral"
	var color := Color(1, 1, 1, 0.8)
	if game_match.control_owner == team:
		holder = "CENTER: ours"
		color = FRIENDLY
	elif game_match.control_owner >= 0:
		holder = "CENTER: theirs"
		color = ENEMY
	var text := "%s   %d : %d  of %d" % [holder, game_match.control_score[team], game_match.control_score[1 - team],
			Match.CONTROL_POINTS_TO_WIN]
	draw_string(font, at + Vector2(0, height + 15.0), text, HORIZONTAL_ALIGNMENT_CENTER, width, 13, color)


## Far-out marker size in pixels (a thumb-readable icon on a phone, not a blob on a desktop).
func marker_size() -> float:
	return clampf(button_height() * 0.42, 16.0, 24.0)


## A vehicle's heading on screen (radians, 0 = up the screen, clockwise positive).
func _screen_heading(tank: Tank) -> float:
	var at := _screen(tank.global_position)
	var ahead := _screen(tank.global_position - tank.global_basis.z * 4.0)
	return (ahead - at).angle() + PI / 2.0 if ahead.distance_to(at) > 0.5 else 0.0


## C5: a small hull + shield bar floating over a vehicle (ours in the selected squad; enemies only when hurt).
func _draw_health_bar(tank: Tank, ours: bool) -> void:
	var health := float(tank.sync_health) / maxf(float(tank.max_health), 1.0)
	var shield := float(tank.sync_shield) / maxf(tank.max_shield, 1.0) if tank.max_shield > 0.0 else 0.0
	if not ours and health >= 0.999:
		return
	var hull: Array = Units.stat(tank.unit_id, "hull_size")
	var top := tank.global_position + Vector3.UP * (float(hull[1]) + 3.2)
	if camera.is_position_behind(top):
		return
	var at := camera.unproject_position(top)
	var width := clampf(button_height() * 0.7, 26.0, 40.0)
	var bar := Rect2(at - Vector2(width / 2.0, 0.0), Vector2(width, 4.0))
	draw_rect(bar.grow(1.0), Color(0, 0, 0, 0.7))
	draw_rect(Rect2(bar.position, Vector2(width * health, 4.0)), (FRIENDLY if ours else ENEMY) if health > 0.35 else COMMANDER)
	if shield > 0.0:
		draw_rect(Rect2(bar.position - Vector2(0, 3.0), Vector2(width * shield, 2.0)), Color(0.75, 0.9, 1.0, 0.9))


## Whether the camera is close enough that vehicles read as models (3D rings mark them, no 2D markers).
func is_close_up() -> bool:
	return rig != null and not rig.is_overview() and rig.zoom < ICON_ZOOM


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
# G0 (mobile first): every action has an on-screen control sized for a thumb. Bottom left (C3): the five
# drills as icon buttons and a Formation button (showing the squad's formation) that opens the formation
# picker: cards drawn from the real formation geometry, with a plain-language line about the chosen one.
# Top center (C2): the squad bar. Top right: Pause, Overview, Follow. Keys stay as desktop shortcuts.

## Tap targets are this fraction of the screen height (48 px at 1080p is ~4.4%; we go a bit larger),
## clamped to [BUTTON_MIN_PX, BUTTON_MAX_PX] logical pixels.
const BUTTON_HEIGHT_FRACTION := 0.07
const BUTTON_MIN_PX := 40.0
const BUTTON_MAX_PX := 60.0
## Hide the long desktop hint on screens narrower than this.
const HINT_MIN_WIDTH := 1500.0
## Squad chips are this many button heights wide and tall.
const CHIP_WIDTH := 3.0
const CHIP_HEIGHT := 1.3
## Drill buttons (icon over a short name), in button heights.
const DRILL_WIDTH := 1.55
const DRILL_HEIGHT := 1.3
## Formation picker cards, in button heights, and cards per row.
const CARD_WIDTH := 3.0
const CARD_HEIGHT := 2.1
const CARD_COLUMNS := 4
## Picker order: every formation, both echelons.
const PICKER_FORMATIONS := ["wedge", "column", "line", "vee", "echelon_left", "echelon_right", "coil"]
const DRILL_SHORT := {"move": "Move", "bound": "Bound", "hold": "Hold", "assault": "Assault", "break_contact": "Break"}

var _command_bar: HBoxContainer
## The formation picker (kept under its old name: it replaced the formation row).
var _formation_row: PanelContainer
var _formation_grid: GridContainer
var _formation_about: Label
var _top_row: HBoxContainer
var _squad_bar: HBoxContainer
var _squad_chips := {}


func button_height() -> float:
	return clampf(get_viewport().get_visible_rect().size.y * BUTTON_HEIGHT_FRACTION, BUTTON_MIN_PX, BUTTON_MAX_PX)


static func _touch_first() -> bool:
	return DisplayServer.is_touchscreen_available()


func _key_hint(key: Key) -> String:
	return "" if _touch_first() else OS.get_keycode_string(key)


func _build_panels() -> void:
	_command_bar = HBoxContainer.new()
	_command_bar.name = "OrderBar"
	_command_bar.add_theme_constant_override("separation", 4)
	add_child(_command_bar)
	for key in VERB_KEYS:
		var verb: String = VERB_KEYS[key]
		var drill := _icon_button(_command_bar, IconButton.Kind.DRILL, verb, DRILL_SHORT[verb], "verb:" + verb,
				func() -> void: apply_verb(verb))
		drill.hotkey = _key_hint(key)
	var formations := _icon_button(_command_bar, IconButton.Kind.FORMATION, Formations.DEFAULT, "Formation", "formations",
			func() -> void: toggle_formation_row())
	formations.toggle_mode = false

	_formation_row = PanelContainer.new()
	_formation_row.name = "FormationPicker"
	_formation_row.visible = false
	add_child(_formation_row)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_formation_row.add_child(column)
	_formation_about = Label.new()
	_formation_about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(_formation_about)
	_formation_grid = GridContainer.new()
	_formation_grid.columns = CARD_COLUMNS
	_formation_grid.add_theme_constant_override("h_separation", 4)
	_formation_grid.add_theme_constant_override("v_separation", 4)
	column.add_child(_formation_grid)
	var formation_keys := {}
	for key in FORMATION_KEYS:
		formation_keys[FORMATION_KEYS[key]] = key
	for formation in PICKER_FORMATIONS:
		var info: Array = CommandIcons.FORMATION_INFO[formation]
		var card := _icon_button(_formation_grid, IconButton.Kind.FORMATION, formation, info[0], "formation:" + formation,
				func() -> void:
					apply_formation(formation, false)
					_formation_row.visible = false
					_layout_panels())
		card.tagline = info[1]
		card.count = 5
		if formation_keys.has(formation):
			card.hotkey = _key_hint(formation_keys[formation])

# C2: the squad bar (top center): one chip per squad, up to 5.
	_squad_bar = HBoxContainer.new()
	_squad_bar.name = "SquadBar"
	_squad_bar.add_theme_constant_override("separation", 4)
	add_child(_squad_bar)
	var squads := game_match.team_squads(team)
	for i in squads.size():
		var squad_name := squads[i].squad_name
		var chip := SquadChip.new()
		chip.name = "Chip_" + squad_name
		chip.squad = squads[i]
		chip.game_match = game_match
		chip.hotkey = "" if _touch_first() or i >= 5 else str(i + 1)
		chip.pressed.connect(func() -> void: tap_squad_chip(squad_name))
		_squad_bar.add_child(chip)
		_buttons["squad:" + squad_name] = chip
		_squad_chips[squad_name] = chip
	# Camera and time (top right).
	_top_row = HBoxContainer.new()
	_top_row.add_theme_constant_override("separation", 4)
	add_child(_top_row)
	_add_button(_top_row, "Pause", func() -> void: set_paused(not get_tree().paused), "pause", false)
	if rig != null:
		_add_button(_top_row, "Overview", func() -> void: set_tactical_view(not tactical_view), "overview", false)
		_add_button(_top_row, "Follow", func() -> void: follow_selected(), "follow")

	_info = _label(Vector2.ZERO, 15)
	_hint = _label(Vector2.ZERO, 12)
	_hint.text = "Click a squad: select · Click ground or radar: go · Hold then drag: go + face · Drag: look around · Wheel: zoom · 1-5 squads · Space: pause"
	if _touch_first():
		_hint.text = "Tap a squad: select · Tap ground or radar: go · Hold then drag: go + face · Drag: look around · Pinch: zoom · Twist: turn"
	_toast = _label(Vector2.ZERO, 20)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.visible = false
	_pause_label = _label(Vector2.ZERO, 26)
	_pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_label.add_theme_color_override("font_color", COMMANDER)
	_pause_label.visible = false
	_layout_panels()
	get_viewport().size_changed.connect(_layout_panels)


## Place everything for the current screen size (phones and desktops share one layout).
func _layout_panels() -> void:
	var screen := get_viewport().get_visible_rect().size
	var h := button_height()
	for id in _buttons:
		var button := _buttons[id] as Button
		if button is SquadChip:
			button.custom_minimum_size = Vector2(h * CHIP_WIDTH, h * CHIP_HEIGHT)
		elif button is IconButton and String(id).begins_with("formation:"):
			button.custom_minimum_size = Vector2(h * CARD_WIDTH, h * CARD_HEIGHT)
		elif button is IconButton:
			button.custom_minimum_size = Vector2(h * DRILL_WIDTH, h * DRILL_HEIGHT)
		else:
			button.custom_minimum_size = Vector2(h * 1.3, h)
			button.add_theme_font_size_override("font_size", roundi(clampf(h * 0.36, 13.0, 20.0)))
	var bar_height := h * DRILL_HEIGHT
	_command_bar.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_command_bar.offset_left = 10.0
	_command_bar.offset_top = -bar_height - 10.0
	_command_bar.offset_bottom = -10.0
	_formation_about.add_theme_font_size_override("font_size", roundi(clampf(h * 0.3, 12.0, 17.0)))
	_formation_about.custom_minimum_size.x = _formation_grid.get_combined_minimum_size().x
	var picker_size := _formation_row.get_combined_minimum_size()
	_formation_row.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_formation_row.offset_left = 10.0
	_formation_row.offset_bottom = -bar_height - 16.0
	_formation_row.offset_top = _formation_row.offset_bottom - picker_size.y
	_formation_row.offset_right = 10.0 + picker_size.x
	var bar_width := _squad_bar.get_combined_minimum_size().x
	_squad_bar.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_squad_bar.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_squad_bar.offset_top = 8.0
	_squad_bar.offset_bottom = 8.0 + h * CHIP_HEIGHT
	_squad_bar.offset_left = -bar_width / 2.0
	_squad_bar.offset_right = bar_width / 2.0
	var tools_width := _top_row.get_combined_minimum_size().x
	_top_row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_top_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN  # a stale minimum size must grow left, not off screen
	_top_row.offset_right = -10.0
	_top_row.offset_left = -10.0 - tools_width
	_top_row.offset_top = 8.0
	# Narrow screens: if the tools would overlap the squad bar, drop them below it on the right.
	if screen.x - 10.0 - tools_width < (screen.x + bar_width) / 2.0 + 8.0:
		_top_row.offset_top = 14.0 + h * CHIP_HEIGHT
	_top_row.offset_bottom = _top_row.offset_top + h
	var above_bar := bar_height + 16.0
	_hint.visible = screen.x >= HINT_MIN_WIDTH or _touch_first()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_hint.offset_left = 12.0
	_hint.offset_top = -above_bar - 20.0
	_info.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_info.offset_left = 12.0
	_info.offset_top = -above_bar - (46.0 if _hint.visible else 26.0) - (picker_size.y + 6.0 if _formation_row.visible else 0.0)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_left = -360.0
	_toast.offset_right = 360.0
	_toast.offset_top = h * CHIP_HEIGHT + 78.0
	_pause_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pause_label.offset_left = -360.0
	_pause_label.offset_right = 360.0
	_pause_label.offset_top = h * CHIP_HEIGHT + 40.0


func toggle_formation_row() -> void:
	_formation_row.visible = not _formation_row.visible
	_layout_panels()


## Squad chip: tap selects; tapping the already-selected squad's chip centers the camera on it.
func tap_squad_chip(squad_name: String) -> void:
	if selected_squad == squad_name and rig != null:
		center_on_selected()
	else:
		select_squad(squad_name)


func _icon_button(parent: Container, kind: IconButton.Kind, id: String, text: String, button_id: String,
		action: Callable) -> IconButton:
	var button := IconButton.new()
	button.kind = kind
	button.id = id
	button.label = text
	button.toggle_mode = true
	button.pressed.connect(action)
	parent.add_child(button)
	_buttons[button_id] = button
	return button


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
	if squad == null:
		_info.text = "No squad selected: tap a squad"
	else:
		# The squad bar shows the squads; this line teaches what the next tap will do.
		var drill: Array = CommandIcons.DRILL_INFO[pending_verb]
		var shape: Array = CommandIcons.FORMATION_INFO.get(squad.formation if squad.formation != "" else Formations.DEFAULT)
		_info.text = "%s · next order: %s in %s. %s" % [squad.squad_name.to_upper(), drill[0], shape[0], drill[1]]
		_formation_about.text = "%s: %s" % [shape[0], shape[2]]
		var formation_button := _buttons["formations"] as IconButton
		if formation_button.id != squad.formation and squad.formation != "":
			formation_button.id = squad.formation
			formation_button.queue_redraw()
		var alive := squad.alive_members(game_match.tanks_by_name()).size()
		for formation in PICKER_FORMATIONS:
			var card := _buttons["formation:" + formation] as IconButton
			if card.count != clampi(alive, 2, Formations.MAX_MEMBERS):
				card.count = clampi(alive, 2, Formations.MAX_MEMBERS)
				card.queue_redraw()
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
			"follow":
				active = rig != null and rig.tracking_mode() == RtsCamera.Track.FOLLOW
		(_buttons[id] as Button).set_pressed_no_signal(active)
