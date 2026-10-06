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

## Blip textures are drawn at this size and scaled down (they're 5-12 px on screen).
const BLIP_TEXTURE_PX := 32
static var _blip_textures := {}

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

## Round 16 (hud H3): the parts that do not move - the frame, the visibility field's texture (its pixels update in
## place, so the drawn rect never needs redrawing for them), the arena outline and every obstacle - are drawn by a child
## behind the radar's own drawing (`show_behind_parent`: the same order as one _draw), and only when they change.
var _backdrop: Control
var _backdrop_drawn: Array = []

var _press: Variant = null
var _press_moved := false
var _drag_now := Vector2.ZERO
var _press_held := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.show_behind_parent = true
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.draw.connect(_draw_backdrop)
	add_child(_backdrop, false, Node.INTERNAL_MODE_FRONT)
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
	# Match.team_frame(team)["forward"] != FORWARD, without building its Dictionary (this runs per drawn point).
	return (team == Match.Team.GREEN) == Match.swap_bases


## Round 7: the arena's real outline on the radar - its perimeter polygon when the layout has one (the camera's
## RtsCamera.perimeter_poly, read from Arena.perimeter()), else the ACTIVE layout's square bound. It used to be a box at
## Match.ARENA_HALF_SIZE, which becomes the largest bound any arena may have, not this one's: a 140 box round a 120 map,
## and a square round a hexagon.
func outline_points() -> PackedVector2Array:
	var outline := PackedVector2Array()
	if RtsCamera.perimeter_poly.size() >= 3:
		for point in RtsCamera.perimeter_poly:
			outline.append(world_to_radar(Vector3(point.x, 0, point.y)))
		outline.append(outline[0])
		return outline
	var half := float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE))
	for corner in [Vector3(-1, 0, -1), Vector3(1, 0, -1), Vector3(1, 0, 1), Vector3(-1, 0, 1), Vector3(-1, 0, -1)]:
		outline.append(world_to_radar(corner * half))
	return outline


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
## [{"kind": "friendly"|"selected"|"commander"|"enemy"|"contact"|"destination", "position": Vector3, "fade": float}]
## X2: friendly blips also carry "facing" (the hull's heading) and "element" (their control group, 0 for none), so
## the radar reads as a map of your force and not a scatter of dots.
func blips() -> Array:
	var result: Array = []
	if controls != null:
		# Round 16 (hud H4): each unit's first group from one pass over the groups (groups_of per unit walked them all).
		var first_group := {}
		for number in controls.groups.numbers():
			for member in controls.groups.members(number):
				if not first_group.has(member):
					first_group[member] = number
		for tank in game_match.sorted_team_tanks(team):
			if tank.is_alive():
				var tank_name := String(tank.name)
				result.append({"kind": "selected" if controls.selection.units.has(tank_name) else "friendly",
						"position": tank.global_position, "fade": 1.0, "facing": -tank.global_basis.z,
						"length": _hull_length(tank), "element": int(first_group.get(tank_name, 0))})
		var destinations := {}
		for unit_name in controls.selection.units:
			# Round 19 (orders, O4): where each vehicle will stand, not the station a travelling squad moves it along.
			var goal: Variant = controls.arrival_slot(unit_name) if controls.orders != null else null
			if goal != null:
				destinations[Vector2i(roundi(goal.x / 4.0), roundi(goal.z / 4.0))] = goal
		for key in destinations:
			result.append({"kind": "destination", "position": destinations[key], "fade": 1.0})
	var legacy_squads: Array = [] if controls != null else game_match.team_squads(team)
	var by_name := game_match.tanks_by_name() if controls == null else {}
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
		var seen := game_match.tanks.get_node_or_null(NodePath(contact_name)) as Tank
		if seen != null and seen.is_queued_for_deletion():
			seen = null  # tanks_by_name()'s rule, without building it
		result.append({"kind": "enemy" if contact["visible"] else "contact", "position": contact["position"],
				"fade": 1.0 if contact["visible"] else clampf(1.0 - age, 0.15, 0.8),
				"length": _hull_length(seen) if seen != null else 0.0})
	return result


## Radar.hull_length, remembered per unit type (Units.stat formats a key per call).
var _hull_lengths := {}

