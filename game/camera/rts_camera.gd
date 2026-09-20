class_name RtsCamera
extends Node
## G4: the skirmish camera. A tilted, perspective RTS camera that drives an existing Camera3D:
## pan, zoom in and out, tilt, rotate, follow a squad.
##
## Round 6 (control X3): **pitch is its own axis.** Zoom sets only the distance; the tilt stays where the player (or
## the default) put it. Until then one slider did both - `lerp(25°, 82°)` over the same zoom that set the distance -
## so a player zooming out to see thirty vehicles was tilted to a near top-down view he never asked for (the lead:
## "the bird's eye view is what's problematic ... the lower camera angles look good because we actually get to see
## the vehicles"). The top-down view is still there, on purpose: the overview (O on desktop).
##
##   Desktop   arrows (or the screen edge) pan · wheel zooms toward the cursor · , . rotate
##             Page Up / Page Down or ctrl+wheel tilt · Home resets the tilt
##             middle-drag pans · F follows the selected squad's commander · O overview / back
##   Touch     one finger drags the ground (pan) · pinch zooms · two-finger twist rotates
##             (the tactical map owns one-finger taps and long-press drags: see tactical_map.gd)
##
## The pose is pure math (pose_for) so it's testable without a screen. Runs while paused, so the
## player can look around during the tactical pause.

const MIN_DISTANCE := 16.0
const MAX_DISTANCE := 260.0
## X3: the tilt the player can choose (degrees below the horizon), and where it starts.
## **The default is a PLAYABILITY number and must be chosen from a played session, not from a frame.** Round 6: the lead
## picked 25°, then 12°, from camera pages of STILL frames of a frozen fight (the floor of the range both times), then
## played `make skirmish` at 12° and rejected it: "I was totally wrong about the camera, the game is unplayable now with
## low field of view." A still shows composition (and at 12° it is striking); it cannot show how much ground you can
## read while commanding. So the default is back to ~45° - round 5's start pose, which he never complained about. His
## real complaint was that zooming out became a bird's-eye view; decoupling pitch from zoom fixed that and stands. The
## player can still tilt 8°-50° (Page Up/Down, ctrl+wheel). Do not lower the default again from a picture.
const MIN_PITCH_DEG := 8.0
## SETTLED FROM PLAY (round 6, 2026-09-18): the lead found the camera himself with the live controls and sent back
## `CAMERA_POSE pitch=21 distance_m=49 fov=35 yaw=-0 zoom=0.365 auto_frame=on`. Low pitch, telephoto lens, 49 m out, the
## vision camera left on. Two stills-pages and two agents had the lens backwards (see FOV_DEG). 21° is close to the 12°
## he rejected: the pitch was never the problem, the lens was.
const MAX_PITCH_DEG := 70.0
const DEFAULT_PITCH_DEG := 21.0
## Round 6, after playing the lead's 12°: a very low camera pulled back to frame a whole army (~150 m) showed the arena
## as a thin strip between sky and cut-away stands, with units as specks (shell-playtest, 50 s). So past FAR_TILT_FROM_M
## a soft floor lifts the tilt, from MIN_PITCH_DEG there to FAR_TILT_MAX_DEG at FAR_TILT_FULL_M. Up to that distance -
## including the lead's own 50 m - the tilt is exactly the player's; a tilt already above the floor is untouched. This
## is not round 5's weld (25°-82° across the whole range): it only engages far out and stops well short of top-down.
## The ramp reaches ~30° by 130 m: from there out the sight line clears the stands' back, so they stay as foreground
## instead of being cut to a void (a gentler ramp - 21° at 150 m - left the bottom 40% of the frame black).
const FAR_TILT_FROM_M := 70.0
const FAR_TILT_FULL_M := 160.0
const FAR_TILT_MAX_DEG := 40.0
## The deliberate top-down read of the map (toggle_overview): the one place the camera still looks nearly straight down.
const OVERVIEW_PITCH_DEG := 77.0
## Tilt speed: degrees per second for held keys, degrees per wheel notch.
const TILT_SPEED_DEG := 40.0
const WHEEL_TILT_DEG := 3.0
## The default field of view: **35°, a telephoto - the lead's, from play.** DO NOT widen it toward 55-60° without him.
## Two agents independently argued the wrong way: "a wider lens shows more of the fight" is sound and irrelevant. At a
## low pitch a wide lens is a vista of horizon with tiny vehicles - that was "unplayable because of the field of view";
## a telephoto crops to the action and makes the machines read large, without a close camera's loss of tactical read.
## The stills pages could never have found this: a still rendered at a fixed FOV holds constant the one variable that
## mattered. (Was 55° before round 6, 60° for most of it.) The live value is `fov`: `[` / `]` change it in play.
const FOV_DEG := 35.0
## He chose the floor of the range offered, so the range now goes below his pick.
const MIN_FOV_DEG := 20.0
const MAX_FOV_DEG := 90.0
const FOV_STEP_DEG := 5.0
## Round 6, after two wrong answers from still frames: the lead finds the camera himself, in play. `fov` is live (one
## camera, so a static the pure pose math reads), and `auto_frame` off stops the vision camera taking the view back.
static var fov := FOV_DEG
## X3 cutaway: the camera's near plane when there is nothing to cut (Camera3D's default), and how far short of the
## wall's foot the plane stops when there is.
const NEAR_DEFAULT := 0.05
## The perimeter wall's height (ArenaDressing.WALL_HEIGHT, feel's): the cut must clear its top edge too, or at a low
## pitch that edge hides every vehicle parked against it (the lead's 12°, shell-playtest).
const WALL_HEIGHT_M := 3.0
## The grandstand's profile outside the wall, as (metres out from the wall's inner face, height): the wall's top, the
## stands' front rail, their middle and their back. Measured from feel's kit_stands (15.7 m high, 19.9 m deep, set
## 0.3 m past the 2 m wall); if the venue changes shape, these follow it.
## The front point includes the railing above the first seats (7 m): at 5 m the railing still crossed the back row of a
## squad parked by the wall (shell-playtest at 78 m, round 7).
## FALLBACK ONLY since feel published StandsProfile (c97520a9): `stands_profile()` reads the profile computed from the
## kit the dressing places, which moves when the venue does (the hexagon's venue builds modules per edge); this hand
## measurement is lesson 66, a derived value copied. feel's test asserts StandsProfile reproduces these four points.
const STANDS_PROFILE := [Vector2(2.0, 3.0), Vector2(2.3, 7.0), Vector2(12.3, 11.0), Vector2(22.2, 15.7)]
const STANDS_PROFILE_SCRIPT := "res://game/theme/arena_kit/stands_profile.gd"
static var _stands: Array = []


## The stands' profile for the cutaway: feel's StandsProfile.points() when this build has it (looked up by path, as it
## may not have merged yet), else STANDS_PROFILE. Read once: StandsProfile caches, and the venue is fixed for a match.
static func stands_profile() -> Array:
	if not _stands.is_empty():
		return _stands
	_stands = STANDS_PROFILE.duplicate()
	if ResourceLoader.exists(STANDS_PROFILE_SCRIPT):
		var script := load(STANDS_PROFILE_SCRIPT) as Script
		var points: Variant = script.call("points") if script != null else null
		if points is PackedVector2Array and (points as PackedVector2Array).size() >= 2:
			_stands = Array(points)
	return _stands
