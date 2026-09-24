class_name SyndicateAdAirship
extends Node3D
## The Syndicate's broadcast airship: the thing drifting over the fight, showing your own kills back at you.
## Round 11, the lead's `airship_r11_m`. It replaced round 10's primitive ad blimp; this is its second pass, after
## *"the airship is too small … it's just moving in straight lines. We need to invest whatever effort necessary to
## make it appear floating … and splining or circling behavior throughout the match. Also the airship should ideally
## generally fly to where the action is … I think the airship would have its own PID controller to try to fly the
## path of a target spline, and since it's an airship, slightly bad PID tunes might create a realistic effect for
## high rotational inertia."*
##
## So it no longer follows a route at all. `AirshipPilot` is a PID rudder on a body with high rotational inertia,
## chasing a carrot that circles wherever the units are fighting; this node owns the tick loop, the float, and the
## screens. Four things make it read as floating rather than translating, and they are separable on purpose:
##   1. **It never flies straight** -- the carrot is always off to one side of the orbit, so the rudder is always
##      working and the heading always wandering.
##   2. **It leans late.** Bank lags yaw rate by ~2.2 s, so the hull is still rolling into a turn after the turn has
##      started and still rolling out of it after the turn has ended.
##   3. **It wallows on three axes at once**, on periods that share no common multiple (`float_offsets`), so the
##      motion never visibly repeats and never looks like a sine.
##   4. **It slips.** A turning airship is a sail; the hull tracks a little outside its own turn.
##
## Constraints that survive from round 9, each earned from a failure this project already paid for:
##   * NO collision body of any kind; the sim baseline is pre-registered unchanged.
##   * The pose advances on the FIXED tick, never the wall clock, so 30 fps and 144 fps look the same.
##   * "Visible" is verified AT THE LEAD'S POSE with frames (`make airship-shot`), never with a screenshot taken
##     from somewhere it happens to look good.

const MESH := "res://game/theme/arena_kit/generated/arena_airship.tscn"

## --- size ---------------------------------------------------------------------------------------------------
## The normalised asset is 38 m (`arena.airship`); SCALE grows the whole node, hull and screens together.
## The lead: *"it should be at least 1.5x to 2x its current size."* 1.5x is shipped, and the reason it is not 2x is
## geometry rather than preference -- see the band below. `TUNE=airship.scale=2` on any launch to see 2x.
const BASE_LENGTH := 38.0
const SCALE := 1.5
const LENGTH := BASE_LENGTH * SCALE
## The hull's own proportions, as fractions of its length, measured off the mesh.
const BELLY_FRACTION := -0.1904
const DECK_FRACTION := 0.0800
## The tallest thing the belly must clear: the game's tallest hull (6.18 m) with air for the float.
const HULL_CLEARANCE := 6.2
## Centre height: as low as the belly floor allows, because LOW IS WHAT MAKES IT VISIBLE. At his pose the camera
## sits at 17.56 m and the frame's top edge is 3.5 deg BELOW the horizon, so the highest thing on his screen at 45 m
## is 14.8 m up and at 30 m is 15.7 m. Every metre of extra size pushes the flank screens further through that
## ceiling, which is the whole cost of going bigger and the reason 2x is offered rather than shipped.
const ALTITUDE := HULL_CLEARANCE + FLOAT_RISE_TOTAL - BELLY_FRACTION * LENGTH

## --- the float ----------------------------------------------------------------------------------------------
## Three rises on periods with no common multiple, so the vertical wander never repeats on a beat the eye can catch.
## Amplitudes in metres; the total is what ALTITUDE reserves above the hull clearance.
const FLOAT_RISES := [[0.62, 13.7], [0.34, 23.1], [0.19, 7.3]]
const FLOAT_RISE_TOTAL := 1.15
## Slow pitch and roll wallow, degrees and seconds. Small: a big hull's attitude changes are gentle, and overdoing
## this reads as a boat in a swell rather than a gas bag in still air.
const FLOAT_PITCH_DEG := 1.5
const FLOAT_PITCH_S := 19.3
const FLOAT_ROLL_DEG := 2.2
const FLOAT_ROLL_S := 31.7
## How far the hull rolls at full yaw rate, on top of the wallow.
const BANK_DEG := 11.0
## Nose-up as it rises: attitude follows the vertical motion, which is what sells buoyancy rather than levitation.
const RISE_PITCH_DEG_PER_MPS := 9.0

