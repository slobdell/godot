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
##   standoff fixed guns (round 7, the default): a gun truck's shoot-and-scoot — drive (with arrival) to a firing
##           position inside the effective band, stop, lay the hull on the target and fire; slide along the band when
##           rounds are incoming; never close to ramming range. The result carries "hold": true when it should stop
##           and shoot. The lead, round 7: *"Scouts are just running directly into their targets and then they have
##           to turn around to get a fix again"* — which is exactly what `run` did.
##   run     fixed guns (round 3, kept for A/B: `--nav-off=standoff`): attack runs at the target's side and rear,
##           closing to RUN_BREAK (9 m, whatever the band), then driving AWAY to RUN_RETURN and turning back
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

const STYLES := ["strafe", "angle", "run", "standoff"]
## Round 7: the style a fixed gun fights with. `--nav-off=standoff` restores round 3's attack runs (for A/B).
## Resolved at READ time, never in a static initialiser: one initialised from another class's static (Movement._off) can
## run before that one is populated (Movement, TankBrain and CombatMotion reference each other), and then the switch
## silently does nothing — round 7's first commitment A/B came back with two byte-identical arms for exactly that
## reason. Assigning it (tests, squad's scenario) pins it; reading it otherwise follows --nav-off=standoff.
static var _fixed_style_pinned := ""
static var fixed_style: String:
	get:
		if _fixed_style_pinned != "":
			return _fixed_style_pinned
		return "run" if Movement.switched_off("standoff") else "standoff"
	set(value):
		_fixed_style_pinned = value
## Round 7: commitment. The direction chosen at the last plan ("previous_index"/"previous_reverse" in the request) gets
## this score bonus. `--nav-off=commit` switches it off (A/B: squad measured ~70% of attack-move target jumps as motion
## inside one unchanged decision — ENGAGE re-planning its circle).
## (Read at call time — see fixed_style.)
static func commit_on() -> bool:
	return not Movement.switched_off("commit")
const COMMIT_BONUS := 0.35
## ...and a fighter jinks on a timer (to spoil a gunner's lead) only against weapons with a flight time to lead:
## `jink_worth(contact_weapon)`. Against hitscan the jink buys nothing and reads as dithering.
static func jink_worth(weapon_id: String) -> bool:
	if not commit_on():
		return true
	var kind: int = int(Weapons.profile(weapon_id).get("kind", Weapons.Kind.PROJECTILE))
	return kind == Weapons.Kind.PROJECTILE or kind == Weapons.Kind.ARC


## Standoff: hold and shoot anywhere from this share of the band's outer edge out to the edge (a scout: 17.5-35 m).
const STANDOFF_HOLD_SHARE := 0.5
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
	"standoff": {"range": 1.2, "tangent": 0.5, "side": 0.2, "flank": 0.3, "armor": 0.3, "continuity": 0.3, "reverse": 0.1, "turn": 0.1},
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


## Round 8 (nav): a hold has hysteresis. A gun already holding ("previous_index" -1: the last plan was a hold, or there
## was none) keeps holding HOLD_SLACK_M past either edge of its hold band, and only a round that WOULD hit it (would_be_hit,
## standing still) breaks the hold; a gun on the move stops only inside the band with nothing incoming. Measured before:
## gang cars flipped hold <-> move at the band edge and on every incoming round, and each flip made a wheeled hull re-lay
## itself with a K-turn — about 40% of their in-place-yaw events, and the hold never saw the commitment bonus.
## OFF by default (like r5sidestep, `--nav-off=holdband` turns it ON): its pre-registered A/B (builder0, 7c4ec608,
## _agents/streams/nav.md) cut scout in-place yaw 20%+ on only 1 of 4 maps and tripped the kills guard, so it does not
## ship without the lead's say-so.
const HOLD_SLACK_M := 3.0


static func hold_band_on() -> bool:
	return Movement.switched_off("holdband")


## Standoff: should a fixed gun stop and shoot from where it is? Inside its hold band, with nothing incoming.
static func standoff_holds(request: Dictionary) -> bool:
	var band: Array = request.get("band", [15.0, 40.0])
	var outer := float(band[1])
	var here := _flat(request["position"])
	var distance := here.distance_to(_flat((request["target"] as Dictionary)["position"]))
	var incoming: Array = request.get("incoming", [])
	var holding := hold_band_on() and int(request.get("previous_index", -1)) == -1
	var slack := HOLD_SLACK_M if holding else 0.0
	var inside := distance >= maxf(float(band[0]), outer * STANDOFF_HOLD_SHARE) - slack and distance <= outer + slack
	if not inside:
		return false
	if incoming.is_empty():
		return true
	return holding and not would_be_hit(here, Vector3.ZERO, Vector3.ZERO, incoming)


## Round 9 (nav, catalogue A7 — Antonelli, Arrichiello & Chiaverini 2008): null-space behavioural control. `choose`
## dispatches to the priority-projected chooser; `--nav-off=a7` restores the additive blend below, unchanged, as the
## A/B control. The priority table (which term became which level, and the lead-approved behaviour each encodes) is in
## _agents/navigation.md, reviewed by combat and feel before this code existed.
static func choose(request: Dictionary) -> Dictionary:
	if a7_on():
		return choose_projected(request)
	return choose_blended(request)