## Whether the stands hide the arena is judged for a vehicle this far inside the wall, this high.
const OCCLUSION_PROBE := Vector2(4.0, 1.0)
## A camera less than this far behind the stands' back still counts as among them (their back rail and lights).
const STANDS_CLEARANCE_M := 4.0
## How far past the wall's top edge the near plane sits (a vehicle against the wall is further away than that edge).
const CUTAWAY_PAST_WALL_M := 0.2
## Keyboard pan speed in meters per second at zoom 1 (scales down as you zoom in).
const PAN_SPEED := 160.0
const ROTATE_SPEED := deg_to_rad(100.0)
const WHEEL_ZOOM_STEP := 0.07
const KEY_ZOOM_SPEED := 0.8
## Higher = snappier. Exponential smoothing of the shown pose toward the wanted one.
const SMOOTHING := 12.0
const EDGE_PAN_PX := 6.0
## How far past the arena the focus may wander.
const FOCUS_LIMIT := Match.ARENA_HALF_SIZE + 10.0
const OVERVIEW_ZOOM := 0.92
const FOLLOW_ZOOM := 0.18
## C4 framing: points must sit inside this fraction of the screen (so they aren't under the HUD).
const FRAME_INSET := 0.62
## Framing never zooms in closer than this, and a frame adds this much ground around the points.
const FRAME_MIN_ZOOM := 0.22
const FRAME_MARGIN_M := 8.0
## Tracking moves gently: exponential smoothing this slow, and never faster than these limits
## (meters per second at zoom 1, scaled down when close; zoom levels per second).
const TRACK_SMOOTHING := 3.0
const TRACK_SPEED := 120.0
const TRACK_ZOOM_SPEED := 0.35
## L4 (control X1): the vision frame may go this close, and no closer (the auto frame's floor; the player may
## still scroll in from there, which costs them awareness and is their call).
## Round 6: in play at 45° the auto camera closed to ~29 m on a three-vehicle squad (shell-playtest), too close to see
## what the squad is shooting at. It no longer comes closer than VISION_FLOOR_M on its own; the wheel still can.
## Round 7: nor further than this. At the lead's 35° telephoto, fitting a squad strung along the spawn line pulled the
## auto camera to ~220 m (shell-playtest), nothing like his 49 m; past the cap the rest of the squad goes to the edge
## markers. `auto_frame_max_m` is the live value (the wheel still goes anywhere; this only limits the auto camera).
const AUTO_FRAME_MAX_M := 100.0
const VISION_FLOOR_M := 45.0  # confirmed by the lead's pose (auto-framing left on at 49 m)
const VISION_MIN_ZOOM := 0.345  # RtsCamera.level_for(VISION_FLOOR_M)
## After the player last moved the camera, this many seconds of stillness give the element back to it.
const HANDBACK_SECONDS := 2.5
## L4: the vision frame fills more of the screen than a C4 frame does (the lead: "always zoom in as close as
## possible"). The HUD's command card eats the bottom strip, so the frame is also nudged up-screen by
## VISION_FRAME_LIFT of the half-height, which buys the closeness without putting units under the card.
const VISION_FRAME_INSET := 0.78
const VISION_FRAME_LIFT := 0.16
## Round 8: how far BELOW the screen's centre, as a fraction of the half-height, a lean may put the squad. The command
## card and group chips cover the bottom of the screen - at 1920x1080 their top is at y 778, 0.44 of the half-height
## below centre (squad's control-scale-shots frame) - and a symmetric bound (VISION_FRAME_INSET, 0.78) let the lean
## toward the reach park the selected squad underneath them. 0.40 leaves room for the hulls above the card.
const VISION_FRAME_BOTTOM := 0.40
## L4 zoom-out cap: at least this much of the screen's ground must be ground the force can see…
const VISION_SEEN_FRACTION := 0.7
## …sampled on this grid of screen points, …
const VISION_SAMPLES := 5
## …never forcing the player closer in than this (a hole in your vision must not slam the camera to the floor), …
const VISION_CAP_FLOOR := 0.35
## …and re-derived every this many frames, because it moves slowly and costs more than the rest of the camera.
const VISION_CAP_EVERY := 6

## Order tracking never climbs above this zoom (below TacticalMap.ICON_ZOOM, so models stay models) to fit a far destination: it keeps the squad readable and leans
## the view toward where it's going instead (the lead: follow them, don't make me zoom out and in).
const TRACK_MAX_ZOOM := 0.48

signal gesture_started
## C4: tracking stopped; reason = "arrived" (the tracked points ran out), "manual" (the player moved the
## camera), or "replaced" / "stopped" (code).
signal tracking_ended(reason: String)

enum Track { NONE, ORDER, FOLLOW, VISION }

var camera: Camera3D
## What we look at (on the ground), which way we face (0 = north up the screen), how far out (0..1).
var focus := Vector3(0.0, 0.0, 40.0)
var yaw := 0.0
var zoom := 0.7
## X3: the tilt in degrees below the horizon, independent of zoom (MIN_PITCH_DEG..MAX_PITCH_DEG; the overview goes
## past it on purpose).
var pitch := DEFAULT_PITCH_DEG
var follow_target: Node3D
## Screen-edge panning: off in tests and when the window isn't focused.
var edge_pan := true
## L4: the vision source. Returns {"frame": Array of ground points to keep on screen, "region": VisionRegion (the
## whole team's sight), "destination": Vector3 or null}. While it is set the camera frames the commanded element
## by itself, refuses to zoom out past the force's collective horizon, and keeps a free look over seen ground.
var vision: Callable = Callable()
## The furthest-out zoom the force's sight earns (1.0 = unconstrained; refreshed from `vision` every frame).
var vision_zoom := 1.0
## The ground a free camera may look at (null = anywhere).
var vision_region: VisionRegion = null
## How long the camera stays the player's after they move it (seconds; 0 hands back at once).
var handback_seconds := HANDBACK_SECONDS
## Control X3 (the lead's dial): how much of the screen the commanded element fills (`--camera-frame`).
var vision_inset := VISION_FRAME_INSET
## Off: the vision camera never takes the view back (V in play).
var auto_frame := true
var auto_frame_max_m := AUTO_FRAME_MAX_M
## Round 7 (A), the lead: "the camera's yaw orientation should match the intended facing position of the squad or
## selected unit - this is what I think can differentiate us from a normal RTS game." `facing` returns the selection's
## facing (a ground Vector3) or null; the yaw turns toward it at YAW_FOLLOW_DEG_PER_S once it is YAW_DEADBAND_DEG off,
## until within YAW_SETTLE_DEG (so a hull's wiggle never shakes the view). Manual yaw pauses it for the hand-back time;
## Y turns it off. Null (nothing selected, or a mixed selection) keeps the current yaw: no snap.
var yaw_follow := true
var facing: Callable = Callable()
const YAW_FOLLOW_DEG_PER_S := 70.0
const YAW_DEADBAND_DEG := 12.0
const YAW_SETTLE_DEG := 2.0
var _yaw_turning := false

