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
## How many `standable` calls returned their point unchecked because there was no baked navigation map to ask.
static var unchecked := 0


## The nearest point to `point` a vehicle can stand on (flat), or `point` itself when it already is one, or when the
## navigation map isn't ready (early frames, tests without an arena): then there is nothing better to say.
static func standable(node: Node3D, point: Vector3) -> Vector3:
	if node == null or not node.is_inside_tree() or not Pathing.enabled or not Pathing.is_ready(node):
		# Round 14 (A0): this no-op is SILENT to its caller, and a skirmish deploys before the bake -- so every slot
		# of the lead's army went unchecked and two War Rigs were placed inside a building. Counted, so a caller (and
		# a test) can say how many points it could not check.
		unchecked += 1
		return point
	var map := node.get_world_3d().navigation_map
	var closest := Pathing.closest_point(map, Vector3(point.x, 0.0, point.z), "slot")
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
## Round 11 (nav R2): how far off the mesh a clearance probe may fall before it pushes. It was TOLERANCE_M (1 m), which
## stacked on the mesh's own edge error left an IFV 2.4 m from a rotated wreck with a 4.0 m envelope
## (tests/nav/test_nav_grounded_goals.gd). The centre's tolerance stays 1 m: that one is about not moving a good goal.
const PROBE_TOLERANCE_M := 0.25


## THE ONE GROUNDING CALL for anyone issuing a per-unit goal (Element, Orders' group moves, the drills): the nearest
## point to `point` where a hull of `unit_id` stands on the navmesh with its own turning envelope clear. `node` is any
## node in the match's world (it only reaches the navigation map). Round 10: nav measured 11 of 13 Terminus arrival
## misses as right-click moves (Orders, no Element) whose goal sat 4-10 m inside a block; one rule, one owner.
static func for_unit(node: Node3D, point: Vector3, unit_id: String) -> Vector3:
	return standable_for(node, point, envelope_of(unit_id))


## Round 24 (brains R1, his bridge on the Locks): ground a vehicle cannot cross. Water and pits are holes in the navmesh
## (ArenaTerrain), and every nearest-point question asked of the mesh answers a point IN the water with whichever bank
## is nearer -- which for a slot in the middle of a canal is a coin toss between the bank its element is on and the bank
## it is going to, and for a slot just past the middle, the wrong one. These answer from the arena's own terrain
## (Arena.active, Invariant 0: no copied table), so a dry map pays one dictionary lookup and nothing else.
## Samples along a leg are this far apart (metres): the narrowest carving shipped (a Sumps pit) is several times wider.
const WET_STEP_M := 1.0
## How far onto dry ground a pulled slot lands past the first dry sample: the rim (1.2 m) and the bake's agent radius
## (2 m) to reach the navmesh's edge, plus a margin so the hull's own clearance push does not reach back over the water.
const DRY_MARGIN_M := 4.0
## The A/B switch (`--wet-ground=off` on a probe is the control arm: round 23's grounding, slots snapped to either bank).
static var WET_ENABLED := true


## Whether `point` is on water or a pit (and not on a bridge deck over it). The arena's shape is not asked: off the
## map is a different question (Arena.contains answers both).
static func wet(point: Vector3, data: Dictionary = Arena.active) -> bool:
	if not data.has("terrain"):
		return false
	for entry: Dictionary in data["terrain"]:
		if not ArenaTerrain.carves(String(entry["kind"])):
			continue
		var box := ArenaTerrain.bounds(entry)
		if point.x > box[0] and point.x < box[2] and point.z > box[1] and point.z < box[3]:
			for deck: Dictionary in data["terrain"]:
				if ArenaTerrain.is_deck(String(deck["kind"])):
					var d := ArenaTerrain.bounds(deck)
					if point.x > d[0] and point.x < d[2] and point.z > d[1] and point.z < d[3]:
						return false
			return true
	return false


