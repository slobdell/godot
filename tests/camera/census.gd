extends SceneTree
## Round 46 (camera C1): what his camera showed, second by second, read from a match recording. Measurement only.
##
## For each `cam` row (once a second, and at each automatic turn) it rebuilds his camera from the recorded SHOWN pose
## (RtsCamera.pose_at: yaw, pitch, distance, ground point; his 35 deg lens; ASPECT) on the recording's arena and asks, of
## his SELECTION (the units of his last order: the recording has no selection rows, and every order is given to what
## is selected), at the nearest `census` row:
##   on      selected crews inside the frame and above the HUD's card (HUD_TOP of the half-height below centre)
##   hid     of those, how many a building hides (RtsCamera.sight_blockers on the drawn layout, rays camera -> the hull's
##           middle AND its top both blocked)
##   moving  whether the selection is driving (its middle moved > MOVING_MPS since the last census row)
##   path    the angle between where the selection drives and where the view looks (0 = down the street it drives)
##   foes    enemy crews in the frame / enemy crews within FOE_RANGE_M of the selection
##   hits    hits on his units since the last row / of those, on a unit off screen
## and, per order whose units differ from the order before (a NEW selection), the seconds until one of them is on screen.
##
##   godot --headless --path . --script res://tests/camera/census.gd -- --recording=<file.jsonl[.gz]> [--aspect=1.7778]
##         [--from=S] [--to=S]
## Lines: CENSUS_ROW {...} per cam row, CENSUS_SELECT {...} per new selection, CENSUS_TOTALS {...}, CENSUS_DONE.

const FOV_DEG := 35.0
## The command card's top, as a fraction of the half-height below centre (rts_camera.gd VISION_FRAME_BOTTOM's
## measurement at 1920x1080: y 778 -> 0.44 below centre).
const HUD_TOP := 0.44
const MOVING_MPS := 1.5
const FOE_RANGE_M := 120.0
## A building shorter than this is a wall or a container: it may hide a hull's wheels, not the vehicle.
const BLOCK_MIN_HEIGHT_M := 3.0

var _aspect := 16.0 / 9.0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func read_rows(path: String) -> Array:
	var text := ""
	if path.ends_with(".gz"):
		var bytes := FileAccess.get_file_as_bytes(path)
		text = bytes.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP).get_string_from_utf8()
	else:
		text = FileAccess.get_file_as_string(path)
	var out: Array = []
	for line in text.split("\n", false):
		var parsed: Variant = JSON.parse_string(line)
		if parsed is Dictionary:
			out.append(parsed)
	return out


## The camera at a recorded `cam` row: the shown pose, as RtsCamera draws it.
static func pose_of(cam: Dictionary) -> Transform3D:
	var at := Vector3(float(cam["target"][0]), 0.0, float(cam["target"][1]))
	return RtsCamera.pose_at(at, deg_to_rad(float(cam["yaw"])), float(cam["dist"]), float(cam["pitch"]))


## Where `point` lands on a screen of `aspect` from `pose` (x right, y up, each -1..1 at the edges), or null behind it.
static func screen_of(pose: Transform3D, point: Vector3, aspect: float, fov_deg := FOV_DEG) -> Variant:
	var local := pose.affine_inverse() * point
	if local.z > -0.1:
		return null
	var half := tan(deg_to_rad(fov_deg) / 2.0)
	return Vector2(local.x / -local.z / (half * aspect), local.y / -local.z / half)


static func on_screen(ndc: Variant, hud_top := HUD_TOP) -> bool:
	return ndc is Vector2 and absf((ndc as Vector2).x) <= 1.0 and (ndc as Vector2).y <= 1.0 and (ndc as Vector2).y >= -hud_top


## Whether buildings hide a hull standing at `ground` (its middle and its top both behind a solid) from `eye`.
static func hidden(eye: Vector3, ground: Vector3, height: float, data: Dictionary) -> bool:
	for y in [height * 0.5, height * 0.95]:
		if RtsCamera.sight_blockers(eye, ground + Vector3(0.0, y, 0.0), data, BLOCK_MIN_HEIGHT_M, true).is_empty():
			return false
	return true


