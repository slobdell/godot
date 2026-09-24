class_name AirshipFlight
extends RefCounted
## The broadcast airship's whole flight: the pilot, the height it holds, and what it must not fly into. One object,
## stepped once per fixed tick, used by the node that draws it, the tests that fly it and the report that measures it,
## so the flight that is measured is the flight that is drawn.
##
## Round 11 (airship stream), the lead: *"It also looks like the airship itself ends up intersecting with the
## buildings in Terminus as it flies around."* It did, 37.5 % of a four-minute Terminus flight, for three reasons
## that each had to go:
##
## 1. **WHAT IT AVOIDED WAS A CIRCLE TABLE, NOT THE MAP.** A 40 x 40 m city block was a circle of radius 21, and the
##    block's corner is 28.28 m out, so the hull was scored "clear" with its beam 7 m inside a building (the start
##    position itself was 17.8 m inside one). Now the solids are the layout's own rotated boxes (`solids_of`), and the
##    hull is a rotated rectangle, not a point: two rectangles, separating-axis test, nothing round anywhere.
## 2. **A FLOODLIGHT IS 16 m TALL, NOT 3 m AND NOT 24 m.** Heights come from what is DRAWN, because the lead sees the
##    mast, not the collision box under it. The kit's collision boxes are gameplay's (a floodlight is its 3 m
##    footing; an ad screen is its plinth; a sign collides with nothing), so each kit type the art draws taller than
##    its box is grown here to its drawn extent (`DRAWN`), and `tests/test_theme_ad_airship.gd` measures the kit's
##    own meshes to hold that table honest. The old table had the floodlight at 24 m (it climbed over a lamp post as
##    if it were a building); the brief guessed 3 m (it would have flown through 13 m of mast).
## 3. **IT CLIMBED WHEN ITS CENTRE WAS ALREADY OVER THE ROOF.** Climbing 20.8 m at 2.4 m/s takes 8.7 s, it was told
##    1.6 s before the wall, and the nose is 28.5 m ahead of the point that was tested. **THE RULE NOW: fly a ghost of
##    the pilot ahead, and hold the lowest height from which every roof the hull's footprint will cross can still be
##    climbed over in time** -- for a roof needing height `r` reached `t` seconds from now, the hull must already be at
##    `r - CLIMB_LEAD * CLIMB_MPS * t`. That is the latest the climb can start, with a fifth of the climb rate kept in
##    reserve for a ghost that turned differently from the real hull. The converse falls out of the same rule: the
##    moment the hull's footprint is off the last roof and nothing is ahead, the held height drops to the cruise and
##    it sinks straight back to where he can see it, at the same gentle rate it climbed.

## --- what is drawn taller than its collision box ---------------------------------------------------------------
## [width along the prop's x, top, depth along its z], metres, from the kit's own mesh constants. Grown, never shrunk:
## the footprint used is the larger of this and the collision box.
static var DRAWN := {
	# The footing (2.4 m), a 15 m lattice mast and a 4.2 m lamp head on top of it.
	"floodlight": [4.2, KitYard.MAST_HEIGHT + 1.05, KitYard.FLOODLIGHT.z],
	# A 6 x 1.5 m neon board on a 6 m post, in a 0.15 m frame; the post's plinth is 0.9 m square.
	"sign": [KitYard.SIGN_SIZE.x + 0.3, KitYard.SIGN_HEIGHT + KitYard.SIGN_SIZE.y + 0.15, 0.9],
	# The 7 x 14 m LED wall from 6 m up, its housing, and the red beacon on top (ad_screen.gd).
	"ad_screen": [7.8, 20.7, 2.1],
}

