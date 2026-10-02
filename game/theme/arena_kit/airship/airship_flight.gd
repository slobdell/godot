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

## --- the player's view (round 14) ------------------------------------------------------------------------------
## The lead (2026-09-27): *"make the aircraft choose its flight path such that it doesn't go directly into the player's
## view"*. WHAT SHIPS is the CLIMB over his view (`view_climb`, below `plan`); this section is the STEERING that was
## built first, measured, and kept OFF (`view_avoid`). Switches: `_read_switches`.
##
## HOW the steering works: the orbit chooser below already prices every candidate circle by what its next stretch (0.4-1.6 rad ahead, ~13 s
## at cruise: more than the 8.7 s the heavy rudder needs to answer) would cost. The view term adds two things to it:
## circles centred elsewhere than on the fight (`view_offsets`), and a price on every look-ahead sample where the hull
## would sit in FRONT of the fight in his frame (`AirshipSight.between`, the same test `make airship-view` measures).
## WHICH CENTRES (`TOWARD_CAMERA`, `AWAY_FROM_ARMY`): the fight, the fight pushed toward his camera, and the fight
## pushed away from his army; neither family wins alone (the measurements are kept there). The price counts the live
## camera and the camera behind each of his squads (`squad_views`), because the live camera travels to whichever
## squad he recalls.
## The PID, the carrot, the containment and the climb-over are untouched: this only chooses WHICH circle the carrot rides.
## MEASURED NO HELP IN PLAY, so OFF by default (`--airship-on=viewsteer` turns it on): the design series
## (builder0, seeds 1-4 and 7, `make airship-view`) had steering + climb hide the fight 4.0 % on the yard against climb
## alone 0.9-2.1 %, and steering alone 7.7-9.6 % against round 13's 3.4-5.5 %. Kept, switchable, with its reasons.
static var view_avoid := false
static var _switches_read := false
## Candidate orbit centres, as offsets from the fight in orbit radii: pushed TOWARD the ground under his camera
## (`TOWARD_CAMERA`) and pushed AWAY FROM HIS ARMY, toward the enemy (`AWAY_FROM_ARMY`). Neither family wins alone,
## measured: toward the camera keeps a FIXED camera clear (it sits 45.7 m back, inside the 62 m orbit, so that circle's
## near arc passes behind the lens) but is a circle over his own squads, and in play (builder0, yard, seeds 1-4 and 7)
## it hid the fight MORE, 5.5 -> 9.6 %, because the camera travels to whichever squad he recalls; away from his army
## keeps clear of where the camera goes but, against a camera inside the orbit, drags the near arc across the lens.
## So both are offered and the price decides -- the price counts the live camera AND each squad's likely view.
const TOWARD_CAMERA := [0.35, 0.7]
const AWAY_FROM_ARMY := [0.5, 0.9]
## The price of a look-ahead that is wholly in front of the fight, in the same units as the climb cost (metres of mean
## climb): a circle that spends its whole next stretch in his face is worth this much climbing to avoid.
const VIEW_COST := 24.0
## How far ahead the view ghost flies, and its step. 10 s: the hull answers the rudder in ~5 s and needs its 57 m
## length again to get out of the way. 6 ticks a step keeps it to ~40 pilot steps a tick for all the candidates.
const VIEW_AHEAD_S := 10.0
const VIEW_STEP_TICKS := 6
## The live camera, sampled once per fixed tick by the node (`SyndicateAdAirship.advance_to`), or empty: no term.
## {camera: Transform3D, fov: float (vertical, degrees), screen: Vector2}.
var view := {}
## Where his camera is LIKELY to go: his pose behind each of his squads, looking along its heading (the vision camera
## frames the commanded squad and turns with its facing). Measured on the live camera (`make airship-view`, builder0,
## seed 7): of 7 intrusions 2 were the camera travelling onto the hull and 4 both moving at once -- a camera that
## jumps to another squad cannot be dodged by a hull that takes 5 s to answer its rudder, so the likely views are
## priced too, at SQUAD_VIEW_WEIGHT. [Transform3D], refreshed with the action (`SyndicateAdAirship._read_action`).
var squad_views: Array = []
## From his army's centre toward the fight (unnormalised; zero when unknown, then the camera's forward is used).
var away := Vector2.ZERO
const SQUAD_VIEW_WEIGHT := 0.5
## Where the chosen orbit's centre sits relative to the (live, eased) action: zero, or pushed beyond it (above). An
## offset rather than a point, so the circle keeps following the fight every tick between re-choices, exactly as the
## unshifted circle always has.
var centre_offset := Vector2.ZERO

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
	AirshipFlight._read_switches()
	solids = AirshipFlight.solids_of(layout)
	for solid: Dictionary in solids:
		_highest = maxf(_highest, float(solid["need"]))
	play_radius = SyndicateAdAirship.play_radius(layout)
	var start := AirshipFlight.start_of(layout, solids)
	home = start["at"]
	home_heading = start["heading"]
	action = Vector2.ZERO
	reset()


