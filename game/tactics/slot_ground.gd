class_name SlotGround
extends RefCounted
## X2 (round 6): a formation slot must be somewhere a vehicle can stand. Formation geometry is pure (TacticsFormation)
## and knows nothing of walls, so a wedge laid alongside a container stack used to put a vehicle's slot INSIDE it
## (the visible half of "no coherent formations"). Every slot is checked here, where a plan becomes orders, and pushed
## to the nearest standable point when it isn't.
##
## The question "can a vehicle stand here" is navigation's, and this file does not answer it with geometry of its own:
## it asks the navigation mesh the arena bakes (the same map Pathing plans on), whose polygons already leave a vehicle's
## radius clear of every obstacle. One seam, `standable()`, so when nav's Movement API (N1) grows a query of its own
## this is the only line that changes.

## A slot this close to the navmesh counts as standable already (meters): the mesh is a coarse surface.
const TOLERANCE_M := 1.0


## The nearest point to `point` a vehicle can stand on (flat), or `point` itself when it already is one, or when the
## navigation map isn't ready (early frames, tests without an arena): then there is nothing better to say.
static func standable(node: Node3D, point: Vector3) -> Vector3:
	if node == null or not node.is_inside_tree() or not Pathing.enabled or not Pathing.is_ready(node):
		return point
	var map := node.get_world_3d().navigation_map
	var closest := NavigationServer3D.map_get_closest_point(map, Vector3(point.x, 0.0, point.z))
	var flat := Vector3(closest.x, point.y, closest.z)
	if Vector2(flat.x - point.x, flat.z - point.z).length() <= TOLERANCE_M:
		return point
	return flat


## Whether `point` is standable as it is.
static func is_standable(node: Node3D, point: Vector3) -> bool:
	return standable(node, point) == point