var _shown_focus := Vector3.ZERO
var _shown_yaw := 0.0
var _shown_zoom := 0.7
var _shown_pitch := DEFAULT_PITCH_DEG
var _before_overview: Variant = null
## Touch: finger index → screen position, for pinch/twist.
var _fingers := {}
var _middle_dragging := false
var _track := Track.NONE
## Returns the Array of ground points to keep framed; an empty array ends the tracking ("arrived").
var _track_points: Callable
## While tracking, never zoom in past the zoom the player had when it started.
var _track_floor_zoom := 0.0
## UI clock (seconds, advancing while paused) and when the player last moved the camera, for the hand-back.
var _clock := 0.0
var _manual_at := -1e9
## This frame's `vision` reading, so the tracking and the cap agree and it is called once.
var _vision_state := {}
## Frames left before the zoom-out cap is re-derived (see VISION_CAP_EVERY).
var _cap_countdown := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if camera is FollowCamera:
		(camera as FollowCamera).target = null
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = fov
	camera.far = 1200.0
	# The rig moves the camera every rendered frame from where vehicles are drawn (Shown): physics interpolation
	# (combat's 30 Hz tick) must not also smooth it, or it trails a tick behind its own targets.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	RtsCamera.load_perimeter()  # round 7: the arena's own wall shape, when it has one
	snap()


## Jump the shown pose to the wanted pose (no smoothing).
func snap() -> void:
	_shown_focus = focus
	_shown_yaw = yaw
	_shown_zoom = zoom
	_shown_pitch = pitch
	_apply()


func _process(delta: float) -> void:
	_clock += delta
	_update_vision()
	var keys := Vector2(float(Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_LEFT)),
			float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP)))
	if edge_pan and DisplayServer.window_is_focused() and camera.get_viewport() != null:
		var viewport := camera.get_viewport()
		var mouse := viewport.get_mouse_position()
		var size := viewport.get_visible_rect().size
		if Rect2(Vector2.ZERO, size).has_point(mouse):
			keys.x += float(mouse.x >= size.x - EDGE_PAN_PX) - float(mouse.x <= EDGE_PAN_PX)
			keys.y += float(mouse.y >= size.y - EDGE_PAN_PX) - float(mouse.y <= EDGE_PAN_PX)
	if keys != Vector2.ZERO:
		follow_target = null
		pan_world(keys.limit_length(1.0) * PAN_SPEED * lerpf(0.25, 1.0, zoom) * delta)
	var turn := float(Input.is_key_pressed(KEY_PERIOD)) - float(Input.is_key_pressed(KEY_COMMA))
	if turn != 0.0:
		rotate_by(turn * ROTATE_SPEED * delta)
	var zoom_keys := float(Input.is_key_pressed(KEY_MINUS)) - float(Input.is_key_pressed(KEY_EQUAL))
	if zoom_keys != 0.0:
		zoom_by(zoom_keys * KEY_ZOOM_SPEED * delta)
	var tilt_keys := float(Input.is_key_pressed(KEY_PAGEUP)) - float(Input.is_key_pressed(KEY_PAGEDOWN))
	if tilt_keys != 0.0:
		tilt_by(tilt_keys * TILT_SPEED_DEG * delta)
	if follow_target != null and is_instance_valid(follow_target) and follow_target.is_inside_tree():
		focus = Shown.ground(follow_target)
	_update_yaw_follow(delta)
	_update_tracking()
	var weight := 1.0 - exp(-SMOOTHING * delta)
	if _track != Track.NONE:
		# Gentle and speed-limited, so a long camera move never whips (no motion sickness).
		var soft := 1.0 - exp(-TRACK_SMOOTHING * delta)
		var step := (_shown_focus.lerp(focus, soft) - _shown_focus).limit_length(TRACK_SPEED * lerpf(0.3, 1.0, _shown_zoom) * delta)
		_shown_focus += step
		_shown_zoom += clampf(lerpf(_shown_zoom, zoom, soft) - _shown_zoom, -TRACK_ZOOM_SPEED * delta, TRACK_ZOOM_SPEED * delta)
	else:
		_shown_focus = _shown_focus.lerp(focus, weight)
		_shown_zoom = lerpf(_shown_zoom, zoom, weight)
	_shown_yaw = lerp_angle(_shown_yaw, yaw, weight)
	_shown_pitch = lerpf(_shown_pitch, pitch, weight)
	_apply()


## Round 9: how many degrees the camera lifted itself to get out of a building this frame (0 in the open). The
## readout shows it, because this is the second place the camera overrides the player's tilt and the first one is
## flagged to him too.
var lifted_deg := 0.0


func _apply() -> void:
	if camera != null:
		camera.fov = fov
		var distance := RtsCamera.distance_for(_shown_zoom)
		# The far-range floor is about how far the player ZOOMED OUT, so it is read from the asked-for distance, not
		# from whatever the solid test leaves - otherwise a camera pulled in by a building would also un-tilt itself.
		var tilt := RtsCamera.tilt_at(_shown_pitch, distance)
		var clear := RtsCamera.clear_pose(_shown_focus, _shown_yaw, distance, tilt)
		lifted_deg = float(clear["lifted_deg"])
		camera.global_transform = RtsCamera.pose_at(_shown_focus, _shown_yaw, float(clear["distance"]), float(clear["pitch_deg"]))
		camera.near = RtsCamera.cutaway_near(_shown_focus, _shown_yaw, float(clear["distance"]), float(clear["pitch_deg"]),
				RtsCamera.perimeter_half())


## X3 cutaway. At the lead's low camera a squad near the wall is framed from a camera that sits past the wall, inside
## the grandstand, and the railing and the crowd hide it (`make shell-playtest`, 50 s). Tilting up to stay inside the
## arena would bring back the top-down view exactly where every army starts, so instead the camera does not draw what
## stands between it and the wall: its near plane sits just past the wall's top edge where its line of sight crosses
## the wall (the stands and the wall go, the floor and a vehicle against the wall stay). A camera over the arena gets
## NEAR_DEFAULT. Pure, for tests.
static func cutaway_near(at: Vector3, heading: float, distance: float, pitch_deg: float, half: float) -> float:
	var back := Vector3(sin(heading), 0.0, cos(heading))  # from the focus toward the camera, on the ground
	var reach := INF  # how far from the focus, along `back`, the wall's inner face is
	var wall_height := WALL_HEIGHT_M
	var profile: Array = stands_profile()
	if perimeter_poly.size() >= 3:
		# Round 7: the arena's own perimeter (arena's Arena.perimeter / perimeter_edges), any convex polygon. The span
		# of wall the sight line crosses says what stands behind it: stands and gates use the stands profile, "none"
		# only the wall.
		var hit := RtsCamera.perimeter_crossing(Vector2(at.x, at.z), Vector2(back.x, back.z))
		if hit.is_empty():
			return NEAR_DEFAULT
		reach = float(hit["reach"])
		wall_height = float(hit.get("wall_height_m", WALL_HEIGHT_M))
		if String(hit.get("kind", "stands")) == "none":
			profile = [Vector2(2.0, wall_height)]
	else:
		for axis in [0, 2]:
			var along: float = back[axis]
			if absf(along) > 0.0001:
				reach = minf(reach, (half * signf(along) - at[axis]) / along)
	return RtsCamera._cut(at, heading, distance, pitch_deg, reach, back, wall_height, profile)


