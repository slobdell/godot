class_name DepartureQueue
extends Node
## Round 41 (orders O2; the lead, round-40 playtest: "when I'm controlling a large set of squads at once and commanding all
## of them to go somewhere, a bunch of units block other units"). His group order, departure order: the squads of one
## plain move / attack-move set off front first, and a squad whose first stretch of road still holds crews of a squad
## ahead of it waits its turn instead of driving into them -- cars leaving a car park one lane at a time. O1's census
## (builder0 8b828ec59, references/round41/orders/o1-census-builder0-8b828ec59/) found no crossing routes but 50-258
## crew-seconds a run of crews stepping aside where the five squads' roads converge.
##
## The turn is read from the road, never a timer: a squad's CORRIDOR is the first CORRIDOR_M of its own navmesh route
## (centre -> its place; at most half the route), CORRIDOR_HALF_M a side. It sets off on the first tick no living crew
## of a squad ranked AHEAD of it in this order stands in that corridor (an arrived squad's crews don't count). A squad
## whose corridor is clear when he clicks leaves on the click; the front squad never waits. Bounded: MAX_WAIT_S.
## While it waits it keeps the task it had (his squads are parked or holding: they stand still).
##
## `--group-depart=queue` turns it on (OFF: RtsControls dispatches every squad on the click, as before). Deterministic:
## it runs on physics ticks, in rank order, on crew positions only.

static var ENABLED := OS.get_cmdline_user_args().has("--group-depart=queue")
const CORRIDOR_M := 30.0
const CORRIDOR_HALF_M := 7.0
const MAX_WAIT_S := 20.0
## Measurement (the probe reads them): squads queued, squads released by a clear road / by MAX_WAIT_S, ticks waited.
static var queued := 0
static var released_clear := 0
static var released_timeout := 0
static var waited_ticks := 0
## Per squad (its first crew's name) the ticks it waited (0: it left on the click), for the probe's wait guard.
static var waits := {}

## [{units: Array, ahead: Array (crew names of squads ranked ahead), corridor: PackedVector2Array, since: int,
##   release: Callable, element: Variant}], rank order.
var waiting: Array = []
var game_match: Match


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	process_physics_priority = -30  # before the executor (-20) and the controllers (-10)


## Queue a squad: `release` gives it its task. Returns true when it must wait (its corridor holds a crew ahead of it).
func add(units: Array, ahead: Array, corridor: PackedVector2Array, release: Callable, arrived_of: Callable) -> bool:
	var entry := {"units": units.duplicate(), "ahead": ahead.duplicate(), "corridor": corridor, "release": release,
			"since": game_match.tick if game_match != null else 0, "arrived_of": arrived_of}
	waits[String(units[0])] = 0
	if blockers(corridor, _positions(ahead, arrived_of)).is_empty():
		return false
	queued += 1
	waiting.append(entry)
	return true


## A new order for any of `units` takes its squad out of the queue (it has been given something else).
func cancel(units: Array) -> void:
	waiting = waiting.filter(func(e: Dictionary) -> bool:
		return not (e["units"] as Array).any(func(n: String) -> bool: return units.has(n)))


func _physics_process(_delta: float) -> void:
	if waiting.is_empty() or game_match == null:
		return
	var still: Array = []
	var due: Array = []
	for entry: Dictionary in waiting:
		var timed_out := game_match.tick - int(entry["since"]) >= int(MAX_WAIT_S * SimClock.TICK_RATE)
		if timed_out or blockers(entry["corridor"], _positions(entry["ahead"], entry["arrived_of"])).is_empty():
			if timed_out:
				released_timeout += 1
			else:
				released_clear += 1
			due.append(entry)
		else:
			waited_ticks += 1
			var key := String((entry["units"] as Array)[0])
			waits[key] = int(waits.get(key, 0)) + 1
			still.append(entry)
	waiting = still
	for entry: Dictionary in due:
		(entry["release"] as Callable).call()


## The living crews of `names` whose squad has not arrived on its new task: name -> flat position. A squad still waiting
## its own turn has not set off, so its crews count however its old task reads.
func _positions(names: Array, arrived_of: Callable) -> Dictionary:
	var out := {}
	if game_match == null:
		return out
	var held := {}
	for entry: Dictionary in waiting:
		for n: String in entry["units"]:
			held[n] = true
	for n: String in names:
		var tank := game_match.tanks.get_node_or_null(NodePath(n)) as Tank
		if tank == null or not tank.is_alive() or (not held.has(n) and bool(arrived_of.call(n))):
			continue
		out[n] = Vector2(tank.global_position.x, tank.global_position.z)
	return out


## The names in `positions` (name -> Vector2) standing within CORRIDOR_HALF_M of the polyline `corridor`. Pure.
static func blockers(corridor: PackedVector2Array, positions: Dictionary) -> Array:
	var out: Array = []
	if corridor.size() < 2:
		return out
	var names: Array = positions.keys()
	names.sort()
	for n: String in names:
		var p: Vector2 = positions[n]
		for i in corridor.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, corridor[i], corridor[i + 1])) <= CORRIDOR_HALF_M:
				out.append(n)
				break
	return out


## The first `CORRIDOR_M` of `route` (flat; at most half its length), from its first point. Pure.
static func corridor_of(route: PackedVector3Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if route.size() < 2:
		return out
	var total := 0.0
	for i in route.size() - 1:
		total += Vector2(route[i].x, route[i].z).distance_to(Vector2(route[i + 1].x, route[i + 1].z))
	var left := minf(CORRIDOR_M, total * 0.5)
	out.append(Vector2(route[0].x, route[0].z))
	for i in route.size() - 1:
		var a := Vector2(route[i].x, route[i].z)
		var b := Vector2(route[i + 1].x, route[i + 1].z)
		var step := a.distance_to(b)
		if step <= 0.0:
			continue
		if step >= left:
			out.append(a + (b - a) * (left / step))
			return out
		out.append(b)
		left -= step
	return out


## Rank `centres` (Vector3, one a squad) front first along `approach` (the group's direction of travel): indices. Pure.
static func rank(centres: Array, approach: Vector3) -> Array:
	var order: Array = range(centres.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		var da := (centres[a] as Vector3).dot(approach)
		var db := (centres[b] as Vector3).dot(approach)
		return da > db + 0.001 or (absf(da - db) <= 0.001 and a < b))
	return order


static func reset_counters() -> void:
	queued = 0
	released_clear = 0
	released_timeout = 0
	waited_ticks = 0
	waits = {}