## --- the hull, as the parts that can hit something ------------------------------------------------------------
## The hull is NOT a 57 x 22 m box. Measured off `arena_airship` in 20 slices (the test re-measures it): the full
## 22.2 m beam exists only where the screen housings and tail fins stand out, and all of that sits at least 2.9 m
## BELOW THE CENTRE (1.97 m on the 38 m mesh) -- eight metres above the belly. Only a 14.4 m keel reaches the belly.
## So a lamp post can pass under a wing at a height that would have forced the old box over a building's worth of
## climb. Two parts, in the UNSCALED mesh's metres (the node carries SCALE): [centre z along the hull (+z is aft),
## half-width, half-length, how far the part's underside hangs below the hull centre].
const HULL_PARTS := [
	[0.0, 4.8, 19.0, 7.237],   # the keel, nose to tail, down to the belly (-BELLY_FRACTION * 38)
	[6.65, 7.41, 12.35, 1.97], # the wings: screen housings and fins, from 5.7 m ahead of centre to the tail
]

## The top of everything drawn on the hull (fins, the broadcast apparatus), as a fraction of its length: the mesh's
## bounds are +-7.2549 m on the 38 m asset. NOT the deck screen's height (0.08): a camera parked over the deck panel
## was still inside the fins, which is what the first clip of the camera lift showed.
const TOP_FRACTION := 0.1910

## --- the climb --------------------------------------------------------------------------------------------------
## How far around the hull's footprint it keeps clear of a solid's footprint before counting itself over it.
const SIDE_MARGIN := 2.0
## The share of the climb rate the plan counts on; the rest is the reserve for a ghost that flew a slightly different
## line from the real hull.
const CLIMB_LEAD := 0.8
## The ghost is flown at this step (3 fixed ticks), and the plan is redone every LOOK_EVERY ticks. Measured: the ghost's
## heading stays within a few degrees of the real hull's over the horizon, and it costs ~20 pilot steps per tick.
const LOOK_STEP_TICKS := 3
const LOOK_EVERY := 6
## A catch-up re-fly (a rebuild mid-match flies again from tick 0) plans only its last stretch: the height it ends at
## is all anyone sees, and planning 40 000 ticks would be a hitch of seconds.
const PLAN_TAIL_TICKS := 900

## --- the orbit bends toward open ground -------------------------------------------------------------------------
## Climbing is what keeps it out of the buildings, but a hull up over the roofs is a hull he cannot see (his frame's
## top edge is 3.5 deg below the horizon), so the ORBIT prefers ground it can cruise over: every LOOK_EVERY ticks the
## radius is re-chosen from these multiples of ORBIT_RADIUS by what the next stretch of each circle would make it climb,
## plus a small price for straying from the nominal orbit, and a new choice has to win by STICKY to replace the old one
## (a hull that changed its mind every second would weave). Never SMALLER than the nominal orbit: a heavy hull slowed
## by its own turn cannot track a 40 m circle, and on the Sumps it looped on the spot trying.
const ORBIT_CHOICES := [1.0, 1.2, 1.4, 1.6]
const ORBIT_AHEAD_RAD := [0.4, 0.8, 1.2, 1.6]
const CLIMB_COST := 1.0
const STRAY_COST := 0.06
const STICKY := 1.5

var pilot := AirshipPilot.new()
var orbit := AirshipPilot.ORBIT_RADIUS
## The hull centre's height before the float, and the height the plan wants it at.
var altitude := SyndicateAdAirship.ALTITUDE
var wanted_altitude := SyndicateAdAirship.ALTITUDE
var solids: Array = []
var play_radius := 100.0
var action := Vector2.ZERO
var home := Vector2.ZERO
var home_heading := 0.0
var ticks := 0
var _highest := SyndicateAdAirship.ALTITUDE


func _init(layout: Dictionary = {}) -> void:
	solids = AirshipFlight.solids_of(layout)
	for solid: Dictionary in solids:
		_highest = maxf(_highest, float(solid["need"]))
	play_radius = SyndicateAdAirship.play_radius(layout)
	var start := AirshipFlight.start_of(layout, solids)
	home = start["at"]
	home_heading = start["heading"]
	action = Vector2.ZERO
	reset()


func reset() -> void:
	pilot.reset(home, home_heading)
	ticks = 0
	orbit = AirshipPilot.ORBIT_RADIUS
	choose_orbit()
	wanted_altitude = plan()
	altitude = wanted_altitude