## --- screens (measured with `make assets-apertures`; fractions of LENGTH) -------------------------------------
const FLANK_CENTRE := Vector3(0.1408, -0.0329, 0.0342)
const FLANK_NORMAL := Vector3(0.845, -0.534, 0.0)
const FLANK_SIZE := Vector2(0.2474, 0.1289)
const DECK_CENTRE := Vector3(-0.0026, 0.0324, 0.0645)
const DECK_SIZE := Vector2(0.1658, 0.4579)
## THERE IS NO BELLY SCREEN, AND THE REASON IS WORTH KEEPING. Scaling the hull pushes the FLANK screens up through
## the top of his frame, so a downward-facing panel under the keel looked like the answer: it stays low whatever the
## hull does. It was built, and it cannot be seen from anywhere. His camera sits at 17.56 m, and this hull spans
## 6.2 m (belly) to 22.8 m (deck) -- **the camera is INSIDE that range**, so it views the hull edge-on from the side
## and a panel facing straight down faces away from him exactly as the deck panel facing straight up does. Even at
## the bottom of his tilt range (8 deg, camera 6.8 m) it is still above the belly. Only the FLANKS can ever work on
## this airship, which is also why size costs readable screen and nothing else can buy it back.
##
## How far a screen quad floats off its measured panel, as a fraction of the base length, so it never z-fights the
## recess floor behind it.
const SCREEN_PROUD := 0.0032
## The feed is authored portrait at this aspect (AdBroadcast.LAYOUT.x / .y).
const FEED_ASPECT := 0.5

## --- where the action is -----------------------------------------------------------------------------------
## The action centre is re-read this often (ticks) and eased toward, never snapped: a 57 m hull chasing a twitching
## centroid would look like it was being flicked around.
const ACTION_EVERY := 6
const ACTION_EASE := 0.035
## A unit this close to its nearest enemy counts fully toward the action centre; further away it fades out. This is
## what makes the airship favour the CONTACT LINE over the middle of two armies that have not met yet.
const CONTACT_RANGE := 70.0
## Beam and the room the hull wants around anything tall.
const BEAM := LENGTH * 0.3896
const AVOID_CLEARANCE := 8.0
## How far inside the perimeter wall the hull keeps. The venue's grandstands stand just outside `half_size`, and an
## airship that leaves the map flies into them and vanishes -- which is what the lead saw.
const WALL_MARGIN := 10.0
## Everything tall enough to fly into, as [half-width, height] in metres. The heights are what let the airship CLIMB
## over what it cannot go round, which at this size it often cannot: a 57 m hull has a 22.2 m beam and the Terminus
## streets are 18 m wide, so it no longer fits between the city blocks at all. Steering alone could not fix that --
## the first version bent the goal away from blocks and the hull, with its deliberately heavy rudder, flew straight
## through one anyway. Half-widths as before; block and floodlight heights from the kit's slot contracts.
const TALL_PROPS := {"block": [21.0, 24.0], "floodlight": [4.5, 24.0], "ad_screen": [4.0, 20.0], "sign": [4.0, 12.0]}
## How fast it may climb or sink, and how much air it keeps over a rooftop. Slow on purpose: a gentle rise over the
## city and a long settle back down is the most airship-like motion it makes, and it costs nothing to watch.
const CLIMB_MPS := 2.4
const ROOF_CLEARANCE := 3.0

## The lead's camera, held here so the geometry above is checkable.
const CAMERA_PITCH_DEG := 21.0
const CAMERA_FOV_DEG := 35.0
const CAMERA_BOOM_M := 49.0
## Catch-up cap: a rebuild mid-match re-flies from tick 0, and this bounds that to a few milliseconds.
const MAX_CATCHUP := 40000

var broadcast: AdBroadcast
## The landscape cut of the same channel, for the wide flank panels (see `_apply_channel`).
var wide_broadcast: AdBroadcast
var channel_name := "arena"
var pilot := AirshipPilot.new()
var home := Vector2.ZERO
var _layout := {}
var _blockers: Array = []
var _screens: Array[MeshInstance3D] = []
var _tick_source: Node
var _stepped := -1
var _action := Vector2.ZERO
var _action_known := false
## Current hull-centre height. State, because climbing over a block and settling back is a motion, not a lookup.
var _altitude := ALTITUDE
var _play_radius := 100.0


