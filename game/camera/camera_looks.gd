class_name CameraLooks
extends Node
## Control X3 (round 6's lead gate): the same moment of the same fight, photographed from a grid of camera poses, so
## the lead can point at the look he means by "somewhere between StarCraft 2 and Twisted Metal" instead of the stream
## guessing at it. `make camera-looks` runs it; the page it writes is `index.html` beside the frames.
##
## How: both sides are CPU armies (so there is a fight without anyone ordering it); when the first shot is fired it
## waits HOLD_AFTER_CONTACT_S for the fight to develop, freezes the match (the tree pause), aims at the player's vehicle
## nearest the enemy, and takes one frame per pose. The rig is switched off while it shoots, so nothing re-aims between
## frames. Every frame is the same instant: only the camera changes.
##
## The grid is pitch (degrees below the horizon) × distance (metres from the focus) × field of view, plus a row of
## round 5's welded poses (the tilt followed the zoom from 25° to 82°) - what the lead actually played.

const PITCHES := [25.0, 35.0, 45.0, 60.0]
const DISTANCES := [28.0, 50.0, 90.0]
const FOVS := [45.0, 60.0]
## Round 5's poses, as zoom levels: close, the skirmish start, a squad-sized view, and an army-sized view.
const WELDED_LEVELS := [0.2, 0.36, 0.55, 0.75]
## Seconds of fighting after the first shot before the picture is taken.
const HOLD_AFTER_CONTACT_S := 6.0
## If nobody has fired by then, shoot anyway (the page says so).
const GIVE_UP_S := 90.0
## The player's vehicles this close to the one nearest the enemy count as "the element in the fight" for the focus.
const CLUSTER_M := 40.0
const JPG_QUALITY := 0.86

var game_match: Match
var rig: RtsCamera
var camera: Camera3D
var out_dir := ""
var team := Match.Team.GREEN
## Recorded on the page and in looks.json, so the moment can be re-shot.
var seed_value := -1
## "full" = the whole grid; "arena" = three frames for the arena tour (round 5's start pose, the new default, the
## overview), which `make camera-looks` takes on every arena first and the full page then shows in one row per arena.
var grid := "full"
## The grid's axes (`--camera-looks-pitches=15,20,25` etc. override them, for a follow-up page around a pick).
var pitches: Array = PITCHES.duplicate()
var distances: Array = DISTANCES.duplicate()
var fovs: Array = FOVS.duplicate()
## Round 5's welded row: off for a follow-up page, where it has already been seen.
var show_today := true

var _first_shot_at := -1.0
var _clock := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game_match.weapon_fired.connect(_on_fired)


func _on_fired(_event: Dictionary) -> void:
	if _first_shot_at < 0.0:
		_first_shot_at = _clock


func _physics_process(delta: float) -> void:
	if not get_tree().paused:
		_clock += delta