func _hull_length(tank: Tank) -> float:
	var known: Variant = _hull_lengths.get(tank.unit_id)
	if known == null:
		known = Radar.hull_length(tank)
		_hull_lengths[tank.unit_id] = known
	return known


## X2: one label per living element, at its middle: [{"text", "position": Vector3, "color": Color}]. The radar is
## now the main way to read the map, so elements are named on it instead of being anonymous clusters.
func element_labels() -> Array:
	var result: Array = []
	if controls == null or controls.awareness == null:
		return result
	for element: Dictionary in controls.awareness.elements():
		if int(element["alive"]) == 0:
			continue
		var key: String = EdgeMarkers.STATE_COLORS.get(element["state"], "friendly")
		result.append({"text": "%d" % int(element["number"]), "position": element["position"],
				"color": GameTheme.ui[key]})
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
	var started := HudClock.begin()
	_process_timed(delta)
	HudClock.end(&"radar.process", started)


func _process_timed(delta: float) -> void:
	_check_backdrop()
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

## Round 9 (CP2): A BLIP READS THE HULL IT STANDS FOR.
##
## Every blip used to be the same dot. That was defensible when the roster ran 2.8-5.0 m; after the resize it runs
## **2.93 m (the rat rod) to 14.0 m (the War Rig)**, and a radar where a rig and a rat rod are the same mark throws
## away the one thing the resize bought - you can see what a vehicle IS. The length comes from `hull_size` through
## the same seam everything else reads it through (`Units.stat`); there is deliberately **no second table of size
## classes** to drift away from the roster.
##
## Square-rooted, not linear: a radar is not a scale drawing (at radar scale every hull is sub-pixel), so the mark
## has to say "longer than that one" while staying a readable dot. sqrt over this roster gives about 2.1x between
## the extremes - rat rod 0.72, tank 1.20, Sonic Emitter 1.07, rig 1.53 - where linear would have given 4.8x and put
## a rig blip over its neighbours.
const BLIP_REFERENCE_M := 6.0
const BLIP_SCALE_MIN := 0.72
const BLIP_SCALE_MAX := 1.6


## The hull length a blip should read, or 0.0 for a vehicle we have no handle on (a remembered contact).
static func hull_length(tank: Tank) -> float:
	if tank == null:
		return 0.0
	var hull: Array = Units.stat(tank.unit_id, "hull_size")
	return float(hull[2]) if hull.size() == 3 else 0.0


## How much bigger than the standard dot this vehicle's mark is. 0 length (unknown) is the standard dot, so nothing
## a remembered contact does not know about it is invented.
static func blip_scale(length_m: float) -> float:
	if length_m <= 0.0:
		return 1.0
	return clampf(sqrt(length_m / BLIP_REFERENCE_M), BLIP_SCALE_MIN, BLIP_SCALE_MAX)


## A white blip shape, drawn once and tinted per use: "disc", "ring", "diamond" or "diamond_outline".
static func blip_texture(shape: String) -> Texture2D:
	if not _blip_textures.has(shape):
		var image := Image.create(BLIP_TEXTURE_PX, BLIP_TEXTURE_PX, false, Image.FORMAT_RGBA8)
		var half := BLIP_TEXTURE_PX / 2.0
		for y in BLIP_TEXTURE_PX:
			for x in BLIP_TEXTURE_PX:
				var offset := (Vector2(x, y) + Vector2(0.5, 0.5) - Vector2(half, half)) / half
				var reach := offset.length() if shape in ["disc", "ring"] else absf(offset.x) + absf(offset.y)
				var inside := 1.0 - clampf((reach - 1.0) * half + 0.5, 0.0, 1.0)
				if shape in ["ring", "diamond_outline"]:
					var inner := 1.0 - 1.5 / half * (2.0 if shape == "ring" else 1.4)
					inside = minf(inside, clampf((reach - inner) * half + 0.5, 0.0, 1.0))
				image.set_pixel(x, y, Color(1, 1, 1, inside))
		_blip_textures[shape] = ImageTexture.create_from_image(image)
	return _blip_textures[shape]


