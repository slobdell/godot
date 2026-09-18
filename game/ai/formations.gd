class_name Formations
extends RefCounted
## The formations a PLAYER can name (a squad in the garage, the G key, a doctrine JSON squad) and the squad-size cap.
## Since round 6 (N2) this file owns no geometry: every shape comes from TacticsFormation, the one formation system,
## so the icon on a button, the slots a squad drives to and the slots an element's leader hands out are the same.
##
## A slot offset is Vector2(right, back) in meters in the commander's frame: x > 0 is to the commander's right,
## y > 0 is BEHIND the commander. Slot 0 is the commander itself.

## The shapes a player picks from. The rest of TacticsFormation.NAMES (herringbone, swarm, ring) are halts and
## drills a leader chooses, not orders.
const NAMES := ["column", "wedge", "vee", "line", "echelon_right", "echelon_left", "coil"]
const DEFAULT := TacticsFormation.DEFAULT
const DEFAULT_SPACING := TacticsFormation.DEFAULT_SPACING
## A squad is at most this many vehicles (C2's army JSON rule).
const MAX_MEMBERS := 5


## Offsets for `count` tanks (commander first), raw: the commander at the origin.
static func offsets(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> Array[Vector2]:
	return TacticsFormation.offsets(formation, count, spacing)


## World position of an offset, given the anchor (commander, or destination) and the formation heading.
static func to_world(anchor: Vector3, heading: Vector3, offset: Vector2) -> Vector3:
	return TacticsFormation.to_world(anchor, heading, offset) + Vector3(0.0, anchor.y, 0.0)


## Which way a tank in `formation` should face at `offset` when halted: its sector of fire (a coil faces out).
static func facing(formation: String, heading: Vector3, offset: Vector2) -> Vector3:
	if formation == "coil" and offset.length_squared() > 1e-6:
		return TacticsFormation.to_world(Vector3.ZERO, heading, offset).normalized()  # outward
	return TacticsFormation.flat(heading)
