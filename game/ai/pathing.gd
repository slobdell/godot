class_name Pathing
extends RefCounted
## Navigation queries against the arena's baked navigation mesh (see game/arena/arena.gd).

## Experiment switch (`--no-navigation`): steer straight at goals, as before M4.
static var enabled := true
## query(): distances under this (flat metres) are float noise, not a gap.
const MESH_EPSILON := 0.05


## Waypoints from `from` to `to` around obstacles, or an empty array if the
## navigation map isn't ready yet (it syncs on the physics frame after baking).
## An unreachable `to` (say, inside a crate) yields a path to the closest reachable point.
static func find_path(node: Node3D, from: Vector3, to: Vector3) -> PackedVector3Array:
	if NativePathing.usable() and not RouteDoors.any():  # round 28 (native N6.4): the same path natively; round 47 (R5): not while a door needs its mask
		return NativeBridge.impl.pathing_find_path(node, from, to)
	if not enabled or not is_ready(node):
		return PackedVector3Array()
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var path := NavigationServer3D.map_get_path(node.get_world_3d().navigation_map, from, to, true, RouteDoors.mask(node, from))
	if OrderController.profile_detail:
		OrderController.add_part("nav.path", Time.get_ticks_usec() - started)
	return path


## Round 7 (lesson 76): a route AND whether it gets there, so no caller has to guess from the last point.
## {"points": PackedVector3Array (as find_path), "ready": bool (false = navigation not synced; nothing below is known),
##  "reachable": bool   the route ends where the goal's nearest point of navmesh is — i.e. on the goal's own island
##                      (false = the goal is cut off: water, a missing bridge, a sealed room; the route only gets near),
##  "goal_on_mesh": bool  the goal itself is on the navmesh (false = it is inside cover, in a pit, off the map),
##  "end_gap_m": float    flat metres from the route's end to the goal's nearest navmesh point (0 when reachable),
##  "goal_gap_m": float   flat metres from the goal to its nearest navmesh point (0 when it is on the mesh)}
## `reachable` and `goal_on_mesh` are different questions: a goal in a pit is off the mesh but may be reachable-as-near-
## as-possible; a goal across a destroyed bridge is on the mesh and unreachable. The gaps are reported, not compared
## against a caller's tolerance; the two booleans only absorb float noise (MESH_EPSILON).
static func query(node: Node3D, from: Vector3, to: Vector3) -> Dictionary:
	if NativePathing.usable() and not RouteDoors.any():  # round 28 (native N6.4): the same reading natively; round 47 (R5): as find_path
		return NativeBridge.impl.pathing_query(node, from, to)
	var result := {"points": PackedVector3Array(), "ready": false, "reachable": false, "goal_on_mesh": false,
			"end_gap_m": INF, "goal_gap_m": INF}
	if not enabled or not is_ready(node):
		return result
	var map := node.get_world_3d().navigation_map
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var points := NavigationServer3D.map_get_path(map, from, to, true, RouteDoors.mask(node, from))
	if OrderController.profile_detail:
		OrderController.add_part("nav.path", Time.get_ticks_usec() - started)
	var nearest := closest_point(map, to, "query")
	var goal_gap := Vector2(to.x - nearest.x, to.z - nearest.z).length()
	var end_gap := INF
	if points.size() > 0:
		var end := points[points.size() - 1]
		end_gap = Vector2(end.x - nearest.x, end.z - nearest.z).length()
	result["points"] = points
	result["ready"] = true
	result["goal_gap_m"] = goal_gap
	result["end_gap_m"] = end_gap
	result["reachable"] = end_gap <= MESH_EPSILON
	result["goal_on_mesh"] = goal_gap <= MESH_EPSILON
	return result


## True once the map actually contains navigation polygons. A few physics frames
## pass between baking and that. Note that "map iteration id > 0" is NOT enough:
## the first sync can be of a map that doesn't include the region yet.
## Round 16 (brains A6): the owner probe is asked once per map ITERATION, not once per call. A map's polygons change
## only when the server syncs a new iteration (the id goes up), so between two syncs the probe's answer cannot move;
## at ~23 calls a tick at 29 units (builder0, 791c3001) it was a nav query each for the same answer.
static var _ready_map := RID()
static var _ready_iteration := -1
static var _ready_answer := false


