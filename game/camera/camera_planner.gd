class_name CameraPlanner
extends RefCounted
## Round 46 (camera C2): ONE planner decides where the play camera is. The lead, after round 45 (Terminus): "we generally
## don't want special cases and we ideally want an abstract algorithm that's planning camera position at all times."
##
## Until now four rules took turns over the pose: the vision frame (where and how far), the yaw follow and the danger
## look (which way), the corner swing (OFF), and the aim hold (whether any of it moves). Each decided one part of the pose
## and none saw the others' result: the danger look faced the enemy while his squad drove a corridor the other way with a
## block between the boom and the squad (his recording, 70-74 s); the aim hold froze a new selection's pan while his hand
## was on the mouse. The planner replaces their DECISIONS with one cost over a small set of candidate poses:
##
##   candidates  a yaw from a fixed set (the current wanted yaw + YAW_STEPS headings); at each, the ground point and the
##               distance FRAME his selection (and lean toward its path ahead), under the zoom caps. Pitch and FOV stay his.
##               With contacts in play, each yaw also has a WIDE variant that frames them too.
##   cost        W_SEL     his selected crews off screen (x FRESH_X just after a new selection)
##               W_PATH    the points of his selection's path ahead off screen
##               W_ACTION  the contacts that matter (near, firing at / hitting his selection) off screen, by threat
##               W_SIGHT   rays from the candidate's camera (after the building clearance) to his crews and to the path
##                         ahead that a DRAWN solid blocks: a boom down the street the squad drives has clear rays, which
##                         is how "look down the corridor" emerges without a corridor rule
##               W_ARENA   the view's ground beyond the arena's wall (the stands: round 42's "pointed out completely to the
##                         audience", now a cost instead of the danger look's pull toward the middle)
##               W_LIFT    a boom that ends inside a building (the clearance must tilt it up over the roof: dev seeds
##                         spent more seconds with the camera inside a block while it turned)
##               W_WAR     the view turned away from where the fight is (the known enemies' centre, else the arena's
##                         middle), past what his lens shows: with nothing near, the view faces the war, not the way it
##                         happened to point (dev 7001-7006: without it enemies were on screen 47 % of play v 62 % today)
##               W_TURN    the turn from the current wanted yaw; W_DIST the zoom past his 49 m
##   stability   the current yaw is always a candidate, and a challenger must beat it by SWITCH_MARGIN: equal costs never
##               flip-flop and a small gain never swings the view back (round 43's corner swing failed exactly there).
##
## Pure over a `world` Dictionary the rig fills (`plan`), so every term has a test. Motion stays the glide's (springs,
## caps, the building clearance's easing); his hand still wins for the hand-back time (the rig never asks the planner then).

## How often the rig starts a plan (seconds of UI clock) at most. Between plans the glide carries the view to the last one.
const PLAN_S := 0.2
## Poses scored per frame (`step`) off the laptop preset; the laptop scores one (C3).
const HEADINGS_PER_FRAME := 4
## The candidate headings: every 360 / YAW_STEPS degrees, plus the current wanted yaw.
const YAW_STEPS := 12
## THE weights (one table; see the header).
const W_SEL := 10.0
const FRESH_X := 3.0
const W_PATH := 2.0
const W_ACTION := 6.0
const W_SIGHT_CREW := 4.0
const W_SIGHT_PATH := 2.0
const W_TURN := 1.5
const W_DIST := 0.5
const W_ARENA := 1.5
const W_LIFT := 1.0
const W_WAR := 1.5
## C1 v2 (Bar C1's one miss, G7: a gun firing from BEHIND the view was a share of all the contacts, and the turn to it waited out
## the switch hold and the cost mean): each enemy that fired at his selection within RtsCamera.DANGER_RECENT_S costs W_GUN off
## screen, as a share of those guns only, and is not averaged; a pose that shows more of them is not held back by a recent switch.
const W_GUN := 6.0
## The war term starts past this bearing (his lens shows ~+-29 deg) and is spent in full this far past it.
const WAR_FREE_DEG := 25.0
const WAR_FULL_DEG := 90.0
## Standing on the war's point every way is toward it: no war term within this distance (as the danger look's).
const WAR_NEAR_M := 20.0
## The lift at which W_LIFT is spent in full (degrees the building clearance must tilt the boom up to clear a roof).
const LIFT_FULL_DEG := 15.0
## The weights in force: the constants above, unless a dev run overrides some (`--camera-planner-w=action:5,turn:2`;
## a bar runs at the constants). Read by `score` / `plan`.
static var w_sel := W_SEL
static var w_path := W_PATH
static var w_action := W_ACTION
static var w_sight_crew := W_SIGHT_CREW
static var w_sight_path := W_SIGHT_PATH
static var w_turn := W_TURN
static var w_dist := W_DIST
static var w_arena := W_ARENA
static var w_lift := W_LIFT
static var w_war := W_WAR
static var w_gun := W_GUN
static var action_range_m := ACTION_RANGE_M
static var hold_margin := HOLD_MARGIN


