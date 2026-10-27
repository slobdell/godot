class_name FiringPosition
extends RefCounted
## Round 42 (engage E2, C42.2): WHERE A CREW GOES TO GET A SHOT. His playtest after round 41 (Locks, seed 49326): a Rat
## Rod under his attack order sat 37 s behind a 20-ft container, 26 m from the Missile Ring, NOT FIRING, because "in
## range" was a distance. *"If I tell my units to attack I expect them to navigate around obstacles and toward the enemy
## such that they can and do attack."*
##
## Pure: the arena's cover as the CoverMap (the same 2D boxes the brains reason with, so a plan tick asks no physics),
## a crew, its target, its gun's band and its friends in. Candidates ring the TARGET at fractions of the crew's
## effective range (inside the band the brain holds at, so the crew stops and fires on arrival), on a fixed table of
## directions (no trig at decision time: _agents/determinism.md). Each candidate is kept only if a tank can stand
## there, it is inside the arena, its line to the target is clear, it is in the gun's band, it is within SEARCH_M of
## the crew (the bounded search: past it the plan keeps closing straight) and no friend stands or is sent within
## FRIEND_CLEAR_M. Cost = the straight drive, + DETOUR_PENALTY_M when that straight line crosses a feature (the real
## route goes round), + AWAY_PENALTY_M when the spot is farther from the target than the crew is now (toward the enemy,
## never away unless nothing nearer exists). The previous spot is kept while it is still valid and within HYSTERESIS_M
## of the best (no dither between two spots of equal worth). Ties go to the first candidate in table order.

## Fractions of the crew's effective range the rings sit at, nearest the band's top first.
const RING_FRACTIONS := [0.9, 0.75, 0.6, 0.45]
## 24 directions round the target, 15 deg apart, as [cos, sin] (x, z) constants.
const DIRECTIONS := [
	[1.0, 0.0], [0.9659258, 0.2588190], [0.8660254, 0.5], [0.7071068, 0.7071068], [0.5, 0.8660254], [0.2588190, 0.9659258],
	[0.0, 1.0], [-0.2588190, 0.9659258], [-0.5, 0.8660254], [-0.7071068, 0.7071068], [-0.8660254, 0.5], [-0.9659258, 0.2588190],
	[-1.0, 0.0], [-0.9659258, -0.2588190], [-0.8660254, -0.5], [-0.7071068, -0.7071068], [-0.5, -0.8660254], [-0.2588190, -0.9659258],
	[0.0, -1.0], [0.2588190, -0.9659258], [0.5, -0.8660254], [0.7071068, -0.7071068], [0.8660254, -0.5], [0.9659258, -0.2588190]]
## The bounded search: a spot farther than this from the crew is not offered (the crew keeps closing straight instead).
const SEARCH_M := 45.0
## No spot this close to a friend's hull or a friend's spot (splash, and each other's lanes).
const FRIEND_CLEAR_M := 5.0
## The previous spot is kept while its cost is within this of the best new one.
const HYSTERESIS_M := 8.0
## A spot whose straight line from the crew crosses a feature costs this much extra (the route goes round).
const DETOUR_PENALTY_M := 12.0
## A spot farther from the target than the crew stands now costs this much extra (never away unless nothing nearer).
const AWAY_PENALTY_M := 20.0
## A spot never closer to the target than this (ramming range, the gun's minimum).
const MIN_STANDOFF_M := 6.0
## How far a candidate's straight line is grown when asked whether it crosses a feature (half a hull).
const PATH_GROW := 1.5
## Candidates stay this far inside the drivable limit.
const EDGE_M := 6.0

## Measurement only (never read by decisions): spots found / none found / previous kept, since the process started.
static var found := 0
static var none := 0
static var kept := 0


## {"point": Vector3, "cost": float, "kept": bool} or {} when no candidate within the bounded search has a shot.
## `friends`: Array of Vector3 (other crews' positions and the spots already dealt this plan); `previous`: the spot
## this crew was last sent to (Vector3) or null; `min_m`: the gun's preferred minimum (0 = MIN_STANDOFF_M).
static func find(map: CoverMap, crew: Vector3, target: Vector3, effective_range: float, min_m: float,
		friends: Array, previous: Variant = null) -> Dictionary:
	var here := Vector3(crew.x, 0.0, crew.z)
	var at := Vector3(target.x, 0.0, target.z)
	var crew_distance := here.distance_to(at)
	var low := maxf(min_m, MIN_STANDOFF_M)
	var best := {}
	var best_cost := INF
	for fraction: float in RING_FRACTIONS:
		var radius := effective_range * fraction
		if radius < low + 1.0:
			continue
		for direction: Array in DIRECTIONS:
			var point := Vector3(at.x + float(direction[0]) * radius, 0.0, at.z + float(direction[1]) * radius)
			var cost := cost_of(map, here, at, point, effective_range, low, friends, crew_distance)
			if cost < best_cost:
				best = {"point": point, "cost": cost, "kept": false}
				best_cost = cost
	if previous is Vector3:
		var prior := Vector3((previous as Vector3).x, 0.0, (previous as Vector3).z)
		var cost := cost_of(map, here, at, prior, effective_range, low, friends, crew_distance)
		if cost < INF and cost <= best_cost + HYSTERESIS_M:
			kept += 1
			return {"point": prior, "cost": cost, "kept": true}
	if best.is_empty():
		none += 1
	else:
		found += 1
	return best


## The cost of standing at `point` to shoot `target` from `crew`; INF when it is no firing position at all.
static func cost_of(map: CoverMap, crew: Vector3, target: Vector3, point: Vector3, effective_range: float, low: float,
		friends: Array, crew_distance: float) -> float:
	var limit := Match.DRIVABLE_LIMIT - EDGE_M
	if absf(point.x) > limit or absf(point.z) > limit:
		return INF
	var to_target := point.distance_to(target)
	if to_target > effective_range or to_target < low:
		return INF
	var drive := crew.distance_to(point)
	if drive > SEARCH_M:
		return INF
	var flat := Vector2(point.x, point.z)
	if map != null and map.inside_any(flat, CoverMap.STAND_CLEARANCE):
		return INF
	if map != null and not map.clear_line(point, target):
		return INF
	for friend: Vector3 in friends:
		if Vector2(friend.x - point.x, friend.z - point.z).length() < FRIEND_CLEAR_M:
			return INF
	var cost := drive
	if map != null and map.path_blocked(Vector2(crew.x, crew.z), flat, PATH_GROW):
		cost += DETOUR_PENALTY_M
	if to_target > crew_distance + 1.0:
		cost += AWAY_PENALTY_M
	return cost
