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
## X3: the tilt the player can choose (degrees below the horizon), and where it starts. **The lead's pick** (round 6,
## 2026-09-18, on the camera page from `make camera-looks`): "pitch 25° · 50 m · FOV 60°" - the lowest angle offered.
## The player can still tilt from 22° (nearly Twisted Metal) to 50° (nearly StarCraft).
const MIN_PITCH_DEG := 22.0
const MAX_PITCH_DEG := 50.0
const DEFAULT_PITCH_DEG := 25.0
## The deliberate top-down read of the map (toggle_overview): the one place the camera still looks nearly straight down.
const OVERVIEW_PITCH_DEG := 77.0
## Tilt speed: degrees per second for held keys, degrees per wheel notch.
const TILT_SPEED_DEG := 40.0
const WHEEL_TILT_DEG := 3.0
## The lead's pick (see DEFAULT_PITCH_DEG); was 55°.
const FOV_DEG := 60.0
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
const VISION_MIN_ZOOM := 0.10
## After the player last moved the camera, this many seconds of stillness give the element back to it.
const HANDBACK_SECONDS := 2.5
## L4: the vision frame fills more of the screen than a C4 frame does (the lead: "always zoom in as close as
## possible"). The HUD's command card eats the bottom strip, so the frame is also nudged up-screen by
## VISION_FRAME_LIFT of the half-height, which buys the closeness without putting units under the card.
const VISION_FRAME_INSET := 0.78
const VISION_FRAME_LIFT := 0.16
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
	camera.fov = FOV_DEG
	camera.far = 1200.0
	# The rig moves the camera every rendered frame from where vehicles are drawn (Shown): physics interpolation
	# (combat's 30 Hz tick) must not also smooth it, or it trails a tick behind its own targets.
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
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


func _apply() -> void:
	if camera != null:
		camera.global_transform = RtsCamera.pose_for(_shown_focus, _shown_yaw, _shown_zoom, _shown_pitch)


## Camera transform looking at `at` from `yaw` (0 = camera south of the focus, looking north), `level` (0 = close,
## 1 = far) and `pitch_deg` below the horizon. X3: the two are independent - zoom never tilts the camera.
static func pose_for(at: Vector3, heading: float, level: float, pitch_deg := DEFAULT_PITCH_DEG) -> Transform3D:
	return RtsCamera.pose_at(at, heading, RtsCamera.distance_for(level), pitch_deg)


## The camera `distance` metres from `at`, `pitch_deg` below the horizon. `make camera-looks` poses with this directly.
static func pose_at(at: Vector3, heading: float, distance: float, pitch_deg: float) -> Transform3D:
	var tilt := deg_to_rad(clampf(pitch_deg, 1.0, 89.0))
	var back := Vector3(0.0, sin(tilt), cos(tilt)).rotated(Vector3.UP, heading) * distance
	return Transform3D(Basis.IDENTITY, at + back).looking_at(at, Vector3.UP)


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
		pitch_deg := DEFAULT_PITCH_DEG) -> bool:
	var view := RtsCamera.pose_for(at, heading, level, pitch_deg).affine_inverse()
	var tan_y := tan(deg_to_rad(FOV_DEG) / 2.0) * inset
	for p in points:
		var c: Vector3 = view * (p as Vector3)
		if c.z >= -0.1:
			return false
		if absf(c.x / -c.z) > tan_y * aspect or absf(c.y / -c.z) > tan_y:
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
	var tan_y := tan(deg_to_rad(FOV_DEG) / 2.0)
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
		if RtsCamera.shows_all(corners, start + toward * mid, heading, level, aspect, inset, pitch_deg):
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
	if _track == Track.NONE and follow_target == null and _before_overview == null \
			and _clock - _manual_at >= handback_seconds and not (_vision_state.get("frame", []) as Array).is_empty():
		track(Callable(), Track.VISION)


## Give the camera back to the commanded element right now (switching elements, not waiting out the hand-back).
func take_vision() -> void:
	if not vision.is_valid():
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
	zoom = minf(float(goal[1]), vision_zoom)
	focus = look_clamp(RtsCamera.lift(goal[0], heading_of(yaw), zoom, VISION_FRAME_LIFT))


## Shift a frame centre up the screen by `amount` of the screen's half-height, so the HUD's command card does not
## sit on top of the element. Pure: the ground moves away from the camera along its own heading.
static func lift(center: Vector3, forward: Vector3, level: float, amount: float) -> Vector3:
	var distance := RtsCamera.distance_for(level)
	return center + forward * distance * tan(deg_to_rad(FOV_DEG) / 2.0) * amount


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