## Apply a dev override string "key:value,key:value" (keys: sel path action sight_crew sight_path turn dist arena hold).
static func override_weights(text: String) -> void:
	for pair in text.split(",", false):
		var kv := pair.split(":")
		if kv.size() != 2:
			continue
		var v := float(kv[1])
		match kv[0]:
			"sel": w_sel = v
			"path": w_path = v
			"action": w_action = v
			"sight_crew": w_sight_crew = v
			"sight_path": w_sight_path = v
			"turn": w_turn = v
			"dist": w_dist = v
			"arena": w_arena = v
			"lift": w_lift = v
			"war": w_war = v
			"gun": w_gun = v
			"range": action_range_m = v
			"hold": hold_margin = v


## A challenger replaces the current pose only when it is cheaper by this much.
const SWITCH_MARGIN := 0.25
## Changing its mind costs more just after it did: the switch margin is raised by HOLD_MARGIN, fading over HOLD_S since
## the last switch (dev seeds 7001-7002: without it the plan went -120 -> -60 -> -120 inside 0.4 s as a crew passed a block).
const HOLD_MARGIN := 1.5
const HOLD_S := 2.0
## Each heading's cost is averaged over about this long (an exponential mean, by heading): a ray that flickers as a crew
## passes a corner moves the mean, not the view.
const COST_TAU_S := 0.6
## A new selection: how long its selection term weighs FRESH_X.
const FRESH_S := 2.0
## His distance (the settled pose, rts_camera.gd): the zoom past it costs W_DIST, scaled to the auto frame's cap.
const PREFERRED_M := 49.0
## The path ahead: this far along the selection's drive, a point every PATH_STEP_M.
const PATH_AHEAD_M := 40.0
const PATH_STEP_M := 10.0
## Contacts beyond this from his selection are not his fight (they cost nothing off screen).
const ACTION_RANGE_M := 120.0
## A ray is aimed this high on a crew (a hull's top half: a hull whose roof shows is a hull he sees).
const CREW_AIM_M := 2.0
const PATH_AIM_M := 1.0
## Solids shorter than this hide wheels, not vehicles.
const SIGHT_MIN_HEIGHT_M := 3.0
## At most this many crews are ray-tested (evenly picked): the term is a fraction, and the laptop pays per ray.
const MAX_SIGHT_CREWS := 4
## How far inside the wall the frame's focus stays (as the danger camera kept it).
const WALL_MARGIN_M := 4.0

## The last plan's result (the trace and the readout read it): {yaw, focus, level, cost, terms, candidates, switched}.
var last := {}
var _mean := {}  # "heading:variant" -> [mean cost, when]
var _switched_at := -1e9
var _queue: Array = []  # headings left to score in this cycle (step)
var _cycle := {}


## The headings to try: `current` first, then every 360 / steps degrees (skipping any within 5 deg of `current`). Pure.
static func candidate_yaws(current: float, steps := YAW_STEPS) -> Array:
	var out: Array = [current]
	for i in steps:
		var yaw := wrapf(TAU * float(i) / float(steps), -PI, PI)
		if absf(angle_difference(current, yaw)) > deg_to_rad(5.0):
			out.append(yaw)
	return out


## The path ahead of a selection centred on `middle` driving along `travel` (a ground vector, m/s; null or slow = parked):
## points every PATH_STEP_M out to PATH_AHEAD_M. Empty when it is not driving. Pure.
static func path_ahead(middle: Vector3, travel: Variant, min_speed := 1.5) -> Array:
	var out: Array = []
	if not travel is Vector3:
		return out
	var flat := Vector3((travel as Vector3).x, 0.0, (travel as Vector3).z)
	if flat.length() < min_speed:
		return out
	var d := PATH_STEP_M
	while d <= PATH_AHEAD_M + 0.01:
		out.append(middle + flat.normalized() * d)
		d += PATH_STEP_M
	return out


