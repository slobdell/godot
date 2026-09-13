class_name Armor
extends RefCounted
## Where a shell strikes a hull decides how much it hurts. This is the core
## positioning trade-off of tank combat: face your enemy, flank theirs.

enum Facing { FRONT, SIDE, REAR }

const MULTIPLIER := {Facing.FRONT: 0.5, Facing.SIDE: 1.0, Facing.REAR: 1.5}
const FACING_NAMES := {Facing.FRONT: "front", Facing.SIDE: "side", Facing.REAR: "rear"}
## A hit within this many degrees of dead-ahead counts as front (or dead-behind as rear).
const ARC_DEG := 45.0


## Which armor face a shell travelling along `shell_direction` strikes on a hull
## facing `hull_forward`. Only the horizontal plane matters.
static func facing(hull_forward: Vector3, shell_direction: Vector3) -> Facing:
	var forward := Vector3(hull_forward.x, 0.0, hull_forward.z).normalized()
	# Direction from the hull back toward where the shell came from.
	var toward_shooter := Vector3(-shell_direction.x, 0.0, -shell_direction.z).normalized()
	var alignment := forward.dot(toward_shooter)
	var arc := cos(deg_to_rad(ARC_DEG))
	if alignment >= arc:
		return Facing.FRONT
	if alignment <= -arc:
		return Facing.REAR
	return Facing.SIDE


static func damage(base_damage: float, hull_forward: Vector3, shell_direction: Vector3) -> int:
	return roundi(base_damage * MULTIPLIER[facing(hull_forward, shell_direction)])
