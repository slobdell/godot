class_name OrderFeedback
extends Node3D
## Order and selection feedback (feel X5). Control's K1 Orders decide WHEN (an order was issued, a waypoint queued, the
## selection changed); this decides how it looks and sounds: a ground marker per command (one per group, not per unit),
## a dotted waypoint trail under selected units with queued orders, a pulse under each newly selected unit, and short
## acknowledgement sounds. Only the local player's team shows. Everything is two MultiMeshes (markers, trail dots).
##
## It reads K1 by duck typing (`current(unit)`, `queue(unit)`, `order_changed`, `queue_changed`; the orders object is
## `Match.orders` or the match's "orders" meta) and the selection from the controls node (`selection.units`, `team`),
## so it works before and after control's CP1 merges.

const SHADER := preload("res://game/theme/fx/shaders/order_marker.gdshader")
const KINDS := {"move": 0, "attack": 1, "attack_move": 2, "follow": 3, "hold": 4, "stop": 5, "waypoint": 6, "select": 7,
		"trail": 8}
## Seconds each marker shows, and its size (m).
const SECONDS := {"move": 0.9, "attack": 1.0, "attack_move": 1.0, "follow": 0.9, "hold": 1.0, "stop": 0.7, "waypoint": 0.8,
		"select": 0.45}
const SIZES := {"move": 8.0, "attack": 10.0, "attack_move": 9.0, "follow": 9.0, "hold": 8.0, "stop": 6.0, "waypoint": 4.5,
		"select": 8.0}
const SOUNDS := {"move": "ui_ack_move", "attack_move": "ui_ack_attack", "attack": "ui_ack_attack", "follow": "ui_ack_move",
		"hold": "ui_ack_move", "stop": "ui_ack_move", "waypoint": "ui_ack_move"}
const MARKERS := 48
const MAX_TRAIL_DOTS := 192
const TRAIL_SPACING := 2.5
const WORLD_AABB := AABB(Vector3(-200, -20, -200), Vector3(400, 80, 400))
const SEARCH_EVERY := 0.5

## Markers started since load, and what the last one was (tests and the showcase).
var markers_started := 0
var last_marker_kind := ""
var last_marker_position := Vector3.ZERO
## Sounds the last update played.
var last_acks := PackedStringArray()

var _orders: Object
var _match: Node
var _controls: Node
var _explicit := false
var _search_left := 0.0
var _changed := {}
var _queued := {}
var _seen_ids := {}
var _seen_order: Array[int] = []
var _selected := {}
var _markers := MultiMeshInstance3D.new()
var _trail := MultiMeshInstance3D.new()
var _material := ShaderMaterial.new()
var _next := 0
## Markers that follow a unit (attack and follow targets, selection pulses): [{index, node}]
var _anchors: Array[Dictionary] = []
var _trail_count := 0


func _init() -> void:
	name = "OrderFeedback"
	process_mode = Node.PROCESS_MODE_ALWAYS
	_material.shader = SHADER
	for pair in [[_markers, MARKERS, "Markers"], [_trail, MAX_TRAIL_DOTS, "Trail"]]:
		var instance: MultiMeshInstance3D = pair[0]
		var quad := QuadMesh.new()
		quad.size = Vector2.ONE
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, quad.get_mesh_arrays())
		mesh.surface_set_material(0, _material)
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		multimesh.instance_count = pair[1]
		for i in multimesh.instance_count:
			multimesh.set_instance_custom_data(i, Color(-1000.0, 0.001, 0.0, 0.0))
		instance.multimesh = multimesh
		instance.name = pair[2]
		instance.custom_aabb = WORLD_AABB
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(instance)
	_trail.multimesh.visible_instance_count = 0


## Follow `orders` (K1) for `game_match`, with `controls` giving the player's team and selection. Tests and the showcase
## call it; in a game the pieces are found automatically.
func attach(orders: Object, game_match: Node, controls: Node) -> void:
	_explicit = true
	_bind_orders(orders)
	_match = game_match
	_controls = controls


func trail_dots() -> int:
	return _trail_count


func update(now: float) -> void:
	last_acks = PackedStringArray()
	_material.set_shader_parameter("now", now)
	if not _explicit:
		_discover(get_process_delta_time())
	if _orders == null or not is_instance_valid(_match):
		_trail.multimesh.visible_instance_count = 0
		_trail_count = 0
		return
	_show_new_orders(now)
	_show_selection(now)
	_follow_anchors()
	_draw_trail(now)