func _init(layout: Dictionary = {}) -> void:
	name = "SyndicateAdAirship"
	_layout = layout.duplicate(true) if not layout.is_empty() else {}


func _ready() -> void:
	_blockers = blockers(_layout)
	_play_radius = play_radius(_layout)
	home = start_position(_layout)
	_action = home
	scale = Vector3(SCALE, SCALE, SCALE)
	pilot.reset(home, 0.0)
	_altitude = required_altitude(home, _blockers)
	_build()
	_apply_channel()
	_place(0)


## An airship flies on any layout that is a real map; an empty layout (a gallery, a bench with no arena) gets none.
static func flies_on(layout: Dictionary) -> bool:
	return not layout.is_empty()


## Where it starts: the clearest point on a ring around the middle. The ring is searched at several RADII as well as
## several bearings, because on the Terminus every bearing at one radius is inside a block's keep-out (its eight
## blocks sit at x = +-30 and +-40 with a 21 m footprint, and the hull wants 11 m of its own) -- a bearings-only
## search returned a start 2.1 m INSIDE a building. Pure.
static func start_position(layout: Dictionary) -> Vector2:
	if layout.is_empty():
		return Vector2.ZERO
	var half := float(layout.get("half_size", 120.0))
	var best := Vector2(0.0, -minf(AirshipPilot.ORBIT_RADIUS, half * 0.7))
	var best_clear := -INF
	for ring in 6:
		var radius := lerpf(AirshipPilot.ORBIT_RADIUS * 0.6, half * 0.92, float(ring) / 5.0)
		for i in 24:
			var angle := TAU * i / 24.0
			var at := Vector2(cos(angle), sin(angle)) * radius
			var clear := clearance_at(layout, at)
			# Among clear starts prefer the one nearest the orbit radius, so it begins where it will settle.
			var score := minf(clear, 6.0) - absf(radius - AirshipPilot.ORBIT_RADIUS) * 0.01
			if score > best_clear:
				best_clear = score
				best = at
	return best


## Everything on a map tall enough for the airship to fly into, as [{x, z, radius}]. Radii are half-widths from the
## kit's slot contracts, except the city block, whose footprint is authored per arena; 21 m is the Terminus's, the
## widest the game ships, so using it everywhere errs toward keeping clear.
static func blockers(layout: Dictionary) -> Array:
	var out: Array = []
	for prop: Dictionary in layout.get("props", []):
		var spec: Variant = TALL_PROPS.get(String(prop.get("type", "")), null)
		if spec == null:
			continue
		var position: Array = prop.get("position", [])
		if position.size() >= 2:
			out.append({"x": float(position[0]), "z": float(position[1]),
					"radius": float((spec as Array)[0]), "height": float((spec as Array)[1])})
	return out


## The lowest the hull's CENTRE may sit at `at` and still clear everything under it: the cruise height over open
## ground, or a rooftop plus clearance where something tall is beneath. Pure.
static func required_altitude(at: Vector2, from: Array) -> float:
	var wanted := ALTITUDE
	for blocker: Dictionary in from:
		var offset := at - Vector2(float(blocker["x"]), float(blocker["z"]))
		if offset.length() > float(blocker["radius"]) + BEAM * 0.5:
			continue
		# Its belly must clear the roof: centre = roof + clearance + the float + how far the belly hangs below centre.
		wanted = maxf(wanted, float(blocker["height"]) + ROOF_CLEARANCE + FLOAT_RISE_TOTAL - BELLY_FRACTION * LENGTH)
	return wanted


## Room at `at`: metres from the hull's edge to the nearest tall prop's edge (negative means it would fly through).
## The radius the hull's CENTRE must stay inside: the perimeter, less its own beam and a margin. Pure.
static func play_radius(layout: Dictionary) -> float:
	return maxf(20.0, float(layout.get("half_size", 120.0)) - BEAM * 0.5 - WALL_MARGIN)


