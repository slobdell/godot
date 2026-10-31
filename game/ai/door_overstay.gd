class_name DoorOverstay
extends RefCounted
## Round 47 (manoeuvre, mapkit's request; `--traffic-on=overstay`, Traffic.DEFAULT_OFF until doors reach a real arena): A CREW
## PARKED IN A CLOSING DOORWAY MOVES ON. A closing blast door never lands on a hull: it HOLDS open while a vehicle is in its
## doorway, and after ArenaDoors.HOLD_EVICT_S it emits one `overstay` event naming the crew (game/arena/arena_doors.gd). Here
## that crew gives way to the DOOR as it gives way to a crew wanting past (C47.3: the yield is the one way a crew is moved
## on): a give-way (`Movement._start_yield`) to a spot straight off the slab on the side it already stands on (through the
## door or back out, never across), checked as every give-way's spot is (see move_on). The hull give-way's spot table does
## not fit a door: its spots are offsets from a hull's line of travel, and the first try took the crew's own spot. With no
## tank behind the "other", the yield ends once its spot is reached, the doorway is clear and the door seals. Counter `moves` (route_arms `overstay_moves`).
##
## GDScript on every path: an event handler outside the execute step that starts a yield as `ask` does (it marks the mover
## stale for the native execute), so it needs no twin of its own.

const SWITCH := "overstay"
## How far past the slab face the crew's nearer end stops (m): ArenaDoors.HULL_MARGIN and some.
const CLEAR_M := 1.5

static var moves := 0
static var asked := 0
static var _listening: ArenaDoors = null
static var _installed := false
## Measurement only: OVERSTAY_TRACE=on prints each spot tried.
static var trace := OS.get_environment("OVERSTAY_TRACE") == "on"


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


## Gives way off door `door`'s slab (BlastDoors.door: centre, rotation_deg): a spot straight off the slab along the door's
## normal, keeping the crew's offset along the doorway, CLEAR_M past the slab face plus the hull's half length; the side the
## crew stands on first (through the door or back out, never across), then the other. Each spot passes the give-way's own
## checks (a wheeled crew drives forward or straight back onto it; free of hulls). Whether one was taken.
static func move_on(mover: Movement, door: Dictionary, id: String) -> bool:
	var tank := mover.ctl.tank
	if not tank.is_alive() or mover.yield_to != "":
		return false
	var centre: Vector2 = door["center"]
	var r := deg_to_rad(float(door["rotation_deg"]))
	var normal := Vector2(sin(r), cos(r))  # the slab's local z (the way through), in the ground plane
	var width_way := Vector2(cos(r), -sin(r))
	var here := Vector2(tank.global_position.x, tank.global_position.z)
	var offset := (here - centre).dot(width_way)
	var side := 1.0 if (here - centre).dot(normal) >= 0.0 else -1.0
	var out := BlastDoors.DEPTH * 0.5 + float(Movement.hull_box(tank.unit_id)[2]) * 0.5 + CLEAR_M
	var other := "door:" + id
	mover.native_stale |= Movement.STALE_ALL
	for way: float in [side, -side]:
		var flat := centre + width_way * offset + normal * (out * way)
		var point := Vector3(flat.x, 0.0, flat.y)
		if trace:
			print("OVERSTAY_SPOT %s %s way %+d point %s wheels %s free %s fits %s" % [tank.name, id, int(way), str(point),
					str(mover.wheel_radius() <= 0.0 or mover._ahead_of_wheels(point) or mover._straight_behind(point)),
					str(mover._free_spot(point, String(tank.name), other)), str(mover._yield_fits(point))])  # fits: measurement only
		if mover.wheel_radius() > 0.0 and not mover._ahead_of_wheels(point) and not mover._straight_behind(point):
			continue
		# No navmesh sweep (_yield_fits): the doorway is CARVED from the navmesh (C47.8), so every pose in it reads off the
		# mesh and the sweep refused both ways (the staged case). The run is straight along the normal through a doorway at
		# least BlastDoors.MIN_WIDTH wide whose one obstacle, the slab, is held open; hulls are _free_spot's.
		if not mover._free_spot(point, String(tank.name), other):
			continue
		mover._start_yield(other, point, normal * way, "door(%+d)" % int(way), "door")
		return true
	return false