## The switches, read once: `--airship-on=a,b` / `--airship-off=a,b` on the command line (the shape of nav's
## `--nav-off`), or the same lists in the environment as AIRSHIP_ON / AIRSHIP_OFF, so any launch can take them without
## a make variable (`AIRSHIP_ON=viewclimb make skirmish`). Names: `viewclimb` (climb over his view), `viewsteer` (the
## steering term; `viewavoid` in --airship-off for the same), `climbsquads` (climb for his squads' views too).
static func _read_switches() -> void:
	if _switches_read:
		return
	_switches_read = true
	var on := PackedStringArray(OS.get_environment("AIRSHIP_ON").split(",", false))
	var off := PackedStringArray(OS.get_environment("AIRSHIP_OFF").split(",", false))
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--airship-on="):
			on.append_array(arg.trim_prefix("--airship-on=").split(",", false))
		elif arg.begins_with("--airship-off="):
			off.append_array(arg.trim_prefix("--airship-off=").split(",", false))
	if on.has("viewclimb"):
		view_climb = true
	if on.has("viewsteer"):
		view_avoid = true
	if off.has("viewclimb"):
		view_climb = false
	if off.has("viewavoid") or off.has("viewsteer"):
		view_avoid = false
	if off.has("climbsquads"):
		climb_squads = false
	if on.has("viewlow"):
		view_low = true
	if on.has("viewsink"):
		view_sink = true
	if off.has("viewlow"):
		view_low = false
	if off.has("viewsink"):
		view_sink = false
	if on.has("viewrest"):
		view_rest = true
	if off.has("viewrest"):
		view_rest = false


func reset() -> void:
	pilot.reset(home, home_heading)
	ticks = 0
	orbit = AirshipPilot.ORBIT_RADIUS
	centre_offset = Vector2.ZERO
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
	var goal := AirshipPilot.carrot(at, action + centre_offset, orbit)
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
	var rate := SyndicateAdAirship.CLIMB_MPS
	if view_sink and wanted_altitude < altitude:
		rate *= SINK_FACTOR
	altitude = move_toward(altitude, wanted_altitude, rate * dt)


## What flying the next stretch of a circle of `radius` round `around` (default: the action) would cost: the mean climb
## its footprint would need there, plus the price of straying from the nominal orbit. `view_price` (round 14) is the
## share of the ghost's look-ahead toward that centre spent in front of the fight (`view_ghost`), priced by VIEW_COST.
func orbit_cost(radius: float, around: Variant = null, view_price := 0.0) -> float:
	var middle: Vector2 = action if around == null else around
	var offset := pilot.position - middle
	var bearing := atan2(offset.y, offset.x)
	var climb := 0.0
	for ahead: float in ORBIT_AHEAD_RAD:
		var angle := bearing + ahead * AirshipPilot.ORBIT_SIGN
		var at := middle + Vector2(cos(angle), sin(angle)) * radius
		var along := Vector2(-sin(angle), cos(angle)) * AirshipPilot.ORBIT_SIGN
		climb += AirshipFlight.need_at(at, AirshipPilot.heading_toward(along), solids) - SyndicateAdAirship.ALTITUDE
	return climb / ORBIT_AHEAD_RAD.size() * CLIMB_COST + absf(radius - AirshipPilot.ORBIT_RADIUS) * STRAY_COST \
			+ view_price * VIEW_COST