## A7 is OPT-IN, like `holdband` and `r5sidestep`: `--nav-off=a7` turns it ON. It is built, tested and measured, and
## it is NOT the default, because the behaviour assertion and the ladder disagree and the rule is to believe the
## behaviour assertion (lesson 150). `scenario_elements::test_a_unit_fighting_from_a_formation_slot_stays_in_it`:
## slot drift **15.4 m -> 42.1 m** and the element's shots **10 -> 5**, A7 against the blend on one tree.
## Cause, localised by switching each level off in turn rather than guessed: **level 2**. Strict "weapon above
## formation" makes a unit hold its band around the enemy, and holding a band around a moving enemy is what takes it
## out of the slot it was given. The blend let the two compromise; strict priority does not, and in this scenario
## squad's `element_slot()` returns null for an attacking role, so there is no leash at level 0 to state the task
## region with. **That is a contract question for squad, not a tolerance for nav to tune**, and A7 waits behind this
## switch until it is answered rather than shipping a regression in lead-approved behaviour (X1).
static func a7_on() -> bool:
	return Movement.switched_off("a7")


## Round 3-8's additive score, kept whole as the control arm. A control that is also rewritten is not a control.
static func choose_blended(request: Dictionary) -> Dictionary:
	var style: String = request.get("style", "strafe")
	if style == "standoff" and standoff_holds(request):
		return {"hold": true, "point": _flat(request["position"]), "reverse": false, "index": -1, "score": 0.0}
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
	var previous_index := int(request.get("previous_index", -1))
	var previous_reverse := bool(request.get("previous_reverse", false))
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
			# Round 7: commitment (hysteresis, the standard cure for a utility argmax that flips between near-equals).
			# The direction chosen last plan keeps a bonus, so a rival has to be clearly better to take over; a round
			# actually on its way (PENALTY_HIT below) still outweighs it, so reactive dodging is untouched.
			if commit_on() and i == previous_index and reverse == previous_reverse:
				score += COMMIT_BONUS
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


# ---- A7: null-space priority projection (round 9, nav) -------------------------------------------------------------
# Catalogue row A7 (Antonelli, Arrichiello & Chiaverini 2008). The textbook form synthesises a velocity as
# v = SUM_i (PROD_{j<i} N_j) v_i, every lower task projected into the null space N_j = I - J_j^+ J_j of the higher
# ones. Our velocity set is DISCRETE — a 16-direction ring today, A11's reachable (speed, yaw-rate) lattice at N2 — so
# the projection is exercised as a tolerance-banded lexicographic filter over candidates, which is the same algebra on
# a finite set: each level keeps the candidates within TOLERANCE of its own best, and the level below chooses inside
# exactly the freedom that leaves. TOLERANCE *is* the null space: 0 makes a level dictatorial, a large value makes it
# a pure preference.
#
# What this buys, and it is the whole reason A7 was sequenced first: opposing goals can no longer cancel to zero,
# because they no longer act on the same scalar. The weapon band owns the RADIAL component; the tangential component
# is untouched by it and is where circling, the flank and the slot are answered.
#
# The priority table (every WEIGHTS term, every PENALTY_*, the leash, commitment, the dodge, `beaten`, the sight
# check, and which lead-approved behaviour each encodes) is in _agents/navigation.md. It was written, sent to combat
# and feel, and reviewed BEFORE this function existed, because CombatMotion.WEIGHTS is where round 7's approved
# behaviour lives and "six multiply-adds" badly understates the blast radius.

## The null space each level leaves the one below it. Tuned nowhere else; changing one of these changes how much
## freedom a level gives away, which is the only tuning surface A7 has.
## - survival 0.0: dictatorial. If ANY candidate avoids the round, only such candidates continue. When none does, the
##   level is inactive and leaves the whole set free, which is how "a unit boxed in by fire has to go somewhere"
##   survives (it is today's `beaten_fallback` release, restated as a priority level).
## - weapon 0.15: `_band` is flat inside the band and falls linearly over 12 m below / 20 m above, so 0.15 of band
##   cost is ~1.8 m of slack inside the near edge and ~3.0 m past the far one. Both stay inside the weapon's
##   EFFECTIVE range (TankBrain.fire_band), which is the condition combat set: a tolerance that parks a hull where it
##   may not legally fire would buy motion at the price of the shot.
## - arc 0.125: level 3's cost is `(1 - dot) / 2` over the whole half-turn, so 0.125 admits headings within `dot`
##   0.75 of the best — a ~41 degree cone. Measured, not chosen: the first monotone version kept 0.25 and the duel
##   scenario's front hits fell 100% -> 75% (bar 80%), because `(1 - dot) / 2` reaches 0.25 at 60 degrees where the
##   floored `1 - max(0, dot)` reached it at 41. Making a cost monotone CHANGES WHAT A TOLERANCE MEANS, and the
##   tolerance has to be re-derived with it or the level quietly loosens. That is lesson 153's second half.
## - formation 0.2: enough slack that a unit manoeuvres inside its slot's cell rather than being frozen on its centre.
const TOLERANCE := {"survival": 0.0, "weapon": 0.15, "arc": 0.125, "formation": 0.2}
## Level 4 prices the leash in LEASH_FALLOFF units (1.0 = a full falloff outside the slot), so crowding has to be
## quoted in the same currency to be comparable. The blend's ratio is kept: PENALTY_CROWD 0.6 / PENALTY_LEASH 1.5.
const CROWD_IN_LEASH_UNITS := PENALTY_CROWD / PENALTY_LEASH

## Measurement only, and the thing that makes an A/B a comparison rather than a fiction (lesson 147): plans that ran
## the projection, and — separately, because this is the claim round 8 could not check — plans in which the HOLD
## candidate was scored against the ring instead of returned by an early exit. `a7_holds_scored` is how we know the
## commitment term is reachable on a hold at last, rather than asserting that it is.
static var a7_projected := 0
static var a7_holds_scored := 0
static var a7_holds_won := 0


