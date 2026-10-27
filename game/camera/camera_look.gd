class_name CameraLook
extends Node
## Round 42 (camera K4.1): does the view look where the danger is? The lead: "if the camera is following the direction at
## which a squad is moving, and then there's an ambush from the east (assuming we're driving north), the camera doesn't
## end up pointing at the action ... when the camera is pointing outward it's a little impractical." His retreat case:
## "a group of scouts drive back behind my own lines to the edge of the map, and the camera pointed out completely to the
## audience."
##
## Per frame, from the commanded units (DangerFeed `from`), the bearing (degrees, 0 = straight up the screen) from the
## view's yaw to: the nearest enemy firing at them, the centre of the known enemies, and the arena's middle. And what he
## sees: whether any shooter, and any known enemy, is on screen (projected through the real camera, inside SCREEN_MARGIN_PX
## and above the HUD: somewhere he could click it). Its summary:
##   under_fire_s  seconds some known enemy fired at the commanded units within FIRING_S
##   blind_s       of those, seconds with NO known enemy on screen (the ambush from the east)
##   wall_s        seconds facing the wall: the arena's middle more than 90 deg off the view's direction while the
##                 commanded units are WALL_FROM_M or more from it (his retreat case)
##   latencies     each episode of a shooter firing at them from off screen: seconds until it is first on screen (null =
##                 never, by the end of the run)
##   own_shown_s   seconds x the fraction of the commanded units on screen and not behind an uncut wall (a danger
##                 turn must not lose his own squad)
##   inside_s      seconds the camera itself sat inside a solid (the building clearance easing in too slowly)
##   yaw_reversals the view's turn changing direction after at least REVERSAL_DEG each way (a swinging camera)
## CameraTrace attaches it with the trace; the playtest gives it the feed once the controls exist.

## "Firing at us" = a round at the commanded units within this many seconds.
const FIRING_S := 3.0
## Facing the wall only counts this far from the middle (near the middle every direction is "toward" it).
const WALL_FROM_M := 30.0
## A turn counts as a reversal only after the yaw went at least this far one way, then this far back (hysteresis).
const REVERSAL_DEG := 5.0
## On screen = inside this margin of the viewport and above the HUD's top (CameraPlaytest._aimable's rule).
const SCREEN_MARGIN_PX := 60.0

var rig: RtsCamera
var feed: DangerFeed
var keep_frames := false
var frames: Array = []
var episodes: Array = []

var _clock := 0.0
var _play_s := 0.0
var _under_fire_s := 0.0
var _blind_s := 0.0
var _wall_s := 0.0
var _own_shown_s := 0.0
var _inside_s := 0.0
var _bearings := {"shooter": [], "centroid": [], "middle": []}
var _open := {}  # shooter name -> its open episode
var _reversals := 0
var _turn_anchor := NAN
var _turn_sign := 0
var _last_fired := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after the rig has placed the camera this frame


