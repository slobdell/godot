extends SceneTree
## `make airship-view` (round 14, A1): the lead's *"frequently when we're playing the airship flies right in front of
## the camera and disrupting the game"*, measured with the camera he actually has.
##
## `make airship-report` answers "is it in frame" for four FIXED camera yaws round a fixed fight. His camera is none of
## those: it follows his selection, turns with the squad's facing, and lifts itself over the hull. So this builds a
## real skirmish through `main.tscn` (the live RtsCamera, vision framing, yaw follow, the camera's hull lift, the live
## airship) and drives it the way he does: every DRIVE_EVERY_S it recalls the next living group and attack-moves it at
## the nearest enemy (or the far base), and the vision camera frames that group. Per SIMULATION tick it asks where the
## drawn hull box (`SyndicateAdAirship.camera_occluder`) is against the camera's frustum:
##   * **frame %**   -- any of the hull inside the frustum: he can see it (the ship he wants in the venue);
##   * **hides_fight %** -- the hull box cuts any of the sight lines from the camera to the fight he is looking at
##                      (`AirshipSight.hidden`: a 3x3 grid over the aimed ground). **The disruptive case**, his complaint
##                      as a number, and the same function the pilot's view term avoids;
##   * **intrusions** -- runs of those ticks: how many, the longest (s), and the mean;
##   * **hidden_while / cover %** -- while it hides the fight: the share of the grid it hides, and the share of the
##                      screen its projected box spans (an upper bound: a box, not the silhouette);
##   * **yaw** -- the hull's mean |yaw rate| (A4: the stately figure is 8.5 deg/s).
##   * **visible %** (round 21) -- in frame AND some of the hull has a clear line of sight from the lens through the
##                      arena's colliders (`_line_of_sight`): frame % ignores the blocks standing in the way.
## The three worst moments (most cover while between) are saved as frames when there is a display.
##
## Round 15 (B1): `--airship-view-trace` also writes `trace_<map>_<arm>.csv`, one row per simulation tick (the camera,
## where it aims, the hull, its height and the height the plan wants, the action, whether the view term asks for a
## climb NOW, the intrusion state, and the driver's order ticks), so an intrusion can be read back tick by tick
## (`tools/airship_view_pool.py --trace`).
##
## Flags (after `--`, with any skirmish flag): --airship-view=<abs dir>  --airship-view-seconds=240. The arm switch is
## the airship's own (`--airship-off=viewavoid`), so one build runs both arms. Prints AIRSHIP_VIEW lines and
## AIRSHIP_VIEW_DONE.

const MAIN := "res://game/main.tscn"
const SIZE := Vector2i(1280, 720)
## How often the driver gives the next group an order, seconds of match time.
const DRIVE_EVERY_S := 12.0
## How far back an intrusion's cause is judged: 3 s.
const LOOK_BACK := 90