## The perimeter the cutaway crosses (round 7): arena's wall inner face, CCW, and its edges with their spans. Empty = the
## square fallback (perimeter_half). Loaded from the arena by `load_perimeter`, or set directly in tests.
static var perimeter_poly := PackedVector2Array()
static var perimeter_edge_data: Array = []


## Read arena's perimeter when this build has it (looked up by name: arena's shapes may not have merged yet).
static func load_perimeter() -> void:
	perimeter_poly = PackedVector2Array()
	perimeter_edge_data = []
	var script := load("res://game/arena/arena.gd") as Script
	if script == null:
		return
	var names := script.get_script_method_list().map(func(m: Dictionary) -> String: return String(m["name"]))
	if not names.has("perimeter") or not names.has("perimeter_edges"):
		return
	var poly: Variant = script.call("perimeter")
	var edges: Variant = script.call("perimeter_edges")
	if poly is PackedVector2Array and (poly as PackedVector2Array).size() >= 3 and edges is Array:
		perimeter_poly = poly
		perimeter_edge_data = edges


## Where a ray from `from` (inside the perimeter) along `direction` leaves it: {"reach": metres, "edge": index,
## "along_m": metres along that edge from its `from` vertex, "kind": the span's kind there, "wall_height_m"}; {} if none.
static func perimeter_crossing(from: Vector2, direction: Vector2) -> Dictionary:
	var best := {}
	var nearest := INF
	var n := perimeter_poly.size()
	for i in n:
		var a := perimeter_poly[i]
		var b := perimeter_poly[(i + 1) % n]
		var edge := b - a
		var denom := direction.cross(edge)
		if absf(denom) < 1e-6:
			continue
		var t := (a - from).cross(edge) / denom
		var u := (a - from).cross(direction) / denom
		if t > 0.0 and u >= 0.0 and u <= 1.0 and t < nearest:
			nearest = t
			best = {"reach": t, "edge": i, "along_m": u * edge.length()}
	if best.is_empty():
		return best
	var kind := "stands"
	var height := WALL_HEIGHT_M
	if int(best["edge"]) < perimeter_edge_data.size():
		var data: Dictionary = perimeter_edge_data[int(best["edge"])]
		height = float(data.get("wall_height_m", WALL_HEIGHT_M))
		for span: Dictionary in data.get("spans", []):
			if float(best["along_m"]) >= float(span["from_m"]) and float(best["along_m"]) <= float(span["to_m"]):
				kind = String(span["kind"])
				break
	best["kind"] = kind
	best["wall_height_m"] = height
	return best


static func _cut(at: Vector3, heading: float, distance: float, pitch_deg: float, reach: float, back: Vector3,
		wall_height: float, profile: Array) -> float:
	var tilt := deg_to_rad(clampf(pitch_deg, 1.0, 89.0))
	if reach < 0.0 or distance * cos(tilt) <= reach:
		return NEAR_DEFAULT
	# Past the wall - but only cut what is actually in the way. From far out and high up the sight line to a vehicle
	# just inside the wall clears the stands, and they stay (crowd and all) instead of leaving a black void.
	var outside := distance * cos(tilt) - reach  # the camera's horizontal distance past the wall's inner face
	var height := distance * sin(tilt)
	var span := outside + OCCLUSION_PROBE.x  # camera to the probe vehicle, horizontally
	# Inside the stands' footprint (or just behind it) the camera is among the seats and railings: always cut.
	var hidden := profile.size() > 1 and outside <= (profile.back() as Vector2).x + STANDS_CLEARANCE_M
	for point: Vector2 in profile:
		if point.x >= outside:
			continue  # this part of the stands is behind the camera
		var sight := OCCLUSION_PROBE.y + (height - OCCLUSION_PROBE.y) * (point.x + OCCLUSION_PROBE.x) / span
		if sight < point.y:
			hidden = true
	if not hidden:
		return NEAR_DEFAULT
	var pose := RtsCamera.pose_at(at, heading, distance, pitch_deg)
	var forward := -pose.basis.z
	var wall_foot := Vector3(at.x, 0.0, at.z) + back * reach
	# The wall's top edge is nearer the camera than its foot by its height * sin(pitch): cut just past it.
	var wall_top := wall_foot + Vector3.UP * wall_height
	return maxf(NEAR_DEFAULT, (wall_top - pose.origin).dot(forward) + CUTAWAY_PAST_WALL_M)


## The arena perimeter's half size: the walls stand one metre outside the layout's half size (ArenaDressing.setup).
static func perimeter_half() -> float:
	return float(Arena.active.get("half_size", Match.ARENA_HALF_SIZE)) + 1.0


## Camera transform looking at `at` from `yaw` (0 = camera south of the focus, looking north), `level` (0 = close,
## 1 = far) and `pitch_deg` below the horizon. X3: the two are independent - zoom never tilts the camera.
static func pose_for(at: Vector3, heading: float, level: float, pitch_deg := DEFAULT_PITCH_DEG) -> Transform3D:
	var distance := RtsCamera.distance_for(level)
	return RtsCamera.pose_at(at, heading, distance, RtsCamera.tilt_at(pitch_deg, distance))


## The tilt a camera `distance` metres out actually uses: the player's, lifted by the far-range floor (see
## FAR_TILT_FROM_M). Every pose goes through this, so framing, the vision cap and the drawn camera agree.
static func tilt_at(pitch_deg: float, distance: float) -> float:
	var t := clampf((distance - FAR_TILT_FROM_M) / (FAR_TILT_FULL_M - FAR_TILT_FROM_M), 0.0, 1.0)
	return maxf(pitch_deg, lerpf(MIN_PITCH_DEG, FAR_TILT_MAX_DEG, t))


## The camera `distance` metres from `at`, `pitch_deg` below the horizon. `make camera-looks` poses with this directly.
static func pose_at(at: Vector3, heading: float, distance: float, pitch_deg: float) -> Transform3D:
	return Transform3D(Basis.IDENTITY, at + RtsCamera.boom(heading, distance, pitch_deg)).looking_at(at, Vector3.UP)


## The vector from the focus to the camera: the boom. One definition, so the pose, the solid test and the cutaway
## cannot drift apart.
static func boom(heading: float, distance: float, pitch_deg: float) -> Vector3:
	var tilt := deg_to_rad(clampf(pitch_deg, 1.0, 89.0))
	return Vector3(0.0, sin(tilt), cos(tilt)).rotated(Vector3.UP, heading) * distance


