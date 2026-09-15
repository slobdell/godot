class_name Radar
extends Control
## G2: the always-on radar / minimap. Shows what the team knows, and doubles as an input (C1):
##   tap / click     order the selected squad there (the same SquadCommand a tap on the map sends)
##   drag or hold    look: the camera follows the finger across the radar (no order)
## Why tap = order: the lead asked to "click on a location in the radar" to send a squad, and ordering is
## the action that matters most; looking stays one gesture (touch and scrub, the usual minimap idiom),
## and a press that rests is a look too, so a hesitant finger never sends anyone.
## Draws: arena outline and obstacles, the visibility field (lit / remembered / unexplored), friendly
## tanks (commander ringed), enemies in sight, last-known contacts fading out, squad destinations, and
## the camera's footprint. Enemies come ONLY from team intel (fog of war).
##
## Round 3 (desktop, StarCraft-style; set `controls` instead of `map`): left click or drag = look there; right click
## = move the selection there (shift queues); with an order armed (A, M), a left click orders it there.
##
## Behavior and data are gameplay's; the frame and palette are look & feel's: a StyleBox under
## GameTheme.ui["radar_frame"] replaces the placeholder frame, and GameTheme.ui colors tint the blips.

## The radar shows this many meters edge to edge (the arena plus a margin).
const SPAN := Match.ARENA_HALF_SIZE * 2.0 + 12.0
## Side length as a fraction of the viewport height, clamped to [MIN_SIZE, MAX_SIZE] pixels.
const HEIGHT_FRACTION := 0.3
const MIN_SIZE := 150.0
const MAX_SIZE := 300.0
const MARGIN := 12.0
## A press that moves less than this (pixels) is a tap (order), not a drag (look).
const DRAG_PX := 10.0

var game_match: Match
var map: TacticalMap
## Round 3: the desktop controls (takes precedence over `map`).
var controls: RtsControls
var visibility: VisibilityField
var team := Match.Team.GREEN
## Obstacles as world-space rectangles: [PackedVector2Array of 4 xz corners].
var obstacles: Array[PackedVector2Array] = []

var _press: Variant = null
var _press_moved := false
var _drag_now := Vector2.ZERO
var _press_held := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_layout()
	get_viewport().size_changed.connect(_layout)


func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var side := clampf(viewport_size.y * HEIGHT_FRACTION, MIN_SIZE, MAX_SIZE)
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -side - MARGIN
	offset_right = -MARGIN
	offset_top = -side - MARGIN
	offset_bottom = -MARGIN


## Collect obstacle footprints from an arena's collision boxes (the Obstacles node).
func read_arena(arena: Node) -> void:
	obstacles.clear()
	var root := arena.get_node_or_null("Obstacles")
	if root == null:
		return
	for shape_node in root.find_children("*", "CollisionShape3D", true, false):
		var box := (shape_node as CollisionShape3D).shape as BoxShape3D
		if box == null:
			continue
		var xf := (shape_node as CollisionShape3D).global_transform
		var half := box.size / 2.0
		var corners := PackedVector2Array()
		for corner in [Vector3(-half.x, 0, -half.z), Vector3(half.x, 0, -half.z), Vector3(half.x, 0, half.z), Vector3(-half.x, 0, half.z)]:
			var world: Vector3 = xf * corner
			corners.append(Vector2(world.x, world.z))
		obstacles.append(corners)


# ---- Mapping ----------------------------------------------------------------------------

## Team-forward is up: the enemy base is at the top for either team.
func _flip() -> bool:
	return Match.team_frame(team)["forward"] != Vector3.FORWARD


func world_to_radar(world: Vector3) -> Vector2:
	var p := Vector2(world.x, world.z)
	if _flip():
		p = -p
	return (p / SPAN + Vector2(0.5, 0.5)) * size


func radar_to_world(local: Vector2) -> Vector3:
	var p := (local / size - Vector2(0.5, 0.5)) * SPAN
	if _flip():
		p = -p
	return Vector3(p.x, 0.0, p.y)