## The backdrop's inputs: when none changed, its last drawing is still exactly right.
func _check_backdrop() -> void:
	if _backdrop == null:
		return
	var texture: Texture2D = visibility.texture if visibility != null else null
	var drawn := [game_match != null, size, _flip(), obstacles.hash(), texture, visibility.origin if visibility != null else Vector2.ZERO,
			visibility.cells if visibility != null else 0, GameTheme.ui.get("radar_frame"), outline_points()]
	if drawn != _backdrop_drawn:
		HudClock.changed(&"radar.backdrop")
		_backdrop_drawn = drawn
		_backdrop.queue_redraw()


func _draw_backdrop() -> void:
	var started := HudClock.begin()
	if game_match == null:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var frame: Variant = GameTheme.ui.get("radar_frame")
	if frame is StyleBox:
		_backdrop.draw_style_box(frame, rect)
	else:
		_backdrop.draw_rect(rect, Color(0.02, 0.03, 0.05, 0.82))
	# The visibility field: a texture that already encodes never / seen / visible.
	if visibility != null and visibility.texture != null:
		# X3 (combat, round 7): `origin` is per-instance now, because the field sizes to the ACTIVE layout rather
		# than to Match.ARENA_HALF_SIZE, which became a bound and stopped being a size.
		var corner_a := world_to_radar(Vector3(visibility.origin.x, 0, visibility.origin.y))
		var extent := visibility.cells * VisibilityField.CELL_SIZE
		var corner_b := world_to_radar(Vector3(visibility.origin.x + extent, 0, visibility.origin.y + extent))
		var field_rect := Rect2(corner_a, corner_b - corner_a).abs()
		# Flipped teams see the texture rotated 180 degrees: draw it with a negative size.
		if _flip():
			field_rect = Rect2(corner_a, corner_b - corner_a)
		_backdrop.draw_texture_rect(visibility.texture, field_rect, false, Color(0.55, 0.85, 0.7, 0.55))
	# X3 (combat, round 7) + 4f7371ef (control): the wall's real polygon, not a square off the constant. Two bugs in
	# one line before: the constant is now the BOUND (140), so this drew an outline 20 m outside the wall of every
	# shipped map, and it assumed four corners, so a hexagon would have been drawn as the square it is not.
	# Resolved to control's outline_points() rather than combat's inline Arena.perimeter() loop: the two agree on the
	# polygon case, and outline_points() ALSO falls back to the active layout's own bound when a layout has no
	# perimeter, where the inline version draws nothing at all. It is also the seam test_radar calls directly.
	_backdrop.draw_polyline(outline_points(), Color(0.6, 0.8, 0.9, 0.9), 1.5)
	var prop_color := Color(0.75, 0.8, 0.85, 0.85)
	var prop_colors := PackedColorArray([prop_color, prop_color, prop_color, prop_color])
	for corners in obstacles:
		var shape := PackedVector2Array()
		for c in corners:
			shape.append(world_to_radar(Vector3(c.x, 0, c.y)))
		# A four-cornered footprint (almost every prop) is a primitive, which batches; anything else is a polygon.
		if shape.size() == 4:
			_backdrop.draw_primitive(shape, prop_colors, PackedVector2Array())
		else:
			_backdrop.draw_colored_polygon(shape, prop_color)
	HudClock.end(&"radar.backdrop.draw", started)


## What _draw draws for a list of blips (blips()'s shape): {"by_shape": {shape: [[at, radius, color]]}, "ticks",
## "crosses"}, in blip order within each shape. The touch map draws through this; on the desktop it is the reference
## `_marks()` must match (test_radar).
func _marks_from_blips(list: Array) -> Dictionary:
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var commander: Color = GameTheme.ui["commander"]
	var dot := maxf(2.5, size.x / 70.0)
	var ticks := PackedVector2Array()
	var crosses := PackedVector2Array()
	var by_shape := {"disc": [], "ring": [], "diamond": [], "diamond_outline": []}
	for blip in list:
		var at := world_to_radar(blip["position"])
		# The mark is sized to the hull it stands for (blip_scale); an unknown hull is the standard dot.
		var mark_dot := dot * Radar.blip_scale(float(blip.get("length", 0.0)))
		match blip["kind"]:
			"friendly", "selected", "commander":
				by_shape["disc"].append([at, mark_dot, friendly])
				# X2: a tick showing which way the hull points, so you can read a formation's facing at a glance.
				if blip.has("facing"):
					var heading: Vector3 = blip["facing"]
					ticks.append_array([at, world_to_radar(blip["position"] + heading.normalized() * 6.0)])
				if blip["kind"] != "friendly":
					by_shape["ring"].append([at, mark_dot + 3.25, commander])
			"enemy":
				# Diamonds for enemies, circles for us: readable without color (accessibility).
				by_shape["diamond"].append([at, mark_dot * 1.3, enemy])
			"contact":
				by_shape["diamond_outline"].append([at, mark_dot * 1.3 + 0.75, Color(enemy, blip["fade"])])
			"destination":
				crosses.append_array([at + Vector2(-dot, -dot), at + Vector2(dot, dot), at + Vector2(-dot, dot), at + Vector2(dot, -dot)])
	return {"by_shape": by_shape, "ticks": ticks, "crosses": crosses}


