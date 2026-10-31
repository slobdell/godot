class_name ArenaDoors
extends Node3D
## The blast doors in the world (mapkit P2, round 47): per door of the layout's `doors`, a StaticBody3D slab whose collider
## is live while BlastDoors' schedule says shut, and ONE NavigationLink3D across it. The rules are BlastDoors (pure,
## seeded); this node applies them to physics once per physics tick, from the Match's own tick (a replay re-sims the same
## ticks, so it shuts the same doors at the same moments).
##
## **The route (C47.8 as built with route, R47.12).** The doorway is CARVED from the navmesh: a bake-only slab per door
## sits in Obstacles while the arena bakes (`bake_blockers`) and is freed after (`after_bake`). The only way across is the
## door's link, on exactly the navigation layer `RouteDoors.register(&id, middle)` returns; Pathing asks for that bit only
## while `BlastDoors.is_open(id, tick)` holds now and at the crew's arrival. With no RouteDoors in the project the link sits
## on UNUSED_LAYER, which no query asks for: no route ever uses a door, and every route is today's.
##
## **A closing door never crushes or traps a crew.** At its shut tick a door whose slab footprint (plus HULL_MARGIN) holds
## a vehicle stays passable -- HELD -- until the doorway is clear, then seals. A hold only ever errs OPEN (later than the
## schedule), never shut, so a route planned on the schedule is never wrong in the dangerous direction. A crew parked in
## the doorway for HOLD_EVICT_S gets an `overstay` event naming it (for manoeuvre's yield to move it on, C47.3): the door
## never seals onto a hull. Events: `door_event(event)` with BlastDoors' {tick, door, group, kind} plus "held" (with
## `crew`), "overstay" (with `crew`) and "sealed". The hold is sim state read from physics: a replay reproduces it.

signal door_event(event: Dictionary)

## Vehicles (Tank) are on physics layer 2 (the world is 1): what a closing door must not land on.
const VEHICLE_LAYER := 2
## How far outside the slab a hull still counts as "in the doorway" (m): a hull's half-width brushing the jamb.
const HULL_MARGIN := 0.5
## A held door asks the crew in it to move on after this long (s).
const HOLD_EVICT_S := 6.0
## The link's ends: this far either side of the slab's centre line (m), outside the carve (slab 0.8 + bake radius 2.0).
const LINK_REACH := 4.0
## A navigation layer no query asks for (bit 32): a link here is never used.
const UNUSED_LAYER := 1 << 31

var doors: BlastDoors
## The doors of the arena built last (the booth's adapter listens to its door_event); null without doors.
static var live: ArenaDoors = null
## id → StaticBody3D
var bodies := {}
## id → NavigationLink3D
var links := {}
var _held := {}  # id → the tick its hold began
var _evicted := {}  # id → true once its overstay was asked
var _blockers: Array[Node] = []
var _last_tick := -1
var _match: Node
var _match_tries := 0
## When no Match is found (tests, galleries), the node counts its own physics ticks.
var own_tick := 0
var tick_source: Callable


func setup(layout: Dictionary, match_seed: int) -> void:
	doors = BlastDoors.from_layout(layout, match_seed)
	BlastDoors.active = doors
	live = self
	var route := _route_doors()
	if route != null:
		route.call("clear")
	for id in doors.ids():
		var d := doors.door(id)
		var center: Vector2 = d["center"]
		var size := doors.slab_size(id)
		var body := StaticBody3D.new()
		body.name = "Door_%s" % id
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = Vector3(center.x, 0.0, center.y)
		body.rotation.y = deg_to_rad(float(d["rotation_deg"]))
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = Vector3(0, size.y / 2.0, 0)
		body.add_child(shape)
		# The look (his pick A, vault slabs) through its slot: art never touches the rules.
		var look := VisualSlot.new()
		look.name = "Look"
		look.slot = "prop.blast_door"
		body.add_child(look)
		look.invoke("setup", [{"width": size.x, "height": size.y, "depth": size.z}])
		add_child(body)
		bodies[id] = body
		var link := NavigationLink3D.new()
		link.name = "Link_%s" % id
		link.bidirectional = true
		link.start_position = Vector3(0, 0, -LINK_REACH)
		link.end_position = Vector3(0, 0, LINK_REACH)
		var layer := int(route.call("register", StringName(id), body.position)) if route != null else 0
		link.navigation_layers = layer if layer != 0 else UNUSED_LAYER
		body.add_child(link)
		links[id] = link
	_apply(0, true)


func _exit_tree() -> void:
	if live == self:
		live = null
	if BlastDoors.active == doors:
		BlastDoors.active = null
		var route := _route_doors()
		if route != null:
			route.call("clear")