static func reset_arms() -> void:
	a7_projected = 0
	a7_holds_scored = 0
	a7_holds_won = 0
	a7_region_rejected = 0
	a7_leash_radius = 0.0
	dwa_lattices = 0
	dwa_candidates_reachable = 0
	dwa_with_live_state = 0


static func arm_report() -> Dictionary:
	return {"a7_projected": a7_projected, "a7_holds_scored": a7_holds_scored, "a7_holds_won": a7_holds_won,
			"a7_region_rejected": a7_region_rejected, "a7_leash_radius": a7_leash_radius, "a11_lattices": dwa_lattices,
			"dwa_candidates_reachable": dwa_candidates_reachable, "a11_with_live_state": dwa_with_live_state}


## Keep every candidate within `tolerance` of the best cost. Ties and near-ties survive together: that IS the null
## space handed to the level below. Deterministic — one pass for the minimum, one to filter, input order preserved.
static func _keep_within(live: Array, costs: Array, tolerance: float) -> Array:
	var best := INF
	for i: int in live:
		best = minf(best, float(costs[i]))
	if best == INF:
		return live
	var kept: Array = []
	var bar := best + tolerance
	for i: int in live:
		if float(costs[i]) <= bar:
			kept.append(i)
	return kept if not kept.is_empty() else live