## Whether `point` is no place to be TOLD TO STAND: over water or a pit at all (a bridge deck included), or in a
## bridge's mouth (its deck's rectangle grown by MOUTH_CLEAR_M). A crew parked on a bridge holds every crew behind it
## (his Locks, the bridge series' seed 1: a seat grounded onto the west swing bridge's deck, and later one reseated at
## the deck's far end; the crew covered its sector there and three crews queued against it for 50 s). Routes still
## cross decks: this is about where a crew is SENT, never where it drives.
const MOUTH_CLEAR_M := 2.0


static func over_water(point: Vector3, data: Dictionary = Arena.active) -> bool:
	if not data.has("terrain"):
		return false
	for entry: Dictionary in data["terrain"]:
		var box := ArenaTerrain.bounds(entry)
		var grow := MOUTH_CLEAR_M if ArenaTerrain.is_deck(String(entry["kind"])) else 0.0
		if not ArenaTerrain.carves(String(entry["kind"])) and grow == 0.0:
			continue
		if point.x > box[0] - grow and point.x < box[2] + grow and point.z > box[1] - grow and point.z < box[3] + grow:
			return true
	return false


## Whether the straight leg from `from` to `to` crosses water or a pit anywhere.
static func leg_wet(from: Vector3, to: Vector3, data: Dictionary = Arena.active) -> bool:
	if not data.has("terrain"):
		return false
	var steps := maxi(1, ceili(Vector2(to.x - from.x, to.z - from.z).length() / WET_STEP_M))
	for i in range(1, steps + 1):
		if wet(from.lerp(to, float(i) / float(steps)), data):
			return true
	return false


## Where the straight leg from `from` toward `to` must stop to keep `margin` metres short of the first water on it:
## `to` itself when the leg is dry, else the point `margin` back from the last dry sample (never behind `from`).
## `strict`: stop at the first point over the water at all (a deck too: a place to stand, not a route).
static func dry_leg_end(from: Vector3, to: Vector3, margin: float, data: Dictionary = Arena.active,
		strict := false) -> Vector3:
	if not data.has("terrain"):
		return to
	var length := Vector2(to.x - from.x, to.z - from.z).length()
	var steps := maxi(1, ceili(length / WET_STEP_M))
	for i in range(1, steps + 1):
		var probe := from.lerp(to, float(i) / float(steps))
		if over_water(probe, data) if strict else wet(probe, data):
			var dry := length * float(i - 1) / float(steps) - margin
			return from if dry <= 0.0 else from.lerp(to, dry / length)
	return to


## A point over water or a pit (a bridge deck included: see over_water), pulled toward `toward` (the element's
## anchor) until it is DRY_MARGIN_M onto dry ground. Unchanged when it is not over the water, when `toward` itself is
## (he clicked the bridge: his to keep), or when no dry ground lies between them.
static func pulled_dry(point: Vector3, toward: Vector3, data: Dictionary = Arena.active) -> Vector3:
	# Round 24 (native, C24.8): natively (NativeEl, el_native.cpp); the GDScript below is the reference.
	if NativeEl.usable():
		return NativeEl.pulled_dry(point, toward, data)
	if not WET_ENABLED or not over_water(point, data) or over_water(toward, data):
		return point
	var length := Vector2(toward.x - point.x, toward.z - point.z).length()
	var steps := maxi(1, ceili(length / WET_STEP_M))
	for i in range(1, steps + 1):
		if not over_water(point.lerp(toward, float(i) / float(steps)), data):
			var at := length * float(i) / float(steps) + DRY_MARGIN_M
			return toward if at >= length else point.lerp(toward, at / length)
	return point


