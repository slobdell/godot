class_name RouteDoors
extends RefCounted
## Round 47 (route R5, C47.8 / R47.12): **a route never goes through a blast door that will be shut when the crew gets
## there.** A door is a collider plus ONE NavigationLink3D across its wall (mapkit's), on its OWN navigation layer bit and
## no other: `1 << (LAYER_BIT0 + slot)`. The arena's navmesh is on layer 1 only, so a query that does not ask for a
## door's bit never routes through it. That is the safe default for every caller that bypasses Pathing.
##
## Pathing's GDScript queries ask with `mask(node, from)`: layer 1 | the bit of each door that is open NOW and still open
## at the crew's estimated arrival (straight-line metres to the door at the cruise share of its top speed; a route that
## winds gets there later, and a door that shuts in that slack is caught by the next re-plan). Open/shut is read from
## mapkit's `BlastDoors.is_open(id, tick)` (deterministic from the match seed) once that class exists, else from
## `is_open_fn` (tests and the stub). `--route-off=doors`: every registered door counts as open whatever its clock says.
##
## Native (C47.6): NativePathing does not pass a mask, so while any door is registered Pathing takes its GDScript path;
## the native drive and native callers keep routing with layer 1 only (never through a door) until native passes the same
## mask. Doors therefore ship only on a dev arena until then.

const BASE_LAYERS := 1
## Door slot 0 is navigation layer bit 9 (value 1 << 8); 24 slots fit in the 32 layers.
const LAYER_BIT0 := 8
const MAX_DOORS := 24
## Arrival estimate: speed when the node is not a Tank (m/s).
const DEFAULT_SPEED := 8.0

## {"id": StringName, "position": Vector3, "slot": int} per door, in registration order.
static var doors: Array = []
## (id: StringName, tick: int) -> bool. Used when the BlastDoors class does not exist (tests, the stub); empty = open.
## A test that sets it resets it to Callable() (a static holding a lambda of a freed test instance aborts the process
## at exit).
static var is_open_fn := Callable()
## The tick for a node outside a match (tests set it).
static var now_tick := 0
static var off := OS.get_cmdline_user_args().has("--route-off=doors")
## Measurement: queries asked with a door shut out of the mask, by door id.
static var shut_out := {}


## A door at `position` (its link's middle), returning its layer value (put the link on exactly this), or 0 when full.
static func register(id: StringName, position: Vector3) -> int:
	for door: Dictionary in doors:
		if door["id"] == id:
			return layer_of(int(door["slot"]))
	if doors.size() >= MAX_DOORS:
		push_error("RouteDoors: more than %d doors" % MAX_DOORS)
		return 0
	doors.append({"id": id, "position": position, "slot": doors.size()})
	return layer_of(doors.size() - 1)


static func clear() -> void:
	doors.clear()
	shut_out.clear()
	is_open_fn = Callable()
	now_tick = 0


static func any() -> bool:
	return not doors.is_empty()


static func layer_of(slot: int) -> int:
	return 1 << (LAYER_BIT0 + slot)


static func is_open(id: StringName, tick: int) -> bool:
	if off:
		return true
	# A test's stand-in schedule wins (the game never sets one); otherwise mapkit's BlastDoors, once it is in the project, would
	# shadow every stub and route's shut-door tests would read every door open (round 47 integration, main 79cea77e5 RED 3604/2).
	if is_open_fn.is_valid():
		return bool(is_open_fn.call(id, tick))
	var blast := _blast_doors()
	if blast != null and blast.has_method("is_open"):
		return bool(blast.call("is_open", id, tick))
	return true


## Mapkit's BlastDoors script class, when it is in the project (looked up by name once, so this file parses without it).
static var _blast_looked := false
static var _blast: Script = null


static func _blast_doors() -> Script:
	if not _blast_looked:
		_blast_looked = true
		for entry: Dictionary in ProjectSettings.get_global_class_list():
			if String(entry["class"]) == "BlastDoors":
				_blast = load(String(entry["path"])) as Script
	return _blast


static func _tick(node: Node) -> int:
	var tank := node as Tank
	if tank != null and tank.get_parent() != null:
		var game_match := tank.get_parent().get_parent() as Match
		if game_match != null:
			return game_match.tick
	return now_tick


## The navigation layers a route from `from` may use, asked by `node` (a Tank, for its speed and its match's tick).
static func mask(node: Node, from: Vector3) -> int:
	var layers := BASE_LAYERS
	if doors.is_empty():
		return layers
	var tick := _tick(node)
	var speed := DEFAULT_SPEED
	var tank := node as Tank
	if tank != null and tank.max_forward_speed > 0.0:
		speed = tank.max_forward_speed * Movement.ETA_CRUISE_SHARE
	for door: Dictionary in doors:
		var at: Vector3 = door["position"]
		var eta_ticks := int(ceilf(Vector2(at.x - from.x, at.z - from.z).length() / speed * SimClock.TICK_RATE))
		var id: StringName = door["id"]
		if is_open(id, tick) and is_open(id, tick + eta_ticks):
			layers |= layer_of(int(door["slot"]))
		else:
			shut_out[id] = int(shut_out.get(id, 0)) + 1
	return layers