func _process(delta: float) -> void:
	if rig == null or feed == null or rig.camera == null or delta <= 0.0 or get_tree().paused:
		return
	_clock += delta
	var state := feed.read()
	_count_reversal(rad_to_deg(rig._shown_yaw))
	if not RtsCamera.solid_at(rig.camera.global_position).is_empty():
		_inside_s += delta  # the building clearance's job: never sit inside a solid
	if state["from"] == null:
		return
	_play_s += delta
	var from: Vector3 = state["from"]
	var yaw := rig._shown_yaw
	var own: Array = state.get("own", [])
	var own_shown := own.filter(func(at: Vector3) -> bool: return on_screen(at) and not wall_hides(at))
	if not own.is_empty():
		_own_shown_s += delta * float(own_shown.size()) / float(own.size())
	var any_on_screen := false
	var firing: Array = []
	var centroid := Vector3.ZERO
	var known := 0
	for enemy: Dictionary in state["enemies"]:
		centroid += enemy["at"]
		known += 1
		var shown := bool(enemy["seen"]) and on_screen(enemy["at"])
		enemy["on_screen"] = shown
		any_on_screen = any_on_screen or shown
		if float(enemy["fired_s"]) <= FIRING_S:
			firing.append(enemy)
	var row := {"t": snappedf(_clock, 0.01)}
	if not firing.is_empty():
		_under_fire_s += delta
		if not any_on_screen:
			_blind_s += delta
		firing.sort_custom(func(one: Dictionary, other: Dictionary) -> bool:
			return from.distance_to(one["at"]) < from.distance_to(other["at"]))
		var b := CameraLook.bearing(yaw, from, firing[0]["at"])
		_bearings["shooter"].append(absf(b))
		row["shooter"] = snappedf(b, 0.1)
	if known > 0:
		var b := CameraLook.bearing(yaw, from, centroid / float(known))
		_bearings["centroid"].append(absf(b))
		row["centroid"] = snappedf(b, 0.1)
	var middle: Vector3 = state["middle"]
	if CameraLook.facing_wall(yaw, from, middle):
		_wall_s += delta
		row["facing_wall"] = true
	if from.distance_to(middle) >= WALL_FROM_M:
		var b := CameraLook.bearing(yaw, from, middle)
		_bearings["middle"].append(absf(b))
		row["middle"] = snappedf(b, 0.1)
	_track_episodes(state["enemies"], from)
	if keep_frames:
		var eye := rig.camera.global_position
		row["cam"] = [snappedf(eye.x, 0.1), snappedf(eye.y, 0.1), snappedf(eye.z, 0.1), snappedf(rad_to_deg(yaw), 0.1)]
		row["from"] = [snappedf(from.x, 0.1), snappedf(from.z, 0.1)]
		row["own"] = "%d/%d" % [own_shown.size(), own.size()]
		row["near"] = snappedf(rig.camera.near, 0.01)
		var f := rig._shown_focus
		row["focus"] = [snappedf(f.x, 0.1), snappedf(f.z, 0.1)]
		row["boom"] = [snappedf(RtsCamera.distance_for(rig._shown_zoom), 0.1), snappedf(rig.lifted_deg, 0.1),
				snappedf(RtsCamera.tilt_at(rig._shown_pitch, RtsCamera.distance_for(rig._shown_zoom)), 0.1)]
		var fhit := RtsCamera.perimeter_crossing(Vector2(f.x, f.z), Vector2(sin(yaw), cos(yaw)))
		row["fwall"] = snappedf(float(fhit.get("reach", -1.0)), 0.1)
		row["profile"] = str(RtsCamera.stands_profile())
		var hit := RtsCamera.perimeter_crossing(Vector2(from.x, from.z), Vector2(sin(yaw), cos(yaw)))
		row["wall"] = [snappedf(float(hit.get("reach", -1.0)), 0.1), str(hit.get("kind", "")), float(hit.get("wall_height_m", 0.0))]
		row["blocked"] = own.filter(func(at: Vector3) -> bool:
			return RtsCamera.sight_blocked(eye, at + Vector3.UP, RtsCamera.seen(), 0.0)).size()
		frames.append(row)


## A shooter firing at the commanded units from off screen opens an episode; it closes the first frame it is on screen.
func _track_episodes(enemies: Array, from: Vector3) -> void:
	for enemy: Dictionary in enemies:
		var key: String = enemy["name"]
		var fired_at := feed.now() - float(enemy["fired_s"])
		var new_shot := float(enemy["fired_s"]) <= FIRING_S and fired_at > float(_last_fired.get(key, -DangerFeed.NEVER))
		if new_shot:
			_last_fired[key] = fired_at
		if _open.has(key):
			if enemy["on_screen"]:
				var episode: Dictionary = _open[key]
				episode["latency_s"] = snappedf(_clock - float(episode["t"]), 0.01)
				_open.erase(key)
		elif new_shot and not enemy["on_screen"]:
			var episode := {"shooter": key, "t": snappedf(_clock, 0.01), "latency_s": null,
					"bearing": snappedf(CameraLook.bearing(rig._shown_yaw, from, enemy["at"]), 0.1)}
			episodes.append(episode)
			_open[key] = episode


func _count_reversal(yaw_deg: float) -> void:
	if is_nan(_turn_anchor):
		_turn_anchor = yaw_deg
		return
	var moved := angle_difference(deg_to_rad(_turn_anchor), deg_to_rad(yaw_deg))
	var moved_deg := rad_to_deg(moved)
	if absf(moved_deg) < REVERSAL_DEG:
		return
	var turn := int(signf(moved_deg))
	if _turn_sign != 0 and turn != _turn_sign:
		_reversals += 1
	_turn_sign = turn
	_turn_anchor = yaw_deg