static func is_ready(node: Node3D) -> bool:
	if NativePathing.usable():  # round 28 (native N6.4): the same answer natively (the memo in these statics)
		return NativeBridge.impl.pathing_is_ready(node)
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var map := node.get_world_3d().navigation_map
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	var ready := false
	if iteration > 0 and not BrainSwitches.ready_memo:
		ready = NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid()
	elif iteration > 0:
		if map != _ready_map or iteration != _ready_iteration:
			_ready_map = map
			_ready_iteration = iteration
			_ready_answer = NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid()
		ready = _ready_answer
	if OrderController.profile_detail:
		OrderController.add_part("nav.is_ready", Time.get_ticks_usec() - started)
	return ready


## NavigationServer3D.map_get_closest_point, counted, and memoised for one physics frame: every brain-side
## closest-point query goes through here. The detailed profile (ai-perf DETAIL=1, --sim-profile) counts the queries
## ("nav.closest") and the answers served from the frame's memo ("nav.closest_memo"). Round 16 (A6): 14 % of the queries
## at 50 units asked a point already asked in the same frame (a chord's end that is the next unit's probe, a gate
## asked by the route and by the guard). The navmesh does not change inside a physics frame, so the same map and the
## same point give the same answer: the memo returns exactly what the server would.
static var _memo_frame := -1
static var _memo_map := RID()
static var _memo_iteration := -1
static var _memo := {}


static func closest_point(map: RID, point: Vector3, site := "") -> Vector3:
	if BrainSwitches.native and BrainSwitches.native_nav:  # round 23 (native N2a, C23.1a): the same point from a native index of the map's polygons
		if NativeBridge.counting:
			NativeBridge.took("nav")
		return NativeBridge.nav.closest_point(map, point)
	if not BrainSwitches.closest_memo:
		var started_off := Time.get_ticks_usec() if OrderController.profile_detail else 0
		var answer := NavigationServer3D.map_get_closest_point(map, point)
		if OrderController.profile_detail:
			OrderController.add_part("nav.closest", Time.get_ticks_usec() - started_off)
			OrderController.add_part("nav.closest@" + site, 0)
		return answer
	# Keyed by the map's iteration as well as the frame, so a sync inside a frame (a test baking and stepping by hand)
	# can never be answered from before it.
	var frame := Engine.get_physics_frames()
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if frame != _memo_frame or map != _memo_map or iteration != _memo_iteration:
		_memo_frame = frame
		_memo_map = map
		_memo_iteration = iteration
		_memo.clear()
	var known: Variant = _memo.get(point)
	if known != null:
		if OrderController.profile_detail:
			OrderController.add_part("nav.closest_memo", 0)
		return known
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	_memo[point] = closest
	if OrderController.profile_detail:
		OrderController.add_part("nav.closest", Time.get_ticks_usec() - started)
		OrderController.add_part("nav.closest@" + site, 0)  # who asks (round 16 A6): a count
	return closest


## Round 47 (route R0, C47.3): **the one door through which anyone asks for a new route for a crew.** Manoeuvre's
## no-progress watchdog calls it when a crew has made no progress (it never plans itself); route owns what comes back.
## Today it forces the crew's next drive to re-plan its navmesh route from where it stands (the same route a fresh
## order would get), on the GDScript and the native-owned execute alike. True when there was a mover to re-plan.
## `reason` is counted by name (`reroutes`), so a census can say who asked and how often.
static var reroutes := {}


static func reroute(crew: Node, reason: StringName) -> bool:
	var mover := Movement.of(crew)
	if mover == null or not (crew is Tank) or not (crew as Tank).alive:
		return false
	# Round 47 (manoeuvre, R47.25's grant): a crew whose route ENDS far short of a goal that is reachable from nearby (it stands on a
	# sliver of navmesh cut off from the goal's region) is given the route from the nearest point of the goal's region instead.
	if _off_island(mover):
		reroutes[reason] = int(reroutes.get(reason, 0)) + 1
		return true
	# The route is re-planned on an EVENT (`Movement._next_waypoint`: the goal moved, off the route, a stall); a goal it
	# was never planned for is that event on the next tick, here and in the C++ (drive_native.cpp reads `_path_goal`).
	mover._path_goal = Vector3.INF
	mover._repath_left = 0.0
	mover.native_stale |= Movement.STALE_ALL  # a write from outside the native execute (as OrderController's forwarders)
	reroutes[reason] = int(reroutes.get(reason, 0)) + 1
	return true