## A formation slot on its ANCHOR's side of any water: when the slot is over the water (a deck included) or the
## straight line from the anchor to it crosses water (the far bank), the slot moves back along that line to
## DRY_MARGIN_M short of the first water (the anchor itself when it stands closer to the water than that). A shape whose anchor has just
## crossed a canal had its rear seats on the bank it came from, and the crews sent there stopped on the wrong side.
## Unchanged when neither holds, or when the anchor itself is over the water (a click on the bridge: his to keep).
static func on_anchor_side(slot: Vector3, anchor: Vector3, data: Dictionary = Arena.active) -> Vector3:
	# Round 24 (native, C24.8): natively (NativeEl, el_native.cpp); the GDScript below is the reference.
	if NativeEl.usable():
		return NativeEl.on_anchor_side(slot, anchor, data)
	if not WET_ENABLED or not data.has("terrain") or over_water(anchor, data) \
			or not (over_water(slot, data) or leg_wet(anchor, slot, data)):
		return slot
	var at := dry_leg_end(anchor, slot, DRY_MARGIN_M, data, true)
	return Vector3(at.x, slot.y, at.z)


## Round 21 (brains stretch d; orders' R1, builder0, parade seed 3): a wedge anchored on the bay's row of stacked
## containers asked for a slot inside the row, and the NEAREST standable point was the row's far side; the crew drove
## round the west end and ended blocked 26 m short. `standable_from` grounds a slot on the side its element reaches it
## FROM: when the nearest answer can only be driven to by going round (its navmesh path from `from` is more than
## REACH_DETOUR x the straight line + REACH_SLACK_M), it steps back from the asked point toward `from` and takes the
## first grounded point that is reached directly, that is within SIDE_MAX_M of the asked point and whose drive is at
## least SIDE_GAIN_M shorter. A slot that needed no push, or `from` null, is standable_for's answer.
## The two bounds are the arrive series' (lesson 261): with "reached directly" alone, the Sumps' winding lanes read
## almost every pushed slot as a detour and stepped it back toward the squad, and 6 of its 20 runs never arrived.
const REACH_DETOUR := 1.3
const REACH_SLACK_M := 6.0
const SIDE_MAX_M := 12.0
const SIDE_GAIN_M := 15.0
## The steps back toward `from` are this far apart (metres), at least.
const SIDE_STEP_M := 2.5
## The A/B switch (`--slot-side=nearest` on any match run is the control arm: round 6's nearest point).
static var SIDE_ENABLED := true
static var _side_memo := {}


static func standable_from(node: Node3D, point: Vector3, clearance: float, from: Variant) -> Vector3:
	var at := standable_for(node, point, clearance)
	if not SIDE_ENABLED or not (from is Vector3) or Vector2(at.x - point.x, at.z - point.z).length() <= TOLERANCE_M \
			or node == null or not node.is_inside_tree() or not Pathing.enabled or not Pathing.is_ready(node):
		return at
	var origin := Vector3((from as Vector3).x, 0.0, (from as Vector3).z)
	# The side does not change while the element stays in one 5 m cell: memoised with the ground memo's map iteration.
	var key := [point, clearance, Vector2i(roundi(origin.x / 5.0), roundi(origin.z / 5.0))]
	if _side_memo.size() >= GROUND_MEMO_LIMIT or _ground_iteration != NavigationServer3D.map_get_iteration_id(
			node.get_world_3d().navigation_map):
		_side_memo.clear()
	var known: Variant = _side_memo.get(key)
	if known != null:
		return known
	var answer := at
	var far := path_length(node, origin, at)
	if not reached_directly(node, origin, at, far):
		var back := Vector3(origin.x - point.x, 0.0, origin.z - point.z)
		var span := back.length()
		var step := maxf(SIDE_STEP_M, clearance * 0.5)
		var t := step
		while t < span:
			var candidate := standable_for(node, point + back / span * t, clearance)
			if Vector2(candidate.x - point.x, candidate.z - point.z).length() > SIDE_MAX_M:
				break
			var near := path_length(node, origin, candidate)
			if reached_directly(node, origin, candidate, near) and near + SIDE_GAIN_M <= far:
				answer = candidate
				break
			t += step
	_side_memo[key] = answer
	return answer