# ---- Round 9: the camera is never inside a building ---------------------------------------------------------
#
# The lead, on the Terminus: *"the camera often ends up inside a building and we can't see what's going on inside
# the alleyways. We need to make it so the camera is forced outside the solid for these cases."*
#
# Why it happens, in numbers: at his pose (21 deg, 49 m) the camera sits **17.6 m up and 45.7 m back**. The Terminus
# is 40 x 24 x 40 m blocks with 20 m streets, so a boom that long from a street crosses a block almost every time,
# and 17.6 m is well under the 24 m roof. The camera is inside a building, and he is looking at the inside of a wall.
#
# TWO MECHANISMS WERE AVAILABLE AND THE NUMBERS DECIDED IT.
#   * Shorten the boom until it exits the block (the classic third-person camera). With the focus mid-street the
#     block's face is ~10 m away, so the boom collapses **49 m -> ~11 m** - below MIN_DISTANCE, a near-first-person
#     view, and the OTHER side of the street still walls the alley. It fixes his sentence and not his problem.
#   * **Lift the camera over the roof**, keeping the boom's length. Clearing a 24 m roof at a 49 m boom is
#     **21 deg -> 32 deg**, still 41.5 m of horizontal reach, and it looks DOWN INTO the alley - which is the thing
#     he said he could not see. It is also inside the tilt range he can reach by hand (8-70 deg).
# So: lift first, and shorten only when even MAX_PITCH_DEG cannot clear the roof (a solid taller than the boom).
#
# This is the SECOND place the camera overrides the player's tilt, after the far-range floor, and round 6's rule is
# that such a place is flagged to him rather than hidden: `lifted_deg` is what it did, and CameraReadout shows it.
## How far above a roof the camera is put: enough that the near plane is outside the solid too.
const SOLID_CLEAR_M := 2.0
## Bounded refinement - lifting moves the camera horizontally as well, so it can arrive over a different block.
const SOLID_PASSES := 6
## When even the maximum tilt cannot clear a roof, the boom shortens instead, and never below this (a camera on top
## of the focus shows nothing either).
const SOLID_MIN_DISTANCE_M := 6.0

## The height of the tallest solid whose footprint covers this point and whose roof is above it, or -1.0 when the
## point is in the open. Reads the layout's own boxes (`Arena.active["obstacles"]`, which already folds in the kit
## props a cityscape is built from), so it needs no physics and works headless. Pure, for tests.
static func roof_over(point: Vector3, data: Dictionary = Arena.active) -> float:
	var roof := -1.0
	var flat := Vector2(point.x, point.z)
	for obstacle: Dictionary in data.get("obstacles", []):
		var size := Arena.obstacle_size(obstacle)
		if point.y >= size.y or size.y <= roof:
			continue
		var centre := Vector2(float(obstacle["position"][0]), float(obstacle["position"][1]))
		if ArenaKit.distance_to_footprint(flat, centre, size, float(obstacle.get("rotation_deg", 0.0))) <= 0.0:
			roof = size.y
	return roof


## Whether the straight line from `a` to `b` passes through a solid: the second half of the lead's sentence, because
## a camera that is outside every building can still be looking at the side of one. Slab test per box in the box's own
## frame, restricted to the segment. Pure, for tests and for the alley frames.
static func sight_blocked(a: Vector3, b: Vector3, data: Dictionary = Arena.active, min_height := 0.0) -> bool:
	for obstacle: Dictionary in data.get("obstacles", []):
		var size := Arena.obstacle_size(obstacle)
		if size.y < min_height:
			continue
		var centre := Vector3(float(obstacle["position"][0]), size.y / 2.0, float(obstacle["position"][1]))
		if RtsCamera.segment_hits_box(a, b, centre, size / 2.0, deg_to_rad(float(obstacle.get("rotation_deg", 0.0)))):
			return true
	return false


## Does the SEGMENT a→b cross this box? Slab test in the box's own frame, clipped to the segment, so a box behind
## either end is not in the way. `half` is the box's half extents, `yaw` its rotation about +Y. The one definition:
## `sight_blocked` (the measurement) and `BlockCutaway` (what the player sees) must never disagree about it.
static func segment_hits_box(a: Vector3, b: Vector3, centre: Vector3, half: Vector3, yaw: float) -> bool:
	var start := (a - centre).rotated(Vector3.UP, -yaw)
	var step := (b - a).rotated(Vector3.UP, -yaw)
	var near := 0.0
	var far := 1.0
	for axis in 3:
		if absf(step[axis]) < 1e-6:
			if absf(start[axis]) > half[axis]:
				return false
			continue
		var t0 := (-half[axis] - start[axis]) / step[axis]
		var t1 := (half[axis] - start[axis]) / step[axis]
		near = maxf(near, minf(t0, t1))
		far = minf(far, maxf(t0, t1))
	return near <= far


## The pose to actually use: `{"distance", "pitch_deg", "lifted_deg"}`. Equal to what was asked for whenever the
## camera is in the open, which is every arena without a cityscape and most of the Terminus. Pure, for tests.
static func clear_pose(at: Vector3, heading: float, distance: float, pitch_deg: float,
		data: Dictionary = Arena.active) -> Dictionary:
	var tilt := pitch_deg
	var reach := distance
	for pass_index in SOLID_PASSES:
		var roof := RtsCamera.roof_over(at + RtsCamera.boom(heading, reach, tilt), data)
		if roof < 0.0:
			return {"distance": reach, "pitch_deg": tilt, "lifted_deg": tilt - pitch_deg}
		var needed := roof + SOLID_CLEAR_M
		if needed < reach:
			var lifted := rad_to_deg(asin(clampf(needed / reach, 0.0, 1.0)))
			if lifted > tilt + 0.01 and lifted <= MAX_PITCH_DEG:
				tilt = lifted
				continue
		# The roof is higher than the boom is long, or higher than the steepest tilt reaches: pull the camera in.
		# One step per pass, so a stack of blocks resolves over the passes instead of jumping to the floor at once.
		reach = maxf(SOLID_MIN_DISTANCE_M, reach * 0.6)
		if is_equal_approx(reach, SOLID_MIN_DISTANCE_M):
			break
	return {"distance": reach, "pitch_deg": tilt, "lifted_deg": tilt - pitch_deg}


## How far out a zoom level puts the camera. Eased, so the middle of the range isn't all long distance.
static func distance_for(level: float) -> float:
	var t := clampf(level, 0.0, 1.0)
	return lerpf(MIN_DISTANCE, MAX_DISTANCE, t * t)


## The zoom level that puts the camera `distance` metres out (the inverse of distance_for).
static func level_for(distance: float) -> float:
	return sqrt(clampf((distance - MIN_DISTANCE) / (MAX_DISTANCE - MIN_DISTANCE), 0.0, 1.0))


## Round 5's welded pose, kept only so `make camera-looks` can show the lead what he played: the tilt followed zoom
## from 25° to 82°. Nothing in the game uses it.
static func welded_pitch(level: float) -> float:
	return lerpf(25.0, 82.0, clampf(level, 0.0, 1.0))


# ---- Commands (input handlers and other code call these) -------------------------------

## Move the focus by a world-space amount in the camera's frame: +x = screen right, +y = screen down.
func pan_world(amount: Vector2) -> void:
	_manual()
	var right := Vector3.RIGHT.rotated(Vector3.UP, yaw)
	var down := Vector3.BACK.rotated(Vector3.UP, yaw)
	focus += right * amount.x + down * amount.y
	focus.x = clampf(focus.x, -FOCUS_LIMIT, FOCUS_LIMIT)
	focus.z = clampf(focus.z, -FOCUS_LIMIT, FOCUS_LIMIT)
	focus.y = 0.0
	focus = look_clamp(focus)


