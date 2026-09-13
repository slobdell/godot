class_name Formations
extends RefCounted
## Formation geometry, relative to a squad's commander. Pure math.
## Loosely after US Army tank platoon formations (see _agents/tactical_map.md).
##
## A slot offset is Vector2(right, back) in units of meters, in the commander's frame:
## x > 0 is to the commander's right, y > 0 is BEHIND the commander. Slot 0 is the
## commander itself. COIL is special: slots ring the squad's destination.

const NAMES := ["column", "wedge", "vee", "line", "echelon_right", "echelon_left", "coil"]
const DEFAULT := "wedge"
const DEFAULT_SPACING := 12.0
const MAX_MEMBERS := 5


## Offsets for `count` tanks (commander first).
static func offsets(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in mini(count, MAX_MEMBERS):
		result.append(_offset(formation, i, count, spacing))
	return result


static func _offset(formation: String, i: int, count: int, s: float) -> Vector2:
	if i == 0 and formation != "coil":
		return Vector2.ZERO
	# Followers alternate sides: 1 left, 2 right, 3 left (further), 4 right (further).
	var side := -1.0 if i % 2 == 1 else 1.0
	var rank := float((i + 1) / 2)
	match formation:
		"column":
			return Vector2(0.0, i * s)
		"wedge":
			return Vector2(side * rank * s, rank * s)
		"vee":
			return Vector2(side * rank * s, -rank * s)
		"line":
			return Vector2(side * rank * s, 0.0)
		"echelon_right":
			return Vector2(i * s, i * s)
		"echelon_left":
			return Vector2(-i * s, i * s)
		"coil":
			# A ring around the destination, first slot straight ahead.
			var angle := TAU * i / count
			var radius := s * (0.6 if count <= 3 else 0.8)
			return Vector2(sin(angle) * radius, -cos(angle) * radius)
	return Vector2.ZERO


## World position of an offset, given the anchor (commander, or destination for coil)
## and the formation heading (a horizontal forward vector).
static func to_world(anchor: Vector3, heading: Vector3, offset: Vector2) -> Vector3:
	var forward := Vector3(heading.x, 0.0, heading.z)
	forward = Vector3.FORWARD if forward.length_squared() < 1e-6 else forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	return anchor + right * offset.x - forward * offset.y


## Which way a tank in `formation` should face at `slot_offset` when halted.
static func facing(formation: String, heading: Vector3, offset: Vector2) -> Vector3:
	if formation == "coil" and offset.length_squared() > 1e-6:
		return to_world(Vector3.ZERO, heading, offset).normalized()  # outward
	return Vector3(heading.x, 0.0, heading.z).normalized()