static func choose_projected(request: Dictionary) -> Dictionary:
	var style: String = request.get("style", "strafe")
	# `run` is round 3's attack runs, kept only as the A/B control for round 7's standoff. A control that is also
	# rewritten is not a control, so A7 does not touch it.
	if style == "run":
		return choose_blended(request)
	a7_projected += 1
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
	var band_low := float(band[0])
	var band_high := float(band[1])
	var side := 1.0 if float(request.get("side", 1.0)) >= 0.0 else -1.0
	var map: CoverMap = request.get("map")
	var friends: Array = request.get("friends", [])
	var limit := float(request.get("limit", Match.DRIVABLE_LIMIT)) - 4.0
	var travel_forward := clampf(float(request["speed"]) * HORIZON_SECONDS, MIN_TRAVEL, MAX_TRAVEL)
	var travel_reverse := clampf(float(request.get("reverse_speed", 0.0)) * HORIZON_SECONDS, 0.0, MAX_TRAVEL)
	var wheels: bool = request.get("wheels", false)
	var min_cos := -1.0
	if wheels and float(request.get("min_turn_radius", 0.0)) > 0.0:
		var theta := travel_forward / float(request["min_turn_radius"])
		min_cos = maxf(-1.0, 1.0 - theta * theta / 2.0) if theta < 2.0 else -1.0
	var incoming: Array = request.get("incoming", [])
	var threats: Array = request.get("threats", [])
	var busy: bool = request.get("target_busy", false)
	var flank_weight := BUSY_FLANK if busy else float(weights["flank"])
	var armor_weight := float(weights["armor"]) * (BUSY_ARMOR if busy else 1.0)
	var velocity_now := _flat(request.get("velocity", Vector3.ZERO))
	var leash: Dictionary = request.get("leash", {})
	var leash_center := _flat(leash.get("center", Vector3.ZERO))
	var leash_radius := float(leash.get("radius", 0.0))
	# The orchestrator's ruling (2026-09-19): for a unit told to fight from a place, the leash is a level-0 FEASIBILITY
	# bound on every candidate, DODGES INCLUDED — it dodges INSIDE its leash and never leaves it. Without that, level 1
	# filtering before level 4 lets incoming fire pull a firing line off its line with the leash never consulted, which
	# breaks "the player's units hold until ordered" and squad's base-of-fire scenario.
	#
	# "Told to fight from a place" needs no new request field, because squad established (2026-09-19) that
	# `TankBrain.element_slot()` returns null for the `bound` and `maneuver` roles: under bounding overwatch the moving
	# half arrives here UNLEASHED by design, and base of fire, overwatch and the covering half arrive leashed. **So a
	# leash in the request already means "you were given a position to fight from".**
	#
	# And it binds only a unit that is currently INSIDE its leash: if every candidate is outside, level 0's release
	# below drops the bound and level 4's soft term pulls the unit back instead. That is X1's own rule — *pulled back
	# rather than frozen when something pushes it out* — falling out of the structure rather than being special-cased.
	# The radius is the one that ARRIVES (squad derives it per formation from member hulls: `max(pitch, SLOT_LEASH)`,
	# ~16 m for a squad of War Rigs and growing at CP2), never `SLOT_LEASH` read as a constant here.
	if leash_radius > 0.0:
		a7_leash_radius = leash_radius
	var leash_binds := leash_radius > 0.0
	## How far outside its leash the hull is right now: 0 or less while it is in its slot's cell. A candidate may
	## never make this worse (level 0 above), so a unit outside its slot always closes on it, whatever it is fighting.
	var leash_now := leash_center.distance_to(here) - leash_radius if leash_binds else 0.0
	var previous_index := int(request.get("previous_index", -1))
	var previous_reverse := bool(request.get("previous_reverse", false))
	var beaten: Callable = request.get("beaten", Callable())

	# ---- candidates ------------------------------------------------------------------------------------------------
	# Each is [index, reverse, end, hull, turn_cos, gap, from_target, tangent, around, turning]. The HOLD is index -1
	# with no displacement: round 7's "stop and shoot" is not an early exit any more, it is the zero-radial-speed
	# solution of the weapon level, scored against the ring like everything else. Its admissibility still uses the
	# HOLD band (narrower than the weapon band) and its hysteresis, so round 7's behaviour is preserved exactly; what
	# level 1 now owns is the dodge, which is why "slide along the band when rounds are incoming" still happens.
	# A fixed gun's weapon level targets the HOLD band, not the whole preferred band: round 7's `STANDOFF_HOLD_SHARE`
	# already says a gun truck stops and shoots between half the outer edge and the edge. Using the preferred band here
	# would leave a `standoff` hull between `band_low` and the hold band with a flat level-2 cost AND no tangent
	# preference (level 5 suppresses it in band) — directionless, by construction. Level 2 owns the radial component,
	# so it is the level that must know where the gun actually wants to be.
	var weapon_low := maxf(band_low, band_high * STANDOFF_HOLD_SHARE) if style == "standoff" else band_low
	var cands: Array = []
	if style == "standoff":
		var holding := hold_band_on() and previous_index == -1
		var slack := HOLD_SLACK_M if holding else 0.0
		if distance >= weapon_low - slack and distance <= band_high + slack:
			a7_holds_scored += 1
			cands.append([-1, false, here, forward, 1.0, distance, -to_target, 0.0, 0.0, 0.0, 0.0])
	if a11_on():
		# A11: the candidates are arcs the plant can drive, not directions it may be unable to take.
		cands.append_array(_lattice_candidates(request, here, forward, target_at, bearing))
	else:
		for i in RING.size():
			var ring := Vector3(RING[i].x, 0.0, RING[i].y)
			for reverse: bool in [false, true]:
				var travel := travel_reverse if reverse else travel_forward
				if travel <= 0.0:
					continue
				var hull := -ring if reverse else ring
				var turn_cos := hull.dot(forward)
				# A heading the plant cannot swing onto within this horizon is not a candidate. A11 deletes this
				# test, because a lattice is reachable by construction and does not need a restatement of the rule.
				if wheels and turn_cos < min_cos:
					continue
				var end := here + ring * travel
				var from_target := end - target_at
				var gap := maxf(from_target.length(), 0.1)
				var tangent := absf(ring.x * bearing.z - ring.z * bearing.x)
				var around := bearing.x * ring.z - bearing.z * ring.x
				var turning := 0.0 if wheels else CombatMotion.turn_seconds(turn_cos, float(request.get("turn_rate_deg", 90.0)))
				cands.append([i, reverse, end, hull, turn_cos, gap, from_target, tangent, around, turning,
						-travel_reverse / HORIZON_SECONDS if reverse else travel_forward / HORIZON_SECONDS])

	# ---- LEVEL 0: feasibility. Not a priority level — an infeasible candidate is not a candidate. ---------------------
	var live: Array = []
	for c in cands.size():
		var entry: Array = cands[c]
		var end: Vector3 = entry[2]
		if absf(end.x) > limit or absf(end.z) > limit:
			continue
		if map != null and (map.path_blocked(Vector2(here.x, here.z), Vector2(end.x, end.z), OBSTACLE_GROW)
				or map.inside_any(Vector2(end.x, end.z), OBSTACLE_GROW)):
			continue
		# The leash is the TASK REGION, so level 0 states it as: stay in it, and if you are already out of it, come
		# back. A unit inside may only pick candidates that stay inside; a unit outside may only pick candidates that
		# do not increase how far outside it is. Both are the same rule and the second is the one that matters.
		#
		# Measured, not assumed. With the leash as a level-4 preference ONLY, A7 took slot drift from 15.4 m (the
		# blended arm, `--nav-off=a7`) to 42.1 m and the element's shots from 10 to 5 — strict priority demoted the
		# leash below a band filter that had already narrowed the set, so by the time level 4 spoke there was nothing
		# left to choose between. X1 is lead-approved behaviour (mutual support, sectors of fire, armour facing) and
		# A7 was quietly buying the band with it.
		if leash_binds:
			var excess := leash_center.distance_to(end) - leash_radius
			if excess > maxf(0.0, leash_now):
				a7_region_rejected += 1
				continue
		live.append(c)
	if live.is_empty():
		# Boxed in. Drop the leash bound first (a held unit that cannot stay inside its leash must still move), then
		# the obstacle filter, exactly as the blended path's last loop does: standing still in a fight is worse.
		for c in cands.size():
			var end: Vector3 = (cands[c] as Array)[2]
			if absf(end.x) <= limit and absf(end.z) <= limit:
				live.append(c)
	if live.is_empty():
		return {}

	# ---- LEVEL 1: SURVIVAL. A round that would hit me, and a route through a beaten zone. ------------------------------
	# Dictatorial (tolerance 0), and INACTIVE when nothing is safe, which is the release that keeps a unit boxed in by
	# fire moving. `beaten` is a hard skip today, so its promotion is a rename; `would_be_hit` genuinely changes from a
	# large-but-finite 3.0 to dominant — predict that as a tail effect (3.0 against a max achievable ~3.25 for strafe).
	var survival: Array = []
	survival.resize(cands.size())
	var any_survival := false
	for c: int in live:
		var entry: Array = cands[c]
		var cost := 0.0
		if not incoming.is_empty():
			var planned: Vector3 = Vector3.ZERO
			if int(entry[0]) >= 0:
				var travel_dir: Vector3 = (entry[2] as Vector3) - here
				if travel_dir.length_squared() > 0.0001:
					travel_dir = travel_dir.normalized()
					planned = travel_dir * (float(entry[10]) if a11_on() else
							(float(request.get("reverse_speed", 0.0)) if bool(entry[1]) else float(request["speed"])))
			if CombatMotion.would_be_hit(here, velocity_now, planned, incoming, float(entry[9]),
					float(request.get("acceleration", 1000.0))):
				cost += 1.0
		if beaten.is_valid() and beaten.call(here, entry[2] as Vector3):
			cost += 1.0
		survival[c] = cost
		any_survival = any_survival or cost > 0.0
	if any_survival:
		live = _keep_within(live, survival, float(TOLERANCE["survival"]))

	# ---- LEVEL 2: WEAPON. The standoff band owns the RADIAL component; the ram guard is its inner wall. ----------------
	# The band is `[weapon.preferred_min, weapon.preferred_max]` straight from Weapons.PROFILES (tank_brain.gd), never
	# a radial constant of nav's own, or the motion band and N5's firing envelope drift apart silently.
	var weapon: Array = []
	weapon.resize(cands.size())
	for c: int in live:
		var entry: Array = cands[c]
		var gap := float(entry[5])
		# Metres outside the band, NOT `1 - _band()`. Same saturation trap as level 4: `_band` floors at 0 twelve
		# metres below the band and twenty above, so a unit 60 m from its target would have EVERY candidate tied at
		# cost 1.0 and the weapon level would rank nothing — no pressure to close, on the level whose whole job is the
		# radial component. Uncapped and monotone, keeping the blend's asymmetry (12 m below, 20 m above), so
		# TOLERANCE 0.15 is ~1.8 m of slack inside the near edge and ~3.0 m past the far one.
		var cost := maxf(0.0, weapon_low - gap) / 12.0 + maxf(0.0, gap - band_high) / 20.0
		var passes := gap
		if int(entry[0]) >= 0:
			var travel_dir: Vector3 = (entry[2] as Vector3) - here
			var reach := travel_dir.length()
			if reach > 0.0001:
				travel_dir /= reach
				var along := clampf((target_at - here).dot(travel_dir), 0.0, reach)
				passes = (here + travel_dir * along).distance_to(target_at)
		if minf(gap, passes) < MIN_GAP:
			cost += 1.0  # the ram guard: not a preference, a wall
		weapon[c] = cost
	# The bar is the BETTER of "within TOLERANCE of the best" and "no worse than standing here". That second clause is
	# the null-space statement this table has claimed all along — *level 2 owns the radial component and leaves the
	# whole tangential component free* — and without it the claim was false while out of band.
	#
	# Measured: with a magnitude tolerance alone, a unit outside its band admitted only candidates within ~1.8 m of the
	# single best radial step, which is "drive straight at it" — round 3's `run`, the behaviour round 7 removed. It took
	# slot drift from 15.4 m (blended arm) to 42.1 m, and switching level 2 off entirely brought it back to 16.3 m,
	# which is how the level was identified rather than guessed at. The weapon level wants the gap to IMPROVE; it has
	# no opinion about how directly, and a tolerance in metres was an opinion about how directly.
	var here_cost := maxf(0.0, weapon_low - distance) / 12.0 + maxf(0.0, distance - band_high) / 20.0
	var best_weapon := INF
	for c: int in live:
		best_weapon = minf(best_weapon, float(weapon[c]))
	live = _keep_within(live, weapon, maxf(float(TOLERANCE["weapon"]), here_cost - best_weapon))
	# Keeping the target in sight is the weapon level's own null-space preference — it now orders EVERY candidate that
	# ties on the band, where the blended path could only rescan its best SIGHT_CHECKS. Strictly better, and it costs
	# up to one line query per surviving candidate rather than 6 per plan.
	if map != null and live.size() > 1:
		var sight: Array = []
		sight.resize(cands.size())
		for c: int in live:
			sight[c] = 0.0 if map.clear_line_coarse((cands[c] as Array)[2], target_at) else 1.0
		live = _keep_within(live, sight, 0.0)

	# ---- LEVEL 3: ARC / ARMOUR. Front toward what can shoot me. A6's motion law joins this level (S4). ----------------
	# A heading constraint, not a velocity one. For a TURRETED hull the gun aims independently, so this is demoted into
	# level 5's preference sum; for a hull-fixed or heavy hull the hull IS the mount and it is a priority. The demotion
	# reaches `strafe` only, where the weight is 0.15 — already the smallest term in that vector.
	var armour_is_priority := style != "strafe"
	if armour_is_priority and live.size() > 1:
		var arc: Array = []
		arc.resize(cands.size())
		for c: int in live:
			arc[c] = 1.0 - _front_share(cands[c], target_at, threats, armor_weight, false)
		live = _keep_within(live, arc, float(TOLERANCE["arc"]))

	# ---- LEVEL 4: FORMATION. The slot leash and crowding — below safety, which is the inversion A7 exists to fix. -----
	if (leash_radius > 0.0 or not friends.is_empty()) and live.size() > 1:
		var formation: Array = []
		formation.resize(cands.size())
		for c: int in live:
			var end: Vector3 = (cands[c] as Array)[2]
			# UNCLAMPED, and this is the one place A7 could not reuse the blend's shape. As a PENALTY, saturating the
			# leash at LEASH_FALLOFF past the radius was harmless — other terms still separated the candidates. As a
			# LEVEL it is fatal: a unit far outside its slot has every candidate clamped to the same 1.0, the level
			# ranks nothing, and level 5 then keeps it exactly where it is. That is the stall this row exists to make
			# impossible, reappearing inside the fix; `test_a_gun_held_outside_its_slot_slides_back_into_it` caught it.
			# A cost inside one level only ever competes with itself, so it must stay monotone in the thing it prices.
			var cost := maxf(0.0, leash_center.distance_to(end) - leash_radius) / LEASH_FALLOFF if leash_radius > 0.0 else 0.0
			for friend: Vector3 in friends:
				if _flat(friend).distance_to(end) < FRIEND_SPACING:
					cost += CROWD_IN_LEASH_UNITS
					break
			formation[c] = cost
		live = _keep_within(live, formation, float(TOLERANCE["formation"]))

	# ---- LEVEL 5: PREFERENCE, and it is still a weighted sum. --------------------------------------------------------
	# A7 forbids summing ACROSS priority levels, not within one. Continuity, the turn cost and commitment go on working
	# exactly as round 7 measured them; what changed is that they can no longer outvote a dodge or a standoff band.
	# For `standoff`, `tangent` and `side` apply only while the weapon level is UNSATISFIED (combat's blocking review):
	# a fixed gun's nose IS its aim (nose-on 0.91 measured), so tangential motion in band costs the shot and buys
	# nothing — which is exactly what round 7 removed when `standoff` replaced `run`.
	# "Satisfied" for a fixed gun means inside the HOLD band — the same edge level 2 aims at, so the two cannot disagree.
	var reposition := not (style == "standoff" and distance >= weapon_low and distance <= band_high)
	var best_index := -2
	var best_score := -INF
	for c: int in live:
		var entry: Array = cands[c]
		var score := 0.0
		if reposition:
			score += float(weights["tangent"]) * float(entry[7])
			score += float(weights["side"]) * (1.0 if float(entry[8]) * side > 0.0 else 0.0)
		var gap := float(entry[5])
		score += flank_weight * (1.0 - target_forward.dot((entry[6] as Vector3) / gap)) * 0.5
		if not armour_is_priority:
			score += armor_weight * _front_share(entry, target_at, threats, armor_weight)
		score += float(weights["continuity"]) * (float(entry[4]) + 1.0) * 0.5
		score -= float(weights["turn"]) * float(entry[9])
		if bool(entry[1]):
			score -= float(weights["reverse"])
		# Commitment — and for the first time it is reachable ON A HOLD. Round 8's clearest finding was that a hold
		# returned index -1 before the ring was scored, so COMMIT_BONUS was shipped and measured twice while never
		# executing. Here the hold IS index -1 and `previous_index == -1` matches it.
		if commit_on() and int(entry[0]) == previous_index and bool(entry[1]) == previous_reverse:
			score += COMMIT_BONUS
		if score > best_score:
			best_score = score
			best_index = c
	if best_index < 0:
		return {}

	# ---- the answer -------------------------------------------------------------------------------------------------
	var won: Array = cands[best_index]
	if int(won[0]) == -1:
		a7_holds_won += 1
		return {"hold": true, "point": here, "reverse": false, "index": -1, "score": best_score}
	# The output contract is unchanged: a point to steer at, at a fixed distance, so `Steering` and `Movement` are
	# untouched by A11. What changed is the SET the choice was made over. The arc's direction of travel is what the
	# steer point expresses; its curvature is the plant's business, and the plant is what generated it.
	var direction: Vector3 = (won[2] as Vector3) - here
	if a11_on():
		direction = direction.normalized() if direction.length_squared() > 0.0001 else forward
	else:
		direction = Vector3(RING[won[0]].x, 0.0, RING[won[0]].y)
	var steer := maxf(STEER_DISTANCE, float(request.get("min_turn_radius", 0.0)) * WHEELS_STEER_RADII) if wheels else STEER_DISTANCE
	var point := here + direction * steer
	return {"point": Vector3(clampf(point.x, -limit, limit), point.y, clampf(point.z, -limit, limit)),
			"reverse": bool(won[1]), "index": int(won[0]), "score": best_score,
			"dodging": any_survival}


