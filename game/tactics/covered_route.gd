class_name CoveredRoute
extends RefCounted
## X7 (round 6): the lead wants *"to be able to set up ambushes, do flanking maneuvers"*. A flank that drives straight
## across the enemy's front is not a flank; it is a charge at an angle. An element tasked round a flank should take
## the route the enemy can see least of — along a lane behind cover, or wide of the direct line — and pay for the
## extra distance only when it buys concealment.
##
## Pure: a CoverMap (sight lines against the arena's obstacles), the known enemy positions and the arena's annotated
## lanes (M2) in, waypoints out. Routes are scored on straight segments; navigation (nav's N1) drives each leg, so a
## segment through an obstacle costs a detour this estimate does not see — which only makes the direct route look
## better than it is, never worse.
##
##   CoveredRoute.choose(map, from, to, threats, sight, lanes) ->
##     {"waypoints": [Vector3, ..., to], "exposed_m", "length_m", "direct_exposed_m", "via"}

## Routes are sampled every this many meters for exposure.
const SAMPLE_M := 8.0
## One meter in the enemy's sight is worth this many meters of extra driving to avoid.
const EXPOSED_COST := 4.0
## Detours tried: the midpoint pushed this fraction of the route's length to either side.
const DETOURS := [0.35, 0.6]
## A lane is only worth joining if its nearest point is within this far of the start (meters).
const LANE_REACH_M := 60.0


## The least-exposed sensible route from `from` to `to`. `threats`: enemy positions (Vector3); `sight`: how far they
## see (meters); `lanes`: Arena.lanes_of() entries ({"name", "points": PackedVector3Array, "width"}).
static func choose(map: CoverMap, from: Vector3, to: Vector3, threats: Array, sight: float, lanes: Array = []) -> Dictionary:
	var candidates: Array = [{"via": "direct", "waypoints": [to]}]
	var along := Vector3(to.x - from.x, 0.0, to.z - from.z)
	var length := along.length()
	if length > 1.0:
		var across := Vector3(-along.z, 0.0, along.x) / length
		var middle := from.lerp(to, 0.5)
		for fraction: float in DETOURS:
			for side in [1.0, -1.0]:
				candidates.append({"via": "wide %s %.2f" % ["right" if side > 0.0 else "left", fraction],
						"waypoints": [ElementPlan.clamp_to_arena(middle + across * side * length * fraction), to]})
	for lane: Dictionary in lanes:
		var points: PackedVector3Array = lane["points"]
		if points.size() < 2:
			continue
		var entry := _closest_on(points, from)
		if Vector2(entry["point"].x - from.x, entry["point"].z - from.z).length() > LANE_REACH_M:
			continue
		var exit := _closest_on(points, to)
		var waypoints: Array = [entry["point"]]
		var a: int = entry["segment"]
		var b: int = exit["segment"]
		# The lane's own vertices between where we join it and where we leave it, in travel order.
		if a < b:
			for i in range(a + 1, b + 1):
				waypoints.append(points[i])
		elif a > b:
			for i in range(a, b, -1):
				waypoints.append(points[i])
		waypoints.append(exit["point"])
		waypoints.append(to)
		candidates.append({"via": "lane " + String(lane["name"]), "waypoints": waypoints})
	var best: Dictionary = {}
	var best_cost := INF
	var direct_exposed := 0.0
	for candidate: Dictionary in candidates:
		var scored := _score(map, from, candidate["waypoints"], threats, sight)
		if candidate["via"] == "direct":
			direct_exposed = scored["exposed_m"]
		var cost: float = scored["length_m"] + EXPOSED_COST * scored["exposed_m"]
		if cost < best_cost - 0.01:
			best_cost = cost
			best = {"waypoints": candidate["waypoints"], "exposed_m": scored["exposed_m"], "length_m": scored["length_m"],
					"via": candidate["via"]}
	best["direct_exposed_m"] = direct_exposed
	return best


## How long a route is and how much of it (meters) some threat within `sight` has a clear line to.
static func _score(map: CoverMap, from: Vector3, waypoints: Array, threats: Array, sight: float) -> Dictionary:
	var length := 0.0
	var exposed := 0.0
	var at := from
	for waypoint: Vector3 in waypoints:
		var leg := Vector2(waypoint.x - at.x, waypoint.z - at.z).length()
		var steps := maxi(1, ceili(leg / SAMPLE_M))
		for k in steps:
			var point := at.lerp(waypoint, (k + 0.5) / float(steps))
			if _seen(map, point, threats, sight):
				exposed += leg / steps
		length += leg
		at = waypoint
	return {"length_m": length, "exposed_m": exposed}


static func _seen(map: CoverMap, point: Vector3, threats: Array, sight: float) -> bool:
	for threat: Vector3 in threats:
		if Vector2(threat.x - point.x, threat.z - point.z).length() <= sight and (map == null or map.clear_line_coarse(threat, point)):
			return true
	return false


## The closest point on a polyline to `point`: {"point", "segment" (index of the segment's first vertex)}.
static func _closest_on(points: PackedVector3Array, point: Vector3) -> Dictionary:
	var best := {"point": points[0], "segment": 0}
	var best_distance := INF
	for i in points.size() - 1:
		var on := Geometry3D.get_closest_point_to_segment(point, points[i], points[i + 1])
		var distance := Vector2(on.x - point.x, on.z - point.z).length()
		if distance < best_distance - 0.001:
			best_distance = distance
			best = {"point": Vector3(on.x, 0.0, on.z), "segment": i}
	return best