var out := ""
var seconds := 240.0
var main: Node
var controls: RtsControls
var ship: SyndicateAdAirship
var _next_group := 1
var _worst: Array = []  # [{cover, tick, file}]
var _display := false
var _trace: FileAccess
## The group the driver ordered on this tick (0: none), for the trace.
var _ordered := 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--airship-view="):
			out = arg.trim_prefix("--airship-view=")
		elif arg.begins_with("--airship-view-seconds="):
			seconds = float(arg.trim_prefix("--airship-view-seconds="))
	if out == "":
		push_error("airship-view: --airship-view=<dir> is required")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	_display = DisplayServer.get_name() != "headless"
	root.size = SIZE
	main = (load(MAIN) as PackedScene).instantiate()
	root.add_child(main)
	current_scene = main
	for i in 900:
		controls = main.find_child("TacticalMap", true, false) as RtsControls
		ship = main.find_child("SyndicateAdAirship", true, false) as SyndicateAdAirship
		if controls != null and ship != null and controls.game_match != null:
			break
		await process_frame
	if controls == null or ship == null:
		print("AIRSHIP_VIEW_FAILED controls=%s airship=%s (a skirmish on a real map, not LOW quality?)" % [controls != null, ship != null])
		quit(1)
		return
	var game_match: Match = controls.game_match
	ship.follow_match(game_match)
	if OS.get_cmdline_user_args().has("--airship-view-trace"):
		_trace = FileAccess.open(out.path_join("trace_%s_%s.csv" % [String(Arena.active.get("name", "map")), _arm()]), FileAccess.WRITE)
		_trace.store_line("tick,cam_x,cam_y,cam_z,cam_yaw_deg,aim_x,aim_z,hull_x,hull_z,heading_deg,alt,wanted,view_need_now,"
				+ "action_x,action_z,orbit,in_frame,hidden,order,groups,"
				+ "need_live,frame_at_cruise,hidden_at_cruise")
	# The driver is not a mouse: with a display (builder0's desktop, a window that may have focus and a pointer parked
	# at an edge) the rig's edge-pan would drive the camera on its own. Round 15 B3: the rendered runs showed the camera
	# moving 75-95 m onto the hull where the headless runs never did; suspected, not proven, and now impossible.
	if controls.rig != null:
		controls.rig.edge_pan = false
	for i in 3:
		await create_timer(0.5, true, false, true).timeout
		if paused:
			controls.set_paused(false, "")
	var counts := {"n": 0, "frame": 0, "between": 0, "cover": 0.0, "hidden": 0.0, "yaw": 0.0, "inside": 0, "visible": 0}
	var runs: Array[int] = []
	var run := 0
	var last_tick := game_match.tick
	var start_tick := game_match.tick
	var end_tick := start_tick + int(seconds * SimClock.TICK_RATE)
	var next_order := start_tick
	var stalled := 0
	var history: Array = []  # [camera Transform3D, hull box], last LOOK_BACK ticks
	var causes := {"camera": 0, "hull": 0, "both": 0}
	while game_match.tick < end_tick and is_instance_valid(ship):
		await process_frame
		if paused:
			controls.set_paused(false, "")
		var tick := game_match.tick
		if tick == last_tick:
			# A match that has ENDED stops ticking, and the first version of this loop then waited forever (a 20-minute
			# timeout on builder0 with nothing printed). Said, and the run stops.
			stalled += 1
			if stalled > 600:
				print("AIRSHIP_VIEW_STALLED at tick %d of %d: the match stopped ticking (did it end? run with --tune=match.no_damage=1 --no-control)" % [
						tick, end_tick])
				break
			continue
		stalled = 0
		ship.advance_to(tick)  # headless there is no FxWorld to drive it; with one, this is a no-op
		last_tick = tick
		_ordered = 0
		if tick >= next_order:
			_drive(game_match)
			next_order = tick + int(DRIVE_EVERY_S * SimClock.TICK_RATE)
		var camera := root.get_viewport().get_camera_3d()
		if camera == null:
			continue
		var box := ship.camera_occluder()
		var seen := AirshipSight.measure(camera.global_transform, camera.fov, Vector2(SIZE), box)
		history.append([camera.global_transform, box])
		if history.size() > LOOK_BACK:
			history.pop_front()
		if _trace != null:
			_trace_row(tick, camera, seen)
		counts["n"] += 1
		# Round 11's complaint, the other side of B4: the lens inside the drawn hull.
		counts["inside"] += int(not RtsCamera.hull_hit(camera.global_position, [box]).is_empty())
		counts["frame"] += int(seen["in_frame"])
		if bool(seen["in_frame"]) and _line_of_sight(camera, box):
			counts["visible"] += 1
		counts["yaw"] += absf(ship.pilot.yaw_rate)
		if bool(seen["between"]):
			counts["between"] += 1
			counts["cover"] += float(seen["cover"])
			counts["hidden"] += float(seen["hidden"])
			if run == 0 and history.size() == LOOK_BACK:
				# WHO MOVED: the hull where it is now against the camera of LOOK_BACK ticks ago, and the hull of then
				# against the camera of now. Only the camera's move explains it -> "camera"; only the hull's -> "hull".
				var then: Array = history[0]
				var hull_now_cam_then := AirshipSight.hidden(then[0], box) > 0.0
				var hull_then_cam_now := AirshipSight.hidden(camera.global_transform, then[1]) > 0.0
				var cause := "both"
				if hull_then_cam_now and not hull_now_cam_then:
					cause = "camera"
				elif hull_now_cam_then and not hull_then_cam_now:
					cause = "hull"
				causes[cause] += 1
				print("AIRSHIP_VIEW_INTRUSION t=%.1fs cause=%s camera_moved=%.0fm hull_to_camera=%.0fm hidden=%.0f%%" % [
						float(tick) / SimClock.TICK_RATE, cause, (then[0] as Transform3D).origin.distance_to(camera.global_position),
						Vector2(camera.global_position.x, camera.global_position.z).distance_to(box["centre"]),
						100.0 * float(seen["hidden"])])
			run += 1
			_keep_worst(float(seen["cover"]), tick)
		elif run > 0:
			runs.append(run)
			run = 0
	if run > 0:
		runs.append(run)
	var n := maxf(1.0, float(counts["n"]))
	var longest := 0
	var total := 0
	for r in runs:
		longest = maxi(longest, r)
		total += r
	if _trace != null:
		_trace.close()
	var arena := String(Arena.active.get("name", "?"))
	var arm := _arm()
	var row := {"arena": arena, "viewavoid": arm, "ticks": counts["n"],
			"frame_pct": 100.0 * counts["frame"] / n, "between_pct": 100.0 * counts["between"] / n,
			"intrusions": runs.size(), "longest_s": float(longest) / SimClock.TICK_RATE,
			"mean_s": float(total) / maxf(1.0, runs.size()) / SimClock.TICK_RATE,
			"cover_pct_while_between": 100.0 * float(counts["cover"]) / maxf(1.0, float(counts["between"])),
			"hidden_pct_while_between": 100.0 * float(counts["hidden"]) / maxf(1.0, float(counts["between"])),
			"mean_yaw_deg_s": rad_to_deg(float(counts["yaw"]) / n),
			"inside_pct": 100.0 * float(counts["inside"]) / n,
			"visible_pct": 100.0 * float(counts["visible"]) / n,
			"causes": causes,
			"worst": _worst.map(func(w: Dictionary) -> Dictionary: return {"tick": w["tick"], "cover": w["cover"]})}
	var file := FileAccess.open(out.path_join("airship_view_%s_%s.json" % [arena, arm]), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(row, "  "))
	print("AIRSHIP_VIEW %-9s viewavoid=%-3s ticks=%5d frame=%5.1f%% hides_fight=%5.1f%% intrusions=%3d longest=%5.1fs mean=%4.1fs hidden_while=%4.1f%% cover=%4.1f%% yaw=%4.1fdeg/s" % [
			arena, arm, row["ticks"], row["frame_pct"], row["between_pct"], row["intrusions"], row["longest_s"],
			row["mean_s"], row["hidden_pct_while_between"], row["cover_pct_while_between"], row["mean_yaw_deg_s"]])
	print("AIRSHIP_VIEW_CAUSES %s viewavoid=%s camera=%d hull=%d both=%d" % [arena, arm, causes["camera"], causes["hull"], causes["both"]])
	var blockers := _los.keys()
	blockers.sort_custom(func(a: String, b: String) -> bool: return int(_los[a]) > int(_los[b]))
	print("AIRSHIP_VIEW_LOS %s %s" % [arena, ", ".join(blockers.slice(0, 8).map(func(k: String) -> String: return "%s x%d" % [k, _los[k]]))])
	print("AIRSHIP_VIEW_DONE %s" % out)
	quit(0)


