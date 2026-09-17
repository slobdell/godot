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
##           "wheels": bool, "min_turn_radius": meters (wheels),
##           "velocity": Vector3 (current), "incoming": IncomingFire.for_unit() entries (X3: dodge them),
##           "acceleration": m/s², "turn_rate_deg": hull turn rate (the dodge model),
##           "threats": [{"position", "weight"}] other guns that can shoot me (front armor toward them too),
##           "target_busy": bool (its gun points at someone else: go for its side),
##           "leash": {"center": Vector3, "radius": float} (X1: fight within your formation slot, not all over the map),
##           "beaten": Callable(from, to) -> bool (X3, L2: is that route a wall of bullets? Routes that are get used
##                     only when every direction is one — the lead's "don't walk into a wall of bullets")}
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
## How many drivable candidates (best first) are checked for keeping the target in sight before settling for one that
## doesn't.
const SIGHT_CHECKS := 6
## Wheels steer at a point at least this many turning radii out: a closer point off the nose can sit inside the turning
## circle, where the wheel steering backs up, and the next plan picks the mirror point (a Lancer rocked 9 times in 15 s).
const WHEELS_STEER_RADII := 3.0
## Term weights per style: range band, tangential motion, keeping the chosen side, working toward the target's side and
## rear, front armor toward the target, and continuity with the current heading; "reverse" is subtracted from a
## reversing candidate (negative: never reverse) and "turn" per second the hull needs to swing onto it (a pivot is time
## standing still, the easiest shot there is: a jink should shuffle forward and back, not spin round).
const WEIGHTS := {
	"strafe": {"range": 1.0, "tangent": 0.8, "side": 0.35, "flank": 0.35, "armor": 0.15, "continuity": 0.1, "reverse": 0.25, "turn": 0.25},
	"angle": {"range": 1.0, "tangent": 0.35, "side": 0.35, "flank": 0.1, "armor": 1.0, "continuity": 0.2, "reverse": 0.1, "turn": 0.25},
	"run": {"range": 0.0, "tangent": 0.3, "side": 0.2, "flank": 0.6, "armor": 0.0, "continuity": 1.0, "reverse": -1.0, "turn": 0.0},
}
## Dangers are subtracted (scores can go below zero once turning costs are in): heading side-on in the angle style,
## passing too close to the target, ending next to a friend, and (X3) passing within HIT_RADIUS of an incoming round
## (would_be_hit models the hull's turn and acceleration, stepped every DODGE_STEP seconds).
const PENALTY_SIDE_ON := 1.5
const PENALTY_RAM := 1.2
const PENALTY_CROWD := 0.6
const PENALTY_HIT := 3.0
## X1: leaving the formation slot a unit was given. Soft, and it grows over LEASH_FALLOFF meters past the radius, so a
## unit still manoeuvres inside its slot's cell and is pulled back rather than frozen when something pushes it out.
const PENALTY_LEASH := 1.5
const LEASH_FALLOFF := 10.0
const HIT_RADIUS := 2.8
const DODGE_STEP := 0.1
## Turns longer than this (seconds) are pivots in place in the dodge model (≈ Steering.TURN_IN_PLACE_DEG at 90°/s).
const PIVOT_SECONDS := 0.75
## Front armor is weighed against every gun only for styles that care this much about it (the loop costs; light hulls
## barely weigh armor at all).
const MULTI_THREAT_ARMOR := 0.5
## A busy target (its gun on someone else): flank weight and the armor weight's factor.
const BUSY_FLANK := 1.2
const BUSY_ARMOR := 0.3
## Angle style: a hull more than this far off the target (cos 50°) is masked unless the unit must close or open the range,
## so heavy hulls rock forward and back along one angled heading instead of turning side-on.
const ANGLE_MASK_COS := 0.64
## Run style: how far past the target's flank a run aims (meters), and the distances where a run breaks away and where
## the extension turns back in.
const RUN_OFFSET := 5.0
const RUN_BREAK := 9.0
const RUN_RETURN := 22.0
## ...and over the last this many meters before the break the run veers from dead-on to past its flank.
const RUN_VEER := 10.0


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
		# Straight at it (the gun on target) until the last RUN_VEER meters, then past its flank.
		var across := Vector3(-bearing.z, 0.0, bearing.x) * side
		run_goal = target_at + across * RUN_OFFSET * clampf((RUN_BREAK + RUN_VEER - distance) / RUN_VEER, 0.0, 1.0)
	var incoming: Array = request.get("incoming", [])
	var threats: Array = request.get("threats", [])
	# X3 weak spots: while the target's gun points at someone else, its side is there for the taking and my own front
	# matters less, so even a heavy hull swings wide for the angle.
	var busy: bool = request.get("target_busy", false)
	var flank_weight := BUSY_FLANK if busy else float(weights["flank"])
	var armor_weight := float(weights["armor"]) * (BUSY_ARMOR if busy else 1.0)
	var velocity_now := _flat(request.get("velocity", Vector3.ZERO))
	# X1: a unit fighting from a formation slot stays in it (mutual support, sectors of fire, armor facing).
	var leash: Dictionary = request.get("leash", {})
	var leash_center := _flat(leash.get("center", Vector3.ZERO))
	var leash_radius := float(leash.get("radius", 0.0))
	var scored: Array = []
	for i in RING.size():
		var ring := Vector3(RING[i].x, 0.0, RING[i].y)
		for reverse: bool in [false, true]:
			var travel := travel_reverse if reverse else travel_forward
			if travel <= 0.0 or (reverse and float(weights["reverse"]) < 0.0):
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
			score += flank_weight * (1.0 - target_forward.dot(from_target / gap)) * 0.5
			var new_bearing := (target_at - end) / gap
			var front := maxf(0.0, hull.dot(new_bearing))
			# Front armor toward everything that can shoot me, the target counting double (X3 "keep your front toward threats").
			if not threats.is_empty() and armor_weight >= MULTI_THREAT_ARMOR:
				var weighted := 2.0 * front
				var weight_sum := 2.0
				for threat: Dictionary in threats:
					var toward := _flat(threat["position"]) - end
					var length := toward.length()
					if length > 0.1:
						weighted += float(threat.get("weight", 1.0)) * maxf(0.0, hull.dot(toward / length))
						weight_sum += float(threat.get("weight", 1.0))
				front = weighted / weight_sum
			score += armor_weight * front
			if style == "angle" and not busy and hull.dot(bearing) < ANGLE_MASK_COS and _band(gap, float(band[0]), float(band[1])) >= 1.0:
				score -= PENALTY_SIDE_ON
			score += float(weights["continuity"]) * (turn_cos + 1.0) * 0.5
			var turning := 0.0 if wheels else CombatMotion.turn_seconds(turn_cos, float(request.get("turn_rate_deg", 90.0)))
			score -= float(weights["turn"]) * turning
			if reverse:
				score -= float(weights["reverse"])
			# Don't ram it: the closest the path passes to the target (a run's approach aims beside it on purpose).
			var along := clampf((target_at - here).dot(ring), 0.0, travel)
			var passes := (here + ring * along).distance_to(target_at)
			if (style != "run" or phase != "run") and minf(gap, passes) < MIN_GAP:
				score -= PENALTY_RAM
			if leash_radius > 0.0:
				var out := leash_center.distance_to(end) - leash_radius
				if out > 0.0:
					score -= PENALTY_LEASH * clampf(out / LEASH_FALLOFF, 0.0, 1.0)
			for friend: Vector3 in friends:
				if _flat(friend).distance_to(end) < FRIEND_SPACING:
					score -= PENALTY_CROWD
					break
			var undodged := score
			if not incoming.is_empty() and CombatMotion.would_be_hit(here, velocity_now,
					ring * (float(request.get("reverse_speed", 0.0)) if reverse else float(request["speed"])), incoming,
					turning,
					float(request.get("acceleration", 1000.0))):
				score -= PENALTY_HIT
			scored.append([-score, i, reverse, end, undodged])
	scored.sort()
	var best_undodged := -INF
	for entry: Array in scored:
		best_undodged = maxf(best_undodged, float(entry[4]))
	# Dangers last, best first: only the winner's path is checked in the common case. A spot that loses sight of the
	# target is used only if nothing in the first SIGHT_CHECKS does (circling behind cover loses the fight: a Lancer
	# circled out of view and wandered off after CP2).
	var fallback: Dictionary = {}
	var beaten_fallback: Dictionary = {}
	var beaten: Callable = request.get("beaten", Callable())
	var checked := 0
	for entry: Array in scored:
		var end: Vector3 = entry[3]
		if absf(end.x) > limit or absf(end.z) > limit:
			continue
		if map != null and (map.path_blocked(Vector2(here.x, here.z), Vector2(end.x, end.z), OBSTACLE_GROW)
				or map.inside_any(Vector2(end.x, end.z), OBSTACLE_GROW)):
			continue
		# X3 (L2): don't drive through a wall of bullets. Checked here, after the cheap filters and best-first, so it
		# costs one field query for the winner in the common case. Kept as a last resort: a unit boxed in by fire has
		# to go somewhere, and standing in it is worse than crossing it.
		if beaten.is_valid() and beaten.call(here, end):
			if beaten_fallback.is_empty():
				beaten_fallback = {"point": here + Vector3(RING[entry[1]].x, 0.0, RING[entry[1]].y) * STEER_DISTANCE,
						"reverse": entry[2], "index": entry[1], "score": -float(entry[0]), "dodging": false, "beaten": true}
			continue
		var direction := Vector3(RING[entry[1]].x, 0.0, RING[entry[1]].y)
		var steer := maxf(STEER_DISTANCE, float(request.get("min_turn_radius", 0.0)) * WHEELS_STEER_RADII) if wheels else STEER_DISTANCE
		var point := here + direction * steer
		point.x = clampf(point.x, -limit, limit)
		point.z = clampf(point.z, -limit, limit)
		# Dodging: without the incoming rounds, something better would have been picked.
		var result := {"point": point, "reverse": entry[2], "index": entry[1], "score": -float(entry[0]),
				"dodging": not incoming.is_empty() and float(entry[4]) < best_undodged - 0.001}
		if map == null or style == "run" or map.clear_line_coarse(end, target_at):
			return result
		if fallback.is_empty():
			fallback = result
		checked += 1
		if checked >= SIGHT_CHECKS:
			break
	if not fallback.is_empty():
		return fallback
	if not beaten_fallback.is_empty():
		return beaten_fallback
	# Boxed in: every end was inside an obstacle (or the path to it crossed one). Standing still in a fight is worse
	# than nudging out of the box, so take the best-scoring direction that stays inside the arena and let the next
	# plan (from the new spot) find clear ground.
	for entry: Array in scored:
		var end: Vector3 = entry[3]
		if absf(end.x) > limit or absf(end.z) > limit:
			continue
		var direction := Vector3(RING[entry[1]].x, 0.0, RING[entry[1]].y)
		var steer := maxf(STEER_DISTANCE, float(request.get("min_turn_radius", 0.0)) * WHEELS_STEER_RADII) if wheels else STEER_DISTANCE
		var point := here + direction * steer
		return {"point": Vector3(clampf(point.x, -limit, limit), point.y, clampf(point.z, -limit, limit)),
				"reverse": entry[2], "index": entry[1], "score": -float(entry[0]), "dodging": false, "boxed_in": true}
	return {}