## Everything on `layout` the hull could visibly fly into, as rotated boxes: [{centre: Vector2, half: Vector2 (x, z),
## yaw (rad), top (m), need (the hull-centre height that clears it), type}]. The layout's own obstacles (every
## colliding kit prop, stacks included, plus legacy boxes) and its non-colliding props, each grown to what is drawn.
## Only what the cruising hull could touch is kept -- anything its belly already clears is dropped here, once.
static func solids_of(layout: Dictionary) -> Array:
	var out: Array = []
	if layout.is_empty():
		return out
	var runtime := Arena.normalize(layout)
	var entries: Array = runtime.get("obstacles", []).duplicate()
	for prop: Dictionary in runtime.get("props", []):
		var type := String(prop.get("type", ""))
		if ArenaKit.is_kit(type) and not ArenaKit.collides(type):
			var copy := prop.duplicate(true)
			var size := ArenaKit.size_of(prop)
			copy["size"] = [size.x, size.y, size.z]
			entries.append(copy)
	for entry: Dictionary in entries:
		var size := Arena.obstacle_size(entry)
		var type := String(entry.get("type", ""))
		if DRAWN.has(type):
			var drawn: Array = DRAWN[type]
			size = Vector3(maxf(size.x, float(drawn[0])), maxf(size.y, float(drawn[1])), maxf(size.z, float(drawn[2])))
		var need := AirshipFlight.need_over(size.y)
		if need <= SyndicateAdAirship.ALTITUDE:
			continue
		var position: Array = entry.get("position", [0.0, 0.0])
		out.append({"centre": Vector2(float(position[0]), float(position[1])), "half": Vector2(size.x, size.z) * 0.5,
				"yaw": deg_to_rad(float(entry.get("rotation_deg", 0.0))), "top": size.y, "need": need, "type": type})
	return out


## The hull-centre height whose `part`'s underside (default: the belly), at the bottom of its float, keeps
## ROOF_CLEARANCE over a roof `top` metres up.
static func need_over(top: float, part: Array = HULL_PARTS[0]) -> float:
	return top + SyndicateAdAirship.ROOF_CLEARANCE + SyndicateAdAirship.FLOAT_RISE_TOTAL + float(part[3]) * SyndicateAdAirship.SCALE


## The hull's footprint at `at`, turned to `heading`, as a box in the same terms as a solid: its beam across local x,
## its length along local z (Godot's forward is -Z, and a node's yaw is its heading, so the hull IS a box yawed by it).
static func hull_half(margin := 0.0) -> Vector2:
	return Vector2(SyndicateAdAirship.BEAM * 0.5 + margin, SyndicateAdAirship.LENGTH * 0.5 + margin)


## How far apart two rotated rectangles are along their best separating axis: positive is a gap (a lower bound on the
## true distance), zero or negative means their footprints overlap. Pure.
static func gap(a_centre: Vector2, a_half: Vector2, a_yaw: float, b_centre: Vector2, b_half: Vector2, b_yaw: float) -> float:
	var d := b_centre - a_centre
	var a_axes := [Vector2(cos(a_yaw), -sin(a_yaw)), Vector2(sin(a_yaw), cos(a_yaw))]
	var b_axes := [Vector2(cos(b_yaw), -sin(b_yaw)), Vector2(sin(b_yaw), cos(b_yaw))]
	var best := -INF
	for axis: Vector2 in a_axes + b_axes:
		var reach_a := a_half.x * absf((a_axes[0] as Vector2).dot(axis)) + a_half.y * absf((a_axes[1] as Vector2).dot(axis))
		var reach_b := b_half.x * absf((b_axes[0] as Vector2).dot(axis)) + b_half.y * absf((b_axes[1] as Vector2).dot(axis))
		best = maxf(best, absf(d.dot(axis)) - reach_a - reach_b)
	return best