## Route's RouteDoors when it is in the project (looked up by name, so this file parses without it).
static func _route_doors() -> Script:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if String(entry["class"]) == "RouteDoors":
			return load(String(entry["path"])) as Script
	return null


## The bake-only slabs that carve every doorway out of the navmesh, parented under `obstacles_root` (a bake source)
## until `after_bake`. Called by Arena before its bake.
func bake_blockers(obstacles_root: Node3D) -> void:
	for id in doors.ids():
		var body := StaticBody3D.new()
		body.name = "DoorBake_%s" % id
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = (bodies[id] as StaticBody3D).transform
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = doors.slab_size(id)
		shape.shape = box
		shape.position = Vector3(0, box.size.y / 2.0, 0)
		body.add_child(shape)
		obstacles_root.add_child(body)
		_blockers.append(body)


func after_bake() -> void:
	for body in _blockers:
		if is_instance_valid(body):
			body.get_parent().remove_child(body)
			body.free()
	_blockers.clear()


func _physics_process(_delta: float) -> void:
	if doors == null:
		return
	own_tick += 1
	_apply(_tick(), false)


func _tick() -> int:
	if tick_source.is_valid():
		return int(tick_source.call())
	if _match == null and _match_tries < 5 and is_inside_tree():
		_match_tries += 1
		var scene := get_tree().current_scene
		if scene != null:
			for node in scene.find_children("*", "Match", true, false):
				_match = node
				break
	return int(_match.get("tick")) if is_instance_valid(_match) else own_tick


## Puts every door in its state for `tick` and emits the events since the last call.
func _apply(tick: int, quiet: bool) -> void:
	if not quiet and _last_tick >= 0 and tick > _last_tick:
		for event: Dictionary in doors.events_between(_last_tick, tick):
			door_event.emit(event)
	_last_tick = tick
	for id in doors.ids():
		var want_shut := not doors.open_at(id, tick)
		var shut := want_shut
		if want_shut and not is_sealed(id):
			var crew := _crew_in_doorway(id)
			if crew != "":
				shut = false
				if not _held.has(id):
					_held[id] = tick
					_emit(quiet, {"tick": tick, "door": id, "group": doors.door(id)["group"], "kind": "held", "crew": crew})
				elif not _evicted.has(id) and tick - int(_held[id]) >= SimClock.ticks(HOLD_EVICT_S):
					_evicted[id] = true
					_emit(quiet, {"tick": tick, "door": id, "group": doors.door(id)["group"], "kind": "overstay", "crew": crew})
		if shut and _held.has(id):
			_held.erase(id)
			_evicted.erase(id)
			_emit(quiet, {"tick": tick, "door": id, "group": doors.door(id)["group"], "kind": "sealed"})
		if not want_shut:
			_held.erase(id)
			_evicted.erase(id)
		_set_shut(id, shut)
		_show(id, "closing" if want_shut and not shut else doors.state(id, tick))


var _shown := {}  # id -> the state the look was last told


## Tells door `id`'s look its state when it changes (a held door shows "closing": open, beacons flashing).
func _show(id: String, state: String) -> void:
	if _shown.get(id, "") == state:
		return
	_shown[id] = state
	((bodies[id] as StaticBody3D).get_node("Look") as VisualSlot).invoke("set_state", [state])


func _emit(quiet: bool, event: Dictionary) -> void:
	if not quiet:
		door_event.emit(event)


## Is door `id`'s collider live right now (shut and not held)?
func is_sealed(id: String) -> bool:
	var body := bodies[id] as StaticBody3D
	return not (body.get_child(0) as CollisionShape3D).disabled


func is_held(id: String) -> bool:
	return _held.has(id)


func _set_shut(id: String, shut: bool) -> void:
	var body := bodies[id] as StaticBody3D
	(body.get_child(0) as CollisionShape3D).disabled = not shut


## The name of a vehicle whose body overlaps door `id`'s slab (plus HULL_MARGIN), or "" (the first by name: stable).
func _crew_in_doorway(id: String) -> String:
	var body := bodies[id] as StaticBody3D
	if not body.is_inside_tree():
		return ""
	var query := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	var size := doors.slab_size(id)
	box.size = size + Vector3(HULL_MARGIN * 2.0, 0.0, HULL_MARGIN * 2.0)
	query.shape = box
	query.transform = body.global_transform * Transform3D(Basis.IDENTITY, Vector3(0, size.y / 2.0, 0))
	query.collision_mask = VEHICLE_LAYER
	query.collide_with_areas = false
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 8)
	var names: Array[String] = []
	for hit: Dictionary in hits:
		var collider: Object = hit.get("collider")
		if collider is Node:
			names.append(String((collider as Node).name))
	names.sort()
	return names[0] if not names.is_empty() else ""