## The whole session: wait for the fight, freeze it, photograph it from every pose, write the page, quit.
func run() -> void:
	DirAccess.make_dir_recursive_absolute(out_dir)
	while _clock < GIVE_UP_S and (_first_shot_at < 0.0 or _clock < _first_shot_at + HOLD_AFTER_CONTACT_S):
		await get_tree().physics_frame
	var contact := _first_shot_at >= 0.0
	get_tree().paused = true
	rig.set_process(false)
	var focus := CameraLooks.fight_focus(game_match, team)
	var heading := CameraLooks.facing_the_enemy(game_match, team, focus)
	var frames: Array = []
	if grid == "arena":
		frames.append(await _shoot("round5", focus, heading, RtsCamera.distance_for(0.36), RtsCamera.welded_pitch(0.36),
				RtsCamera.FOV_DEG, {"row": "arena", "label": "round 5's start"}))
		frames.append(await _shoot("default", focus, heading, RtsCamera.distance_for(0.36), RtsCamera.DEFAULT_PITCH_DEG,
				RtsCamera.FOV_DEG, {"row": "arena", "label": "new default"}))
		frames.append(await _shoot("overview", Vector3.ZERO, Match.team_frame(team)["forward"].angle_to(Vector3.FORWARD),
				RtsCamera.distance_for(RtsCamera.OVERVIEW_ZOOM), RtsCamera.OVERVIEW_PITCH_DEG, RtsCamera.FOV_DEG,
				{"row": "arena", "label": "overview (O)"}))
		# Round 8: the cutaway against the arena's own walls, diagonals included (the hexagon was the first non-square
		# wall it met). Half the edges - the perimeter is 180-degree symmetric - each at the lead's pose (21 deg, 49 m,
		# FOV 35), focused 20 m inside the edge's middle with the camera out beyond the wall looking in.
		var poly := RtsCamera.perimeter_poly
		for k in poly.size() / 2 if poly.size() >= 4 else 0:
			var a2: Vector2 = poly[k]
			var b2: Vector2 = poly[(k + 1) % poly.size()]
			var middle := (a2 + b2) / 2.0
			var outward := middle.normalized()  # regular and centred: the edge's normal points away from the centre
			var at := Vector3(middle.x, 0.0, middle.y) - Vector3(outward.x, 0.0, outward.y) * 20.0
			frames.append(await _shoot("wall%d" % k, at, atan2(outward.x, outward.y), 49.0, RtsCamera.DEFAULT_PITCH_DEG,
					RtsCamera.FOV_DEG, {"row": "arena", "label": "behind wall %d" % k}))
	for level: float in (WELDED_LEVELS if grid == "full" and show_today else []):
		var distance := RtsCamera.distance_for(level)
		var pitch := RtsCamera.welded_pitch(level)
		frames.append(await _shoot("today_z%02d" % roundi(level * 100.0), focus, heading, distance, pitch, RtsCamera.FOV_DEG,
				{"row": "today", "zoom": level}))
	for fov: float in (fovs if grid == "full" else []):
		for pitch: float in pitches:
			for distance: float in distances:
				frames.append(await _shoot("p%02d_d%03d_f%02d" % [roundi(pitch), roundi(distance), roundi(fov)], focus, heading,
						distance, pitch, fov, {"row": "grid"}))
	var meta := {"pitches": pitches, "distances": distances, "fovs": fovs, "seed": seed_value, "arena": String(Arena.active.get("name", "")),
			"contact": contact, "seconds_in": snappedf(_clock, 0.1),
			"first_shot_s": snappedf(_first_shot_at, 0.1), "focus": [snappedf(focus.x, 0.1), snappedf(focus.z, 0.1)],
			"heading_deg": snappedf(rad_to_deg(heading), 0.1), "window": [get_viewport().get_visible_rect().size.x,
			get_viewport().get_visible_rect().size.y], "frames": frames,
			"arena_title": String(Arena.active.get("title", "")), "arena_note": String(Arena.active.get("note", "")),
			"arenas": CameraLooks.arena_tour(out_dir.path_join("arenas"))}
	var json := FileAccess.open(out_dir.path_join("looks.json"), FileAccess.WRITE)
	json.store_string(JSON.stringify(meta, "  "))
	json.close()
	var page := FileAccess.open(out_dir.path_join("index.html"), FileAccess.WRITE)
	page.store_string(CameraLooks.page(meta))
	page.close()
	print("CAMERA_LOOKS_DONE ok=%s frames=%d contact=%s at=%.1fs dir=%s" % [str(frames.size() > 0).to_lower(), frames.size(),
			str(contact).to_lower(), _clock, out_dir])
	get_tree().quit(0)


func _shoot(shot_name: String, focus: Vector3, heading: float, distance: float, pitch: float, fov: float,
		extra: Dictionary) -> Dictionary:
	camera.fov = fov
	camera.global_transform = RtsCamera.pose_at(focus, heading, distance, pitch)
	# The rig's wall cutaway (X3), so a low pose near the wall shows what the game would show.
	camera.near = RtsCamera.cutaway_near(focus, heading, distance, pitch, RtsCamera.perimeter_half())
	# Two drawn frames: the first can still carry the last pose's shadow cascades and the HUD's last layout.
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var file := shot_name + ".jpg"
	if image != null and not image.is_empty():
		image.save_jpg(out_dir.path_join(file), JPG_QUALITY)
	var info := {"file": file, "pitch": pitch, "distance": snappedf(distance, 0.1), "fov": fov,
			"height": snappedf(distance * sin(deg_to_rad(pitch)), 0.1)}
	info.merge(extra)
	return info


