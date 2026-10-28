class_name CameraCorner
extends Node
## Round 43 (camera K5.2): rounding a building's corner, does the view swing to the side the wall was hiding? The lead,
## after round 42: "my vehicles were driving north, and a building was to the east of it, when they got past the building
## there were enemies hiding to the east. The camera was still just angled toward the building, and ideally the camera
## would have recognized the blind spot and rotated clockwise such that it ended up pointing east as well."
##
## Two halves. `lanes()` finds the staged case on any arena from its cover map (pure, for tests): a building (a
## sight-blocking feature at least MIN_WALL_M long), a lane LANE_OFFSETS_M off one long face from LEAD_IN_M before its near
## end to RUN_OUT_M past its far end, clear of every feature, and a hiding spot behind the far end on the other face that
## the lane cannot see until it is past the corner. CameraPlaytest's `--camera-scenario=corner` drives group 1 down it
## with a CPU squad parked at the hiding spot.
##
## The census (this node, per frame, from the commanded units: DangerFeed `own` / `from`): the corner OPENS when the
## first of his crews is past the wall's far end; the CORNER SECONDS run from the lead crew APPROACH_M short of it until
## WINDOW_S after it opens. Each frame of them: the bearing from the view to the side the wall is uncovering (the hidden
## face's outward normal), and whether the view FACES THE BUILDING (the ground ray from the commanded centre along the
## view crosses it within FACING_M: "still just angled toward the building"). Once: seconds from the opening to the hidden
## squad being (i) seen by his team and (ii) on screen where he could click it (CameraLook.on_screen, seen units only:
## the unseen are not drawn), and seen -> on screen. A later round's corner rule reads walls and his units only (C43.6);
## the census is the instrument and may know where the hidden squad is.

## A wall shorter than this hides no squad worth turning for (a container is ~6 m; Locks' sheds and warehouses 14 m up).
const MIN_WALL_M := 12.0
## A feature this tall or taller hides a hull from a crew (CoverMap's sight test uses EYE_HEIGHT; a tank is ~2.4 m).
const HIDE_HEIGHT_M := 2.5
## The lane: this far off the face (the first of these that works), from this far before the near end to this far past
## the far end.
const LANE_OFFSETS_M: Array[float] = [9.0, 6.0, 13.0]
const LEAD_IN_M := 15.0
const RUN_OUT_M := 35.0
## The lane must clear every other feature by this much (a hull's half width and some), and water by WATER_CLEAR_M.
const LANE_CLEAR_M := 3.5
const WATER_CLEAR_M := 4.0  # a hull's half width and some: Locks' quay lanes 6 m off the canal drive, 2 m off do not
## The hiding spot: this far off the far face (the first that works), this far back from the far end, CLEAR_M from
## everything.
const HIDE_OFFS_M: Array[float] = [10.0, 6.0, 14.0]
const HIDE_BACK_M := 6.0
const HIDE_CLEAR_M := 4.0
## The lane must not see the spot from anywhere before this far short of the corner, and must see it from the run-out.
const HIDDEN_UNTIL_M := 2.0
const SAMPLE_M := 4.0
## The census: corner seconds from APPROACH_M short of the far end to WINDOW_S after the opening; facing the building
## means the view's ground ray from his units crosses it within FACING_M.
const APPROACH_M := 15.0
const WINDOW_S := 12.0
const FACING_M := 60.0
## A hidden squad never on screen by the run's end reads this many seconds (K4's rule for a never).
const NEVER_S := 20.0

var rig: RtsCamera
var look: CameraLook
var feed: DangerFeed
var cover: CoverMap
## The staged lane (a `lanes()` entry) and the hidden squad's unit names; empty = nothing to measure.
var lane := {}
var hidden: Array = []
var keep_frames := false
var frames: Array = []