## Front armour toward the target and every other gun that can shoot me, the target counting double (X3 "keep your
## front toward threats"). Shared by level 3 and level 5's demoted form so the two cannot drift apart.
## `floored` is the difference between an addend and a level, and it is lesson 153 in one parameter.
## The blend clamps each facing dot at 0, so a hull 91 degrees off a threat and one 179 degrees off score the SAME.
## Inside an additive sum that is harmless — the other terms still separate the two. As LEVEL 3's cost it is the
## leash bug again: every candidate facing away ties, the level ranks nothing, and it hands a tied set down. So
## level 3 asks for the unfloored form (`(1 - dot) / 2`, monotone over the whole half-turn) and level 5's demoted
## armour term keeps the floored one, which is what `choose_blended` scores and therefore what the A/B compares.
static func _front_share(entry: Array, target_at: Vector3, threats: Array, armor_weight: float, floored := true) -> float:
	var hull: Vector3 = entry[3]
	var end: Vector3 = entry[2]
	var gap := maxf(float(entry[5]), 0.1)
	var new_bearing := (target_at - end) / gap
	var front := _facing(hull, new_bearing, floored)
	if threats.is_empty() or armor_weight < MULTI_THREAT_ARMOR:
		return front
	var weighted := 2.0 * front
	var weight_sum := 2.0
	for threat: Dictionary in threats:
		var toward := _flat(threat["position"]) - end
		var length := toward.length()
		if length > 0.1:
			weighted += float(threat.get("weight", 1.0)) * _facing(hull, toward / length, floored)
			weight_sum += float(threat.get("weight", 1.0))
	return weighted / weight_sum