func _show_new_orders(now: float) -> void:
	var sounded := {}
	for unit_name: String in _changed.keys():
		var order: Dictionary = _orders.call("current", unit_name)
		_note_order(order, unit_name, false, now, sounded)
	for unit_name: String in _queued.keys():
		for order: Dictionary in _orders.call("queue", unit_name):
			_note_order(order, unit_name, true, now, sounded)
	_changed.clear()
	_queued.clear()
	for sound: String in sounded:
		_play(sound)


func _note_order(order: Dictionary, unit_name: String, queued: bool, now: float, sounded: Dictionary) -> void:
	if order.is_empty() or not _is_ours(unit_name):
		return
	# Only the player's own orders are confirmed (K1's `source`). A marker and a cue answer *his* click; an element's
	# leader re-slotting its members dozens of times a second is not something he asked for, and drawing it cost the
	# frame rate and beeped continuously (the lead, round 5: "these blue dots ... they just keep repeating ... beeping").
	if String(order.get("source", "")) != "player":
		return
	var id := int(order.get("id", -1))
	if _seen_ids.has(id):
		return
	_seen_ids[id] = true
	_seen_order.append(id)
	while _seen_order.size() > 256:
		_seen_ids.erase(_seen_order.pop_front())
	var verb := String(order.get("verb", "move"))
	var kind := "waypoint" if queued else verb
	if not KINDS.has(kind):
		return
	var anchor: Node3D = null
	var at: Variant = null
	if order.has("to"):
		at = Vector3(float(order["to"][0]), 0.0, float(order["to"][1]))
	elif order.has("target"):
		anchor = _unit(String(order["target"]))
		if anchor != null:
			at = Vector3(FxWorld.visual_transform(anchor).origin.x, 0.0, FxWorld.visual_transform(anchor).origin.z)
	else:
		at = _middle(order.get("units", [unit_name]))
	if at == null:
		return
	var index := _start(kind, at, _color(verb), now)
	if anchor != null:
		_anchors.append({"index": index, "node": anchor})
	if SOUNDS.has(kind):
		sounded[SOUNDS[kind]] = true


func _show_selection(now: float) -> void:
	var current := {}
	for unit_name: String in _selection():
		current[unit_name] = true
		if not _selected.has(unit_name):
			var unit := _unit(unit_name)
			if unit != null:
				var index := _start("select", Vector3(FxWorld.visual_transform(unit).origin.x, 0.0, FxWorld.visual_transform(unit).origin.z), _color("select"), now)
				_anchors.append({"index": index, "node": unit})
	var added := current.keys().any(func(unit_name: String) -> bool: return not _selected.has(unit_name))
	_selected = current
	if added:
		_play("ui_select")


func _follow_anchors() -> void:
	var multimesh := _markers.multimesh
	for i in range(_anchors.size() - 1, -1, -1):
		var anchor: Dictionary = _anchors[i]
		var node := anchor["node"] as Node3D
		var index := int(anchor["index"])
		var data := multimesh.get_instance_custom_data(index)
		# Custom data is (start, duration, size, kind) packed in a Color.
		if not is_instance_valid(node) or data.g <= 0.01 or float(_material.get_shader_parameter("now")) > data.r + data.g:
			_anchors.remove_at(i)
			continue
		multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, Vector3(FxWorld.visual_transform(node).origin.x, 0.0, FxWorld.visual_transform(node).origin.z)))


## Selected units with queued orders: dots from the unit through its current destination and every queued one.
func _draw_trail(now: float) -> void:
	var multimesh := _trail.multimesh
	var n := 0
	for unit_name: String in _selection():
		var waiting: Array = _orders.call("queue", unit_name)
		var unit := _unit(unit_name)
		if waiting.is_empty() or unit == null:
			continue
		var points: Array[Vector3] = [Vector3(FxWorld.visual_transform(unit).origin.x, 0.0, FxWorld.visual_transform(unit).origin.z)]
		for order: Dictionary in [_orders.call("current", unit_name)] + waiting:
			var stop: Variant = order.get("goal", order.get("to"))
			if stop is Array:
				points.append(Vector3(float(stop[0]), 0.0, float(stop[1])))
		var along := 0.0
		for k in range(1, points.size()):
			var from := points[k - 1]
			var to := points[k]
			var length := from.distance_to(to)
			var d := fmod(TRAIL_SPACING - fmod(along, TRAIL_SPACING), TRAIL_SPACING)
			while d < length and n < MAX_TRAIL_DOTS:
				var spot := from.lerp(to, d / length)
				multimesh.set_instance_transform(n, Transform3D(Basis.IDENTITY, spot))
				var color := _color("trail")
				color.a = (along + d) / TRAIL_SPACING
				multimesh.set_instance_color(n, color)
				multimesh.set_instance_custom_data(n, Color(now - 1.0, 1000.0, 0.7, float(KINDS["trail"])))
				n += 1
				d += TRAIL_SPACING
			along += length
	multimesh.visible_instance_count = n
	_trail_count = n


