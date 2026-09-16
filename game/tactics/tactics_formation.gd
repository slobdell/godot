class_name TacticsFormation
extends RefCounted
## Movement formation geometry for an element (doctrine X1/X2). Pure math, no engine state, no randomness.
##
## A slot is Vector2(right, back) meters in the element's frame: x > 0 is to the element's right, y > 0 is
## BEHIND it (the convention Formations and GroupFormation already use). Slot 0 is the leader's.
## Shapes and their purpose come from US Army movement formations for a platoon (ATP 3-20.15 *Tank Platoon*
## ch. 2; ATP 3-21.8 *Infantry Platoon and Squad* ch. 2); the citations and the "what it's for" line per shape
## are in _agents/doctrine.md.
##
##   offsets(formation, count, spacing) -> Array[Vector2]   raw slots, leader at the origin
##   centered(offsets) -> Array[Vector2]                    the same shape around its own middle (movement anchor)
##   sectors(formation, count) -> Array[float]              each slot's sector of fire, degrees from the heading
##                                                          (0 = ahead, + = right), so the element covers itself
##   frontage/depth(formation, count, spacing) -> float     how wide and how deep the shape is (meters)
##   to_world(anchor, heading, offset) -> Vector3           slot -> world, and facing_of() for halts
##
## Unlike Formations (ai's squad geometry, capped at 5), these scale to any element size, and add the
## herringbone: the halt formation that alternates vehicles 45-90 degrees left and right of the axis.

## Formation ids. The L1 contract names column, wedge, line, echelon_left/right and herringbone; vee and coil
## are the two other shapes real platoons use (a V of scouts, and the 360-degree halt in the open).
const NAMES := ["column", "wedge", "vee", "line", "echelon_left", "echelon_right", "herringbone", "coil",
		"swarm", "ring"]
const DEFAULT := "wedge"
## Meters between neighbors when the doctrine table doesn't say.
const DEFAULT_SPACING := 12.0
## Wedge and echelon slots sit this fraction of the spacing out to the side (a 45-degree-ish diagonal).
const DIAGONAL_SIDE := 0.9
## Herringbone: lateral offset as a fraction of spacing, and how far its middle vehicles turn off the axis
## (degrees) — they point their hulls and guns at the flanks instead of traversing turrets later.
const HERRINGBONE_SIDE := 0.55
const HERRINGBONE_FACING := 90.0
## Sector of fire a single vehicle is responsible for (degrees). Overlap between neighbors is deliberate:
## interlocking fires are the point of assigning sectors at all.
const SECTOR_WIDTH := 90.0
## The swarm: how much wider than a line it spreads, and how far vehicles stagger fore and aft. It is not a
## formation any manual would recognise, which is the point — a pack that has never drilled doesn't hold a
## line, it comes at you loose and all at once, and being spread means one shell is one vehicle.
const SWARM_SPREAD := 1.9
const SWARM_STAGGER := 0.8
## The ring (encircle): how far out the pack orbits a target, as a multiple of spacing.
const RING_RADIUS := 2.4