static func clearance_at(layout: Dictionary, at: Vector2) -> float:
	var clear := INF
	for blocker: Dictionary in blockers(layout):
		var offset := at - Vector2(float(blocker["x"]), float(blocker["z"]))
		clear = minf(clear, offset.length() - float(blocker["radius"]) - BEAM * 0.5)
	return clear if clear < INF else 999.0


## --- the geometry the whole design is fitted to (pure, and asserted by the test) -----------------------------
static func camera_height() -> float:
	return CAMERA_BOOM_M * sin(deg_to_rad(CAMERA_PITCH_DEG))


static func camera_run() -> float:
	return CAMERA_BOOM_M * cos(deg_to_rad(CAMERA_PITCH_DEG))


## The highest world height still inside his frame at `distance` -- the top edge is CAMERA_FOV/2 - pitch above the
## horizon, which at his pose is 3.5 deg BELOW it. This one function is why the airship is low and why bigger costs
## screen area rather than nothing.
static func visible_ceiling_at(distance: float) -> float:
	var above_horizon := deg_to_rad(CAMERA_FOV_DEG / 2.0 - CAMERA_PITCH_DEG)
	return camera_height() + tan(above_horizon) * distance


static func belly_y() -> float:
	return ALTITUDE + BELLY_FRACTION * LENGTH - FLOAT_RISE_TOTAL


static func deck_y() -> float:
	return ALTITUDE + DECK_FRACTION * LENGTH


## How far off straight-on the DECK panel is seen from his camera (90 = edge-on). It is ~89 deg: the deck panel is a
## dark panel in play, not a display, and no resize fixes that at pitch 21. Reported, never hidden.
static func deck_grazing_deg() -> float:
	var rise := camera_height() - deck_y()
	return rad_to_deg(acos(clampf(rise / sqrt(rise * rise + camera_run() * camera_run()), -1.0, 1.0)))


## `feed_rect` for a panel of `size` metres: the portrait feed CONTAINED in it, centred, never stretched and never
## cropped, with the panel's own backlight filling the margins. (offset.x, offset.y, scale.x, scale.y) in feed UV.
static func feed_rect_for(size: Vector2, feed := Vector2i(320, 640)) -> Vector4:
	var panel := size.x / maxf(size.y, 0.0001)
	var feed_aspect := float(feed.x) / maxf(float(feed.y), 0.0001)
	if panel >= feed_aspect:
		var scale_x := panel / feed_aspect
		return Vector4(0.5 - scale_x * 0.5, 0.0, scale_x, 1.0)
	var scale_y := feed_aspect / panel
	return Vector4(0.0, 0.5 - scale_y * 0.5, 1.0, scale_y)


## What fraction of a `seconds`-long flight the airship spends inside his frame, if he watches the fight at
## `action` from his own pose. CLOSED FORM, and that is the point: round 10's answer to this question came from a
## bench that swept the map, searched the scene for the airship, and got both the subject and the arithmetic wrong.
## Here there is nothing to search -- the pilot is deterministic, so the flight is known, and "in frame" is two
## inequalities: the hull must be nearer than the range at which his frame's ceiling drops below it, and within the
## FOV either side of where he is looking. It ignores occlusion (a block between them still hides it), so read it as
## an UPPER bound on how often he sees it, and as the honest way to compare two flight tunes.
static func seen_fraction(action: Vector2, seconds := 180.0, start := Vector2.ZERO) -> Dictionary:
	var pilot := AirshipPilot.new()
	pilot.reset(start if start != Vector2.ZERO else action + Vector2(0.0, -AirshipPilot.ORBIT_RADIUS), 0.0)
	var dt := 1.0 / SimClock.TICK_RATE
	var ticks := int(seconds * SimClock.TICK_RATE)
	var seen := 0
	var half_fov := deg_to_rad(CAMERA_FOV_DEG / 2.0)
	for i in ticks:
		pilot.step(dt, AirshipPilot.carrot(pilot.position, action))
		# His camera orbits `action` at the boom; take the yaw that has him looking at the fight from behind his own
		# army, which is the pose the opening frame uses.
		var eye := action + Vector2(0.0, -camera_run())
		var offset := pilot.position - eye
		var distance := offset.length()
		var lowest := ALTITUDE + BELLY_FRACTION * LENGTH
		if lowest > visible_ceiling_at(distance):
			continue
		if absf(wrapf(atan2(offset.x, offset.y) - 0.0, -PI, PI)) > half_fov * (16.0 / 9.0):
			continue
		seen += 1
	return {"seen_pct": 100.0 * seen / maxi(ticks, 1), "ticks": ticks,
			"orbit_m": AirshipPilot.ORBIT_RADIUS, "length_m": LENGTH, "altitude_m": ALTITUDE}