## The share of the next VIEW_AHEAD_S the hull would spend in front of the fight if the carrot rode a circle of `radius`
## round `middle`: a GHOST of the pilot is flown there (the real rudder, the real inertia, the real corner-cutting of a
## hull that is not on that circle yet), and each of its poses is put to `AirshipSight` against the camera as it is
## now (`AirshipSight.hidden`: does it hide any of the fight). Sampling the ideal circle instead was tried first and was wrong: a heavy hull switching circles cuts in 10-20 m
## inside the new one, and the samples said "behind the camera" while the hull swept through the lens.
func view_ghost(middle: Vector2, radius: float) -> float:
	var ghost := pilot.copy()
	var dt := float(VIEW_STEP_TICKS) / SimClock.TICK_RATE
	var steps := int(VIEW_AHEAD_S / dt)
	var camera: Transform3D = view["camera"]
	var hits := 0.0
	for i in steps:
		ghost.step(dt, AirshipPilot.contain(AirshipPilot.carrot(ghost.position, middle, radius), ghost.position, play_radius))
		var box := AirshipFlight.hull_box(ghost.position, ghost.heading, altitude)
		if AirshipSight.hidden(camera, box) > 0.0:
			hits += 1.0
		for likely: Transform3D in squad_views:
			if AirshipSight.hidden(likely, box) > 0.0:
				hits += SQUAD_VIEW_WEIGHT
				break
	return hits / float(maxi(steps, 1))


## The candidate orbit centres for the view term, as offsets from the action: the action itself, toward the ground
## under his camera, and away from his army (`away`; the camera's forward when his army is unknown). Just the action
## when the term is off or there is no camera.
func view_offsets() -> Array:
	if not view_avoid or view.is_empty():
		return [Vector2.ZERO]
	var camera := view["camera"] as Transform3D
	var out: Array = [Vector2.ZERO]
	var toward := Vector2(camera.origin.x, camera.origin.z) - action
	if toward.length() > 1.0:
		for f: float in TOWARD_CAMERA:
			out.append(toward * f)
	var along := away if away.length() > 0.01 else Vector2(-camera.basis.z.x, -camera.basis.z.z)
	if along.length() > 0.01:
		for f: float in AWAY_FROM_ARMY:
			out.append(along.normalized() * f * AirshipPilot.ORBIT_RADIUS)
	return out


## Re-choose the orbit (the rules above): which circle, and round which centre. Circles that would carry the hull past
## the containment are not offered. The one being flown is kept unless another beats it by STICKY.
func choose_orbit() -> void:
	var offsets := view_offsets()
	if solids.is_empty() and offsets.size() == 1:
		orbit = AirshipPilot.ORBIT_RADIUS
		centre_offset = Vector2.ZERO
		return
	# The circle being flown, re-anchored to the nearest candidate: the camera turns, and the offsets turn with it.
	var current: Vector2 = offsets[0]
	for offset: Vector2 in offsets:
		if offset.distance_to(centre_offset) < current.distance_to(centre_offset):
			current = offset
	# Round 13's rule for the circle being flown round the action itself: kept whether or not it still fits (the
	# containment then pulls the hull in). A shifted one must fit, or it is not being flown any more.
	var keep := current == Vector2.ZERO or _fits(action + current, orbit)
	# Every candidate is priced every re-choice. Pricing the others only when the current circle is about to cross
	# his view was tried: 0.84 -> 0.62 ms a tick on the laptop, and the hull hid the fight 4-8 % of the time instead
	# of 0-2 %, because a circle that is clear NOW is not the circle that stays clear.
	var prices := {}
	if offsets.size() > 1:
		for offset: Vector2 in offsets:
			if offset == current or _fits(action + offset, AirshipPilot.ORBIT_RADIUS):
				prices[offset] = view_ghost(action + offset, orbit if offset == current else AirshipPilot.ORBIT_RADIUS)
	var best_radius := orbit
	var best_offset := current
	var best_cost := orbit_cost(orbit, action + current, float(prices.get(current, 0.0))) - STICKY if keep else INF
	for offset: Vector2 in offsets:
		for k: float in ORBIT_CHOICES:
			var radius := AirshipPilot.ORBIT_RADIUS * k
			if not _fits(action + offset, radius):
				continue
			var cost := orbit_cost(radius, action + offset, float(prices.get(offset, 0.0)))
			if cost < best_cost:
				best_radius = radius
				best_offset = offset
				best_cost = cost
	if best_cost == INF:
		best_radius = AirshipPilot.ORBIT_RADIUS
		best_offset = Vector2.ZERO
	orbit = best_radius
	centre_offset = best_offset