var _clock := 0.0
var _opened := -1.0
var _seen := -1.0
var _screen := -1.0
var _corner_s := 0.0
var _facing_s := 0.0
var _bearing_sum := 0.0
var _bearing_n := 0
var _toward_s := 0.0
var _away_s := 0.0
var _back_s := 0.0
var _frame := 0
## Bar K5's no-fog-cheat line (C43.6): every frame from the staging, the shown and wanted yaw at full precision and how
## many enemies his team knows. Run the same lane with and without the hidden squad (`--camera-corner-hidden=off`):
## up to the first frame either run knows an enemy, the two yaw columns must be identical (tests/camera/corner_nocheat.py).
var yaw_log: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after the rig has placed the camera this frame


## Every staged corner on this cover map, deterministic order (feature, drive way, face). Each: {feature (index),
## centre, along (the drive's unit direction), normal (the lane face's outward normal; the hidden side is -normal),
## half_len, half_w, start, end, hide (Vector2 ground points), side ("right" | "left": where the hidden face lies
## relative to the drive, his screen's words)}. Pure, for tests.
static func lanes(map: CoverMap, limit := Match.DRIVABLE_LIMIT - 6.0, water: Array = []) -> Array:
	var out: Array = []
	rejects = {}
	for wall: Dictionary in CameraCorner.walls(map):
		for way in [1.0, -1.0]:
			for face in [1.0, -1.0]:
				var why := ""
				for offset: float in LANE_OFFSETS_M:
					for hide_off: float in HIDE_OFFS_M:
						var entry := CameraCorner._lane(map, wall, way, face, offset, hide_off, limit, water)
						if entry.has("why"):
							why = String(entry["why"]) if why == "" else why
							continue
						out.append(entry)
						why = "ok"
						break
					if why == "ok":
						break
				rejects[why] = int(rejects.get(why, 0)) + 1
	return out


## Why the lanes() of the last call were dropped, by reason ("ok" = found): the dev read's diagnostic.
static var rejects := {}


## One lane down `wall` (`way` along its length, on the face `face` x its normal), `offset` off the face, the hiding spot
## `hide_off` off the far face: the lanes() entry, or {"why": the first test it failed}.
static func _lane(map: CoverMap, wall: Dictionary, way: float, face: float, offset: float, hide_off: float, limit: float,
		water: Array = []) -> Dictionary:
	var centre: Vector2 = wall["centre"]
	var half_len: float = wall["half_len"]
	var half_w: float = wall["half_w"]
	var along: Vector2 = (wall["long"] as Vector2) * way
	var normal: Vector2 = (wall["normal"] as Vector2) * face
	var line := centre + normal * (half_w + offset)
	var start := line - along * (half_len + LEAD_IN_M)
	var end := line + along * (half_len + RUN_OUT_M)
	var hide := centre - normal * (half_w + hide_off) + along * (half_len - HIDE_BACK_M)
	if not (CameraCorner._inside(start, limit) and CameraCorner._inside(end, limit) and CameraCorner._inside(hide, limit)):
		return {"why": "outside"}
	if map.path_blocked(start, end, LANE_CLEAR_M):
		return {"why": "lane_blocked"}
	if CameraCorner._wet(start, end, water, WATER_CLEAR_M) or CameraCorner._wet(hide, hide, water, HIDE_CLEAR_M):
		return {"why": "water"}
	if map.inside_any(hide, HIDE_CLEAR_M):
		return {"why": "hide_blocked"}
	if not CameraCorner._hidden_until_corner(map, line, along, half_len, hide):
		return {"why": "not_hidden"}
	# Seen from above with the drive up the screen, the hidden face (-normal) is to the right when it lies clockwise of
	# the drive: cross(along, -normal) > 0 in x/z with -Z up the screen (trip-up 2).
	var hidden_dir := -normal
	var side := "right" if along.x * hidden_dir.y - along.y * hidden_dir.x > 0.0 else "left"
	return {"feature": int(wall["index"]), "centre": centre, "along": along, "normal": normal, "half_len": half_len,
			"half_w": half_w, "start": start, "end": end, "hide": hide, "side": side, "offset": offset}