## The wallow: rise in metres and pitch/roll/heading trim in radians at `seconds`. Pure, and deliberately built from
## periods with no common multiple so the eye never catches the loop.
static func float_offsets(seconds: float) -> Dictionary:
	var rise := 0.0
	var rate := 0.0
	for entry: Array in FLOAT_RISES:
		var amplitude := float(entry[0])
		var period := float(entry[1])
		rise += amplitude * sin(seconds * TAU / period)
		rate += amplitude * TAU / period * cos(seconds * TAU / period)
	return {
		"rise": rise,
		"rate": rate,
		"pitch": deg_to_rad(FLOAT_PITCH_DEG) * sin(seconds * TAU / FLOAT_PITCH_S)
				+ deg_to_rad(RISE_PITCH_DEG_PER_MPS) * clampf(rate, -1.0, 1.0),
		"roll": deg_to_rad(FLOAT_ROLL_DEG) * sin(seconds * TAU / FLOAT_ROLL_S),
	}


## --- the tick loop ------------------------------------------------------------------------------------------
func _process(_delta: float) -> void:
	advance_to(_match_tick())


func _match_tick() -> int:
	if _tick_source == null or not is_instance_valid(_tick_source):
		var fx := FxWorld.existing()
		_tick_source = fx.link.attached_match() if fx != null and fx.link != null else null
	if _tick_source == null:
		return 0
	return int(_tick_source.get("tick"))


## Fly the pilot forward to `tick`, one fixed tick at a time. Going BACKWARDS (a replay scrubbed, a bench posing an
## earlier moment) re-flies from the start rather than integrating backwards, which a PID cannot do.
func advance_to(tick: int) -> void:
	if tick < _stepped:
		pilot.reset(home, 0.0)
		_altitude = required_altitude(home, _blockers)
		_stepped = -1
	var steps := mini(tick - _stepped, MAX_CATCHUP)
	if steps <= 0:
		_place(tick)
		return
	var dt := 1.0 / SimClock.TICK_RATE
	for i in steps:
		var at := _stepped + 1 + i
		if at % ACTION_EVERY == 0:
			_read_action()
		var goal := AirshipPilot.carrot(pilot.position, _action)
		goal = AirshipPilot.avoid(goal, pilot.position, _blockers, BEAM * 0.5 + AVOID_CLEARANCE)
		# Containment LAST, so neither the orbit nor an avoidance push can send it through the wall.
		goal = AirshipPilot.contain(goal, pilot.position, _play_radius)
		pilot.step(dt, goal)
		_altitude = move_toward(_altitude, required_altitude(pilot.position, _blockers), CLIMB_MPS * dt)
	_stepped = tick
	_place(tick)


## The action centre: the living units' centroid, each weighted by how close its nearest ENEMY is, so the airship
## favours the contact line over the middle of two armies that have not met. Eased, never snapped.
func _read_action() -> void:
	var match_node := _tick_source
	if match_node == null or not is_instance_valid(match_node):
		return
	var tanks: Variant = match_node.get("tanks")
	if not (tanks is Node):
		return
	var live: Array = []
	for tank in (tanks as Node).get_children():
		if tank.get("team") == null or not (tank is Node3D):
			continue
		live.append({"at": Vector2((tank as Node3D).global_position.x, (tank as Node3D).global_position.z),
				"team": int(tank.get("team"))})
	if live.size() < 2:
		return
	var sum := Vector2.ZERO
	var weight := 0.0
	for one: Dictionary in live:
		var nearest := INF
		for other: Dictionary in live:
			if int(other["team"]) == int(one["team"]):
				continue
			nearest = minf(nearest, (one["at"] as Vector2).distance_to(other["at"]))
		if nearest == INF:
			nearest = CONTACT_RANGE
		var w := clampf(1.0 - nearest / CONTACT_RANGE, 0.05, 1.0)
		sum += (one["at"] as Vector2) * w
		weight += w
	if weight <= 0.0:
		return
	var centre: Vector2 = sum / weight
	# Keep the orbit CENTRE far enough in that the orbit itself fits inside the arena: an action centre out at the
	# edge would otherwise put half the circle beyond the wall.
	var room := maxf(0.0, _play_radius - AirshipPilot.ORBIT_RADIUS - AirshipPilot.TRACK_MARGIN)
	if centre.length() > room:
		centre = centre.normalized() * room
	_action = centre if not _action_known else _action.lerp(centre, ACTION_EASE)
	_action_known = true