func _fits(middle: Vector2, radius: float) -> bool:
	return middle.length() + radius <= play_radius * AirshipPilot.CONTAIN_FROM + AirshipPilot.TRACK_MARGIN


## The height to hold now (the rule in the header): fly a ghost ahead and take, over every pose it passes, the roof
## that pose needs less what the climb can still make up before it gets there. Stops as soon as nothing further out
## could matter, so over open ground it is a few ghost steps.
func plan() -> float:
	var wanted := maxf(AirshipFlight.need_at(pilot.position, pilot.heading, solids), view_need(pilot.position, pilot.heading))
	var top := maxf(_highest, view_top())
	if solids.is_empty() and top <= SyndicateAdAirship.ALTITUDE:
		return wanted
	var ghost := pilot.copy()
	var dt := float(LOOK_STEP_TICKS) / SimClock.TICK_RATE
	var rate := SyndicateAdAirship.CLIMB_MPS * CLIMB_LEAD
	var seconds := 0.0
	# Beyond this nothing can raise `wanted`: the tallest solid (or view), less the climb that far ahead.
	while top - rate * seconds > wanted:
		ghost.step(dt, goal_for(ghost.position))
		seconds += dt
		wanted = maxf(wanted, maxf(AirshipFlight.need_at(ghost.position, ghost.heading, solids),
				view_need(ghost.position, ghost.heading)) - rate * seconds)
	return wanted


## --- round 14: CLIMB OVER HIS VIEW ------------------------------------------------------------------------------
## A sight line runs from his camera (17.6 m up at his pose) DOWN to the fight (1.5 m), so it is above the belly
## (6.2 m) only over the first ~70 % of the way from the camera: the hull can only ever hide the fight when it is
## within ~32-43 m of the CAMERA, and an orbit of 62 m round a fight he watches from 45.7 m back passes ~16 m from the
## lens every lap. Steering round that cannot work on these maps, nor outrun a camera that jumps to another squad
## (measured: `make airship-view`, the reasons kept at TOWARD_CAMERA). Height can: sight lines only descend from the
## lens, so a hull whose belly is over the camera is over every one of them. So the lens's near wedge -- the live
## camera's, and each squad's likely view -- is one more thing the flight climbs over, planned ahead by the same ghost
## and the same "latest the climb can start" rule as a roof. `--airship-off=viewclimb` turns it off.
##
## SHIPPED OFF, AND WHY (the brief: "ship ON only if A1's pre-registration holds"). Acceptance, fresh seeds 11-18,
## builder0, `ea755f2a`, `make airship-view`: it roughly HALVES how often the hull hides the fight -- pit 7.8 -> 2.3 %
## (8 of 8 seeds better), yard 5.0 -> 2.5 % (7 of 8), Terminus 2.3 -> 1.2 % (5 of 8) -- and cuts the worst intrusion
## from 10-21 s to 4.5-6.2 s, but the pre-registered bar was "falls by most of itself (<= 0.4 x), no intrusion over
## 3 s, still seen half as often", and it passed that only on the pit, and it is in his frame about half as often. The
## trade is his, and HE MADE IT (2026-09-28, in chat, shown the numbers and the cost): *"ah ok that's a great idea, turn
## that on by default"*. THE LEAD'S TOGGLE: this one line. true = the flight climbs over his view (rarer, shorter
## intrusions; the airship in his frame about half as often). false = round 13's flight (`AIRSHIP_OFF=viewclimb` on any
## launch does the same). No test pins the value (test_theme_ad_airship.gd sets it both ways). Decision record:
## _agents/game_design.md *Round 14: the view-climb decided*.
static var view_climb := true
## Air kept between the belly and the camera it is passing over.
const VIEW_CLEAR_M := 1.5
## Climb over each squad's LIKELY view too, not only the live camera's. `--airship-off=climbsquads` climbs for the live
## camera alone.
static var climb_squads := true