## [focus, level] that frames `points` (ground Vector3s, grown by `pad`) at `yaw`, then leans toward `lean` (or null) as far
## as keeping them all in the frame allows; the level between `floor_level` and `cap_level`. Binary searches (the shown
## pose's frame_pose steps 0.01 at a time; the planner fits ~20 of these per plan). Pure.
static func fit(points: Array, lean: Variant, yaw: float, w: Dictionary) -> Array:
	var aspect := float(w.get("aspect", 16.0 / 9.0))
	var pitch := float(w.get("pitch", RtsCamera.DEFAULT_PITCH_DEG))
	var inset := float(w.get("inset", RtsCamera.VISION_FRAME_INSET))
	var bottom := float(w.get("bottom", RtsCamera.VISION_FRAME_BOTTOM))
	var floor_level := float(w.get("floor_level", RtsCamera.VISION_MIN_ZOOM))
	var cap_level := maxf(float(w.get("cap_level", 1.0)), floor_level)
	var bounds := AABB(Vector3(points[0].x, 0.0, points[0].z), Vector3.ZERO)
	for p: Vector3 in points:
		bounds = bounds.expand(Vector3(p.x, 0.0, p.z))
	bounds = bounds.grow(float(w.get("pad", 0.0)) + RtsCamera.FRAME_MARGIN_M)
	var centre := bounds.get_center()
	centre.y = 0.0
	var corners: Array = []
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.z, bounds.end.z]:
			corners.append(Vector3(x, 0.0, z))
	var lo := floor_level
	if not RtsCamera.shows_all(corners, centre, yaw, lo, aspect, inset, pitch, minf(inset, bottom)):
		var hi := cap_level
		for i in 8:
			var mid := (lo + hi) / 2.0
			if RtsCamera.shows_all(corners, centre, yaw, mid, aspect, inset, pitch, minf(inset, bottom)):
				hi = mid
			else:
				lo = mid
		lo = hi
	var level := minf(lo, cap_level)
	var focus := centre
	if lean is Vector3:
		var toward := Vector3((lean as Vector3).x - centre.x, 0.0, (lean as Vector3).z - centre.z)
		var low := 0.0
		var high := 1.0
		for i in 8:
			var mid := (low + high) / 2.0
			if RtsCamera.shows_all(corners, centre + toward * mid, yaw, level, aspect, inset, pitch, minf(inset, bottom)):
				low = mid
			else:
				high = mid
		focus = centre + toward * low
	return [RtsCamera.inside_wall(focus, WALL_MARGIN_M), level]


## The solids near a set of points (their 2D bounds grown by `reach`): the only ones a ray or the clearance among them
## can meet. Returns a layout-shaped {"obstacles": [...]}. Pure.
static func near_solids(data: Dictionary, points: Array, reach: float) -> Dictionary:
	if points.is_empty():
		return {"obstacles": []}
	var box := Rect2(Vector2(points[0].x, points[0].z), Vector2.ZERO)
	for p: Vector3 in points:
		box = box.expand(Vector2(p.x, p.z))
	box = box.grow(reach)
	var out: Array = []
	for obstacle: Dictionary in data.get("obstacles", []):
		var size := Arena.obstacle_size(obstacle)
		if size.y < SIGHT_MIN_HEIGHT_M:
			continue
		var r := 0.5 * Vector2(size.x, size.z).length()
		var c := Vector2(float(obstacle["position"][0]), float(obstacle["position"][1]))
		if box.grow(r).has_point(c):
			out.append(obstacle)
	return {"obstacles": out}


## Where `point` lands on a screen of `aspect` seen from `view` (the camera's inverse transform): x right, y up, -1..1 at
## the edges; null behind the camera. Pure.
static func screen_of(view: Transform3D, point: Vector3, aspect: float) -> Variant:
	var c := view * point
	if c.z > -0.1:
		return null
	var half := tan(deg_to_rad(RtsCamera.fov) / 2.0)
	return Vector2(c.x / -c.z / (half * aspect), c.y / -c.z / half)


## Whether a screen point is in his view: inside the frame and above the command card (`bottom` of the half-height). Pure.
static func on_screen(ndc: Variant, bottom: float) -> bool:
	return ndc is Vector2 and absf((ndc as Vector2).x) <= 1.0 and absf((ndc as Vector2).y) <= 1.0 \
			and (ndc as Vector2).y >= -bottom


