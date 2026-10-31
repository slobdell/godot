class_name ArenaDoors
extends Node3D
## The blast doors in the world (mapkit P2, round 47): one StaticBody3D slab per door of the layout's `doors`, its
## collider live while BlastDoors' schedule says shut. The rules are BlastDoors (pure, seeded); this node only applies
## them to physics, once per physics tick, from the Match's own tick (a replay re-sims the same ticks, so it shuts the
## same doors at the same moments).
##
## **A closing door never crushes or traps a crew.** At its shut tick a door whose slab footprint (plus HULL_MARGIN)
## holds any vehicle stays passable -- HELD -- until the doorway is clear, then seals. A held door is a deviation in the
## crew's favour that lasts only as long as a hull sits in a 1.6 m slot; the schedule (what the route plans on) does not
## move. Events: `door_event(event)` with BlastDoors' {tick, door, group, kind} plus kind "held" (the door that waited,
## with `crew`) and "sealed" (when a held door finally shuts).
##
## NOT a navigation source: the navmesh is baked with every doorway open (doors are not in `navigation_source`), and the
## route reads `BlastDoors.is_open(id, tick)` to cost a shut door (C47.8, route's side). Until that lands, doors ship on
## the dev arena only. The look is a placeholder slab until the lead picks one on the looks page.

signal door_event(event: Dictionary)

## Vehicles (Tank) are on physics layer 2 (the world is 1): what a closing door must not land on.
const VEHICLE_LAYER := 2
## How far outside the slab a hull still counts as "in the doorway" (m): a hull's half-width brushing the jamb.
const HULL_MARGIN := 0.5

var doors: BlastDoors
## id → StaticBody3D
var bodies := {}
var _held := {}  # id → true while a door is due shut but a crew is in it
var _last_tick := -1
var _match: Node
var _match_tries := 0
## When no Match is found (tests, galleries), the node counts its own physics ticks.
var own_tick := 0
var tick_source: Callable


func setup(layout: Dictionary, match_seed: int) -> void:
	doors = BlastDoors.from_layout(layout, match_seed)
	for id in doors.ids():
		var d := doors.door(id)
		var body := StaticBody3D.new()
		body.name = "Door_%s" % id
		body.collision_layer = 1
		body.collision_mask = 0
		var center: Vector2 = d["center"]
		body.position = Vector3(center.x, 0.0, center.y)
		body.rotation.y = deg_to_rad(float(d["rotation_deg"]))
		var size := doors.slab_size(id)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = size
		shape.shape = box
		shape.position = Vector3(0, size.y / 2.0, 0)
		body.add_child(shape)
		var mesh := MeshInstance3D.new()
		mesh.name = "Slab"
		var slab := BoxMesh.new()
		slab.size = size
		mesh.mesh = slab
		mesh.position = shape.position
		mesh.material_override = CyberMaterials.surface(Color(0.2, 0.21, 0.24), 0.4, 0.7)
		body.add_child(mesh)
		add_child(body)
		bodies[id] = body
	_apply(0, true)


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
		var want_shut := not doors.is_open(id, tick)
		var shut := want_shut
		if want_shut and not is_sealed(id):
			var crew := _crew_in_doorway(id)
			if crew != "":
				shut = false
				if not _held.has(id):
					_held[id] = true
					if not quiet:
						door_event.emit({"tick": tick, "door": id, "group": doors.door(id)["group"], "kind": "held", "crew": crew})
		if shut and _held.has(id):
			_held.erase(id)
			if not quiet:
				door_event.emit({"tick": tick, "door": id, "group": doors.door(id)["group"], "kind": "sealed"})
		if not want_shut:
			_held.erase(id)
		_set_shut(id, shut)


## Is door `id`'s collider live right now (shut and not held)?
func is_sealed(id: String) -> bool:
	var body := bodies[id] as StaticBody3D
	return not (body.get_child(0) as CollisionShape3D).disabled


func is_held(id: String) -> bool:
	return _held.has(id)


func _set_shut(id: String, shut: bool) -> void:
	var body := bodies[id] as StaticBody3D
	(body.get_child(0) as CollisionShape3D).disabled = not shut
	# Placeholder look: the slab drops into the floor when open (the drop-gate reading), stands when shut.
	(body.get_node("Slab") as MeshInstance3D).visible = shut


## The name of a vehicle whose body overlaps door `id`'s slab (plus HULL_MARGIN), or "".
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