## Whether a unit at `here` moving at `now` that sets out on `planned` passes within HIT_RADIUS of any incoming round
## before it arrives (plus a little: rounds arrive early when the unit drives toward them). Driving model: the current
## velocity holds while the hull turns onto the new heading (`turn_seconds`), then ramps toward `planned` at
## `acceleration` m/s². Stepped every DODGE_STEP seconds with an exact closest approach inside each step (pure).
static func would_be_hit(here: Vector3, now: Vector3, planned: Vector3, incoming: Array, turn_seconds := 0.0,
		acceleration := 1000.0) -> bool:
	for entry: Dictionary in incoming:
		var round_at: Vector3 = entry["position"]
		var round_velocity: Vector3 = entry["velocity"]
		var seconds := float(entry.get("eta_ticks", SimClock.TICK_RATE / 2)) / SimClock.TICK_RATE + 0.25
		var t := 0.0
		var position := here
		var velocity := now
		while t < seconds:
			var step := minf(DODGE_STEP, seconds - t)
			if IncomingFire.closest_approach(position, velocity, round_at + round_velocity * t, round_velocity, step) < HIT_RADIUS:
				return true
			position += velocity * step
			t += step
			# A hull swinging through more than Steering.TURN_IN_PLACE_DEG pivots in place: it brakes while it turns.
			var goal := planned if t >= turn_seconds else (Vector3.ZERO if turn_seconds > PIVOT_SECONDS else velocity)
			velocity = velocity.move_toward(goal, acceleration * step)
	return false


## Seconds a hull turning at `turn_rate_deg` needs to swing through the angle whose cosine is `turn_cos`
## (θ ≈ √(2(1 − cos θ)) radians: exact at 0, 4% short at 90°; square roots are portable, trig isn't).
static func turn_seconds(turn_cos: float, turn_rate_deg: float) -> float:
	if turn_rate_deg <= 0.0:
		return 0.0
	return sqrt(maxf(0.0, 2.0 * (1.0 - turn_cos))) * 57.29578 / turn_rate_deg


## 1 inside [low, high], falling off linearly to 0 over 12 m below and 20 m above.
static func _band(value: float, low: float, high: float) -> float:
	if value < low:
		return maxf(0.0, 1.0 - (low - value) / 12.0)
	if value > high:
		return maxf(0.0, 1.0 - (value - high) / 20.0)
	return 1.0


static func _flat(point: Vector3) -> Vector3:
	return Vector3(point.x, 0.0, point.z)
