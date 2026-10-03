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
	if not enabled or not is_ready(node):
		return PackedVector3Array()
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var path := NavigationServer3D.map_get_path(node.get_world_3d().navigation_map, from, to, true)
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
	var result := {"points": PackedVector3Array(), "ready": false, "reachable": false, "goal_on_mesh": false,
			"end_gap_m": INF, "goal_gap_m": INF}
	if not enabled or not is_ready(node):
		return result
	var map := node.get_world_3d().navigation_map
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var points := NavigationServer3D.map_get_path(map, from, to, true)
	if OrderController.profile_detail:
		OrderController.add_part("nav.path", Time.get_ticks_usec() - started)
	var nearest := closest_point(map, to)
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
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var map := node.get_world_3d().navigation_map
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	var ready := false
	if iteration > 0:
		if map != _ready_map or iteration != _ready_iteration:
			_ready_map = map
			_ready_iteration = iteration
			_ready_answer = NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid()
		ready = _ready_answer
	if OrderController.profile_detail:
		OrderController.add_part("nav.is_ready", Time.get_ticks_usec() - started)
	return ready


## NavigationServer3D.map_get_closest_point, counted: every brain-side closest-point query goes through here so
## the detailed profile (ai-perf DETAIL=1, --sim-profile) can say how many a tick makes ("nav.closest", round 16 A2),
## and how many ask a point already asked in the same physics frame ("nav.closest_repeat"). The same answer, always.
static func closest_point(map: RID, point: Vector3) -> Vector3:
	var started := Time.get_ticks_usec() if OrderController.profile_detail else 0
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	if OrderController.profile_detail:
		OrderController.add_part("nav.closest", Time.get_ticks_usec() - started)
		var frame := Engine.get_physics_frames()
		if frame != _seen_frame:
			_seen_frame = frame
			_seen.clear()
		if _seen.has(point):
			OrderController.add_part("nav.closest_repeat", 0)
		else:
			_seen[point] = true
	return closest


## Measurement only: the points closest_point was asked this physics frame.
static var _seen_frame := -1
static var _seen := {}