## What the radar shows, as data (drawn by _draw, checked by tests):
## [{"kind": "friendly"|"commander"|"enemy"|"contact"|"destination", "position": Vector3, "fade": float}]
func blips() -> Array:
	var result: Array = []
	var by_name := game_match.tanks_by_name()
	if controls != null:
		for tank in game_match.sorted_team_tanks(team):
			if tank.is_alive():
				result.append({"kind": "commander" if controls.selection.units.has(String(tank.name)) else "friendly",
						"position": tank.global_position, "fade": 1.0})
		var destinations := {}
		for unit_name in controls.selection.units:
			var goal: Variant = controls.orders.goal_position(unit_name) if controls.orders != null else null
			if goal != null:
				destinations[Vector2i(roundi(goal.x / 4.0), roundi(goal.z / 4.0))] = goal
		for key in destinations:
			result.append({"kind": "destination", "position": destinations[key], "fade": 1.0})
	var legacy_squads: Array = [] if controls != null else game_match.team_squads(team)
	for squad: Squad in legacy_squads:
		for member in squad.alive_members(by_name):
			result.append({"kind": "commander" if member == squad.commander else "friendly",
					"position": (by_name[member] as Tank).global_position, "fade": 1.0})
		if squad.destination != null and squad.is_commanded():
			result.append({"kind": "destination", "position": squad.destination, "fade": 1.0})
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	for contact_name in names:
		var contact: Dictionary = intel[contact_name]
		var age := float(game_match.tick - int(contact["seen_tick"])) / Match.CONTACT_MEMORY_TICKS
		result.append({"kind": "enemy" if contact["visible"] else "contact", "position": contact["position"],
				"fade": 1.0 if contact["visible"] else clampf(1.0 - age, 0.15, 0.8)})
	return result


# ---- Input -------------------------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if controls != null and _desktop_input(event):
		accept_event()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_press = button.position
			_press_moved = false
			_press_held = 0.0
			_drag_now = button.position
		elif _press != null:
			if _press_moved:
				look(button.position)
			else:
				tap(button.position)
			_press = null
		accept_event()
	elif event is InputEventMouseMotion and _press != null:
		_drag_now = (event as InputEventMouseMotion).position
		if _drag_now.distance_to(_press) > DRAG_PX:
			_press_moved = true
		if _press_moved:
			look(_drag_now)
		accept_event()


## Round 3 desktop grammar. Returns true when the event was handled.
func _desktop_input(event: InputEvent) -> bool:
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_RIGHT:
		if button.pressed:
			controls.world_order(radar_to_world(button.position), button.shift_pressed)
		return true
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and button.pressed and controls.mode != "":
		controls.armed_world_order(radar_to_world(button.position), button.shift_pressed)
		return true
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		_press = button.position if button.pressed else null
		if button.pressed:
			look(button.position)
		return true
	if event is InputEventMouseMotion and _press != null:
		_drag_now = (event as InputEventMouseMotion).position
		look(_drag_now)
		return true
	return false


func _process(delta: float) -> void:
	if controls != null:
		queue_redraw()
		return
	if _press != null and not _press_moved:
		_press_held += delta
		if _press_held >= TacticalMap.LONG_PRESS_SECONDS:
			_press_moved = true  # a resting press is a look, not an order
			look(_drag_now)
	queue_redraw()


## A tap: send the selected squad there; with no squad to command, look there instead.
func tap(local: Vector2) -> String:
	if map != null and map.selected() != null:
		var spot := radar_to_world(local)
		return map.order_drag(spot, spot)
	look(local)
	return ""


## Aim the camera at a radar point.
func look(local: Vector2) -> void:
	if controls != null and controls.rig != null:
		controls.rig.focus_on(radar_to_world(local))
	elif map != null and map.rig != null:
		map.rig.focus_on(radar_to_world(local))


## An order with a facing, from radar points (kept for scripts and the agent's point of view).
func drag_order(from_local: Vector2, to_local: Vector2) -> String:
	if map == null:
		return "no map"
	return map.order_drag(radar_to_world(from_local), radar_to_world(to_local))


# ---- Drawing -----------------------------------------------------------------------------

