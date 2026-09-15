class_name TacticalQuery
extends RefCounted
## Tactical position evaluation (_agents/unit_ai.md §2, after Killzone, CryEngine's TPS, Unreal's EQS):
## GENERATE candidate points (the CoverMap's static points near me), FILTER cheaply (distance, leash,
## friendly spacing, obstacles), SCORE with weighted criteria, running line-of-sight tests last and only on
## the survivors. Pure: the same map and request give the same answer.
##
## Request (Dictionary):
##   "position": Vector3                      the asking tank
##   "threats": [{"position": Vector3, "weight": float}]   known enemies, most dangerous first (≤ MAX_THREATS used)
##   "target": Vector3 or null                what I want to shoot (cover_fire, lane)
##   "friends": [Vector3]                     teammates' positions (spacing, lines of fire)
##   "anchor": Vector3 or null, "anchor_radius": float   player intent: stay near the squad slot / objective
##   "search_radius": float                   how far to look (default SEARCH_RADIUS)
##   "range": [min, max, reach]               weapon: preferred band and maximum range (cover_fire, lane)

const SEARCH_RADIUS := 30.0
const MAX_THREATS := 6
## Candidates kept (nearest first) before line-of-sight tests...
const MAX_CANDIDATES := 16
## ...and how many of the best get the expensive tests (peek search, every threat).
const MAX_DEEP := 8
## Candidates closer than this to a friend are skipped (splash, blocking each other's lanes).
const FRIEND_SPACING := 5.0
## Peek spots: these many degrees off the bearing to the target, smallest first (up to Armor.ARC_DEG 45 the
## front armor stays toward it; 60 gets around a wall's end at the cost of showing some side while out),
const PEEK_ANGLES_DEG := [30.0, 45.0, 60.0]
## at these distances from the hide spot (meters), shortest first.
const PEEK_STEPS := [3.0, 4.5, 6.0, 7.5, 9.0]
const PEEK_MAX := 10.5
## A drive between hide and peek keeps this far from obstacles (half a hull plus a margin).
const DRIVE_CLEARANCE := 1.3
## A spot where a tank can sit: this far outside obstacles.
const STAND_CLEARANCE := 2.4
## A hiding place must hide the whole hull, not just its center: sight lines to points this far to either
## side (across the line of sight) must be blocked too.
const HULL_MARGIN := 1.6
## Peek this much past the first spot that sees the target, so the tank is clearly out when it stops.
const PEEK_MARGIN := 1.5


## Up to `count` hiding places, best first: [{"point": Vector3, "score": float, "cover": float}].
## Cover counts threats (by weight) whose sight line to the point is blocked; a place must hide from at
## least half the threat weight, and places toward the main threat are penalized.
static func find_cover(map: CoverMap, request: Dictionary, count := 3) -> Array:
	var me: Vector3 = request["position"]
	var threats := _threats(request)
	if threats.is_empty():
		return []
	var radius := float(request.get("search_radius", SEARCH_RADIUS))
	var main_threat: Vector3 = threats[0]["position"]
	var my_threat_distance := _flat_distance(me, main_threat)
	var scored: Array = []
	for index in _candidates(map, request, radius):
		var point := _point3(map.points[index])
		var cover := _cover(map, point, threats)
		if cover < 0.5:
			continue
		var travel := 1.0 - _flat_distance(me, point) / radius
		var toward := UtilityCurves.linear(my_threat_distance - _flat_distance(point, main_threat), 0.0, 15.0)
		var score := (0.6 * cover + 0.25 * travel + 0.15 * _spacing(point, request)) * (1.0 - 0.5 * toward)
		scored.append({"point": point, "score": snappedf(score, 0.0001), "cover": cover, "order": scored.size()})
	return _best(scored, count)


## A place to fight from cover: {"hide": Vector3, "peek": Vector3, "score": float} or {} if none.
## HIDE hides the whole hull from the target and is inside weapon reach; PEEK is 3–10.5 m away, within
## 30–60° of the bearing to the target, drivable in a straight line, and sees the target. Driving forward to
## peek and reversing to hide keeps the front armor (mostly) toward the target.
static func find_cover_fire(map: CoverMap, request: Dictionary) -> Dictionary:
	if request.get("target") == null:
		return {}
	var me: Vector3 = request["position"]
	var target: Vector3 = request["target"]
	var band: Array = request.get("range", [20.0, 45.0, 70.0])
	var radius := float(request.get("search_radius", SEARCH_RADIUS))
	var threats := _threats(request)
	var shortlist: Array = []
	for index in _candidates(map, request, radius):
		var point := _point3(map.points[index])
		var to_target := _flat_distance(point, target)
		if to_target > float(band[2]) - 4.0 or to_target < 8.0:
			continue
		if not hull_hidden(map, target, point):
			continue  # the target sees (part of) it: not a hiding place
		var travel := 1.0 - _flat_distance(me, point) / radius
		var fit := UtilityCurves.band(to_target, float(band[0]), float(band[1]), 20.0)
		shortlist.append({"index": index, "point": point, "pre": 0.55 * fit + 0.45 * travel, "fit": fit, "travel": travel,
				"order": shortlist.size()})
	shortlist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["pre"] > b["pre"] or (a["pre"] == b["pre"] and a["order"] < b["order"]))
	var best := {}
	for entry in shortlist.slice(0, MAX_DEEP):
		var hide: Vector3 = entry["point"]
		var peek: Variant = peek_from(map, hide, target, float(band[2]))
		if peek == null:
			continue
		var others := _cover(map, hide, threats) if not threats.is_empty() else 1.0
		var out := Vector2(peek.x - hide.x, peek.z - hide.z)
		var off_bearing := absf(rad_to_deg(out.angle_to(Vector2(target.x - hide.x, target.z - hide.z))))
		var peek_quality := 0.5 * (1.0 - out.length() / PEEK_MAX) + 0.5 * (1.0 - off_bearing / 90.0)
		var score := 0.35 * float(entry["fit"]) + 0.25 * float(entry["travel"]) + 0.25 * others + 0.15 * peek_quality
		if best.is_empty() or score > float(best["score"]):
			best = {"hide": hide, "peek": peek, "score": snappedf(score, 0.0001)}
	return best