## "Grab the ground": dragging the screen by `pixels` moves the view so the ground under the finger
## follows it.
func pan_screen(from: Vector2, to: Vector2) -> void:
	var a: Variant = ground_point(from)
	var b: Variant = ground_point(to)
	if a == null or b == null:
		return
	follow_target = null
	_manual()
	var shift: Vector3 = (a as Vector3) - (b as Vector3)
	focus += Vector3(shift.x, 0.0, shift.z)
	focus.x = clampf(focus.x, -FOCUS_LIMIT, FOCUS_LIMIT)
	focus.z = clampf(focus.z, -FOCUS_LIMIT, FOCUS_LIMIT)
	focus = look_clamp(focus)
	# Panning is direct manipulation: no smoothing lag under the finger.
	_shown_focus = focus
	_apply()


func rotate_by(radians: float) -> void:
	_manual()
	yaw = wrapf(yaw + radians, -PI, PI)


func zoom_by(amount: float) -> void:
	_manual()
	zoom = clampf(zoom + amount, 0.0, vision_zoom)


## X3: tilt the camera by `degrees` (positive = steeper, toward top-down), within the player's range. The overview
## hands the tilt back first, so tilting from it lands in range instead of jumping.
func tilt_by(degrees: float) -> void:
	if _before_overview != null:
		toggle_overview(0)
	pitch = clampf(pitch + degrees, MIN_PITCH_DEG, MAX_PITCH_DEG)


## Widen (positive) or narrow the field of view by `degrees`, within MIN/MAX_FOV_DEG.
func fov_by(degrees: float) -> void:
	fov = clampf(fov + degrees, MIN_FOV_DEG, MAX_FOV_DEG)


## The vision camera frames the commanded element and takes the view back after the player moves it. Off, the camera
## stays wherever the player leaves it (for finding a pose by hand).
func set_auto_frame(on: bool) -> void:
	auto_frame = on
	if not on and _track == Track.VISION:
		stop_tracking("manual")


## Round 7 (A): turn the yaw toward the selection's facing (see `yaw_follow`).
func _update_yaw_follow(delta: float) -> void:
	if not yaw_follow or not facing.is_valid() or _before_overview != null or _clock - _manual_at < handback_seconds:
		_yaw_turning = false
		return
	var wanted: Variant = facing.call()
	if not wanted is Vector3:
		_yaw_turning = false
		return
	var gap := angle_difference(yaw, RtsCamera.yaw_facing(wanted as Vector3))
	if not _yaw_turning and absf(gap) < deg_to_rad(YAW_DEADBAND_DEG):
		return
	_yaw_turning = absf(gap) > deg_to_rad(YAW_SETTLE_DEG)
	var step := deg_to_rad(YAW_FOLLOW_DEG_PER_S) * delta
	yaw = wrapf(yaw + clampf(gap, -step, step), -PI, PI)


## The yaw that looks along `direction` on the ground (0 looks north, -Z; positive turns left: trip-up 2).
static func yaw_facing(direction: Vector3) -> float:
	return atan2(-direction.x, -direction.z)


## The current pose, in the words the lead pastes back: the values the defaults are made from.
func pose_text() -> String:
	var distance := RtsCamera.distance_for(_shown_zoom)
	return "CAMERA_POSE pitch=%.0f distance_m=%.0f fov=%.0f yaw=%.0f zoom=%.3f auto_frame=%s yaw_follow=%s" % [
			RtsCamera.tilt_at(_shown_pitch, distance), distance, fov, rad_to_deg(_shown_yaw), _shown_zoom,
			"on" if auto_frame else "off", "on" if yaw_follow else "off"] + " auto_frame_max_m=%.0f" % auto_frame_max_m


func reset_tilt() -> void:
	if _before_overview == null:
		pitch = DEFAULT_PITCH_DEG


## Zoom toward (or away from) a screen point, keeping the ground under it roughly in place.
func zoom_at(screen: Vector2, amount: float) -> void:
	var before: Variant = ground_point(screen)
	zoom_by(amount)
	if before != null and amount < 0.0:
		follow_target = null
		var toward: Vector3 = (before as Vector3) - focus
		focus += Vector3(toward.x, 0.0, toward.z) * clampf(-amount * 2.5, 0.0, 0.5)


func focus_on(point: Vector3) -> void:
	follow_target = null
	_manual()
	focus = look_clamp(Vector3(point.x, 0.0, point.z))


func follow(target: Node3D) -> void:
	stop_tracking("replaced")
	follow_target = target
	if target != null:
		zoom = minf(zoom, FOLLOW_ZOOM)


## Toggle a high view over the whole arena, and back to where you were.
func toggle_overview(team: int) -> void:
	stop_tracking("replaced")
	if _before_overview == null:
		_before_overview = [focus, yaw, zoom, follow_target, pitch]
		follow_target = null
		pitch = OVERVIEW_PITCH_DEG
		yaw = 0.0 if Match.team_frame(team)["forward"] == Vector3.FORWARD else PI
		# L4: Tab shows everything the force can see, not the whole arena (the lead: no unearned god view).
		if vision_region != null and not vision_region.is_empty():
			focus = look_clamp(vision_region.center())
			zoom = minf(OVERVIEW_ZOOM, vision_zoom)
		else:
			focus = Vector3.ZERO
			zoom = OVERVIEW_ZOOM
	else:
		focus = _before_overview[0]
		yaw = _before_overview[1]
		zoom = _before_overview[2]
		follow_target = _before_overview[3]
		pitch = _before_overview[4]
		_before_overview = null


func is_overview() -> bool:
	return _before_overview != null


func ground_point(screen: Vector2) -> Variant:
	if camera == null:
		return null
	return Plane(Vector3.UP, 0.0).intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))


# ---- C4: framing and tracking --------------------------------------------------------------

## Aim and zoom so every ground point is on screen (inside FRAME_INSET), keeping the current yaw. Never
## zooms in past FRAME_MIN_ZOOM (or `floor_zoom`). With `instant`, the shown pose jumps there too.
func frame(points: Array, instant := false, floor_zoom := FRAME_MIN_ZOOM) -> void:
	if points.is_empty():
		return
	follow_target = null
	var goal := RtsCamera.frame_pose(points, yaw, _aspect(), floor_zoom, FRAME_INSET, pitch)
	focus = goal[0]
	zoom = minf(float(goal[1]), vision_zoom)
	if instant:
		snap()