## The hull-centre height this pose needs for the view: cruise, or -- if the hull at cruise here would hide the fight
## from the live camera or any squad's likely view -- the height that puts the belly VIEW_CLEAR_M over that camera.
func view_need(at: Vector2, heading: float) -> float:
	var wanted := SyndicateAdAirship.ALTITUDE
	if not view_climb or view.is_empty():
		return wanted
	var box := AirshipFlight.hull_box(at, heading, SyndicateAdAirship.ALTITUDE)
	for camera: Transform3D in [view["camera"] as Transform3D] + (squad_views if climb_squads else []):
		# Round 15 B1: a hull whose footprint reaches the camera sets off the camera's lift even when it hides nothing
		# from where the camera rests, and the lift backs the camera off until the hull IS in front of the fight.
		var lift_zone := view_rest and AirshipFlight.in_lift_zone(camera.origin, box)
		if lift_zone or AirshipSight.hidden(camera, box) > 0.0:
			# Over the LENS, not just over the sight lines where the hull is. The lower target (the highest line over the
			# hull's nearest point: ~10.6 m instead of 17.6 at 20 m out) was built and measured (builder0, seeds 1-4
			# and 7): Terminus 4.8 -> 0.6 %, but the yard only 5.5 -> 3.8 %, 2 of 5 seeds better -- a height with no
			# margin is beaten by a camera that moves. Over the lens held on the yard twice (6.5 -> 0.9, 7.5 -> 2.1 %).
			# Round 15 B2 re-measures a lower target WITH a margin and the climb as the base (`view_low`).
			var over := AirshipFlight.over_camera(camera.origin.y)
			if view_low and not lift_zone:
				over = minf(over, AirshipFlight.over_lines(camera, at, heading))
			wanted = maxf(wanted, over)
	return wanted


## The highest `view_need` could ask for right now (the plan's horizon).
func view_top() -> float:
	if not view_climb or view.is_empty():
		return SyndicateAdAirship.ALTITUDE
	var top := AirshipFlight.over_camera((view["camera"] as Transform3D).origin.y)
	for camera: Transform3D in (squad_views if climb_squads else []):
		top = maxf(top, AirshipFlight.over_camera(camera.origin.y))
	return top


## --- round 15 B2: buying back the seen-share (switches, OFF until measured) -------------------------------------
## The climb halved how often he sees the ship (round 14: pit 14 -> 4.4 % in frame). Two levers, each one switch:
## `viewlow` climbs only as high as the sight lines over the hull's footprint, plus VIEW_LOW_MARGIN_M for a camera
## that moves (round 14's no-margin version lost on the yard), never higher than over the lens; `viewsink` sinks back
## to cruise SINK_FACTOR x faster than it climbs once nothing asks for height (the plan's "latest the climb can start"
## rule depends only on the climb rate, so a faster sink never makes a climb late).
static var view_low := false
static var view_sink := false
const VIEW_LOW_MARGIN_M := 4.0
## 3.2 m/s up, 4.8 down: still inside the 3-5 m/s a real airship manages (CLIMB_MPS's note).
const SINK_FACTOR := 1.5


## The hull-centre height that puts the belly (bottom of its float) VIEW_LOW_MARGIN_M over every sight line from
## `camera` to the fight grid where they pass over the hull's footprint at `at`/`heading`. A sight line falls from the
## eye to the fight (`AirshipSight`), so over the footprint it is highest at the footprint's point nearest the eye and
## for the farthest grid point: eye height less the fall over that distance. Conservative, and cheap. Pure.
static func over_lines(camera: Transform3D, at: Vector2, heading: float) -> float:
	var eye := camera.origin
	var forward := -camera.basis.z.normalized()
	if forward.y > -0.01:
		return AirshipFlight.over_camera(eye.y)
	var aim := eye + forward * ((AirshipSight.AIM_HEIGHT_M - eye.y) / forward.y)
	var eye2 := Vector2(eye.x, eye.z)
	var far := eye2.distance_to(Vector2(aim.x, aim.z)) + AirshipSight.FIGHT_HALF_M * 1.415
	# The footprint's nearest point to the eye: into the hull's frame, clamp, back out.
	var half := AirshipFlight.hull_half()
	var axis_x := Vector2(cos(heading), -sin(heading))
	var axis_z := Vector2(sin(heading), cos(heading))
	var local := Vector2((eye2 - at).dot(axis_x), (eye2 - at).dot(axis_z))
	var nearest := at + axis_x * clampf(local.x, -half.x, half.x) + axis_z * clampf(local.y, -half.y, half.y)
	var s := eye2.distance_to(nearest)
	var line := eye.y - (eye.y - AirshipSight.AIM_HEIGHT_M) * clampf(s / maxf(far, 1.0), 0.0, 1.0)
	return line + VIEW_LOW_MARGIN_M - SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH \
			+ SyndicateAdAirship.FLOAT_RISE_TOTAL


