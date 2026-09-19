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
	return NavigationServer3D.map_get_path(node.get_world_3d().navigation_map, from, to, true)


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
	var points := NavigationServer3D.map_get_path(map, from, to, true)
	var nearest := NavigationServer3D.map_get_closest_point(map, to)
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
static func is_ready(node: Node3D) -> bool:
	var map := node.get_world_3d().navigation_map
	return NavigationServer3D.map_get_iteration_id(map) > 0 \
			and NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid()