func _run() -> void:
	var path := _flag("recording", "")
	_aspect = float(_flag("aspect", str(16.0 / 9.0)))
	var from_s := float(_flag("from", "0"))
	var to_s := float(_flag("to", "1e9"))
	var rows := read_rows(path)
	var rate := 30.0
	var arena := ""
	var heights := {}
	var team_of := {}
	var cams: Array = []
	var census: Array = []
	var orders: Array = []
	var hits: Array = []
	for r: Dictionary in rows:
		match String(r.get("t", "")):
			"match":
				rate = float(r.get("tick_rate", 30))
				arena = String(r.get("arena", ""))
				for unit: Dictionary in r.get("units", []):
					var hull: Array = unit.get("hull_size", [3.0, 2.5, 6.0])
					heights[unit["name"]] = minf(float(hull[1]), 4.0)
					team_of[unit["name"]] = int(unit.get("team", 0))
			"cam":
				cams.append(r)
			"census":
				census.append(r)
			"order":
				orders.append(r)
			"hit":
				hits.append(r)
	if arena == "" or cams.is_empty():
		print("CENSUS_DONE ok=false reason=%s" % ("no arena" if arena == "" else "no cam rows"))
		quit(1)
		return
	Arena.active = Arena.load_layout(arena).get("layout", {})
	RtsCamera.load_perimeter()
	var seen := RtsCamera.seen(Arena.active)
	var order_i := 0
	var census_i := 0
	var hit_i := 0
	var selection: Array = []
	var last_tick := -1
	var totals := {"rows": 0, "no_sel_on": 0, "sel_hidden_moving": 0, "moving": 0, "hits": 0, "hits_off": 0,
			"path_off_45_moving": 0}
	var pending: Array = []  # new selections waiting to come on screen: {at_s, units, order}
	var prev_middle: Variant = null
	var prev_s := 0.0
	for cam: Dictionary in cams:
		var tick := int(cam["tick"])
		var s := tick / rate
		while order_i < orders.size() and int(orders[order_i]["tick"]) <= tick:
			var units: Array = orders[order_i]["units"]
			if units != selection and not units.is_empty():
				selection = units
				pending.append({"at_s": int(orders[order_i]["tick"]) / rate, "units": units, "verb": orders[order_i]["verb"]})
			order_i += 1
		while census_i + 1 < census.size() and int(census[census_i + 1]["tick"]) <= tick:
			census_i += 1
		if census.is_empty() or tick == last_tick:
			continue
		last_tick = tick
		var pos := {}
		for u: Dictionary in census[census_i]["units"]:
			if float(u.get("hp", 0.0)) > 0.0:
				pos[u["n"]] = Vector3(float(u["pos"][0]), 0.0, float(u["pos"][1]))
		var pose := pose_of(cam)
		var eye := pose.origin
		var look := -pose.basis.z
		var alive_sel: Array = []
		var on := 0
		var hid := 0
		var middle := Vector3.ZERO
		for unit_name: String in selection:
			if not pos.has(unit_name):
				continue
			alive_sel.append(unit_name)
			middle += pos[unit_name]
			if on_screen(screen_of(pose, pos[unit_name] + Vector3(0, 1, 0), _aspect)):
				on += 1
				if hidden(eye, pos[unit_name], float(heights.get(unit_name, 2.5)), seen):
					hid += 1
		var moving := false
		var path_deg := -1.0
		if not alive_sel.is_empty():
			middle /= float(alive_sel.size())
			if prev_middle is Vector3 and s > prev_s:
				var step: Vector3 = middle - (prev_middle as Vector3)
				step.y = 0.0
				if step.length() / (s - prev_s) > MOVING_MPS:
					moving = true
					var flat_look := Vector3(look.x, 0.0, look.z).normalized()
					path_deg = rad_to_deg(flat_look.angle_to(step.normalized()))
		prev_middle = middle if not alive_sel.is_empty() else null
		prev_s = s
		var foes_on := 0
		var foes_near := 0
		for unit_name: String in pos:
			if int(team_of.get(unit_name, 0)) == 0:
				continue
			if not alive_sel.is_empty() and (pos[unit_name] as Vector3).distance_to(middle) <= FOE_RANGE_M:
				foes_near += 1
			if on_screen(screen_of(pose, pos[unit_name] + Vector3(0, 1, 0), _aspect)):
				foes_on += 1
		var hits_n := 0
		var hits_off := 0
		while hit_i < hits.size() and int(hits[hit_i]["tick"]) <= tick:
			var target := String(hits[hit_i].get("target", ""))
			if int(team_of.get(target, 1)) == 0 and pos.has(target):
				hits_n += 1
				if not on_screen(screen_of(pose, pos[target] + Vector3(0, 1, 0), _aspect)):
					hits_off += 1
			hit_i += 1
		for p: Dictionary in pending.duplicate():
			var any := false
			for unit_name: String in p["units"]:
				if pos.has(unit_name) and on_screen(screen_of(pose, pos[unit_name] + Vector3(0, 1, 0), _aspect)):
					any = true
			if any:
				print("CENSUS_SELECT " + JSON.stringify({"order_s": snappedf(float(p["at_s"]), 0.1), "verb": p["verb"],
						"units": (p["units"] as Array).size(), "on_screen_after_s": snappedf(s - float(p["at_s"]), 0.1)}))
				pending.erase(p)
			elif p != pending.back():
				print("CENSUS_SELECT " + JSON.stringify({"order_s": snappedf(float(p["at_s"]), 0.1), "verb": p["verb"],
						"units": (p["units"] as Array).size(), "on_screen_after_s": -1, "replaced_s": snappedf(s, 0.1)}))
				pending.erase(p)
		if s < from_s or s > to_s:
			continue
		totals["rows"] += 1
		if not alive_sel.is_empty() and on == 0:
			totals["no_sel_on"] += 1
		if moving:
			totals["moving"] += 1
			if on > 0 and hid == on:
				totals["sel_hidden_moving"] += 1
			if path_deg > 45.0:
				totals["path_off_45_moving"] += 1
		totals["hits"] += hits_n
		totals["hits_off"] += hits_off
		print("CENSUS_ROW " + JSON.stringify({"s": snappedf(s, 0.1), "sel": alive_sel.size(), "on": on, "hid": hid,
				"moving": moving, "path_deg": roundi(path_deg), "foes_on": foes_on, "foes_near": foes_near,
				"hits": hits_n, "hits_off": hits_off, "yaw": cam["yaw"], "dist": cam["dist"], "pitch": cam["pitch"],
				"mode": cam["mode"], "mid": [snappedf(middle.x, 1), snappedf(middle.z, 1)]}))
	print("CENSUS_TOTALS " + JSON.stringify(totals))
	print("CENSUS_DONE ok=true")
	quit(0)