## Round 16 (hud H4): the desktop radar's marks in one pass over the units and the intel, without building blips()'s
## Dictionary per blip - the same marks, in the same order, as `_marks_from_blips(blips())`.
func _marks() -> Dictionary:
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var commander: Color = GameTheme.ui["commander"]
	var dot := maxf(2.5, size.x / 70.0)
	var ticks := PackedVector2Array()
	var crosses := PackedVector2Array()
	var discs: Array = []
	var rings: Array = []
	var diamonds: Array = []
	var outlines: Array = []
	var flip := _flip()
	var selected := controls.selection.units
	for tank in game_match.sorted_team_tanks(team):
		if not tank.is_alive():
			continue
		var position := tank.global_position
		var at := _to_radar(position, flip)
		var mark_dot := dot * Radar.blip_scale(_hull_length(tank))
		discs.append([at, mark_dot, friendly])
		var heading: Vector3 = -tank.global_basis.z
		ticks.append_array([at, _to_radar(position + heading.normalized() * 6.0, flip)])
		if selected.has(String(tank.name)):
			rings.append([at, mark_dot + 3.25, commander])
	var destinations := {}
	for unit_name in selected:
		var goal: Variant = controls.arrival_slot(unit_name) if controls.orders != null else null  # round 19: as blips()
		if goal != null:
			destinations[Vector2i(roundi(goal.x / 4.0), roundi(goal.z / 4.0))] = goal
	for key in destinations:
		var at := _to_radar(destinations[key], flip)
		crosses.append_array([at + Vector2(-dot, -dot), at + Vector2(dot, dot), at + Vector2(-dot, dot), at + Vector2(dot, -dot)])
	var intel: Dictionary = game_match.intel[team]
	var names := intel.keys()
	names.sort()
	for contact_name in names:
		var contact: Dictionary = intel[contact_name]
		var seen := game_match.tanks.get_node_or_null(NodePath(contact_name)) as Tank
		if seen != null and seen.is_queued_for_deletion():
			seen = null
		var mark_dot := dot * Radar.blip_scale(_hull_length(seen) if seen != null else 0.0)
		var at := _to_radar(contact["position"], flip)
		if contact["visible"]:
			diamonds.append([at, mark_dot * 1.3, enemy])
		else:
			var age := float(game_match.tick - int(contact["seen_tick"])) / Match.CONTACT_MEMORY_TICKS
			outlines.append([at, mark_dot * 1.3 + 0.75, Color(enemy, clampf(1.0 - age, 0.15, 0.8))])
	return {"by_shape": {"disc": discs, "ring": rings, "diamond": diamonds, "diamond_outline": outlines},
			"ticks": ticks, "crosses": crosses}


## world_to_radar with the flip decided once per pass.
func _to_radar(world: Vector3, flip: bool) -> Vector2:
	var p := Vector2(world.x, world.z)
	if flip:
		p = -p
	return (p / SPAN + Vector2(0.5, 0.5)) * size


func _draw() -> void:
	var started := HudClock.begin()
	_draw_timed()
	HudClock.end(&"radar.draw", started)


