class_name Radar
extends Control
## G2: the always-on radar / minimap. Shows what the team knows, and doubles as an input:
##   tap / click     aim the camera there
##   drag            order the selected squad there (press = destination, drag direction = facing),
##                   the same SquadCommand a drag on the map sends
## Draws: arena outline and obstacles, the visibility field (lit / remembered / unexplored), friendly
## tanks (commander ringed), enemies in sight, last-known contacts fading out, squad destinations, and
## the camera's footprint. Enemies come ONLY from team intel (fog of war).
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
## A press that moves less than this (pixels) is a tap (aim the camera), not a drag (order).
const DRAG_PX := 10.0

var game_match: Match
var map: TacticalMap
var visibility: VisibilityField
var team := Match.Team.GREEN
## Obstacles as world-space rectangles: [PackedVector2Array of 4 xz corners].
var obstacles: Array[PackedVector2Array] = []

var _press: Variant = null
var _press_moved := false
var _drag_now := Vector2.ZERO


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


func _process(_delta: float) -> void:
	queue_redraw()


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
	for squad in game_match.team_squads(team):
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
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var button := event as InputEventMouseButton
		if button.pressed:
			_press = button.position
			_press_moved = false
			_drag_now = button.position
		elif _press != null:
			if _press_moved:
				drag_order(_press, button.position)
			else:
				tap(button.position)
			_press = null
		accept_event()
	elif event is InputEventMouseMotion and _press != null:
		_drag_now = (event as InputEventMouseMotion).position
		if _drag_now.distance_to(_press) > DRAG_PX:
			_press_moved = true
		accept_event()


## A tap: aim the camera at that spot.
func tap(local: Vector2) -> void:
	if map != null and map.rig != null:
		map.rig.focus_on(radar_to_world(local))


## A drag: order the selected squad to the press point, facing along the drag.
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
				draw_circle(at, dot, enemy)
			"contact":
				draw_arc(at, dot, 0.0, TAU, 12, Color(enemy, blip["fade"]), 1.5)
			"destination":
				draw_line(at + Vector2(-dot, -dot), at + Vector2(dot, dot), commander, 1.5)
				draw_line(at + Vector2(-dot, dot), at + Vector2(dot, -dot), commander, 1.5)
	if _press != null and _press_moved:
		draw_line(_press, _drag_now, commander, 2.0)


## The ground area the camera currently shows, as a trapezoid.
func _draw_camera_footprint() -> void:
	if map == null or map.camera == null:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var points := PackedVector2Array()
	for screen in [Vector2.ZERO, Vector2(viewport_size.x, 0), viewport_size, Vector2(0, viewport_size.y)]:
		var ground: Variant = map.screen_to_world(screen)
		if ground == null:
			# A corner above the horizon: clamp it to the far edge of what the radar can show.
			var origin := map.camera.project_ray_origin(screen)
			var direction := map.camera.project_ray_normal(screen)
			ground = origin + Vector3(direction.x, 0.0, direction.z).normalized() * SPAN
		points.append(world_to_radar(ground))
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, 0.5), 1.0)