## Whether a ground point is on screen where he could click it: in front of the camera, inside the margin, above the HUD.
func on_screen(point: Vector3) -> bool:
	var camera := rig.camera
	if camera.get_viewport() == null or camera.is_position_behind(point):
		return false
	var size := camera.get_viewport().get_visible_rect().size
	var floor_y := size.y * 0.72
	if rig.hud_bottom.is_valid():
		var top: float = rig.hud_bottom.call()
		if top > 0.0:
			floor_y = top - 20.0
	var at := camera.unproject_position(point)
	return at.x > SCREEN_MARGIN_PX and at.x < size.x - SCREEN_MARGIN_PX and at.y > SCREEN_MARGIN_PX and at.y < floor_y


## Whether the perimeter wall stands between the camera and his unit at `at` and the cutaway has not cut it: the sight
## line from the camera to the unit's middle (1 m up) crosses the wall's inner face lower than the wall's top, and that
## crossing is in front of the near plane. (Seed 7005, the first retreat clip: a scout parked at his own wall, looked at
## from 80 m outside it, was "on screen" by projection and invisible behind the wall.)
func wall_hides(at: Vector3) -> bool:
	var eye := rig.camera.global_position
	var flat := Vector2(eye.x - at.x, eye.z - at.z)
	if flat.length() < 0.5:
		return false
	var hit := RtsCamera.perimeter_crossing(Vector2(at.x, at.z), flat.normalized())
	if hit.is_empty() or float(hit["reach"]) >= flat.length():
		return false  # the camera is inside the wall: nothing of it stands between
	var t := float(hit["reach"]) / flat.length()
	var crossing := at + Vector3.UP + (eye - at - Vector3.UP) * t
	var height := float(hit.get("wall_height_m", RtsCamera.WALL_HEIGHT_M))
	if crossing.y >= height:
		return false
	# The cutaway cuts at the wall's TOP edge (RtsCamera._cut); seen from outside, the face below it is the inner face,
	# turned away and culled. So the wall still hides him only where the cut has not reached its top.
	var top := Vector3(crossing.x, height, crossing.z)
	return (top - eye).dot(-rig.camera.global_basis.z) > rig.camera.near


func summary() -> Dictionary:
	var latencies: Array = []
	var never := 0
	for episode: Dictionary in episodes:
		if episode["latency_s"] == null:
			never += 1
		else:
			latencies.append(float(episode["latency_s"]))
	var means := {}
	for key: String in _bearings:
		var values: Array = _bearings[key]
		means[key] = snappedf(values.reduce(func(s: float, v: float) -> float: return s + v, 0.0) / maxf(values.size(), 1), 0.1)
	return {"play_s": snappedf(_play_s, 0.01), "under_fire_s": snappedf(_under_fire_s, 0.01), "blind_s": snappedf(_blind_s, 0.01),
			"wall_s": snappedf(_wall_s, 0.01), "own_shown_s": snappedf(_own_shown_s, 0.01), "inside_s": snappedf(_inside_s, 0.01), "episodes": episodes.size(), "never": never, "latencies": latencies,
			"mean_abs_bearing": means, "yaw_reversals": _reversals, "minutes": snappedf(_clock / 60.0, 0.001)}


## The signed angle (degrees, positive = to the LEFT, as positive yaw turns: trip-up 2) from the view's direction at
## `yaw` to the ground point `to`, seen from `from`. 0 = straight up the screen, +-180 = behind. Pure, for tests.
static func bearing(yaw: float, from: Vector3, to: Vector3) -> float:
	var flat := Vector3(to.x - from.x, 0.0, to.z - from.z)
	if flat.length() < 1e-4:
		return 0.0
	return rad_to_deg(angle_difference(yaw, RtsCamera.yaw_facing(flat)))


## Facing the wall: the arena's middle is behind the view (more than 90 deg off) and the units are far from it. Pure.
static func facing_wall(yaw: float, from: Vector3, middle: Vector3) -> bool:
	return from.distance_to(middle) >= WALL_FROM_M and absf(CameraLook.bearing(yaw, from, middle)) > 90.0