func _draw_timed() -> void:
	if game_match == null:
		return
	var _hcs := HudClock.begin()
	if game_match.control_point:
		for ring: Dictionary in Radar.objective_rings(game_match):
			var holder := int(ring["owner"])
			var owner_color: Color = Color(1, 1, 1, 0.7) if holder < 0 else (GameTheme.ui["friendly"] if holder == team else GameTheme.ui["enemy"])
			draw_arc(world_to_radar(ring["position"]), float(ring["radius"]) / SPAN * size.x, 0.0, TAU, 32, owner_color, 2.0)
	HudClock.end(&"radar.static", _hcs)
	_draw_camera_footprint()
	_hcs = HudClock.begin()
	var friendly: Color = GameTheme.ui["friendly"]
	var enemy: Color = GameTheme.ui["enemy"]
	var commander: Color = GameTheme.ui["commander"]
	var dot := maxf(2.5, size.x / 70.0)
	# X4 (CP1: the HUD ≤ 130 draw calls): the Compatibility renderer batches textured rects but gives every polygon,
	# circle and arc a draw call of its own, and 60 vehicles made the radar ~100 of them. Blips are small textures now,
	# drawn one kind at a time so each kind is one batch.
	var _hcd := HudClock.begin()
	var marks := _marks() if controls != null else _marks_from_blips(blips())
	HudClock.end(&"radar.blips_data", _hcd)
	var by_shape: Dictionary = marks["by_shape"]
	var ticks: PackedVector2Array = marks["ticks"]
	var crosses: PackedVector2Array = marks["crosses"]
	for shape: String in ["disc", "diamond", "diamond_outline", "ring"]:
		var texture := Radar.blip_texture(shape)
		for mark: Array in by_shape[shape]:
			var radius: float = mark[1]
			draw_texture_rect(texture, Rect2(mark[0] - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, mark[2])
	if not ticks.is_empty():
		draw_multiline(ticks, Color(friendly, 0.9), 1.5)
	if not crosses.is_empty():
		draw_multiline(crosses, commander, 1.5)
	_hcd = HudClock.begin()
	# Round 16 (hud H7): every label's black outline, then every label - two draw calls instead of two per label - when
	# no two labels' boxes (with their outline) overlap, which is when it draws the same pixels; else label by label.
	var font := CyberStyle.font()
	var text_size := roundi(maxf(9.0, size.x / 16.0))
	var placed: Array = []
	for label: Dictionary in element_labels():
		var at := world_to_radar(label["position"]) + Vector2(dot * 1.6, -dot * 1.6)
		var text := String(label["text"])
		var box := Rect2(at.x, at.y - font.get_ascent(text_size), font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
				text_size).x, font.get_height(text_size)).grow(3.0)
		placed.append([at, text, Color(label["color"]), box])
	var apart := true
	for i in placed.size():
		for j in range(i + 1, placed.size()):
			if (placed[i][3] as Rect2).intersects(placed[j][3]):
				apart = false
	if apart:
		for label: Array in placed:
			draw_string_outline(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 3, Color.BLACK)
		for label: Array in placed:
			draw_string(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, label[2])
	else:
		for label: Array in placed:
			draw_string_outline(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, 3, Color.BLACK)
			draw_string(font, label[0], label[1], HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, label[2])
	HudClock.end(&"radar.labels", _hcd)
	if _press != null and _press_moved:
		draw_arc(_drag_now, dot * 3.0, 0.0, TAU, 20, Color(1, 1, 1, 0.7), 1.5)  # looking here
	HudClock.end(&"radar.blips", _hcs)


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
		# Clamped to the radar's frame: a far corner must not draw outside it.
		points.append(world_to_radar(ground).clamp(Vector2.ZERO, size))
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, 0.5), 1.0)


## Round 10 (terrain's report, relayed): the zones the match actually SCORES, one ring each - `Match.objectives`, which
## is the layout's objective pair on yard, pit and terminus, and the single central zone only when a layout lists none.
## Both maps drew Match.CONTROL_CENTER whatever the layout said: a ring at a centre nobody fights over, and none at the
## real objectives (lesson 183: the UI saying something the game does not do). [{position, radius, owner, progress}].
static func objective_rings(game_match: Match) -> Array:
	var rings: Array = []
	if game_match == null:
		return rings
	for objective: Dictionary in game_match.objectives:
		rings.append({"position": objective["position"], "radius": float(objective["radius"]),
				"owner": int(objective["owner"]), "progress": float(objective["progress"])})
	if rings.is_empty():
		rings.append({"position": Match.CONTROL_CENTER, "radius": Match.CONTROL_RADIUS, "owner": game_match.control_owner,
				"progress": game_match.control_progress})
	return rings
