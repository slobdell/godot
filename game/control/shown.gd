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
