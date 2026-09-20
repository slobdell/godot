class_name Shown
extends RefCounted
## Where a vehicle is drawn this frame, for everything that follows one on screen (camera, rings, bars, picking,
## route lines). With physics interpolation on (combat's 30 Hz tick), a body is drawn between two ticks, but
## `global_position` read in `_process` is the last tick's: a camera or a ring reading it lags what the player sees by a
## tick. Identical to `global_position` while interpolation is off. Orders and the simulation keep using the tick's.


static func at(node: Node3D) -> Vector3:
	return node.get_global_transform_interpolated().origin


## The same point flattened onto the ground.
static func ground(node: Node3D) -> Vector3:
	var origin := node.get_global_transform_interpolated().origin
	return Vector3(origin.x, 0.0, origin.z)


static func forward(node: Node3D) -> Vector3:
	return -node.get_global_transform_interpolated().basis.z


## How far a vehicle's hull reaches from the point it stands on, in metres (round 9). Anything that BOUNDS a
## vehicle wants this: `hull_size` runs from 2.93 m to 14.0 m since CP2, so half a hull is up to 7 m of error in a
## bound built from positions alone. Half the diagonal, so it holds whichever way the hull is turned.
static func half_hull(node: Node3D) -> float:
	var unit_id := String(node.get("unit_id")) if node.get("unit_id") != null else ""
	var hull: Array = Units.stat(unit_id, "hull_size") if unit_id != "" else []
	if hull.size() != 3:
		return 0.0
	return Vector2(float(hull[0]), float(hull[2])).length() * 0.5