## How well `hull` points at `toward`, in [0, 1]: the blend's clamped dot, or the monotone (1 + dot) / 2.
static func _facing(hull: Vector3, toward: Vector3, floored: bool) -> float:
	var dot := hull.dot(toward)
	return maxf(0.0, dot) if floored else (1.0 + dot) * 0.5


# ---- A11: dynamic-window arcs in place of the direction ring (round 9, nav) -----------------------------------------
# Catalogue row A11 (Fox, Burgard & Thrun 1997). The ring scores 16 DIRECTIONS, some of which the plant cannot take
# this tick; the lead's "moving back and forth indefinitely" and a heavy hull "hunting toward" a heading are what that
# looks like from his camera. A11 scores a fixed lattice of (speed, yaw-rate) pairs the plant CAN reach, as
# constant-curvature arcs over a ~2 s lookahead.
#
# **Replaces** `RING` and the `wheels` / `min_cos` chord test — both are candidate generation, so A11 replaces the
# candidate set for BOTH choosers, and the blended scorer can score a lattice as happily as a ring. That keeps A11
# measurable on its own rather than riding on A7 (which is parked behind its own switch).
#
# The honest consequence, stated because it is the interesting one: **the wheeled creep becomes a candidate the
# scorer SEES rather than a reflex the plant takes.** A stopped car is offered no turning arc at all, because
# `yaw = |speed| * turn / radius` will not produce one. Whether `WHEEL_CREEP_THROTTLE` survives is then a finding.