## Round 21: frame % ignores what stands between the lens and the hull, and on the Terminus the frames showed blocks
## hiding it. Seen for real: any of seven points on the hull (along its keel at mid-height, and on its flanks) is in
## the camera's frustum with a clear ray from the lens through the arena's colliders (the blocks are solid to their
## roofs; the hull has no collider). A lower bound on "he can see some of it": a sliver past a corner can be missed.
func _line_of_sight(camera: Camera3D, box: Dictionary) -> bool:
	var space := camera.get_world_3d().direct_space_state
	var centre: Vector2 = box["centre"]
	var half: Vector2 = box["half"]
	var yaw := float(box["yaw"])
	var along := Vector2(sin(yaw), cos(yaw))
	var across := Vector2(cos(yaw), -sin(yaw))
	var mid := (float(box["bottom"]) + float(box["top"])) * 0.5
	var eye := camera.global_position
	for offset: Vector2 in [Vector2.ZERO, along * half.y * 0.4, -along * half.y * 0.4, along * half.y * 0.75,
			-along * half.y * 0.75, across * half.x * 0.6, -across * half.x * 0.6]:
		var point := Vector3(centre.x + offset.x, mid, centre.y + offset.y)
		# Not `Camera3D.is_position_in_frustum`: headless, its frustum is the dummy viewport's, and the first run of this
		# column refused every point on it (Terminus 0.0 %, all `off_frustum`). The instrument's own lens: SIZE, fov.
		if not _in_lens(camera, point):
			_los["off_frustum"] = int(_los.get("off_frustum", 0)) + 1
			continue
		var query := PhysicsRayQueryParameters3D.create(eye, point)
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return true
		var by := "%s@%.0fm" % [String((hit["collider"] as Node).name) if hit.get("collider") is Node else "?",
				(hit["position"] as Vector3).y]
		_los[by] = int(_los.get(by, 0)) + 1
	return false