## The nearest peek spot for `hide` against `target`, or null.
static func peek_from(map: CoverMap, hide: Vector3, target: Vector3, reach: float) -> Variant:
	var bearing := Vector2(target.x - hide.x, target.z - hide.z)
	if bearing.length_squared() < 1.0:
		return null
	bearing = bearing.normalized()
	var start := Vector2(hide.x, hide.z)
	for distance: float in PEEK_STEPS:
		for angle: float in PEEK_ANGLES_DEG:
			for side in [1.0, -1.0]:
				var direction := bearing.rotated(side * deg_to_rad(angle))
				var peek: Variant = _peek_spot(map, start, direction, distance, target, reach)
				if peek == null:
					continue
				# Step a little further out if that's still a good spot, so the stop isn't on the shadow's edge.
				var further: Variant = _peek_spot(map, start, direction, distance + PEEK_MARGIN, target, reach)
				return further if further != null else peek
	return null


static func _peek_spot(map: CoverMap, start: Vector2, direction: Vector2, distance: float, target: Vector3,
		reach: float) -> Variant:
	var flat := start + direction * distance
	if absf(flat.x) > CoverMap.EDGE or absf(flat.y) > CoverMap.EDGE:
		return null
	if map.inside_any(flat, STAND_CLEARANCE) or map.path_blocked(start, flat, DRIVE_CLEARANCE):
		return null
	var peek := Vector3(flat.x, 0.0, flat.y)
	if _flat_distance(peek, target) > reach - 2.0 or not map.clear_line(peek, target):
		return null
	return peek


## True if no part of a hull at `point` is in sight of `viewer`: the center and HULL_MARGIN to either side.
static func hull_hidden(map: CoverMap, viewer: Vector3, point: Vector3) -> bool:
	if map.clear_line(viewer, point):
		return false
	var across := Vector3(point.z - viewer.z, 0.0, viewer.x - point.x)
	if across.length_squared() < 0.01:
		return true
	across = across.normalized() * HULL_MARGIN
	return not map.clear_line(viewer, point + across) and not map.clear_line(viewer, point - across)


## Whether a spot is out of every listed threat's sight (by weight): 0..1. The whole hull must be hidden
## from the main (first) threat; the others are checked at the hull's center (cheaper).
static func _cover(map: CoverMap, point: Vector3, threats: Array) -> float:
	var total := 0.0
	var hidden := 0.0
	for i in threats.size():
		var threat: Dictionary = threats[i]
		var weight := float(threat.get("weight", 1.0))
		total += weight
		if hull_hidden(map, threat["position"], point) if i == 0 else not map.clear_line(threat["position"], point):
			hidden += weight
	return hidden / total if total > 0.0 else 1.0


## Static points within `radius`, filtered by leash and friend spacing, nearest MAX_CANDIDATES.
static func _candidates(map: CoverMap, request: Dictionary, radius: float) -> PackedInt32Array:
	var me: Vector3 = request["position"]
	var anchor: Variant = request.get("anchor")
	var anchor_radius := float(request.get("anchor_radius", 0.0))
	var friends: Array = request.get("friends", [])
	var result := PackedInt32Array()
	for index in map.points_near(Vector2(me.x, me.z), radius):
		var point := map.points[index]
		if anchor != null and anchor_radius > 0.0 and point.distance_to(Vector2(anchor.x, anchor.z)) > anchor_radius:
			continue
		var crowded := false
		for friend: Vector3 in friends:
			if point.distance_to(Vector2(friend.x, friend.z)) < FRIEND_SPACING:
				crowded = true
				break
		if crowded:
			continue
		result.append(index)
		if result.size() >= MAX_CANDIDATES:
			break
	return result


static func _threats(request: Dictionary) -> Array:
	var threats: Array = request.get("threats", [])
	return threats.slice(0, MAX_THREATS)


static func _spacing(point: Vector3, request: Dictionary) -> float:
	var nearest := INF
	for friend: Vector3 in request.get("friends", []):
		nearest = minf(nearest, _flat_distance(point, friend))
	return 1.0 if nearest == INF else UtilityCurves.smooth(nearest, FRIEND_SPACING, 14.0)


static func _best(scored: Array, count: int) -> Array:
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] > b["score"] or (a["score"] == b["score"] and a["order"] < b["order"]))
	var result: Array = []
	for entry: Dictionary in scored.slice(0, count):
		entry.erase("order")
		result.append(entry)
	return result


static func _point3(point: Vector2) -> Vector3:
	return Vector3(point.x, 0.0, point.y)


static func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()