## Whether the segment a -> b comes within `grow` of any water rect (Rect2, ground x/z). The cover map knows walls, not
## the canal: Locks' right quay lanes ran 2 m off the water and his crews never reached the corner (K5.2 census, 9e14c3ade).
static func _wet(a: Vector2, b: Vector2, water: Array, grow: float) -> bool:
	var steps := maxi(1, ceili(a.distance_to(b) / 2.0))
	for rect: Rect2 in water:
		var grown := rect.grow(grow)
		for i in steps + 1:
			if grown.has_point(a.lerp(b, float(i) / float(steps))):
				return true
	return false


## The arena's water as ground rects (Arena terrain "water": rect = [centre x, centre z, size x, size z]).
static func water_of(arena: Dictionary) -> Array:
	var out: Array = []
	for zone: Dictionary in arena.get("terrain", []):
		if String(zone.get("kind", "")) != "water":
			continue
		var r: Array = zone["rect"]
		out.append(Rect2(float(r[0]) - float(r[2]) * 0.5, float(r[1]) - float(r[3]) * 0.5, float(r[2]), float(r[3])))
	return out


static var _walls: Array = []
static var _walls_of := 0


## The map's walls that can hide a squad (at least HIDE_HEIGHT_M tall and MIN_WALL_M long), each {index, centre, long
## (unit, the length), normal (unit, across it), half_len, half_w}; cached per map (a kit arena has thousands of features
## and a few dozen buildings).
static func walls(map: CoverMap) -> Array:
	if map == null:
		return []
	if _walls_of == map.get_instance_id():
		return _walls
	_walls = []
	_walls_of = map.get_instance_id()
	for index in map.features.size():
		var feature: Dictionary = map.features[index]
		if float(feature["height"]) < HIDE_HEIGHT_M:
			continue
		var axis: Vector2 = feature["axis"]
		var across := Vector2(-axis.y, axis.x)
		var half: Vector2 = feature["half"]
		if maxf(half.x, half.y) * 2.0 < MIN_WALL_M:
			continue
		_walls.append({"index": index, "centre": feature["center"], "long": axis if half.x >= half.y else across,
				"normal": across if half.x >= half.y else axis, "half_len": maxf(half.x, half.y), "half_w": minf(half.x, half.y)})
	return _walls


static func _inside(point: Vector2, limit: float) -> bool:
	return absf(point.x) <= limit and absf(point.y) <= limit


## Whether `hide` is out of sight from every lane point up to HIDDEN_UNTIL_M short of the far end, and in sight from
## somewhere on the run-out (else the corner opens onto nothing).
static func _hidden_until_corner(map: CoverMap, line: Vector2, along: Vector2, half_len: float, hide: Vector2) -> bool:
	var target := Vector3(hide.x, 0.0, hide.y)
	var t := -(half_len + LEAD_IN_M)
	while t <= half_len - HIDDEN_UNTIL_M:
		var at := line + along * t
		if map.clear_line(Vector3(at.x, 0.0, at.y), target):
			return false
		t += SAMPLE_M
	t = half_len + HIDE_BACK_M
	while t <= half_len + RUN_OUT_M:
		var at := line + along * t
		if map.clear_line(Vector3(at.x, 0.0, at.y), target):
			return true
		t += SAMPLE_M
	return false


## How far the lead of `points` (ground Vector3s) is along the lane, measured from the wall's far end (0 = at the
## corner, positive = past it). Pure.
static func lead_past(lane_entry: Dictionary, points: Array) -> float:
	var best := -INF
	var centre: Vector2 = lane_entry["centre"]
	var along: Vector2 = lane_entry["along"]
	for p: Vector3 in points:
		best = maxf(best, (Vector2(p.x, p.z) - centre).dot(along))
	return best - float(lane_entry["half_len"])


## Whether the view's ground ray from `from` at `yaw` crosses the lane's building within FACING_M. Pure (given the map).
static func faces_building(map: CoverMap, lane_entry: Dictionary, yaw: float, from: Vector3) -> bool:
	var ahead := RtsCamera.heading_of(yaw)
	var a := Vector2(from.x, from.z)
	var b := a + Vector2(ahead.x, ahead.z) * FACING_M
	return map.segment_hits(int(lane_entry["feature"]), a, b, 0.0)


