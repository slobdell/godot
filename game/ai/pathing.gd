class_name Pathing
extends RefCounted
## Navigation queries against the arena's baked navigation mesh (see game/arena/arena.gd).

## Experiment switch (`--no-navigation`): steer straight at goals, as before M4.
static var enabled := true


## Waypoints from `from` to `to` around obstacles, or an empty array if the
## navigation map isn't ready yet (it syncs on the physics frame after baking).
## An unreachable `to` (say, inside a crate) yields a path to the closest reachable point.
static func find_path(node: Node3D, from: Vector3, to: Vector3) -> PackedVector3Array:
	if not enabled or not is_ready(node):
		return PackedVector3Array()
	return NavigationServer3D.map_get_path(node.get_world_3d().navigation_map, from, to, true)


## True once the map actually contains navigation polygons. A few physics frames
## pass between baking and that. Note that "map iteration id > 0" is NOT enough:
## the first sync can be of a map that doesn't include the region yet.
static func is_ready(node: Node3D) -> bool:
	var map := node.get_world_3d().navigation_map
	return NavigationServer3D.map_get_iteration_id(map) > 0 \
			and NavigationServer3D.map_get_closest_point_owner(map, Vector3.ZERO).is_valid()