## [focus, zoom] that frames `points` (Vector3 on the ground) from `heading`. Pure, for tests.
static func frame_pose(points: Array, heading: float, aspect: float, floor_zoom := FRAME_MIN_ZOOM, inset := FRAME_INSET,
		pitch_deg := DEFAULT_PITCH_DEG) -> Array:
	var bounds := AABB(Vector3(points[0].x, 0.0, points[0].z), Vector3.ZERO)
	for p in points:
		bounds = bounds.expand(Vector3(p.x, 0.0, p.z))
	var center := bounds.get_center()
	center.y = 0.0
	center.x = clampf(center.x, -FOCUS_LIMIT, FOCUS_LIMIT)
	center.z = clampf(center.z, -FOCUS_LIMIT, FOCUS_LIMIT)
	# Test the bounding box's corners, grown by the margin: points in between are then inside too.
	var grown := bounds.grow(FRAME_MARGIN_M)
	var corners: Array[Vector3] = []
	for x in [grown.position.x, grown.end.x]:
		for z in [grown.position.z, grown.end.z]:
			corners.append(Vector3(x, 0.0, z))
	var level := clampf(floor_zoom, 0.0, 1.0)
	while level < 1.0 and not RtsCamera.shows_all(corners, center, heading, level, aspect, inset, pitch_deg):
		level += 0.01
	return [center, minf(level, 1.0)]


## Whether a camera at pose_for(at, heading, level) shows every point inside `inset` of the screen (the default
## keeps them clear of the HUD; the L4 horizon uses the whole screen).
static func shows_all(points: Array, at: Vector3, heading: float, level: float, aspect: float, inset := FRAME_INSET,
		pitch_deg := DEFAULT_PITCH_DEG, bottom := -1.0) -> bool:
	var view := RtsCamera.pose_for(at, heading, level, pitch_deg).affine_inverse()
	var half := tan(deg_to_rad(fov) / 2.0)
	var tan_y := half * inset
	var tan_down := half * (bottom if bottom >= 0.0 else inset)  # below the centre: the HUD's side (round 8)
	for p in points:
		var c: Vector3 = view * (p as Vector3)
		if c.z >= -0.1:
			return false
		var up := c.y / -c.z
		if absf(c.x / -c.z) > tan_y * aspect or up > tan_y or -up > tan_down:
			return false
	return true


## What fraction of the screen's ground a camera at this pose is looking at ground `region` can see, sampled on a
## VISION_SAMPLES × VISION_SAMPLES grid of screen points. A sample whose ray never reaches the ground (sky) is left
## out of the count entirely: it shows no ground, earned or unearned. Round 6: at the lead's 25° a fifth of the screen
## is sky, and counting it as unseen ground would have capped exactly the view he picked. Pure, for tests.
static func seen_fraction(region: VisionRegion, at: Vector3, heading: float, level: float, aspect: float,
		pitch_deg := DEFAULT_PITCH_DEG) -> float:
	if region == null or region.is_empty():
		return 0.0
	var pose := RtsCamera.pose_for(at, heading, level, pitch_deg)
	var tan_y := tan(deg_to_rad(fov) / 2.0)
	var plane := Plane(Vector3.UP, 0.0)
	var seen := 0
	var ground := 0
	for i in VISION_SAMPLES:
		for j in VISION_SAMPLES:
			var u := lerpf(-1.0, 1.0, float(i) / float(VISION_SAMPLES - 1))
			var v := lerpf(-1.0, 1.0, float(j) / float(VISION_SAMPLES - 1))
			var direction := (pose.basis * Vector3(u * tan_y * aspect, v * tan_y, -1.0)).normalized()
			var hit: Variant = plane.intersects_ray(pose.origin, direction)
			if hit == null:
				continue
			ground += 1
			if region.contains(hit as Vector3):
				seen += 1
	return float(seen) / float(ground) if ground > 0 else 0.0


## L4: the furthest-out zoom whose screen is still mostly ground the force can see. Zooming past it is the
## unearned god view the lead ruled out ("we want to actually make the users expend their sentries to be able to
## see"), so the wheel, the keyboard, framing and Tab all obey it. Never below VISION_CAP_FLOOR, so looking at the
## edge of your vision costs you reach without slamming the camera onto the ground. Pure, for tests.
static func horizon_zoom(region: VisionRegion, at: Vector3, heading: float, aspect: float,
		pitch_deg := DEFAULT_PITCH_DEG) -> float:
	if region == null or region.is_empty():
		return 1.0
	if RtsCamera.seen_fraction(region, at, heading, 1.0, aspect, pitch_deg) >= VISION_SEEN_FRACTION:
		return 1.0
	var low := VISION_CAP_FLOOR
	var high := 1.0
	for i in 8:
		var mid := (low + high) / 2.0
		if RtsCamera.seen_fraction(region, at, heading, mid, aspect, pitch_deg) >= VISION_SEEN_FRACTION:
			low = mid
		else:
			high = mid
	return low


## Keep the points returned by `points` framed every frame until it returns an empty array (then
## tracking_ended("arrived")) or the player moves the camera (tracking_ended("manual")).
func track(points: Callable, mode := Track.ORDER) -> void:
	if _track != Track.NONE:
		stop_tracking("replaced")
	follow_target = null
	if _before_overview != null:
		toggle_overview(0)
	_track = mode
	_track_points = points
	_track_floor_zoom = VISION_MIN_ZOOM if mode == Track.VISION else maxf(zoom, FRAME_MIN_ZOOM)
	_update_tracking()


func stop_tracking(reason := "stopped") -> void:
	if _track == Track.NONE:
		return
	# Stay where the view is now: a leftover tracking goal must not lurch the camera after it lets go.
	focus = _shown_focus
	zoom = _shown_zoom
	_track = Track.NONE
	_track_points = Callable()
	tracking_ended.emit(reason)


func is_tracking() -> bool:
	return _track != Track.NONE


func tracking_mode() -> Track:
	return _track


func _update_tracking() -> void:
	if _track == Track.NONE:
		return
	if _track == Track.VISION:
		_update_vision_tracking()
		return
	var points: Array = _track_points.call() if _track_points.is_valid() else []
	if points.is_empty():
		stop_tracking("arrived")
		return
	var goal: Array
	if _track == Track.ORDER and points.size() >= 2:
		goal = RtsCamera.order_pose(points.slice(0, points.size() - 1), points.back(), yaw, _aspect(), _track_floor_zoom,
				FRAME_INSET, pitch)
	else:
		goal = RtsCamera.frame_pose(points, yaw, _aspect(), _track_floor_zoom, FRAME_INSET, pitch)
	focus = goal[0]
	zoom = minf(float(goal[1]), vision_zoom)


## [focus, zoom] for order tracking: `units` and `destination` together when that fits under TRACK_MAX_ZOOM
## (or the player's own zoom, if higher); otherwise the units stay framed at that zoom and the view leans as
## far toward the destination as it can while keeping them all on screen. Pure, for tests.
static func order_pose(units: Array, destination: Vector3, heading: float, aspect: float, floor_zoom := FRAME_MIN_ZOOM,
		inset := FRAME_INSET, pitch_deg := DEFAULT_PITCH_DEG) -> Array:
	var both := RtsCamera.frame_pose(units + [destination], heading, aspect, floor_zoom, inset, pitch_deg)
	var ceiling := maxf(TRACK_MAX_ZOOM, floor_zoom)
	if float(both[1]) <= ceiling:
		return both
	var squad := RtsCamera.frame_pose(units, heading, aspect, floor_zoom, inset, pitch_deg)
	var level := maxf(float(squad[1]), ceiling)
	var start: Vector3 = squad[0]
	var toward := Vector3(destination.x - start.x, 0.0, destination.z - start.z)
	var corners: Array = []
	var bounds := AABB(Vector3(units[0].x, 0.0, units[0].z), Vector3.ZERO)
	for p in units:
		bounds = bounds.expand(Vector3(p.x, 0.0, p.z))
	bounds = bounds.grow(FRAME_MARGIN_M)
	for x in [bounds.position.x, bounds.end.x]:
		for z in [bounds.position.z, bounds.end.z]:
			corners.append(Vector3(x, 0.0, z))
	# Binary search for the furthest lean that still shows the whole squad.
	var low := 0.0
	var high := 1.0
	for i in 12:
		var mid := (low + high) / 2.0
		if RtsCamera.shows_all(corners, start + toward * mid, heading, level, aspect, inset, pitch_deg,
				minf(inset, VISION_FRAME_BOTTOM)):
			low = mid
		else:
			high = mid
	return [start + toward * low, level]