## The cost of the pose that looks along `yaw` at `focus` from zoom `level`, and its terms. `current_yaw` is the wanted
## yaw now (the turn is measured from it). `w` is the world (see `plan`); `solids` the near solids. Pure.
static func score(yaw: float, focus: Vector3, level: float, current_yaw: float, w: Dictionary, solids: Dictionary) -> Dictionary:
	var aspect := float(w.get("aspect", 16.0 / 9.0))
	var bottom := float(w.get("bottom", RtsCamera.VISION_FRAME_BOTTOM))
	var pitch := float(w.get("pitch", RtsCamera.DEFAULT_PITCH_DEG))
	var distance := RtsCamera.distance_for(level)
	var tilt := RtsCamera.tilt_at(pitch, distance)
	var clear := RtsCamera.clear_pose(focus, yaw, distance, tilt, solids)
	var pose := RtsCamera.pose_at(focus, yaw, float(clear["distance"]), float(clear["pitch_deg"]))
	var view := pose.affine_inverse()
	var eye := pose.origin
	var own: Array = w.get("own", [])
	var off := 0
	var blocked := 0
	var tested := 0
	var stride := maxi(1, ceili(float(own.size()) / float(MAX_SIGHT_CREWS)))
	for i in own.size():
		var at: Vector3 = own[i]
		if not on_screen(screen_of(view, at + Vector3(0, 1, 0), aspect), bottom):
			off += 1
		if i % stride == 0:
			tested += 1
			if not RtsCamera.sight_blockers(eye, at + Vector3(0, CREW_AIM_M, 0), solids, SIGHT_MIN_HEIGHT_M, true).is_empty():
				blocked += 1
	var path: Array = w.get("path", [])
	var path_off := 0
	var path_blocked := 0
	for at: Vector3 in path:
		if not on_screen(screen_of(view, at, aspect), bottom):
			path_off += 1
		elif not RtsCamera.sight_blockers(eye, at + Vector3(0, PATH_AIM_M, 0), solids, SIGHT_MIN_HEIGHT_M, true).is_empty():
			path_blocked += 1
	var action_w := 0.0
	var action_off := 0.0
	for contact: Array in w.get("action", []):
		action_w += float(contact[1])
		if not on_screen(screen_of(view, (contact[0] as Vector3) + Vector3(0, 1, 0), aspect), bottom):
			action_off += float(contact[1])
	var outside := 0
	var plane := Plane(Vector3.UP, 0.0)
	var half_y := tan(deg_to_rad(RtsCamera.fov) / 2.0)
	for u: float in [-0.6, 0.0, 0.6]:
		for v: float in [0.2, 0.7]:
			var hit: Variant = plane.intersects_ray(eye, (pose.basis * Vector3(u * half_y * aspect, v * half_y, -1.0)).normalized())
			if hit == null or not CameraPlanner.inside_arena(hit as Vector3):
				outside += 1
	var war_cost := 0.0
	if w.get("war") is Vector3 and not own.is_empty():
		var middle := RtsCamera._middle(own, own.size())
		var to_war := Vector3((w["war"] as Vector3).x - middle.x, 0.0, (w["war"] as Vector3).z - middle.z)
		if to_war.length() > WAR_NEAR_M:
			var war_off := rad_to_deg(absf(angle_difference(yaw, RtsCamera.yaw_facing(to_war))))
			war_cost = w_war * clampf((war_off - WAR_FREE_DEG) / (WAR_FULL_DEG - WAR_FREE_DEG), 0.0, 1.0)
	var guns: Array = w.get("guns", [])
	var guns_off := 0
	for at: Vector3 in guns:
		if not on_screen(screen_of(view, at + Vector3(0, 1, 0), aspect), bottom):
			guns_off += 1
	var sel_w := w_sel * (FRESH_X if bool(w.get("fresh", false)) else 1.0)
	var terms := {
		"sel": sel_w * float(off) / float(maxi(own.size(), 1)),
		"path": w_path * float(path_off) / float(maxi(path.size(), 1)),
		"action": w_action * (action_off / action_w if action_w > 0.0 else 0.0),
		"sight": w_sight_crew * float(blocked) / float(maxi(tested, 1)) + w_sight_path * float(path_blocked) / float(maxi(path.size(), 1)),
		"arena": w_arena * float(outside) / 6.0,
		"war": war_cost,
		"gun": w_gun * float(guns_off) / float(maxi(guns.size(), 1)),
		"lift": w_lift * clampf(float(clear["lifted_deg"]) / LIFT_FULL_DEG, 0.0, 1.0),
		"turn": w_turn * absf(angle_difference(current_yaw, yaw)) / PI,
		"dist": w_dist * clampf((distance - PREFERRED_M) / maxf(RtsCamera.AUTO_FRAME_MAX_M - PREFERRED_M, 1.0), 0.0, 1.0),
	}
	var cost := 0.0
	for key: String in terms:
		cost += float(terms[key])
	return {"cost": cost, "terms": terms}


