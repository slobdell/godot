class_name DoorOverstay
extends RefCounted
## Round 47 (manoeuvre, mapkit's request; `--traffic-on=overstay`, Traffic.DEFAULT_OFF until doors reach a real arena): A CREW
## PARKED IN A CLOSING DOORWAY MOVES ON. A closing blast door never lands on a hull: it HOLDS open while a vehicle is in its
## doorway, and after ArenaDoors.HOLD_EVICT_S it emits one `overstay` event naming the crew (game/arena/arena_doors.gd). Here
## that crew gives way to the DOOR as it gives way to a crew wanting past (C47.3: the yield is the one way a crew is moved
## on): `Movement._begin_yield` with the door's slab as the line to clear (its centre, along its width), so the crew steps
## off the slab to the side it already stands on (through the door or back out, never across), by the same validated spots,
## fit checks and veto as every give-way. With no tank behind the "other", the yield ends once its spot is reached, the
## doorway is clear and the door seals. Counter `moves` (route_arms `overstay_moves`).
##
## GDScript on every path: an event handler outside the execute step that starts a yield as `ask` does (it marks the mover
## stale for the native execute), so it needs no twin of its own.

const SWITCH := "overstay"

static var moves := 0
static var asked := 0
static var _listening: ArenaDoors = null
static var _installed := false


static func on() -> bool:
	return not Traffic.off(SWITCH)


static func reset() -> void:
	moves = 0
	asked = 0


## Movement._init calls this: once a physics frame it (re)connects to the arena's doors when a new arena built them.
static func install() -> void:
	if _installed:
		return
	_installed = true
	(Engine.get_main_loop() as SceneTree).physics_frame.connect(_poll)


static func _poll() -> void:
	var doors := ArenaDoors.live
	if doors == _listening or doors == null or not is_instance_valid(doors):
		return
	_listening = doors
	if not doors.door_event.is_connected(on_door):
		doors.door_event.connect(on_door)


static func on_door(event: Dictionary) -> void:
	if String(event.get("kind", "")) != "overstay" or not on():
		return
	var doors := ArenaDoors.live
	if doors == null or not is_instance_valid(doors) or not doors.doors.has(String(event["door"])):
		return
	var crew := String(event.get("crew", ""))
	for id: int in Movement._registry:
		var mover: Movement = Movement._registry[id]
		if mover != null and is_instance_valid(mover.ctl) and mover.ctl.tank != null and String(mover.ctl.tank.name) == crew:
			asked += 1
			if move_on(mover, doors.doors.door(String(event["door"])), String(event["door"])):
				moves += 1
			return


## Gives way off door `door`'s slab (BlastDoors.door: centre, rotation_deg); whether a spot was taken.
static func move_on(mover: Movement, door: Dictionary, id: String) -> bool:
	if not mover.ctl.tank.is_alive() or mover.yield_to != "":
		return false
	var centre: Vector2 = door["center"]
	var r := deg_to_rad(float(door["rotation_deg"]))
	mover.native_stale |= Movement.STALE_ALL
	return mover._begin_yield("door:" + id, Vector3(centre.x, 0.0, centre.y), Vector2(cos(r), -sin(r)), "door")