## --- round 15 B1: the 39-49 s cluster, named, and the climb that no longer sets off the camera's lift --------------
## `make airship-view VIEW_TRACE=1` (builder0, `d8935f54`, climb ON, seeds 11-18, four maps): 59 of 60 intrusions
## BEGAN WITH THE CAMERA LIFTED over the hull (round 11's `RtsCamera` hull lift), 54 with the hull already climbing.
## The cluster is the first lap's near arc: on every open-map seed the hull first comes within 35 m of the camera at
## 31-49 s, and the first hide follows within 2 s. Three things, each measured in the trace:
##   1. At cruise the passing hull hid nothing from where the camera RESTS, so the climb's look-ahead gave no warning;
##	  but its footprint (grown by `RtsCamera.HULL_LEAD_M`) held the camera, so the camera lifted -- up AND BACK until
##	  the hull lies in front of the fight, by design (round 11, his "push the camera up above the airship").
##   2. The climb then aimed over the LIFTED lens (`view_need` read the live camera) and rose through its sight lines,
##	  and the lift rose with it: targets of 33-60 m against a 31 m climb over the resting lens.
##   3. Even a climb that arrived in time set the lift off: the belly sat VIEW_CLEAR_M (1.5 m) over the lens, inside
##	  the lift's own reach (`RtsCamera.SOLID_CLEAR_M`, 2 m under the belly).
## `viewrest` fixes all three on the airship's side: the view is the camera's pose WITHOUT the hull lift
## (`RtsCamera.rest_transform`, read), the lift's zone is one more thing to climb over, planned ahead by the same
## ghost, and the belly clears the lens by the lift's reach plus VIEW_CLEAR_M. The camera is not touched.
static var view_rest := false
## Kept round the lift's own reach so a hull the ghost flew a few metres differently still clears it.
const LIFT_MARGIN_M := 3.0


## True when a hull box at cruise would set off the camera's lift at `point` (`RtsCamera.hull_hit`, the lift's own test,
## grown by its lead and LIFT_MARGIN_M). Pure.
static func in_lift_zone(point: Vector3, box: Dictionary) -> bool:
	return RtsCamera.hull_over(point, [box], RtsCamera.HULL_LEAD_M + LIFT_MARGIN_M) >= 0.0


## The hull-centre height whose belly, at the bottom of its float, is VIEW_CLEAR_M over a camera `camera_y` up (and,
## with `viewrest`, over the camera's lift reach as well).
static func over_camera(camera_y: float) -> float:
	var clear := VIEW_CLEAR_M + (RtsCamera.SOLID_CLEAR_M if view_rest else 0.0)
	return camera_y + clear - SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH + SyndicateAdAirship.FLOAT_RISE_TOTAL


## The hull as a box for the camera (`RtsCamera.clear_pose`'s `occluders`): its footprint at `at` turned to
## `heading`, from belly to deck around a centre `centre_y` metres up (the drawn height, float included). Pure.
static func hull_box(at: Vector2, heading: float, centre_y: float) -> Dictionary:
	return {"centre": at, "half": AirshipFlight.hull_half(), "yaw": heading,
			"bottom": centre_y + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH,
			"top": centre_y + TOP_FRACTION * SyndicateAdAirship.LENGTH}


## The lowest the belly gets at this height, at the bottom of its float.
func belly() -> float:
	return altitude + SyndicateAdAirship.BELLY_FRACTION * SyndicateAdAirship.LENGTH - SyndicateAdAirship.FLOAT_RISE_TOTAL
