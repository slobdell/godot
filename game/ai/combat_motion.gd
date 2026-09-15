class_name CombatMotion
extends RefCounted
## Movement while fighting (round-3 X2, _agents/unit_ai.md "Alive in combat"). The lead: *"Tanks will just sit there
## stationary and shoot each other - there's no intent at evasive action … no intent of trying to circle your
## opponent (i.e. move tangentially from your opponent while shooting at him)."*
##
## Context steering (Andrew Fray, "Context Steering", Game AI Pro 2, 2015): score a fixed ring of candidate
## directions (forward and reversing) on interest terms, mask the dangerous ones, and drive toward the best. Pure and
## portable: directions are constants, every term is a dot or cross product (no runtime trig), ties go to the lower
## index, so the same request always gives the same answer (_agents/determinism.md).
##
## Styles (STYLES):
##   strafe  turret units: circle the target inside the weapon's band, tangential, jinking sides now and then
##   angle   heavy tracked units: the same, but keep the thick front toward the target (oblique arcs, reversing)
##   run     fixed guns (the scout's machine gun): attack runs at the target's side and rear, then break away
##
## request: {"position", "forward" (flat unit), "speed" (m/s top), "reverse_speed", "style",
##           "target": {"position", "forward", "velocity"?}, "band": [min, max] (preferred range),
##           "side": +1 / -1 (which way around; the caller flips it to jink), "phase": "run" | "extend" (run style),
##           "map": CoverMap or null, "friends": [Vector3], "limit": arena half size (meters),
##           "wheels": bool, "min_turn_radius": meters (wheels)}
## result:  {"point": Vector3 (steer at it), "reverse": bool, "index": int, "score": float} or {} when every
##          direction is blocked.

const STYLES := ["strafe", "angle", "run"]
## 16 directions around the compass (x, z), every 22.5°, as constants.
const RING: Array[Vector2] = [Vector2(0, -1), Vector2(0.38268343, -0.9238795), Vector2(0.70710678, -0.70710678),
		Vector2(0.9238795, -0.38268343), Vector2(1, 0), Vector2(0.9238795, 0.38268343), Vector2(0.70710678, 0.70710678),
		Vector2(0.38268343, 0.9238795), Vector2(0, 1), Vector2(-0.38268343, 0.9238795), Vector2(-0.70710678, 0.70710678),
		Vector2(-0.9238795, 0.38268343), Vector2(-1, 0), Vector2(-0.9238795, -0.38268343), Vector2(-0.70710678, -0.70710678),
		Vector2(-0.38268343, -0.9238795)]
## How far ahead a candidate is judged (seconds of driving), clamped to [MIN_TRAVEL, MAX_TRAVEL] meters...
const HORIZON_SECONDS := 1.2
const MIN_TRAVEL := 5.0
const MAX_TRAVEL := 14.0
## ...and how far out the steer point sits (far enough that steering never slows for arrival).
const STEER_DISTANCE := 12.0
## Hull clearance from obstacles along the way, and from friends at the end (meters).
const OBSTACLE_GROW := 2.2
const FRIEND_SPACING := 7.0
## Never closer to the target than this (meters), except on a run.
const MIN_GAP := 6.0
## Term weights per style: range band, tangential motion, keeping the chosen side, working toward the target's side and
## rear, front armor toward the target, and continuity with the current heading.
const WEIGHTS := {
	"strafe": {"range": 1.0, "tangent": 0.8, "side": 0.35, "flank": 0.35, "armor": 0.15, "continuity": 0.25, "reverse": 0.6},
	"angle": {"range": 1.0, "tangent": 0.45, "side": 0.3, "flank": 0.25, "armor": 0.7, "continuity": 0.25, "reverse": 0.75},
	"run": {"range": 0.0, "tangent": 0.3, "side": 0.2, "flank": 0.6, "armor": 0.0, "continuity": 0.45, "reverse": 0.0},
}
## Run style: how far past the target's flank a run aims (meters), and the distances where a run breaks away and where
## the extension turns back in.
const RUN_OFFSET := 5.0
const RUN_BREAK := 9.0
const RUN_RETURN := 30.0