## The lowest the hull centre may be with its footprint at this pose: the cruise over open ground, or, for each hull
## part whose footprint (plus SIDE_MARGIN) overlaps a solid, the height that puts that part's underside over it. Pure.
static func need_at(at: Vector2, heading: float, from: Array) -> float:
	var wanted := SyndicateAdAirship.ALTITUDE
	var reach := AirshipFlight.hull_half(SIDE_MARGIN).length()
	var aft := Vector2(sin(heading), cos(heading))
	for solid: Dictionary in from:
		if float(solid["need"]) <= wanted:
			continue
		var centre: Vector2 = solid["centre"]
		if at.distance_to(centre) > reach + (solid["half"] as Vector2).length():
			continue
		for part: Array in HULL_PARTS:
			var need := AirshipFlight.need_over(float(solid["top"]), part)
			if need <= wanted:
				continue
			var half := Vector2(float(part[1]), float(part[2])) * SyndicateAdAirship.SCALE + Vector2(SIDE_MARGIN, SIDE_MARGIN)
			if AirshipFlight.gap(at + aft * float(part[0]) * SyndicateAdAirship.SCALE, half, heading, centre, solid["half"],
					float(solid["yaw"])) <= 0.0:
				wanted = need
	return wanted


## Metres between the cruising hull's footprint at this pose and the nearest solid it would have to climb over
## (negative: it is over one). Pure.
static func clearance(at: Vector2, heading: float, from: Array) -> float:
	var clear := 999.0
	for solid: Dictionary in from:
		clear = minf(clear, AirshipFlight.gap(at, AirshipFlight.hull_half(), heading, solid["centre"], solid["half"],
				float(solid["yaw"])))
	return clear


## Where it starts, and facing which way: the clearest pose on rings around the middle, facing along its orbit so it
## sets off the way it will go. Searched at several radii as well as bearings, because on the Terminus a whole ring
## can be inside the blocks. Pure.
static func start_of(layout: Dictionary, from: Array) -> Dictionary:
	if layout.is_empty():
		return {"at": Vector2.ZERO, "heading": 0.0}
	var half := float(layout.get("half_size", 120.0))
	var best := {"at": Vector2(0.0, -minf(AirshipPilot.ORBIT_RADIUS, half * 0.7)), "heading": 0.0}
	var best_score := -INF
	for ring in 6:
		var radius := lerpf(AirshipPilot.ORBIT_RADIUS * 0.6, half * 0.92, float(ring) / 5.0)
		for i in 24:
			var angle := TAU * i / 24.0
			var at := Vector2(cos(angle), sin(angle)) * radius
			# Tangent to the orbit, the way ORBIT_SIGN goes round.
			var along := Vector2(-sin(angle), cos(angle)) * AirshipPilot.ORBIT_SIGN
			var heading := AirshipPilot.heading_toward(along)
			var score := minf(AirshipFlight.clearance(at, heading, from), 6.0) - absf(radius - AirshipPilot.ORBIT_RADIUS) * 0.01
			if score > best_score:
				best_score = score
				best = {"at": at, "heading": heading}
	return best


## Where the pilot is told to go from `at`: round the action, pushed off what it should not fly into, kept inside
## the wall. Pure given the flight's state.
##
## **THE ORDER, DECIDED (round 11, S4): containment wins sideways, height wins over buildings.** On the Terminus the
## (+-100, 0) blocks stand 80-120 m out, entirely inside the band where containment bites (from 85.6 m), and running
## containment last erased the avoidance push exactly there. No goal satisfies both in that band -- the block runs to
## within 1 m of the play radius -- so one of them has to give, and it is the one with another answer: the wall has
## a crowd behind it and only steering keeps the hull off it, while a building is cleared by the climb whatever the
## steering does (`plan`). So containment stays LAST and absolute, avoidance is a preference that makes climbing
## rarer, and the hull goes OVER the outer blocks when the fight draws it that way
## (`test_by_the_wall_it_stays_inside_and_goes_over_the_outer_blocks`).
func goal_for(at: Vector2) -> Vector2:
	var goal := AirshipPilot.carrot(at, action, orbit)
	# Steer round only what it cannot already clear at the height it is flying: pushing the goal off a roof it is
	# passing over anyway just swings the carrot behind the hull and makes it circle.
	goal = AirshipPilot.avoid(goal, at, solids, SyndicateAdAirship.BEAM * 0.5 + SyndicateAdAirship.AVOID_CLEARANCE,
			altitude + 0.5)
	# Containment LAST, so neither the orbit nor an avoidance push can send it through the wall.
	return AirshipPilot.contain(goal, at, play_radius)