## Whether a hull at `from` drives to `to` without going round anything: its navmesh path is at most REACH_DETOUR x the
## straight line + REACH_SLACK_M.
static func reached_directly(node: Node3D, from: Vector3, to: Vector3, length := -1.0) -> bool:
	if length < 0.0:
		length = path_length(node, from, to)
	return length <= Vector2(to.x - from.x, to.z - from.z).length() * REACH_DETOUR + REACH_SLACK_M


## The navmesh drive from `from` to `to` (metres; the straight line when there is no path).
static func path_length(node: Node3D, from: Vector3, to: Vector3) -> float:
	var path := Pathing.find_path(node, from, to)
	if path.size() < 2:
		return Vector2(to.x - from.x, to.z - from.z).length()
	var length := 0.0
	for i in range(1, path.size()):
		length += Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
	return length


## Round 16 (brains, switch `ground_memo`): standable_for is a pure function of the navigation map and its two numbers,
## and the map changes only when the server syncs a new iteration. Formation slots, squad slots and a held post are
## re-grounded at the same points decision after decision (up to ~33 navmesh queries each: the centre, three push
## rounds of eight probes, the fit test, and the rings when it does not fit), so an answer is kept for the map's
## iteration and handed back for the same point and clearance. Cleared wholesale at GROUND_MEMO_LIMIT.
const GROUND_MEMO_LIMIT := 4096
static var _ground_map := RID()
static var _ground_iteration := -1
static var _ground_memo := {}


static func standable_for(node: Node3D, point: Vector3, clearance: float) -> Vector3:
	# Round 24 (native, C24.8): natively (NativeEl, el_native.cpp); the GDScript below is the reference.
	if NativeEl.grounds(node):
		return NativeEl.standable_for(node, point, clearance)
	if not BrainSwitches.ground_memo or node == null or not node.is_inside_tree() or not Pathing.enabled \
			or not Pathing.is_ready(node):
		return _standable_for(node, point, clearance)
	var map := node.get_world_3d().navigation_map
	var iteration := NavigationServer3D.map_get_iteration_id(map)
	if map != _ground_map or iteration != _ground_iteration or _ground_memo.size() >= GROUND_MEMO_LIMIT:
		_ground_map = map
		_ground_iteration = iteration
		_ground_memo.clear()
	var key := [point, clearance]  # exact: a Vector4 would round the clearance to 32 bits
	var known: Variant = _ground_memo.get(key)
	if known != null:
		if OrderController.profile_detail:
			OrderController.add_part("nav.ground_memo", 0)
		return known
	var answer := _standable_for(node, point, clearance)
	_ground_memo[key] = answer
	return answer


static func _standable_for(node: Node3D, point: Vector3, clearance: float) -> Vector3:
	var at := standable(node, point)
	var need := clearance - bake_radius()
	if need <= 0.0 or node == null or not node.is_inside_tree() or not Pathing.enabled or not Pathing.is_ready(node):
		return at
	var map := node.get_world_3d().navigation_map
	at = _settle(node, map, at, need)
	if _fits(map, at, need):
		return at
	# Round 11 (nav R2): the pushes cancelled in a pinch - between a wreck and a block face, a gap narrower than the
	# envelope - and the point they left is one the hull does not fit. Look around it for the nearest point that DOES,
	# ring by ring out to FIT_RINGS envelopes; a street that is narrower than the envelope everywhere keeps the
	# centred point, which is the best there is (and was the only answer before).
	for ring in range(1, FIT_RINGS + 1):
		var best: Variant = null
		var best_d := INF
		for k in CLEARANCE_PROBES:
			var angle := TAU * float(k) / float(CLEARANCE_PROBES)
			var candidate := _settle(node, map, standable(node, at + Vector3(cos(angle), 0.0, sin(angle)) * need * float(ring)), need)
			if not _fits(map, candidate, need):
				continue
			var d := Vector2(candidate.x - at.x, candidate.z - at.z).length()
			if d < best_d:
				best_d = d
				best = candidate
		if best != null:
			return best
	return at