## Is `point` inside the camera's view at the instrument's SIZE (vertical `fov`, Godot's KEEP_HEIGHT)?
func _in_lens(camera: Camera3D, point: Vector3) -> bool:
	var local := camera.global_transform.affine_inverse() * point
	if local.z > -0.1:
		return false
	var half_v := tan(deg_to_rad(camera.fov) * 0.5)
	var half_h := half_v * float(SIZE.x) / float(SIZE.y)
	return absf(local.x / -local.z) <= half_h and absf(local.y / -local.z) <= half_v


## What stopped the rays (name@height -> count), printed once at the end: an instrument's first number is checked.
var _los := {}


## The arm's name, from the switches the airship read.
func _arm() -> String:
	var arm := ("steer" if AirshipFlight.view_avoid else "") + ("climb" if AirshipFlight.view_climb else "")
	if AirshipFlight.view_climb:
		arm += ("live" if not AirshipFlight.climb_squads else "") + ("rest" if AirshipFlight.view_rest else "") \
				+ ("lead" if AirshipFlight.view_lead else "") + ("low" if AirshipFlight.view_low else "")
	arm += "sink" if AirshipFlight.view_sink else ""
	arm += "" if AirshipFlight.camera_lift else "nolift"
	arm += "stations" if AirshipFlight.stations else ""
	arm += "" if AirshipFlight.solid_climb else "nokit"
	arm += "" if AirshipFlight.orbit_choice else "nochoice"
	return "off" if arm == "" else arm