func _process(delta: float) -> void:
	if rig == null or feed == null or lane.is_empty() or delta <= 0.0 or get_tree().paused:
		return
	_clock += delta
	_frame += 1
	var state := feed.read()
	yaw_log.append([_frame, game_tick(), "%.9f" % rig._shown_yaw, "%.9f" % rig.yaw, (state.get("enemies", []) as Array).size()])
	var own: Array = state.get("own", [])
	if state["from"] == null or own.is_empty():
		return
	var from: Vector3 = state["from"]
	var past := CameraCorner.lead_past(lane, own)
	if _opened < 0.0 and past > 0.0:
		_opened = _clock
	var hidden_seen := false
	var hidden_shown := false
	for unit_name: String in hidden:
		var tank := feed.game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
		if tank == null or not tank.is_alive() or not feed.can_see.is_valid() or not bool(feed.can_see.call(tank)):
			continue
		hidden_seen = true
		if look != null and look.on_screen(Shown.ground(tank)):
			hidden_shown = true
	if hidden_seen and _seen < 0.0:
		_seen = _clock
	if hidden_shown and _screen < 0.0:
		_screen = _clock
	var in_window := past >= -APPROACH_M and (_opened < 0.0 or _clock - _opened <= WINDOW_S)
	if not in_window:
		return
	var yaw := rig._shown_yaw
	var hidden_dir: Vector2 = -(lane["normal"] as Vector2)
	var bearing := CameraLook.bearing(yaw, from, from + Vector3(hidden_dir.x, 0.0, hidden_dir.y))
	var facing := cover != null and CameraCorner.faces_building(cover, lane, yaw, from)
	_corner_s += delta
	_bearing_sum += absf(bearing) * delta
	_bearing_n += 1
	if facing:
		_facing_s += delta
	if absf(bearing) <= 45.0:
		_toward_s += delta
	# The swing's cost (Bar K5's empty corner): seconds the view looks more than 90 / 135 deg off the way they drive.
	var travel: Variant = state.get("heading")
	if travel is Vector3 and (travel as Vector3).length() > 0.01:
		var off := absf(CameraLook.bearing(yaw, from, from + (travel as Vector3)))
		if off > 90.0:
			_away_s += delta
		if off > 135.0:
			_back_s += delta
	if keep_frames:
		frames.append({"t": snappedf(_clock, 0.001), "past": snappedf(past, 0.1), "bearing": snappedf(bearing, 0.1),
				"facing": facing, "seen": hidden_seen, "shown": hidden_shown})


func game_tick() -> int:
	return feed.game_match.tick if feed != null and feed.game_match != null else -1


func summary() -> Dictionary:
	var opened := _opened >= 0.0
	return {"opened": opened, "opened_s": snappedf(_opened, 0.01) if opened else null,
			"open_to_seen_s": CameraCorner._gap(_opened, _seen), "open_to_screen_s": CameraCorner._gap(_opened, _screen),
			"seen_to_screen_s": CameraCorner._gap(_seen, _screen) if _seen >= 0.0 else null,
			"seen": _seen >= 0.0, "shown": _screen >= 0.0,
			"corner_s": snappedf(_corner_s, 0.01), "facing_s": snappedf(_facing_s, 0.01), "toward_s": snappedf(_toward_s, 0.01),
			"away_s": snappedf(_away_s, 0.01), "back_s": snappedf(_back_s, 0.01), "hidden": not hidden.is_empty(),
			"mean_abs_bearing": snappedf(_bearing_sum / maxf(_corner_s, 1e-6), 0.1) if _corner_s > 0.0 else null}


# ---- K5.3: the corner pull (the rule's half; walls and his units only, C43.6) -----------------------------------------