## How many envelope-widths out standable_for looks for a point the hull fits, when the one it settled on does not.
const FIT_RINGS := 2


## The push loop: every clearance probe that falls off the mesh pushes the point back by how far off it fell.
static func _settle(node: Node3D, map: RID, at: Vector3, need: float) -> Vector3:
	for iteration in CLEARANCE_ITERATIONS:
		var push := Vector3.ZERO
		for k in CLEARANCE_PROBES:
			var back := _off_mesh(map, at, need, k)
			if back.length() > PROBE_TOLERANCE_M:
				push += back
		if push.length() <= PROBE_TOLERANCE_M:
			break
		at = standable(node, at + push / float(CLEARANCE_PROBES) * 2.0)
	return at


## Whether every clearance probe around `at` is on the mesh (within the mesh's own edge noise, TOLERANCE_M / 2).
static func _fits(map: RID, at: Vector3, need: float) -> bool:
	for k in CLEARANCE_PROBES:
		if _off_mesh(map, at, need, k).length() > TOLERANCE_M * 0.5:
			return false
	return true


## Probe `k`'s way back onto the mesh (zero when it is on it).
static func _off_mesh(map: RID, at: Vector3, need: float, k: int) -> Vector3:
	var angle := TAU * float(k) / float(CLEARANCE_PROBES)
	var probe := Vector3(at.x + cos(angle) * need, 0.0, at.z + sin(angle) * need)
	var closest := Pathing.closest_point(map, probe, "slot")
	return Vector3(closest.x - probe.x, 0.0, closest.z - probe.z)


## Round 11 (nav R2, leak 4): slots are grounded one at a time, so two slots pushed out of the same block can land on
## the same point, and in a street narrower than the envelope a wing slot collapses onto the centreline (leak 5) — onto
## whoever is already there. Two crews handed one spot means one of them never arrives, which on the lead's screen is a
## hull "stuck behind a wall". `apart` takes a grounded goal and the spots already handed out ([point, half width]
## pairs) and, when it overlaps one, searches rings around it for the nearest grounded point that overlaps none. The
## rings step by this hull's width, so the first ring is "the next spot over"; APART_RINGS bounds both the work (only
## ever paid on a conflict) and how far from where he pointed a crew may be moved. Nothing found: the goal as it was.
const APART_RINGS := 3
const APART_DIRECTIONS := 8


static func half_width_of(unit_id: String) -> float:
	if not Units.exists(unit_id):
		return 0.0
	return 0.5 * float((Units.stat(unit_id, "hull_size", [0.0, 0.0, 0.0]) as Array)[0])


static func overlaps(point: Vector3, half_width: float, taken: Array) -> bool:
	for spot: Array in taken:
		var other: Vector3 = spot[0]
		if Vector2(point.x - other.x, point.z - other.z).length() < half_width + float(spot[1]) - 0.01:
			return true
	return false


static func apart(node: Node3D, goal: Vector3, unit_id: String, taken: Array) -> Vector3:
	var half := half_width_of(unit_id)
	if not overlaps(goal, half, taken):
		return goal
	var step := maxf(2.0 * half, 2.0)
	for ring in range(1, APART_RINGS + 1):
		var best: Variant = null
		var best_d := INF
		for k in APART_DIRECTIONS:
			var angle := TAU * float(k) / float(APART_DIRECTIONS)
			var candidate := for_unit(node, goal + Vector3(cos(angle), 0.0, sin(angle)) * step * float(ring), unit_id)
			if overlaps(candidate, half, taken):
				continue
			var d := Vector2(candidate.x - goal.x, candidate.z - goal.z).length()
			if d < best_d:
				best_d = d
				best = candidate
		if best != null:
			return best
	return goal


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
