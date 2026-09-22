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


## Round 10 (nav's finding on the Terminus): the nearest standable point where a HULL fits, not just its centre.
## `standable()` stops at the navmesh's EDGE, which the bake keeps only BAKE_RADIUS clear of a wall, so a bus or a
## War Rig centred there has its nose in the building (nav's drive rows: arrival misses in every arm with the goal 4-10
## m off the mesh, and the mover pressing the nose into the face). `clearance` is the hull's own (the turning envelope:
## half its diagonal): from the grounded point, CLEARANCE_PROBES directions are probed at `clearance - BAKE_RADIUS`,
## and every probe that falls off the mesh pushes the point back by how far off it fell. In a street narrower than the
## envelope the pushes from the two walls cancel, and the hull ends in the middle, which is the best there is.
const CLEARANCE_PROBES := 8
const CLEARANCE_ITERATIONS := 3


static func standable_for(node: Node3D, point: Vector3, clearance: float) -> Vector3:
	var at := standable(node, point)
	var need := clearance - bake_radius()
	if need <= 0.0 or node == null or not node.is_inside_tree() or not Pathing.enabled or not Pathing.is_ready(node):
		return at
	var map := node.get_world_3d().navigation_map
	for iteration in CLEARANCE_ITERATIONS:
		var push := Vector3.ZERO
		for k in CLEARANCE_PROBES:
			var angle := TAU * float(k) / float(CLEARANCE_PROBES)
			var probe := Vector3(at.x + cos(angle) * need, 0.0, at.z + sin(angle) * need)
			var closest := NavigationServer3D.map_get_closest_point(map, probe)
			var back := Vector3(closest.x - probe.x, 0.0, closest.z - probe.z)
			if back.length() > TOLERANCE_M:
				push += back
		if push.length() <= TOLERANCE_M:
			break
		at = standable(node, at + push / float(CLEARANCE_PROBES) * 2.0)
	return at


## The navmesh bake's agent radius (ArenaLanes reads it off arena.tscn); cached, it is a scene constant.
static var _bake := -1.0


static func bake_radius() -> float:
	if _bake < 0.0:
		_bake = ArenaLanes.bake_radius()
	return _bake


## A hull's turning envelope: half its diagonal (0 for a unit the catalogue does not know).
static func envelope_of(unit_id: String) -> float:
	if not Units.exists(unit_id):
		return 0.0
	var hull: Array = Units.stat(unit_id, "hull_size", [0.0, 0.0, 0.0])
	return 0.5 * Vector2(float(hull[0]), float(hull[2])).length()


## Whether `point` is standable as it is.
static func is_standable(node: Node3D, point: Vector3) -> bool:
	return standable(node, point) == point


# ---- Corridor width (round 9, X2 / catalogue A8) --------------------------------------------------------
#
# A8 deforms a formation as a function of the CORRIDOR WIDTH it is driving through, so something has to measure
# that width. nav's `Movement.state()` (contract N1) reports phase, ETA, remaining distance, the route's points and
# what blocks a unit — it does NOT report a clearance, so the seam A8 wanted is not there yet, and the brief's
# instruction in that case is to measure it here and record the request (it is recorded in the brief's Status).
# This file is already the one place that asks "can a vehicle stand here", and it asks the navigation mesh rather
# than geometry of its own, so the width is measured the same way: the mesh's polygons already leave a vehicle's
# radius clear of every obstacle, so the standable width across the heading IS the drivable corridor.
#
# It is deliberately COARSE and CHEAP. It is sampled at three points along the leg (the narrowest wins, because a
# formation has to fit the tightest part of what it is driving through) and the edge on each side is found by
# bisection, so one measurement is ~40 navmesh queries — and `Element` takes one per LEG, not per update.

## How far out a side is probed before the corridor counts as open (meters each side).
const CORRIDOR_REACH_M := 40.0
## Bisection steps per side: 40 m resolved to ~1.25 m, which is finer than a hull is wide.
const CORRIDOR_STEPS := 5
## How far apart the samples along the leg are (metres), and how many there may be. FOUND BY MEASUREMENT, not chosen:
## the first defile run sampled a 56 m leg at 0.3 / 0.55 / 0.8 and reported the corridor as OPEN, because the maze's
## container bands are a few metres thick and all three samples landed in the open ground BETWEEN them. A probe that
## can only see a defile if a sample happens to land on it is a probe that reports whatever it stepped over. The
## spacing is under a band's thickness so a band cannot be straddled, and the cap bounds the work: at most
## CORRIDOR_MAX_SAMPLES x 2 x (CORRIDOR_STEPS + 1) navmesh queries, once per LEG.
const CORRIDOR_SAMPLE_M := 4.0
const CORRIDOR_MAX_SAMPLES := 16
const CORRIDOR_MIN_SAMPLES := 3


## The narrowest drivable width (meters) across `heading` along the leg from `from` to `to`, or INF when there is no
## answer worth having — then A8 keeps the formation it has.
##
## INF means OPEN, and it means it in three different cases, all of which must give the identity rather than a number:
## the navigation map cannot answer (early frames, a test with no arena); the leg's own line is not on the mesh at any
## sample; or **the ground is standable all the way out to CORRIDOR_REACH_M on both sides**. That last one is the
## subtle one: capping the answer at 2 x CORRIDOR_REACH_M would report an open arena as 80 m wide, and a formation
## naturally wider than that — an eight-vehicle wedge at open spacing is over 100 m across — would be squeezed
## forever in the middle of an empty field. A probe that hits its own limit has not measured a corridor; it has failed
## to find one, which is the same thing as open.
static func corridor_width(node: Node3D, from: Vector3, to: Vector3, heading: Vector3) -> float:
	if node == null or not node.is_inside_tree() or not Pathing.enabled or not Pathing.is_ready(node):
		return INF
	var across := Vector3(-heading.z, 0.0, heading.x).normalized()
	if across.length_squared() < 0.5:
		return INF
	var narrowest := INF
	# Evenly spaced along the leg, excluding both ends: the ends are usually inside an open area (a start zone, an
	# objective) and it is what the leg passes THROUGH that decides whether a formation fits.
	var span := Vector2(to.x - from.x, to.z - from.z).length()
	var count := clampi(int(round(span / CORRIDOR_SAMPLE_M)), CORRIDOR_MIN_SAMPLES, CORRIDOR_MAX_SAMPLES)
	for step in count:
		var fraction := float(step + 1) / float(count + 1)
		var at: Vector3 = from.lerp(to, fraction)
		if not is_standable(node, at):
			continue  # the leg's own line is off the mesh here: nothing sensible to measure, and not A8's business
		var left := _reach(node, at, across)
		var right := _reach(node, at, -across)
		if left >= CORRIDOR_REACH_M and right >= CORRIDOR_REACH_M:
			continue  # open as far as this probe reaches: no corridor found here
		narrowest = minf(narrowest, left + right)
	return narrowest


## How far a vehicle can stand out from `at` along `direction`, by bisection (meters, at most CORRIDOR_REACH_M).
static func _reach(node: Node3D, at: Vector3, direction: Vector3) -> float:
	if is_standable(node, at + direction * CORRIDOR_REACH_M):
		return CORRIDOR_REACH_M
	var low := 0.0
	var high := CORRIDOR_REACH_M
	for _i in CORRIDOR_STEPS:
		var middle := (low + high) * 0.5
		if is_standable(node, at + direction * middle):
			low = middle
		else:
			high = middle
	return low