## A fixed 9 x 9 grid, row-major, speeds outer. Fixed count and fixed order: determinism guideline 4.
const DWA_SPEEDS := 9
const DWA_YAWS := 9
## How far ahead an arc is judged (seconds). The ring judged 1.2 s clamped to 5-14 m; an arc can afford longer because
## it is a trajectory rather than a direction, and 2 s is the catalogue's figure.
const DWA_HORIZON := 2.0
## Below this speed (m/s) a wheeled hull is treated as stopped: `yaw = |speed| * turn / radius` gives it nothing.
const DWA_ROLLING := 0.2
## **How long a command is actually HELD before the next plan** — the window is over the control period, not over one
## physics tick. This matters more than it sounds and it was found by measurement, not by reading the paper again.
##
## With a one-tick window, a tracked hull starting from zero yaw could only be offered `yaw_accel * dt` of turn rate;
## held constant over a 2 s arc that is **21 degrees of heading change, total**, when the hull can physically swing
## 160. Every candidate pointed nearly the same way, level 3 had nothing to choose between, and a tank in the duel
## scenario could not get its front around: front hits fell to **67% and it died in 6.3 s** of a 20 s fight.
##
## 0.25 s because that is the brain's own re-plan cadence (`TankBrain.MOTION_REPLAN_TICKS` = TICK_RATE / 4, squad's
## file — matched here deliberately, not read, so nav's window does not silently change when squad retunes its
## cadence; A1 at N3 is where the two become one number on purpose). It is also exactly `YAW_RAMP_SECONDS`, so a
## tracked hull's window reaches its full turn rate, which is the honest statement of what it can do before anyone
## asks it again.
const DWA_CONTROL_SECONDS := 0.25

## Measurement only (lesson 147): lattices built, cells offered, and — separately, because it says whether the window
## was computed from the hull's REAL yaw or from an assumed one — plans whose request carried a live `yaw_rate`.
static var dwa_lattices := 0
static var dwa_candidates_reachable := 0
## ...and whether the request carried a LIVE `motion` state. Without one the window is built from a synthesised state
## with `yaw_rate` 0, which is a less precise window, not a wrong one — but an A/B has to know which it measured.
static var dwa_with_live_state := 0
## Level 0's task region (squad asked for this by name): candidates rejected for leaving, or worsening, the leash.
## "Level 0 engaged" is exactly the kind of claim round 8 proved should never be taken on trust.
static var a7_region_rejected := 0
## The leash radius as it ARRIVED in the request (squad's pin: 14.0 m exactly on the drift scenario). Read from the
## request, never from `SLOT_LEASH`, so a pitch-plumbing bug shows up as a number rather than as a silent default.
static var a7_leash_radius := 0.0


## A11 is OPT-IN (`--nav-off=a11` turns it ON), on the same footing as A7: round 9's new rows land behind their switch
## until their behaviour scenarios pass, and the switch is then the A/B arm rather than a leftover.
static func a11_on() -> bool:
	return Movement.switched_off("a11")


## The (speed, yaw-rate) pairs `TankMotion.step_in_place` actually produces from `state` in ONE tick, as a fixed
## lattice. **Generated in COMMAND space and evaluated through the plant**, not derived from a restatement of the
## plant's rules: a fixed 9 x 9 grid of (throttle, turn), one `TankMotion.step` each, and the resulting (speed,
## yaw_rate) IS the cell. Nothing here models the plant, so nothing here can drift from it.
##
## That choice was forced by the measurement, and it is the most interesting thing A11 found. The first version
## inverted the plant by hand — pick a speed, solve for the throttle — and it was wrong for wheels in a way the
## project already knows about: **the multi-point creep hijacks the throttle** whenever `|throttle| <
## WHEEL_CREEP_THROTTLE * |turn|`, so a whole region of command space does not produce the motion it asks for. The
## hand-inverted lattice promised 3.53 m/s and the plant delivered 4.30, because the creep took the wheel.
##
## Evaluating the plant makes that region **honest instead of invisible**: the creep's legs appear as cells with
## their real speed and yaw, so the scorer sees a K-turn as one option among 81 and prices it, which is exactly what
## the brief asks for — *the creep is a candidate the scorer sees, not a reflex the plant takes*. Whether
## `WHEEL_CREEP_THROTTLE` survives is then a finding rather than a decision.
static func dynamic_window(state: Dictionary) -> Array:
	var dt := SimClock.TICK_SECONDS
	var ticks := maxi(1, int(DWA_CONTROL_SECONDS * SimClock.TICK_RATE))
	var cells: Array = []
	for i in DWA_SPEEDS:
		var throttle := float(i) / float(DWA_SPEEDS - 1) * 2.0 - 1.0  # -1 .. +1, the middle cell exactly 0
		for j in DWA_YAWS:
			var turn := float(j) / float(DWA_YAWS - 1) * 2.0 - 1.0
			# One duplicate per command, then stepped IN PLACE: the live state's creep and yaw bookkeeping is never
			# advanced by a hypothetical, and the control period costs allocations once rather than once per tick.
			var rolled: Dictionary = state.duplicate()
			var before: Vector3 = rolled["forward"]
			var last: Vector3 = before
			for _t in ticks:
				last = rolled["forward"]
				TankMotion.step_in_place(rolled, throttle, turn, dt)
			var turned: Vector3 = rolled["forward"]
			# The rate it ENDS the control period at (the last tick's swing), which is what the arc then holds; and
			# the total swing over the period, which is what actually happened while it got there.
			var yaw_rate := (last.x * turned.z - last.z * turned.x) / dt
			var swing := (before.x * turned.z - before.z * turned.x) / (float(ticks) * dt)
			cells.append({"speed": float(rolled["speed"]), "yaw_rate": yaw_rate, "mean_yaw": swing,
					"position": rolled["position"], "forward": turned, "throttle": throttle, "turn": turn})
	return cells