static func choose(request: Dictionary) -> Dictionary:
	var style: String = request.get("style", "strafe")
	var weights: Dictionary = WEIGHTS.get(style, WEIGHTS["strafe"])
	var here := _flat(request["position"])
	var forward := _flat(request["forward"]).normalized()
	var target: Dictionary = request["target"]
	var target_at := _flat(target["position"])
	var target_forward := _flat(target.get("forward", Vector3.FORWARD)).normalized()
	var to_target := target_at - here
	var distance := maxf(to_target.length(), 0.1)
	var bearing := to_target / distance
	var band: Array = request.get("band", [15.0, 40.0])
	var side := 1.0 if float(request.get("side", 1.0)) >= 0.0 else -1.0
	var phase: String = request.get("phase", "run")
	var map: CoverMap = request.get("map")
	var friends: Array = request.get("friends", [])
	var limit := float(request.get("limit", Match.DRIVABLE_LIMIT)) - 4.0
	var travel_forward := clampf(float(request["speed"]) * HORIZON_SECONDS, MIN_TRAVEL, MAX_TRAVEL)
	var travel_reverse := clampf(float(request.get("reverse_speed", 0.0)) * HORIZON_SECONDS, 0.0, MAX_TRAVEL)
	var wheels: bool = request.get("wheels", false)
	# Wheels can't swing far in one horizon: cos of the widest heading change a turning circle allows (chord math:
	# a heading change θ over arc length s needs radius s/θ; small-angle cos ≈ 1 - θ²/2).
	var min_cos := -1.0
	if wheels and float(request.get("min_turn_radius", 0.0)) > 0.0:
		var theta := travel_forward / float(request["min_turn_radius"])
		min_cos = maxf(-1.0, 1.0 - theta * theta / 2.0) if theta < 2.0 else -1.0
	# A run aims past the target's flank on my side of it; the extension heads out and around.
	var run_goal := target_at
	if style == "run":
		var across := Vector3(-bearing.z, 0.0, bearing.x) * side
		run_goal = target_at + across * RUN_OFFSET
	var scored: Array = []
	for i in RING.size():
		var ring := Vector3(RING[i].x, 0.0, RING[i].y)
		for reverse: bool in [false, true]:
			var travel := travel_reverse if reverse else travel_forward
			if travel <= 0.0 or (reverse and float(weights["reverse"]) <= 0.0):
				continue
			var hull := -ring if reverse else ring
			var turn_cos := hull.dot(forward)
			if wheels and turn_cos < min_cos:
				continue
			var end := here + ring * travel
			var from_target := end - target_at
			var gap := maxf(from_target.length(), 0.1)
			var tangent := absf(ring.x * bearing.z - ring.z * bearing.x)
			# Which way around the target this goes: + = counter-clockwise seen from above... only its sign matters.
			var around := bearing.x * ring.z - bearing.z * ring.x
			var score := 0.0
			match style:
				"run":
					var toward := (_flat(run_goal) - here).normalized()
					if phase == "run":
						score += 1.0 * maxf(0.0, ring.dot(toward))
					else:
						score += 0.8 * maxf(0.0, -ring.dot(bearing)) + 0.6 * tangent
				_:
					score += float(weights["range"]) * _band(gap, float(band[0]), float(band[1]))
					score += float(weights["tangent"]) * tangent
			score += float(weights["side"]) * (1.0 if around * side > 0.0 else 0.0)
			score += float(weights["flank"]) * (1.0 - target_forward.dot(from_target / gap)) * 0.5
			var new_bearing := (target_at - end) / gap
			score += float(weights["armor"]) * maxf(0.0, hull.dot(new_bearing))
			score += float(weights["continuity"]) * (turn_cos + 1.0) * 0.5
			if reverse:
				score *= float(weights["reverse"])
			# Don't ram it: the closest the path passes to the target (a run's approach aims beside it on purpose).
			var along := clampf((target_at - here).dot(ring), 0.0, travel)
			var passes := (here + ring * along).distance_to(target_at)
			if (style != "run" or phase != "run") and minf(gap, passes) < MIN_GAP:
				score *= 0.2
			for friend: Vector3 in friends:
				if _flat(friend).distance_to(end) < FRIEND_SPACING:
					score *= 0.4
					break
			scored.append([-score, i, reverse, end])
	scored.sort()
	# Dangers last, best first: only the winner's path is checked in the common case.
	for entry: Array in scored:
		var end: Vector3 = entry[3]
		if absf(end.x) > limit or absf(end.z) > limit:
			continue
		if map != null and (map.path_blocked(Vector2(here.x, here.z), Vector2(end.x, end.z), OBSTACLE_GROW)
				or map.inside_any(Vector2(end.x, end.z), OBSTACLE_GROW)):
			continue
		var direction := Vector3(RING[entry[1]].x, 0.0, RING[entry[1]].y)
		var point := here + direction * STEER_DISTANCE
		point.x = clampf(point.x, -limit, limit)
		point.z = clampf(point.z, -limit, limit)
		return {"point": point, "reverse": entry[2], "index": entry[1], "score": -float(entry[0])}
	return {}


## 1 inside [low, high], falling off linearly to 0 over 12 m below and 20 m above.
static func _band(value: float, low: float, high: float) -> float:
	if value < low:
		return maxf(0.0, 1.0 - (low - value) / 12.0)
	if value > high:
		return maxf(0.0, 1.0 - (value - high) / 20.0)
	return 1.0


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