## One fixed tick. `plan_now` false is a catch-up re-fly: it keeps the orbit and the height it has and only flies,
## because only where a catch-up ENDS is ever drawn and a rebuild must not hitch (40 000 ticks planned took 2.6 s).
func step(plan_now := true) -> void:
	var dt := 1.0 / SimClock.TICK_RATE
	pilot.step(dt, goal_for(pilot.position))
	ticks += 1
	if plan_now and ticks % LOOK_EVERY == 0:
		choose_orbit()
		wanted_altitude = plan()
	altitude = move_toward(altitude, wanted_altitude, SyndicateAdAirship.CLIMB_MPS * dt)


## What flying the next stretch of a circle of `radius` round the action would cost: the mean climb its footprint
## would need there, plus the price of straying from the nominal orbit.
func orbit_cost(radius: float) -> float:
	var offset := pilot.position - action
	var bearing := atan2(offset.y, offset.x)
	var climb := 0.0
	for ahead: float in ORBIT_AHEAD_RAD:
		var angle := bearing + ahead * AirshipPilot.ORBIT_SIGN
		var at := action + Vector2(cos(angle), sin(angle)) * radius
		var along := Vector2(-sin(angle), cos(angle)) * AirshipPilot.ORBIT_SIGN
		climb += AirshipFlight.need_at(at, AirshipPilot.heading_toward(along), solids) - SyndicateAdAirship.ALTITUDE
	return climb / ORBIT_AHEAD_RAD.size() * CLIMB_COST + absf(radius - AirshipPilot.ORBIT_RADIUS) * STRAY_COST


## Re-choose the orbit radius (the rule above). Circles that would carry the hull past the containment are not offered.
func choose_orbit() -> void:
	if solids.is_empty():
		orbit = AirshipPilot.ORBIT_RADIUS
		return
	var best := orbit
	var best_cost := orbit_cost(orbit) - STICKY
	for k: float in ORBIT_CHOICES:
		var radius := AirshipPilot.ORBIT_RADIUS * k
		if action.length() + radius > play_radius * AirshipPilot.CONTAIN_FROM + AirshipPilot.TRACK_MARGIN:
			continue
		var cost := orbit_cost(radius)
		if cost < best_cost:
			best = radius
			best_cost = cost
	orbit = best


## The height to hold now (the rule in the header): fly a ghost ahead and take, over every pose it passes, the roof
## that pose needs less what the climb can still make up before it gets there. Stops as soon as nothing further out
## could matter, so over open ground it is a few ghost steps.
func plan() -> float:
	var wanted := AirshipFlight.need_at(pilot.position, pilot.heading, solids)
	if solids.is_empty():
		return wanted
	var ghost := pilot.copy()
	var dt := float(LOOK_STEP_TICKS) / SimClock.TICK_RATE
	var rate := SyndicateAdAirship.CLIMB_MPS * CLIMB_LEAD
	var seconds := 0.0
	# Beyond this nothing can raise `wanted`: the tallest solid, less the climb that far ahead.
	while _highest - rate * seconds > wanted:
		ghost.step(dt, goal_for(ghost.position))
		seconds += dt
		wanted = maxf(wanted, AirshipFlight.need_at(ghost.position, ghost.heading, solids) - rate * seconds)
	return wanted


## The hull as a box for the camera (`RtsCamera.clear_pose`'s `occluders`): its footprint at `at` turned to
## `heading`, from belly to deck around a centre `centre_y` metres up (the drawn height, float included). Pure.
static func hull_box(at: Vector2, heading: float, centre_y: float) -> Dictionary:
	return {"centre": at, "half": AirshipFlight.hull_half(), "yaw": heading,
			"bottom": centre_y + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH,
			"top": centre_y + TOP_FRACTION * SyndicateAdAirship.LENGTH}


## The lowest the belly gets at this height, at the bottom of its float.
func belly() -> float:
	return altitude + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH - SyndicateAdAirship.FLOAT_RISE_TOTAL