# ---- L4: the vision-framed camera (control X1) ----------------------------------------------------------

## Refresh the force's sight region and the zoom-out cap it earns, and take the camera back to the commanded
## element once the player has left it alone for `handback_seconds`.
func _update_vision() -> void:
	if not vision.is_valid():
		return
	var reading: Variant = vision.call()
	_vision_state = reading if reading is Dictionary else {}
	var region: VisionRegion = _vision_state.get("region") as VisionRegion
	vision_region = region
	_cap_countdown -= 1
	if _cap_countdown <= 0:
		_cap_countdown = VISION_CAP_EVERY
		vision_zoom = RtsCamera.horizon_zoom(region, look_clamp(focus), yaw, _aspect(), pitch)
	zoom = minf(zoom, vision_zoom)
	if auto_frame and _track == Track.NONE and follow_target == null and _before_overview == null \
			and _clock - _manual_at >= handback_seconds and not (_vision_state.get("frame", []) as Array).is_empty():
		track(Callable(), Track.VISION)


## Give the camera back to the commanded element right now (switching elements, not waiting out the hand-back).
func take_vision() -> void:
	if not vision.is_valid() or not auto_frame:
		return
	_manual_at = -1e9
	_before_overview = null
	follow_target = null
	if _track != Track.VISION:
		track(Callable(), Track.VISION)


## The frame the vision source asks for, right now.
func _update_vision_tracking() -> void:
	var points: Array = _vision_state.get("frame", [])
	if points.is_empty():
		stop_tracking("arrived")
		return
	var destination: Variant = _vision_state.get("destination")
	var goal: Array
	if destination is Vector3:
		goal = RtsCamera.order_pose(points, destination as Vector3, yaw, _aspect(), _track_floor_zoom, vision_inset, pitch)
	else:
		goal = RtsCamera.frame_pose(points, yaw, _aspect(), _track_floor_zoom, vision_inset, pitch)
	zoom = minf(minf(float(goal[1]), vision_zoom), RtsCamera.level_for(auto_frame_max_m))
	focus = look_clamp(RtsCamera.lift(goal[0], heading_of(yaw), zoom, VISION_FRAME_LIFT))


## Shift a frame centre up the screen by `amount` of the screen's half-height, so the HUD's command card does not
## sit on top of the element. Pure: the ground moves away from the camera along its own heading.
static func lift(center: Vector3, forward: Vector3, level: float, amount: float) -> Vector3:
	var distance := RtsCamera.distance_for(level)
	return center + forward * distance * tan(deg_to_rad(fov) / 2.0) * amount


## The ground direction the camera faces at this yaw (away from the camera, on the screen's up axis).
static func heading_of(heading: float) -> Vector3:
	return Vector3.FORWARD.rotated(Vector3.UP, heading)


## Keep a ground point over what the team can see (L4: the "look" camera peeks only where it has vision).
func look_clamp(point: Vector3) -> Vector3:
	if vision_region == null or vision_region.is_empty():
		return point
	return vision_region.clamp_point(point)


## The player touched the camera: tracking yields at once, and holds off for `handback_seconds`.
func _manual() -> void:
	_manual_at = _clock
	stop_tracking("manual")


func _aspect() -> float:
	if camera == null or camera.get_viewport() == null:
		return 16.0 / 9.0
	var size := camera.get_viewport().get_visible_rect().size
	return size.x / maxf(size.y, 1.0)


# ---- Input ------------------------------------------------------------------------------

## Mouse wheel and middle-drag. The tactical map forwards these (it stops GUI mouse events).
func handle_mouse(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if button.pressed and button.ctrl_pressed:
					tilt_by(-WHEEL_TILT_DEG * maxf(button.factor, 1.0))  # X3: ctrl+wheel up lowers toward the horizon
				elif button.pressed:
					zoom_at(button.position, -WHEEL_ZOOM_STEP * maxf(button.factor, 1.0))
				return true
			MOUSE_BUTTON_WHEEL_DOWN:
				if button.pressed and button.ctrl_pressed:
					tilt_by(WHEEL_TILT_DEG * maxf(button.factor, 1.0))
				elif button.pressed:
					zoom_at(button.position, WHEEL_ZOOM_STEP * maxf(button.factor, 1.0))
				return true
			MOUSE_BUTTON_MIDDLE:
				_middle_dragging = button.pressed
				return true
	elif event is InputEventMouseMotion and _middle_dragging:
		var motion := event as InputEventMouseMotion
		pan_screen(motion.position - motion.relative, motion.position)
		return true
	elif event is InputEventMagnifyGesture:
		var magnify := event as InputEventMagnifyGesture
		zoom_at(magnify.position, (1.0 - magnify.factor) * 0.5)
		return true
	elif event is InputEventPanGesture:
		pan_world((event as InputEventPanGesture).delta * 2.0)
		return true
	return false


## Two-finger gestures (pinch = zoom, twist = rotate, both fingers moving = pan). Returns true while
## two or more fingers are down, so the map knows to leave the touch alone.
func handle_touch(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_fingers[touch.index] = touch.position
			if _fingers.size() == 2:
				gesture_started.emit()
		else:
			_fingers.erase(touch.index)
		return _fingers.size() >= 2
	if event is InputEventScreenDrag and _fingers.size() >= 2:
		var drag := event as InputEventScreenDrag
		var keys := _fingers.keys()
		keys.sort()
		var other_index: int = keys[1] if keys[0] == drag.index else keys[0]
		if not _fingers.has(drag.index):
			return true
		var anchor: Vector2 = _fingers[other_index]
		var before: Vector2 = _fingers[drag.index]
		var after := drag.position
		# Pinch: the ratio of finger spans. Twist: the change in the angle between fingers.
		var span_before := maxf(anchor.distance_to(before), 1.0)
		var span_after := maxf(anchor.distance_to(after), 1.0)
		zoom_by((span_before / span_after - 1.0) * 0.6)
		# +yaw turns the ground clockwise on screen, so a clockwise twist (screen angle grows) adds yaw.
		rotate_by(angle_difference((before - anchor).angle(), (after - anchor).angle()))
		# Pan by half the motion of the midpoint.
		pan_screen((anchor + before) / 2.0, (anchor + after) / 2.0)
		_fingers[drag.index] = after
		return true
	return _fingers.size() >= 2


func finger_count() -> int:
	return _fingers.size()