## Slots for `count` units in `formation`, leader first, at the origin.
static func offsets(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for i in maxi(count, 0):
		result.append(offset(formation, i, count, spacing))
	return result


static func offset(formation: String, i: int, count: int, spacing: float) -> Vector2:
	var s := maxf(spacing, 1.0)
	# Followers alternate sides: 1 left, 2 right, 3 further left, 4 further right.
	var side := -1.0 if i % 2 == 1 else 1.0
	var rank := float((i + 1) / 2)
	match formation:
		"column":
			return Vector2(0.0, i * s)
		"wedge":
			return Vector2(0.0, 0.0) if i == 0 else Vector2(side * rank * s * DIAGONAL_SIDE, rank * s)
		"vee":
			return Vector2(0.0, 0.0) if i == 0 else Vector2(side * rank * s * DIAGONAL_SIDE, -rank * s)
		"line":
			return Vector2(0.0, 0.0) if i == 0 else Vector2(side * rank * s, 0.0)
		"echelon_right":
			return Vector2(i * s * DIAGONAL_SIDE, i * s)
		"echelon_left":
			return Vector2(-i * s * DIAGONAL_SIDE, i * s)
		"herringbone":
			# Still in column, but each vehicle pulls off the axis to the side it will cover.
			return Vector2(side * s * HERRINGBONE_SIDE, i * s * 0.8)
		"coil":
			var angle := TAU * i / maxi(count, 1)
			var radius := s * (0.7 if count <= 3 else 0.9) * sqrt(maxf(count, 1.0) / 4.0)
			return Vector2(sin(angle) * radius, -cos(angle) * radius)
		"swarm":
			# Wide and ragged: alternating sides, spreading as it goes out, each vehicle staggered fore or
			# aft so the pack has no line to shoot along. Deterministic, despite looking unruly.
			var rank_out := float((i + 1) / 2)
			var stagger := ((i * 7) % 5) - 2.0
			return Vector2(side * rank_out * s * SWARM_SPREAD, stagger * s * SWARM_STAGGER)
		"ring":
			# Around the enemy, not around a heading: the anchor of a ring is the thing being encircled.
			var step := TAU * i / maxi(count, 1)
			return Vector2(sin(step) * s * RING_RADIUS, -cos(step) * s * RING_RADIUS)
	return Vector2(0.0, 0.0)


## The same shape moved so its middle is the origin: what a movement anchor (the element's destination) uses,
## so "go there" puts the element's centre there, not its leader.
static func centered(raw: Array[Vector2]) -> Array[Vector2]:
	if raw.is_empty():
		return raw
	var middle := Vector2.ZERO
	for slot in raw:
		middle += slot
	middle /= float(raw.size())
	var result: Array[Vector2] = []
	for slot in raw:
		result.append(slot - middle)
	return result


## Each slot's sector of fire: the azimuth (degrees, 0 = the direction of travel, + = right) its crew watches.
## Together they cover the element: the front in the direction of travel, the flanks and rear where the shape
## is blind. SECTOR_WIDTH degrees wide each, so neighbours interlock.
static func sectors(formation: String, count: int) -> Array[float]:
	var result: Array[float] = []
	if count <= 0:
		return result
	match formation:
		"column":
			# Everyone but the lead (front) and the rear vehicle (rear) watches alternate flanks.
			for i in count:
				if i == 0:
					result.append(0.0)
				elif i == count - 1 and count > 2:
					result.append(180.0)
				else:
					result.append(90.0 if i % 2 == 0 else -90.0)
		"wedge", "vee":
			for i in count:
				if i == 0:
					result.append(0.0)
				else:
					var side := -1.0 if i % 2 == 1 else 1.0
					var rank := float((i + 1) / 2)
					result.append(side * minf(45.0 + 45.0 * (rank - 1.0), 135.0))
		"line":
			# Maximum fire forward: the frontage is split so the element's fires interlock across it.
			for i in count:
				var spread: float = 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 60.0
				result.append(spread)
		"echelon_right":
			for i in count:
				result.append(0.0 if i == 0 else minf(45.0 + 45.0 * (i - 1), 135.0))
		"echelon_left":
			for i in count:
				result.append(0.0 if i == 0 else -minf(45.0 + 45.0 * (i - 1), 135.0))
		"herringbone":
			# Lead watches ahead, the middle vehicles turn out to alternate flanks, the tail watches behind:
			# a halted column with every direction covered.
			for i in count:
				if i == 0:
					result.append(0.0)
				elif i == count - 1 and count > 2:
					result.append(180.0)
				else:
					result.append(HERRINGBONE_FACING if i % 2 == 0 else -HERRINGBONE_FACING)
		"coil", "ring":
			for i in count:
				result.append(rad_to_deg(TAU * i / count) - (360.0 if TAU * i / count > PI else 0.0))
		"swarm":
			# Everyone watches roughly forward, fanned wide: no sectors, no discipline, all eyes on the prey.
			for i in count:
				var spread: float = 0.0 if count <= 1 else (float(i) / float(count - 1) - 0.5) * 120.0
				result.append(spread)
		_:
			for i in count:
				result.append(0.0)
	return result


## How much of the full circle the element's sectors watch, 0..1 (SECTOR_WIDTH each, overlap counted once).
## The measurement behind "why formations pay off": a column watching both flanks sees more than a clump.
static func coverage(formation: String, count: int) -> float:
	var watched := {}
	for azimuth in sectors(formation, count):
		for degree in range(int(round(azimuth - SECTOR_WIDTH * 0.5)), int(round(azimuth + SECTOR_WIDTH * 0.5))):
			watched[(degree + 720) % 360] = true
	return watched.size() / 360.0


## Width of the shape across the direction of travel (meters).
static func frontage(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	return _extent(offsets(formation, count, spacing), true)


## Length of the shape along the direction of travel (meters).
static func depth(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	return _extent(offsets(formation, count, spacing), false)


## The closest two slots in the shape (meters): how much one splash or one burst can reach at once.
static func closest_pair(formation: String, count: int, spacing: float = DEFAULT_SPACING) -> float:
	var slots := offsets(formation, count, spacing)
	var closest := INF
	for i in slots.size():
		for j in range(i + 1, slots.size()):
			closest = minf(closest, slots[i].distance_to(slots[j]))
	return closest if is_finite(closest) else 0.0


## World position of a slot, given the element's anchor and its heading (a flat forward vector).
static func to_world(anchor: Vector3, heading: Vector3, slot: Vector2) -> Vector3:
	var forward := flat(heading)
	var right := Vector3(-forward.z, 0.0, forward.x)
	return Vector3(anchor.x, 0.0, anchor.z) + right * slot.x - forward * slot.y


## Which way a slot's crew faces at a halt: its sector of fire, turned into a world direction.
static func facing_of(formation: String, i: int, count: int, heading: Vector3) -> Vector3:
	var list := sectors(formation, count)
	if i < 0 or i >= list.size():
		return flat(heading)
	return rotate(flat(heading), deg_to_rad(list[i]))


## `heading` turned `radians` to the right (positive = clockwise seen from above, i.e. to the element's right).
static func rotate(heading: Vector3, radians: float) -> Vector3:
	var forward := flat(heading)
	# Turning right means turning toward the element's own right vector, (-forward.z, 0, forward.x).
	return (forward * cos(radians) + Vector3(-forward.z, 0.0, forward.x) * sin(radians)).normalized()


## A horizontal unit vector; Vector3.FORWARD when there's nothing to normalize.
static func flat(direction: Vector3) -> Vector3:
	var forward := Vector3(direction.x, 0.0, direction.z)
	return Vector3.FORWARD if forward.length_squared() < 1e-6 else forward.normalized()


static func _extent(slots: Array[Vector2], across: bool) -> float:
	if slots.is_empty():
		return 0.0
	var low := INF
	var high := -INF
	for slot in slots:
		var value := slot.x if across else slot.y
		low = minf(low, value)
		high = maxf(high, value)
	return high - low