func _trace_row(tick: int, camera: Camera3D, seen: Dictionary) -> void:
	var t := camera.global_transform
	var forward := -t.basis.z
	var aim := Vector3(t.origin.x, 0.0, t.origin.z)
	if forward.y < -0.01:
		aim = t.origin + forward * ((AirshipSight.AIM_HEIGHT_M - t.origin.y) / forward.y)
	var flight := ship.flight
	var need_now := flight.view_need(flight.pilot.position, flight.pilot.heading) if not flight.view.is_empty() else 0.0
	# What the live camera alone asks for (the squads' likely views are the rest of `view_need`).
	var need_live := 0.0
	if not flight.view.is_empty():
		var squads := AirshipFlight.climb_squads
		AirshipFlight.climb_squads = false
		need_live = flight.view_need(flight.pilot.position, flight.pilot.heading)
		AirshipFlight.climb_squads = squads
	# The counterfactual: the same hull at its cruise height, against the same camera -- what the climb bought (hidden)
	# and what it cost (in frame) on this tick.
	var cruise := AirshipSight.measure(t, camera.fov, Vector2(SIZE), AirshipFlight.hull_box(flight.pilot.position,
			flight.pilot.heading, SyndicateAdAirship.ALTITUDE + (ship.position.y - flight.altitude)))
	_trace.store_line("%d,%.2f,%.2f,%.2f,%.1f,%.2f,%.2f,%.2f,%.2f,%.1f,%.2f,%.2f,%.2f,%.2f,%.2f,%.1f,%d,%.3f,%d,%d,%.2f,%d,%.3f" % [
			tick, t.origin.x, t.origin.y, t.origin.z, rad_to_deg(atan2(forward.x, forward.z)), aim.x, aim.z,
			flight.pilot.position.x, flight.pilot.position.y, rad_to_deg(flight.pilot.heading), flight.altitude,
			flight.wanted_altitude, need_now, flight.action.x, flight.action.y, flight.orbit, int(seen["in_frame"]),
			float(seen["hidden"]), _ordered, controls.groups.numbers().size(), need_live, int(cruise["in_frame"]),
			float(cruise["hidden"])])


## His loop, roughly: the next living group, attack-moved at the nearest enemy its centroid can find (or the far base).
func _drive(game_match: Match) -> void:
	var numbers: Array = controls.groups.numbers()
	if numbers.is_empty():
		return
	for attempt in numbers.size():
		var number := int(numbers[(_next_group - 1 + attempt) % numbers.size()])
		var members: Array = controls.groups.members(number).filter(func(unit_name: String) -> bool:
			var tank := game_match.tanks.get_node_or_null(NodePath(unit_name)) as Tank
			return tank != null and tank.is_alive())
		if members.is_empty():
			continue
		_next_group = (numbers.find(number) + 1) % numbers.size() + 1
		_ordered = number
		controls.recall_group(number)
		var from := Vector3.ZERO
		for unit_name: String in members:
			from += (game_match.tanks.get_node(NodePath(unit_name)) as Node3D).global_position
		from /= members.size()
		var target := Match.spawn_position(Match.Team.RUST, 0)
		var best := INF
		for tank in game_match.sorted_team_tanks(Match.Team.RUST):
			if tank.is_alive() and tank.global_position.distance_to(from) < best:
				best = tank.global_position.distance_to(from)
				target = tank.global_position
		controls.order_selection("attack_move", {"to": [target.x, target.z], "queue": false})
		return


## Keep the three worst moments; each is saved as a frame the moment it is measured (the display shows it now).
func _keep_worst(cover: float, tick: int) -> void:
	if _worst.size() >= 3 and cover <= float(_worst[-1]["cover"]):
		return
	# One frame per intrusion is enough: a neighbour of a kept tick replaces it only if worse.
	for kept: Dictionary in _worst:
		if absi(int(kept["tick"]) - tick) < SimClock.TICK_RATE * 5:
			if cover > float(kept["cover"]):
				_drop(kept)
				_worst.erase(kept)
				break
			return
	var entry := {"cover": cover, "tick": tick, "file": ""}
	if _display:
		entry["file"] = out.path_join("worst_%s_t%05d.png" % [String(Arena.active.get("name", "map")), tick])
		root.get_texture().get_image().save_png(entry["file"])
	_worst.append(entry)
	_worst.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["cover"]) > float(b["cover"]))
	while _worst.size() > 3:
		_drop(_worst.pop_back())


func _drop(entry: Dictionary) -> void:
	if String(entry["file"]) != "":
		DirAccess.remove_absolute(String(entry["file"]))