## Where to look: the middle of the player's vehicles within CLUSTER_M of whichever of them is nearest an enemy - the
## element that is in the fight. Pure, for tests.
static func fight_focus(p_match: Match, p_team: int) -> Vector3:
	var ours := p_match.sorted_team_tanks(p_team).filter(func(t: Tank) -> bool: return t.is_alive())
	var theirs := p_match.sorted_team_tanks(Match.Team.RUST if p_team == Match.Team.GREEN else Match.Team.GREEN) \
			.filter(func(t: Tank) -> bool: return t.is_alive())
	if ours.is_empty():
		return Vector3.ZERO
	var nearest: Tank = ours[0]
	var best := INF
	for tank: Tank in ours:
		for enemy: Tank in theirs:
			var gap := tank.global_position.distance_to(enemy.global_position)
			if gap < best:
				best = gap
				nearest = tank
	var sum := Vector3.ZERO
	var count := 0
	for tank: Tank in ours:
		if tank.global_position.distance_to(nearest.global_position) <= CLUSTER_M:
			sum += tank.global_position
			count += 1
	var middle := sum / maxf(float(count), 1.0)
	return Vector3(middle.x, 0.0, middle.z)


## The camera's yaw (RtsCamera convention) that puts the camera behind `focus` looking at the nearest enemies' middle,
## so the frame reads "ours in front, theirs beyond". Falls back to the team's forward.
static func facing_the_enemy(p_match: Match, p_team: int, focus: Vector3) -> float:
	var theirs := p_match.sorted_team_tanks(Match.Team.RUST if p_team == Match.Team.GREEN else Match.Team.GREEN) \
			.filter(func(t: Tank) -> bool: return t.is_alive())
	var toward: Vector3 = Match.team_frame(p_team)["forward"]
	if not theirs.is_empty():
		theirs.sort_custom(func(a: Tank, b: Tank) -> bool:
			return a.global_position.distance_squared_to(focus) < b.global_position.distance_squared_to(focus))
		var sum := Vector3.ZERO
		var count := mini(5, theirs.size())
		for i in count:
			sum += (theirs[i] as Tank).global_position
		var direction := sum / float(count) - focus
		direction.y = 0.0
		if direction.length() > 1.0:
			toward = direction.normalized()
	# yaw 0 looks north (-Z); positive yaw turns left (trip-up 2).
	return atan2(-toward.x, -toward.z)


## The arena tour's readings: every `arenas/<name>/looks.json` under `dir`, with frame paths made relative to the page.
static func arena_tour(dir: String) -> Array:
	var result: Array = []
	if not DirAccess.dir_exists_absolute(dir):
		return result  # get_directories_at logs an engine ERROR for a missing folder
	for arena_name in DirAccess.get_directories_at(dir):
		var text := FileAccess.get_file_as_string(dir.path_join(arena_name).path_join("looks.json"))
		var data: Variant = JSON.parse_string(text) if text != "" else null
		if not data is Dictionary:
			continue
		for frame: Dictionary in data["frames"]:
			frame["file"] = "arenas/%s/%s" % [arena_name, frame["file"]]
		result.append(data)
	return result