## One plan. `w` (the world, filled by the rig each plan):
##   own: Array[Vector3]   his selected crews (drawn ground points)       pad: float   half the biggest hull
##   path: Array[Vector3]  the path ahead (path_ahead)                     lean: Vector3 or null  where the frame leans
##   action: Array of [Vector3, weight]  the contacts that matter          fresh: bool  a new selection (FRESH_S)
##   aspect, pitch, inset, bottom, floor_level, cap_level                  data: the drawn layout (RtsCamera.seen)
## `current_yaw` is the wanted yaw now. Returns {yaw, focus, level, wide (framed with the contacts), cost, terms, switched, candidates} or {} with nothing
## to frame. The current yaw wins unless a challenger is SWITCH_MARGIN cheaper. Records itself in `last`.
func plan(w: Dictionary, current_yaw: float, now := 0.0) -> Dictionary:
	_queue.clear()
	return step(w, current_yaw, now, 1 << 20)


## Whether a cycle is under way (the rig keeps stepping it).
func planning() -> bool:
	return not _queue.is_empty()


## Drop the cycle under way (a new selection: plan it from scratch).
func restart() -> void:
	_queue.clear()


## C3 (the laptop budget, C46.7): the same plan spread over frames. Each call scores up to `n` headings of the current
## cycle (the current yaw first) on that frame's world, and returns the decision once the cycle's last heading is scored
## ({} before then). A cycle restarts when the yaw it plans from changes (his hand). `n` is the hardware preset's knob
## (the rig: 1 pose a frame on the laptop preset, HEADINGS_PER_FRAME poses elsewhere): the same decision, later. A pose is
## one heading's tight or wide frame; the wide one is skipped (free) with no contacts.
func step(w: Dictionary, current_yaw: float, now: float, n: int) -> Dictionary:
	var own: Array = w.get("own", [])
	if own.is_empty():
		last = {}
		_queue.clear()
		return {}
	if _queue.is_empty() or float(_cycle.get("current_yaw", NAN)) != current_yaw:
		_queue.clear()
		for yaw: float in CameraPlanner.candidate_yaws(current_yaw):
			_queue.append([yaw, 0])
			_queue.append([yaw, 1])
		var reach := RtsCamera.distance_for(maxf(float(w.get("cap_level", 1.0)), float(w.get("floor_level", 0.0)))) + 10.0
		_cycle = {"best": {}, "current": {}, "count": 0, "current_yaw": current_yaw,
				"solids": CameraPlanner.near_solids(w.get("data", {}), own + (w.get("path", []) as Array), reach)}
	var wide: Array = []
	for contact: Array in w.get("action", []):
		wide.append(RtsCamera.inside_wall(contact[0] as Vector3, WALL_MARGIN_M))
	var solids: Dictionary = _cycle["solids"]
	var scored_n := 0
	while scored_n < n and not _queue.is_empty():
		var unit: Array = _queue.pop_front()
		var yaw: float = unit[0]
		var vi: int = unit[1]
		if vi == 1 and wide.is_empty():
			continue  # no contacts this frame: no wide frame to score (costs nothing)
		var v: Array = CameraPlanner.fit(own, w.get("lean"), yaw, w) if vi == 0 else CameraPlanner.fit(own + wide, null, yaw, w)
		var pick := CameraPlanner.score(yaw, v[0], float(v[1]), current_yaw, w, solids)
		pick["wide"] = vi == 1
		pick["yaw"] = yaw
		pick["focus"] = v[0]
		pick["level"] = float(v[1])
		pick["raw"] = float(pick["cost"])
		var gun := float(pick["terms"].get("gun", 0.0))  # C1 v2: a gun firing at him counts now, not averaged in
		pick["cost"] = _averaged("%d:%d" % [roundi(rad_to_deg(yaw)), vi], float(pick["cost"]) - gun, now) + gun
		scored_n += 1
		_cycle["count"] = int(_cycle["count"]) + 1
		if yaw == current_yaw and ((_cycle["current"] as Dictionary).is_empty() or float(pick["cost"]) < float(_cycle["current"]["cost"])):
			_cycle["current"] = pick
		if (_cycle["best"] as Dictionary).is_empty() or float(pick["cost"]) < float(_cycle["best"]["cost"]):
			_cycle["best"] = pick
	if not _queue.is_empty():
		return {}
	var best: Dictionary = _cycle["best"]
	var out: Dictionary = _cycle["current"]
	out["switched"] = false
	var margin := SWITCH_MARGIN + hold_margin * exp(-(now - _switched_at) / HOLD_S)
	if float(best["terms"].get("gun", 0.0)) < float(out["terms"].get("gun", 0.0)):
		margin = SWITCH_MARGIN  # C1 v2: showing a gun he cannot see now is not held back by the last switch
	if float(best["cost"]) < float(out["cost"]) - margin:
		out = best
		out["switched"] = absf(angle_difference(current_yaw, float(best["yaw"]))) > 0.001
		if bool(out["switched"]):
			_switched_at = now
	out["candidates"] = int(_cycle["count"])
	last = out
	return out