func _start(kind: String, at: Vector3, color: Color, now: float) -> int:
	var index := _next
	var multimesh := _markers.multimesh
	multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, at))
	multimesh.set_instance_color(index, color)
	multimesh.set_instance_custom_data(index, Color(now, float(SECONDS[kind]), float(SIZES[kind]), float(KINDS[kind])))
	for i in range(_anchors.size() - 1, -1, -1):
		if int(_anchors[i]["index"]) == index:
			_anchors.remove_at(i)
	_next = (_next + 1) % MARKERS
	markers_started += 1
	last_marker_kind = kind
	last_marker_position = at
	return index


func _play(sound: String) -> void:
	var fx := get_parent() as FxWorld
	if fx != null:
		fx.sfx.play_ui(sound)
	last_acks.append(sound)


## Moves in the friendly color, attacks in the enemy color, attack-moves in the commander gold (control's HUD colors).
static func _color(verb: String) -> Color:
	match verb:
		"attack":
			return GameTheme.ui.get("enemy", Color(0.95, 0.35, 0.3))
		"attack_move", "hold":
			return GameTheme.ui.get("commander", Color(1.0, 0.85, 0.25))
		"stop":
			return Color(0.9, 0.9, 0.95)
		"trail":
			return Color(GameTheme.ui.get("friendly", Color(0.45, 0.85, 0.4)), 1.0) * 0.6
	return GameTheme.ui.get("friendly", Color(0.45, 0.85, 0.4))


func _bind_orders(orders: Object) -> void:
	if _orders == orders:
		return
	if _orders != null and is_instance_valid(_orders):
		for signal_name in ["order_changed", "queue_changed"]:
			var handler := _on_order_changed if signal_name == "order_changed" else _on_queue_changed
			if _orders.is_connected(signal_name, handler):
				_orders.disconnect(signal_name, handler)
	_orders = orders
	if orders != null:
		orders.connect("order_changed", _on_order_changed)
		if orders.has_signal("queue_changed"):
			orders.connect("queue_changed", _on_queue_changed)


func _on_order_changed(unit_name: String) -> void:
	_changed[unit_name] = true


func _on_queue_changed(unit_name: String) -> void:
	_queued[unit_name] = true


## Games: the match comes from FxWorld's link, its Orders from `Match.orders` or the "orders" meta, the controls from the
## scene's "TacticalMap" node.
func _discover(delta: float) -> void:
	_search_left -= delta
	if _search_left > 0.0 and _orders != null:
		return
	_search_left = SEARCH_EVERY
	var fx := get_parent() as FxWorld
	var game_match := fx.link.attached_match() if fx != null else null
	if game_match == null:
		_match = null
		_bind_orders(null)
		return
	_match = game_match
	var orders: Variant = game_match.get("orders")
	if not (orders is Object) and game_match.has_meta("orders"):
		orders = game_match.get_meta("orders")
	_bind_orders(orders as Object if orders is Object and (orders as Object).has_signal("order_changed") else null)
	if not is_instance_valid(_controls) and is_inside_tree() and get_tree().current_scene != null:
		_controls = get_tree().current_scene.find_child("TacticalMap", true, false)


func _selection() -> Array:
	if not is_instance_valid(_controls):
		return []
	var picked: Variant = _controls.get("selection")
	if picked is Object and (picked as Object).get("units") is Array:
		return (picked as Object).get("units")
	return []


func _is_ours(unit_name: String) -> bool:
	var unit := _unit(unit_name)
	if unit == null:
		return false
	var team: Variant = _controls.get("team") if is_instance_valid(_controls) else null
	var unit_team: Variant = unit.get("team") if unit.get("team") != null else unit.get_meta("team", -1)
	return int(unit_team) == (int(team) if team != null else Match.Team.GREEN)


func _unit(unit_name: String) -> Node3D:
	if not is_instance_valid(_match):
		return null
	var tanks: Variant = _match.get("tanks")
	var root: Node = tanks if tanks is Node else _match.get_node_or_null("Tanks")
	return root.get_node_or_null(NodePath(unit_name)) as Node3D if root != null else null


func _middle(names: Array) -> Variant:
	var sum := Vector3.ZERO
	var count := 0
	for unit_name in names:
		var unit := _unit(String(unit_name))
		if unit != null:
			sum += Vector3(FxWorld.visual_transform(unit).origin.x, 0.0, FxWorld.visual_transform(unit).origin.z)
			count += 1
	return sum / count if count > 0 else null