func _draw() -> void:
	if game_match == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var frame: Variant = GameTheme.ui.get("radar_frame")
	if frame is StyleBox:
		draw_style_box(frame, rect)
	else:
		draw_rect(rect, Color(0.02, 0.03, 0.05, 0.82))
	# The visibility field: a texture that already encodes never / seen / visible.
	if visibility != null and visibility.texture != null:
		var corner_a := world_to_radar(Vector3(VisibilityField.ORIGIN.x, 0, VisibilityField.ORIGIN.y))
		var extent := visibility.cells * VisibilityField.CELL_SIZE
		var corner_b := world_to_radar(Vector3(VisibilityField.ORIGIN.x + extent, 0, VisibilityField.ORIGIN.y + extent))
		var field_rect := Rect2(corner_a, corner_b - corner_a).abs()
		# Flipped teams see the texture rotated 180 degrees: draw it with a negative size.
		if _flip():
			field_rect = Rect2(corner_a, corner_b - corner_a)
		draw_texture_rect(visibility.texture, field_rect, false, Color(0.55, 0.85, 0.7, 0.55))
	var outline := PackedVector2Array()
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		outline.append(world_to_radar(corner * Match.ARENA_HALF_SIZE))
	draw_polyline(outline, Color(0.6, 0.8, 0.9, 0.9), 1.5)
	for corners in obstacles:
		var shape := PackedVector2Array()
		for c in corners:
			shape.append(world_to_radar(Vector3(c.x, 0, c.y)))
		draw_colored_polygon(shape, Color(0.75, 0.8, 0.85, 0.85))
	if game_match.control_point:
		var owner_color: Color = Color(1, 1, 1, 0.7) if game_match.control_owner < 0 else (GameTheme.ui["friendly"] if game_match.control_owner == team else GameTheme.ui["enemy"])
		var zone_radius := Match.CONTROL_RADIUS / SPAN * size.x
		draw_arc(world_to_radar(Match.CONTROL_CENTER), zone_radius, 0.0, TAU, 32, owner_color, 2.0)
	_draw_camera_footprint()
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var commander: Color = GameTheme.ui["commander"]
	var dot := maxf(2.5, size.x / 70.0)
	for blip in blips():
		var at := world_to_radar(blip["position"])
		match blip["kind"]:
			"friendly":
				draw_circle(at, dot, friendly)
			"commander":
				draw_circle(at, dot, friendly)
				draw_arc(at, dot + 2.5, 0.0, TAU, 16, commander, 1.5)
			"enemy":
				# Diamonds for enemies, circles for us: readable without color (accessibility).
				var r := dot * 1.3
				draw_colored_polygon(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0)]), enemy)
			"contact":
				var r := dot * 1.3
				draw_polyline(PackedVector2Array([at + Vector2(0, -r), at + Vector2(r, 0), at + Vector2(0, r), at + Vector2(-r, 0),
						at + Vector2(0, -r)]), Color(enemy, blip["fade"]), 1.5)
			"destination":
				draw_line(at + Vector2(-dot, -dot), at + Vector2(dot, dot), commander, 1.5)
				draw_line(at + Vector2(-dot, dot), at + Vector2(dot, -dot), commander, 1.5)
	if _press != null and _press_moved:
		draw_arc(_drag_now, dot * 3.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 1.5)  # looking here


## The ground area the camera currently shows, as a trapezoid.
func _draw_camera_footprint() -> void:
	var view_camera: Camera3D = controls.camera if controls != null else (map.camera if map != null else null)
	if view_camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var points := PackedVector2Array()
	for screen in [Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]:
		var ground: Variant = Plane(Vector3.UP, 0.0).intersects_ray(view_camera.project_ray_origin(screen), view_camera.project_ray_normal(screen))
		if ground == null:
			# A corner above the horizon: clamp it to the far edge of what the radar can show.
			var origin := view_camera.project_ray_origin(screen)
			var direction := view_camera.project_ray_normal(screen)
			ground = origin + Vector3(direction.x, 0.0, direction.z).normalized() * SPAN
		points.append(world_to_radar(ground))
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, 0.5), 1.0)