## The review page: round 5's poses first, then one table per field of view, pitch down the side and distance across.
## Plain HTML beside the frames, so it opens from disk and publishes as it is.
static func page(meta: Dictionary) -> String:
	var frames: Array = meta["frames"]
	var html := PackedStringArray()
	html.append("<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">")
	html.append("<title>Camera looks</title><style>")
	html.append(":root{--bg:#101318;--fg:#e8ecf1;--muted:#98a2b0;--line:#2a313b;--accent:#ffd34d}")
	html.append("@media (prefers-color-scheme: light){:root:not([data-theme=dark]){--bg:#f6f7f9;--fg:#15191f;--muted:#5b6573;--line:#d5dae1;--accent:#8a6400}}")
	html.append("body{margin:0;padding:16px;background:var(--bg);color:var(--fg);font:15px/1.45 system-ui,sans-serif}")
	html.append("h1{font-size:22px;margin:0 0 4px}h2{font-size:17px;margin:28px 0 8px}p{max-width:70ch;color:var(--muted)}")
	html.append(".row{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:10px}")
	html.append("figure{margin:0}img{width:100%;display:block;border:1px solid var(--line);border-radius:4px}")
	html.append("figcaption{font-size:13px;color:var(--muted);padding:4px 2px}figcaption b{color:var(--accent)}")
	html.append("table{border-collapse:collapse;width:100%}td,th{padding:4px;vertical-align:top}th{font-size:13px;color:var(--muted);text-align:left}")
	html.append("@media (max-width:700px){table,tbody,tr,td,th{display:block}th:empty{display:none}}")
	html.append("</style></head><body>")
	html.append("<h1>Camera looks</h1>")
	html.append("<p>One frozen moment of a 30-a-side fight (arena <b>%s</b>, %s), photographed from every pose. Only the camera changes. Pick the frame closest to \"between StarCraft 2 and Twisted Metal\" - its label is all the game needs.</p>"
			% [meta.get("arena", "?"), "%.0f s after the first shot" % (float(meta.get("seconds_in", 0.0)) - float(meta.get("first_shot_s", 0.0)))
				if bool(meta.get("contact", false)) else "no shot fired yet"])
	html.append("<h2>What you played in round 5</h2><p>Zooming out also tilted the camera toward top-down (25° to 82°): the same slider did both.</p><div class=\"row\">")
	for frame: Dictionary in frames:
		if frame.get("row", "") == "today":
			html.append("<figure><img loading=\"lazy\" src=\"%s\" alt=\"\"><figcaption><b>zoom %.2f</b> · pitch %.0f° · %.0f m out · FOV %.0f°</figcaption></figure>"
					% [frame["file"], float(frame["zoom"]), float(frame["pitch"]), float(frame["distance"]), float(frame["fov"])])
	html.append("</div>")
	for fov: float in meta.get("fovs", FOVS):
		html.append("<h2>Field of view %.0f°</h2><p>Rows: pitch below the horizon. Columns: distance from the fight.</p><table><tr><th></th>" % fov)
		for distance: float in meta.get("distances", DISTANCES):
			html.append("<th>%.0f m out</th>" % distance)
		html.append("</tr>")
		for pitch: float in meta.get("pitches", PITCHES):
			html.append("<tr><th>%.0f°</th>" % pitch)
			for frame: Dictionary in frames:
				if frame.get("row", "") == "grid" and float(frame["pitch"]) == pitch and float(frame["fov"]) == fov:
					html.append("<td><figure><img loading=\"lazy\" src=\"%s\" alt=\"\"><figcaption><b>%s</b> · %.0f m up</figcaption></figure></td>"
							% [frame["file"], String(frame["file"]).get_basename(), float(frame["height"])])
			html.append("</tr>")
		html.append("</table>")
	var arenas: Array = meta.get("arenas", [])
	if not arenas.is_empty():
		html.append("<h2>Every arena</h2><p>The same kind of moment on each arena (6 s after its first shot): round 5's starting camera, the new default (38°), and the overview. Which of these is fun to fight on?</p>")
		for arena: Dictionary in arenas:
			html.append("<h2>%s</h2><p>%s</p><div class=\"row\">" % [String(arena.get("arena_title", arena.get("arena", ""))),
					String(arena.get("arena_note", ""))])
			for frame: Dictionary in arena["frames"]:
				html.append("<figure><img loading=\"lazy\" src=\"%s\" alt=\"\"><figcaption><b>%s</b> · pitch %.0f°</figcaption></figure>"
						% [frame["file"], frame.get("label", ""), float(frame["pitch"])])
			html.append("</div>")
	html.append("</body></html>")
	return "\n".join(html)