## A squad drives ALONG a wall when its heading is within this of the wall's length...
const PULL_ALONG_DEG := 35.0
## ...and its centre is this far off the wall's face, at least and at most (beside it, not through it, not across the road).
const PULL_NEAR_M := 1.0
const PULL_FAR_M := 25.0
## The pull ramps in from the lead crew PULL_IN_M short of the far end to full at the corner, holds PULL_HOLD_M past it
## and fades out by PULL_FADE_M past: the swing starts before the hidden side opens (his "recognized the blind spot") and
## lets go once the crews are clear of it.
const PULL_IN_M := 14.0
const PULL_HOLD_M := 8.0
const PULL_FADE_M := 30.0
## Where the blind spot is: behind the far end, this far off the hidden face and this far back from the end (a squad
## parked against the back of a building sits about here; CameraCorner.lanes stages at HIDE_OFFS_M / HIDE_BACK_M).
const PULL_OFF_M := 10.0
const PULL_BACK_M := 6.0
## Only walls whose centre is this close to the squad are read (a building's half length plus PULL_FAR_M and some).
const PULL_SEARCH_M := 60.0


## The pull toward the blind spot of the wall his squad is driving along, from the cover map and his units only (never an
## enemy): {"look": the ground unit Vector3 from `from` toward the spot behind the far end, or null; "w": 0..1 the ramp;
## "feature": its index or -1; "past": metres the lead crew is past the far end}. `own` = his commanded units' ground
## points, `heading` their facing (a ground Vector3 or null). Pure, for tests.
static func pull(map: CoverMap, from: Variant, own: Array, heading: Variant) -> Dictionary:
	var out := {"look": null, "w": 0.0, "feature": -1, "past": 0.0}
	if map == null or not from is Vector3 or not heading is Vector3 or own.is_empty():
		return out
	var flat_heading := Vector2((heading as Vector3).x, (heading as Vector3).z)
	if flat_heading.length() < 0.01:
		return out
	flat_heading = flat_heading.normalized()
	var at := Vector2((from as Vector3).x, (from as Vector3).z)
	var cos_along := cos(deg_to_rad(PULL_ALONG_DEG))
	for wall: Dictionary in CameraCorner.walls(map):
		var centre: Vector2 = wall["centre"]
		if centre.distance_to(at) > PULL_SEARCH_M:
			continue
		var index: int = wall["index"]
		var long_axis: Vector2 = wall["long"]
		var normal_axis: Vector2 = wall["normal"]
		var half_len: float = wall["half_len"]
		var half_w: float = wall["half_w"]
		var dot := flat_heading.dot(long_axis)
		if absf(dot) < cos_along:
			continue
		var along := long_axis * signf(dot)
		var off := (at - centre).dot(normal_axis)
		var gap := absf(off) - half_w
		if gap < PULL_NEAR_M or gap > PULL_FAR_M:
			continue
		var normal := normal_axis * signf(off)  # the squad's face; the blind side is -normal
		var lead := -INF
		for p: Vector3 in own:
			lead = maxf(lead, (Vector2(p.x, p.z) - centre).dot(along))
		var past := lead - half_len
		var w := CameraCorner.ramp(past)
		if w <= float(out["w"]):
			continue
		var spot := centre - normal * (half_w + PULL_OFF_M) + along * (half_len - PULL_BACK_M)
		var toward := spot - at
		if toward.length() < 0.5:
			continue
		toward = toward.normalized()
		out = {"look": Vector3(toward.x, 0.0, toward.y), "w": w, "feature": index, "past": past}
	return out


## The pull's weight by how far the lead crew is past the far end (see PULL_IN_M). Pure.
static func ramp(past: float) -> float:
	if past <= -PULL_IN_M or past >= PULL_FADE_M:
		return 0.0
	if past < 0.0:
		return smoothstep(-PULL_IN_M, 0.0, past)
	if past <= PULL_HOLD_M:
		return 1.0
	return 1.0 - smoothstep(PULL_HOLD_M, PULL_FADE_M, past)


## Seconds from `a` to `b` (each a clock reading, -1 = never): never reads NEVER_S; `a` never reads null.
static func _gap(a: float, b: float) -> Variant:
	if a < 0.0:
		return null
	if b < 0.0:
		return NEVER_S
	return snappedf(maxf(b - a, 0.0), 0.01)