## Round 47 (manoeuvre, R47.25; the CPU's Rust_Hunters on his Crossing recording, staged in tests/test_manoeuvre_noprogress.gd): two
## crews on a sliver of navmesh between the city block (-34, -33) and a container sat `blocked: no_path` 15 s, their route ending
## 2.9 m away, while a squadmate 2 m off drove to the same seats. Re-planning from where they stand returns the same short route.
## So, for a crew whose current route is unreachable: the nearest point (rings of OFF_ISLAND_RINGS metres, OFF_ISLAND_DIRS
## directions, the nearest ring first and the shortest route within it) from which the goal IS reachable becomes the route's first
## station, and the route from it is the rest; the crew drives the short hop off the sliver and on. False (today's re-plan) when the
## route was reachable, nothing is in hand, or no point near reaches the goal. Pathing.query / closest_point carry native's queries.
const OFF_ISLAND_RINGS: Array[float] = [2.5, 4.0, 6.0, 8.0]
const OFF_ISLAND_DIRS := 12
## A ring point counts only where the navmesh is (within this of its closest point).
const OFF_ISLAND_ON_MESH_M := 1.0
static var off_island_routes := 0
## ...and nowhere another live hull stands within this (the staged case: the nearest point off the sliver was a squadmate's spot, and
## the two held each other: one blocked by it, the other yielding to it in place).
const OFF_ISLAND_CLEAR_M := 3.5


static func _hull_near(tank: Tank, point: Vector3) -> bool:
	for other in tank.get_parent().get_children():
		var hull := other as Tank
		if hull != null and hull != tank and hull.is_alive() \
				and Vector2(hull.global_position.x - point.x, hull.global_position.z - point.z).length() < OFF_ISLAND_CLEAR_M:
			return true
	return false


static func _off_island(mover: Movement) -> bool:
	if mover._reachable or not enabled:
		return false
	var tank := mover.ctl.tank
	var goal := mover._path_goal if mover._path_goal != Vector3.INF else mover._goal
	if goal == Vector3.INF or not is_ready(tank):
		return false
	var map := tank.get_world_3d().navigation_map
	var here := tank.global_position
	for radius: float in OFF_ISLAND_RINGS:
		var best: Dictionary = {}
		var best_m := INF
		for k in OFF_ISLAND_DIRS:
			var angle := TAU * float(k) / float(OFF_ISLAND_DIRS)
			var probe := here + Vector3(cos(angle), 0.0, sin(angle)) * radius
			var start := closest_point(map, probe, "off_island")
			if Vector2(start.x - probe.x, start.z - probe.z).length() > OFF_ISLAND_ON_MESH_M or _hull_near(tank, start):
				continue
			var route := query(tank, start, goal)
			if not bool(route["reachable"]) or float(route["goal_gap_m"]) > Movement.NO_PATH_MARGIN:
				continue
			var points: PackedVector3Array = route["points"]
			var metres := 0.0
			for i in range(1, points.size()):
				metres += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
			if metres < best_m:
				best_m = metres
				best = {"start": start, "route": route}
		if best.is_empty():
			continue
		var path := PackedVector3Array([here, best["start"]])
		for point: Vector3 in (best["route"]["points"] as PackedVector3Array):
			if Vector2(point.x - (best["start"] as Vector3).x, point.z - (best["start"] as Vector3).z).length() > 0.1:
				path.append(point)
		mover._path = path
		mover._path_index = 1
		mover._path_goal = goal
		mover._reachable = true
		mover._route_reading = best["route"]
		mover._repath_left = Movement.REPATH_SECONDS
		mover.native_stale |= Movement.STALE_ALL  # a write from outside the native execute (as reroute's stub)
		off_island_routes += 1
		return true
	return false