func _place(tick: int) -> void:
	var seconds := float(tick) / SimClock.TICK_RATE
	var wallow := float_offsets(seconds)
	var basis := Basis(Vector3.UP, pilot.heading)
	basis *= Basis(Vector3.RIGHT, float(wallow["pitch"]))
	basis *= Basis(Vector3.FORWARD, float(wallow["roll"]) + deg_to_rad(BANK_DEG) * pilot.bank)
	transform = Transform3D(basis.scaled(Vector3(SCALE, SCALE, SCALE)),
			Vector3(pilot.position.x, _altitude + float(wallow["rise"]), pilot.position.y))


## Each screen joins the cut of the channel that matches ITS shape: the tall deck panel takes the portrait feed the
## ground screens use, the wide flank panels take the landscape cut. Screens of the same shape still share one
## layout and one material, so this costs one extra 2D viewport for the whole airship and nothing for the arena.
func _apply_channel() -> void:
	broadcast = AdBroadcast.channel(self, channel_name)
	wide_broadcast = AdBroadcast.channel(self, channel_name, true)
	for screen in _screens:
		var quad := screen.mesh as QuadMesh
		var landscape := quad != null and quad.size.x >= quad.size.y
		var feed := wide_broadcast if landscape else broadcast
		screen.material_override = feed.screen_material
		screen.set_instance_shader_parameter("feed_rect", feed_rect_for(quad.size, feed.layout_size))


func _build() -> void:
	var hull_scene := load(MESH) as PackedScene
	if hull_scene != null:
		var hull := hull_scene.instantiate() as Node3D
		hull.name = "Hull"
		add_child(hull)
		for child in hull.find_children("*", "MeshInstance3D", true, false):
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		push_error("SyndicateAdAirship: %s is missing -- run tools/assets/build_arena_kit.sh" % MESH)
	# Screen placement is in the UNSCALED mesh's own space: this node carries SCALE, so the children inherit it.
	_add_screen("ScreenPort", Vector3(-FLANK_CENTRE.x, FLANK_CENTRE.y, FLANK_CENTRE.z) * BASE_LENGTH,
			Vector3(-FLANK_NORMAL.x, FLANK_NORMAL.y, FLANK_NORMAL.z), FLANK_SIZE * BASE_LENGTH, Vector3.UP)
	_add_screen("ScreenStarboard", FLANK_CENTRE * BASE_LENGTH, FLANK_NORMAL, FLANK_SIZE * BASE_LENGTH, Vector3.UP)
	# The deck panel's "up" runs toward the NOSE, so the feed stands the long way along the hull.
	_add_screen("ScreenDeck", DECK_CENTRE * BASE_LENGTH, Vector3.UP, DECK_SIZE * BASE_LENGTH, Vector3.FORWARD)


## One screen quad seated in a measured panel: centred on it, facing along its normal, floated clear of the recess
## floor behind it, and told through `feed_rect` which part of the channel's portrait feed it shows.
func _add_screen(screen_name: String, centre: Vector3, normal: Vector3, size: Vector2, up_hint: Vector3) -> void:
	var screen := MeshInstance3D.new()
	screen.name = screen_name
	var quad := QuadMesh.new()
	quad.size = size
	screen.mesh = quad
	screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var forward := normal.normalized()
	var right := up_hint.cross(forward)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var up := forward.cross(right).normalized()
	# A QuadMesh faces +Z, so its basis columns are (right, up, normal).
	screen.transform = Transform3D(Basis(right, up, forward), centre + forward * SCREEN_PROUD * BASE_LENGTH)
	add_child(screen)
	_screens.append(screen)
	# A placeholder until `_apply_channel` knows which cut of the feed this panel joins.
	screen.set_instance_shader_parameter("feed_rect", feed_rect_for(size))