## A11's candidates, in the same 10-field shape the ring produces so every level scores one the same way — plus an
## 11th field, the arc's own speed, because an arc knows how fast it is going and a direction never did.
##
## `request["motion"]` is a live `TankMotion.state_of(tank)`. Without one the window is built from a state synthesised
## out of the request, whose `yaw_rate` is 0 — a LESS PRECISE window, not a wrong one, and `dwa_with_live_state`
## records which was measured so no A/B has to guess.
static func _lattice_candidates(request: Dictionary, here: Vector3, forward: Vector3, target_at: Vector3,
		bearing: Vector3) -> Array:
	var state: Dictionary = request.get("motion", {})
	if state.is_empty():
		state = {"position": here, "forward": forward, "speed": _flat(request.get("velocity", Vector3.ZERO)).dot(forward),
				"velocity": _flat(request.get("velocity", Vector3.ZERO)),
				"locomotion": "wheels" if bool(request.get("wheels", false)) else "tracks",
				"max_forward_speed": float(request["speed"]), "max_reverse_speed": float(request.get("reverse_speed", 0.0)),
				"hull_turn_rate_deg": float(request.get("turn_rate_deg", 90.0)),
				"acceleration_mps2": float(request.get("acceleration", 14.0)),
				"braking_mps2": float(request.get("acceleration", 14.0)),
				"min_turn_radius_m": float(request.get("min_turn_radius", 0.0)), "lateral_grip": 1.0}
	else:
		dwa_with_live_state += 1
	dwa_lattices += 1
	var turn_rate := float(state.get("hull_turn_rate_deg", 90.0))
	var cells := dynamic_window(state)
	var out: Array = []
	for k in cells.size():
		var cell: Dictionary = cells[k]
		var speed := float(cell["speed"])
		# The committed part is what the plant DID over the control period; the rest is a constant-curvature arc from
		# there. Only the second part is a model, and it is a model of a command already chosen.
		var driven_at: Vector3 = cell["position"]
		var driven_forward: Vector3 = cell["forward"]
		var rolled := arc_end(driven_at, driven_forward, speed, float(cell["yaw_rate"]),
				DWA_HORIZON - DWA_CONTROL_SECONDS)
		var end: Vector3 = rolled[0]
		var heading: Vector3 = rolled[1]
		var travel := end - here
		var reach := travel.length()
		if reach < 0.01:
			continue  # a cell that goes nowhere is the hold, and only `standoff` gets to offer one
		var travel_dir := travel / reach
		var from_target := end - target_at
		var gap := maxf(from_target.length(), 0.1)
		var tangent := absf(travel_dir.x * bearing.z - travel_dir.z * bearing.x)
		var around := bearing.x * travel_dir.z - bearing.z * travel_dir.x
		var turn_cos := heading.dot(forward)
		# Priced in the same currency the ring used (seconds of swing), so level 5's `turn` weight keeps its meaning
		# across the A/B instead of silently changing units with the candidate set.
		var turning := CombatMotion.turn_seconds(turn_cos, turn_rate)
		out.append([k, speed < 0.0, end, heading, turn_cos, gap, from_target, tangent, around, turning, speed])
	dwa_candidates_reachable += out.size()
	return out


## One constant-curvature arc: where a hull at `here` facing `forward` ends up after DWA_HORIZON seconds holding
## (speed, yaw_rate), and which way it points when it gets there. Closed form, no per-tick integration: a circle of
## radius v/w, or a straight line when w is ~0. Two square roots and a normalise, no trig (determinism guideline 4).
static func arc_end(here: Vector3, forward: Vector3, speed: float, yaw_rate: float, seconds: float) -> Array:
	var right := Vector3(-forward.z, 0.0, forward.x)
	var theta := yaw_rate * seconds
	var heading := TankMotion.turn_heading(forward, theta) if absf(theta) > 0.000001 else forward
	if absf(yaw_rate) < 0.000001:
		return [here + forward * (speed * seconds), heading]
	# Exact arc offset in the hull's own frame: (r*sin theta) forward + (r*(1 - cos theta)) right, r = v / w.
	var r := speed / yaw_rate
	var sin_t := sin(theta)
	var cos_t := cos(theta)
	return [here + forward * (r * sin_t) + right * (r * (1.0 - cos_t)), heading]


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