## The contacts that matter, from a DangerFeed reading: [ground point, weight] for every known enemy within
## ACTION_RANGE_M of his selection, weighted as the danger camera weighed them (nearer more, a gun firing at or hitting
## his selection up to 5x, fading over DangerFeed.MEMORY_S once out of sight). Never an enemy his team has not seen (the
## feed knows only those: no cheating view). Pure.
static func action_of(state: Dictionary) -> Array:
	var out: Array = []
	if not state.get("from") is Vector3:
		return out
	var from: Vector3 = state["from"]
	for enemy: Dictionary in state.get("enemies", []):
		var at: Vector3 = enemy["at"]
		var away := Vector3(at.x - from.x, 0.0, at.z - from.z).length()
		if away > action_range_m:
			continue
		var near := clampf(RtsCamera.DANGER_NEAR_M / maxf(away, 0.5), RtsCamera.DANGER_FAR_FLOOR, RtsCamera.DANGER_NEAR_CAP)
		var fade := 1.0 if bool(enemy.get("seen", true)) else clampf(1.0 - float(enemy.get("age_s", 0.0)) / DangerFeed.MEMORY_S, 0.0, 1.0)
		var threat := 1.0 + RtsCamera.DANGER_FIRING_X * exp(-float(enemy.get("fired_s", DangerFeed.NEVER)) / RtsCamera.DANGER_RECENT_S) \
				+ RtsCamera.DANGER_HIT_X * exp(-float(enemy.get("hit_s", DangerFeed.NEVER)) / RtsCamera.DANGER_RECENT_S)
		if near * fade * threat > 0.0:
			out.append([at, near * fade * threat])
	return out


## The mean cost of the pose `key` (heading in whole degrees : frame variant) with `cost` now. A heading not scored for over 3 COST_TAU_S starts again from `cost`.
func _averaged(key: String, cost: float, now: float) -> float:
	var held: Variant = _mean.get(key)
	var mean := cost
	if held is Array and now - float(held[1]) <= 3.0 * COST_TAU_S:
		mean = cost + (float(held[0]) - cost) * exp(-maxf(now - float(held[1]), 0.0) / COST_TAU_S)
	_mean[key] = [mean, now]
	return mean


## Whether a ground point is inside the arena's wall (the perimeter polygon RtsCamera loaded, else the square). Pure.
static func inside_arena(point: Vector3) -> bool:
	if RtsCamera.perimeter_poly.size() >= 3:
		return Geometry2D.is_point_in_polygon(Vector2(point.x, point.z), RtsCamera.perimeter_poly)
	var half := RtsCamera.perimeter_half()
	return absf(point.x) <= half and absf(point.z) <= half


## Where the fight is, from a DangerFeed reading: the known enemies' centre, else the arena's middle (as the danger look's
## war pull read it). Pure.
static func war_of(state: Dictionary) -> Vector3:
	var known: Array = state.get("enemies", [])
	if known.is_empty():
		return state.get("middle", Vector3.ZERO)
	var sum := Vector3.ZERO
	for enemy: Dictionary in known:
		sum += enemy["at"] as Vector3
	return sum / float(known.size())


## C1 v2: the enemies that fired at his selection within RtsCamera.DANGER_RECENT_S (known to his team), from a DangerFeed
## reading. Pure.
static func guns_of(state: Dictionary) -> Array:
	var out: Array = []
	for enemy: Dictionary in state.get("enemies", []):
		if float(enemy.get("fired_s", DangerFeed.NEVER)) <= RtsCamera.DANGER_RECENT_S:
			out.append(enemy["at"])
	return out
