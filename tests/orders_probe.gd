extends SceneTree
## Round 34 (planner, orders' O5 for C34.11; measurement only): his "select 3 squads, click one point" case, through the
## real player path. A skirmish (main.tscn, the player's squads from tests/control/orders_probe_<N>.json, a one-scout
## enemy far away) is resumed from its planning pause; every squad is selected together and ordered through
## RtsControls.order_selection, as his right-click is: ONE click (`--probe-route=click`), or a shifted route of three
## waypoints (`--probe-route=route`, the first two queued behind nothing, then queued). Then, per squad:
##   anchor_offset_m   straight distance from the click (the route's last waypoint) to the squad's own anchor
##   plan_drive_m      the drive from the squad's start to its anchor on the navmesh; driven_m: its centre's actual path
##   deck              whether any crew stood on a bridge deck on the way (plan_deck: whether the planned drive crosses one)
##   arrived_s         the element's first `arrived`, seconds after the order (-1: not inside the window)
##   foreign_m         at arrival, the nearest hull of ANOTHER of his squads (enemy_m: the nearest enemy)
##   shuffle_m         the most any crew moved after its squad's arrival, to the end of the window (brains' B6 shuffle)
## ORDERS_PROBE_SQUAD {...} a squad, ORDERS_PROBE {...} the run. With a display, top-down screenshots when every squad has
## arrived (or the window ends), desktop 1280x720 and phone 1560x720, into `--probe-shots=DIR`.
##
##   godot --fixed-fps 30 --path . --script res://tests/orders_probe.gd -- --arena=locks --seed=34 --probe-squads=3 \
##     --probe-route=click [--ground-cap=off] [--probe-shots=build/orders-probe] [--probe-click=x,z]
## The click (unless given): the near bank of the deck nearest the arena's middle, DECK_BACK_M short of it on the
## player's side, where an anchor laid 70 m sideways meets the river (his case). The route: the squads' middle, then
## two points a third and two thirds of the way, then the click.

const MAIN := "res://game/main.tscn"
const DECK_BACK_M := 18.0
const WINDOW_S := 90.0
const AFTER_ARRIVAL_S := 20.0
const SHOT_SIZES := {"desktop": Vector2i(1280, 720), "phone": Vector2i(1560, 720)}

var _controls: RtsControls
var _match: Match
var _squads: Array = []  # [{number, units, start, path_len, deck, anchor, arrived_tick, at_arrival, foreign, enemy, shuffle}]
var _click := Vector3.ZERO
var _route: Array = []
var _order_tick := 0
var _last_centre := {}
var _shot := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	# The arena and Match read the COMMAND LINE (LaunchFlags.from_environment), not Main.next_flags: `--arena` and `--seed`
	# are the probe's own arguments, and the rest is added to what main.gd reads.
	var map := _flag("arena", "locks")
	var count := int(_flag("probe-squads", "3"))
	var flags := LaunchFlags.from_environment()
	for extra: String in ["--skirmish", "--player=res://tests/control/orders_probe_%d.json" % count,
			"--enemy=res://tests/control/orders_probe_enemy.json", "--budget=6000", "--no-control", "--no-pick-faction",
			"--hints=off", "--no-record"]:
		var parts := extra.trim_prefix("--").split("=", true, 1)
		flags.values[parts[0]] = parts[1] if parts.size() > 1 else ""
	Main.next_flags = flags
	change_scene_to_file(MAIN)
	for i in 40:  # the scene, the arena's navmesh and the controls (built after the mode starts)
		await physics_frame
	_controls = current_scene.find_child("TacticalMap", true, false) as RtsControls
	if _controls == null:
		print("ORDERS_PROBE {\"error\": \"no RtsControls (TacticalMap)\"}")
		quit(2)
		return
	_match = _controls.game_match
	if paused:
		_controls.set_paused(false, "")
	for i in 30:
		await physics_frame
	var units: Array = []
	for number: int in _controls.groups.numbers():
		var members: Array = _controls.groups.members(number)
		if members.is_empty():
			continue
		units += members
		_squads.append({"number": number, "units": members, "start": _centre(members)})
	var forward: Vector3 = Match.team_frame(Match.Team.GREEN)["forward"]
	_click = _pick_click(map, _centre(units), forward)
	_route = [_click]
	if _flag("probe-route", "click") == "route":
		var from := _centre(units)
		_route = [from.lerp(_click, 1.0 / 3.0), from.lerp(_click, 2.0 / 3.0), _click]
	print("ORDERS_PROBE_SETUP " + JSON.stringify({"map": map, "squads": _squads.size(), "units": units.size(),
			"click": _xz(_click), "route": _route.map(func(p: Vector3) -> Array: return _xz(p)),
			"ground_cap": SelectionSquads.GROUND_CAP, "decks": SlotGround.deck_boxes()}))
	_controls.selection.set_units(units)
	await physics_frame
	var returned: Array = []
	for i in _route.size():
		var p: Vector3 = _route[i]
		returned.append(_controls.order_selection("move", {"to": [p.x, p.z], "queue": i > 0}))
	_order_tick = _match.tick
	for squad: Dictionary in _squads:
		squad["anchor"] = _anchor_of(squad)
		var ground := _tank(String(squad["units"][0]))
		var anchor: Variant = squad["anchor"]
		squad["path_len"] = SlotGround.path_length(ground, squad["start"], anchor) if anchor is Vector3 and ground != null else -1.0
		squad["plan_deck"] = bool(SelectionSquads.crosses_on(ground).call(squad["start"], anchor)) \
				if anchor is Vector3 and ground != null else false
		squad["deck"] = false
		squad["driven"] = 0.0
		squad["arrived_tick"] = -1
		squad["shuffle"] = 0.0
		_last_centre[squad["number"]] = squad["start"]
	var all_in_tick := -1
	while _match.tick - _order_tick < int(WINDOW_S * SimClock.TICK_RATE):
		await physics_frame
		_watch()
		var all_in := _squads.all(func(s: Dictionary) -> bool: return int(s["arrived_tick"]) >= 0)
		if all_in and all_in_tick < 0:
			all_in_tick = _match.tick
			await _shots("arrival")
		if all_in_tick >= 0 and _match.tick - all_in_tick >= int(AFTER_ARRIVAL_S * SimClock.TICK_RATE):
			break
	if all_in_tick < 0:
		await _shots("window_end")
	var rows: Array = []
	for squad: Dictionary in _squads:
		var anchor: Variant = squad["anchor"]
		var row := {"map": map, "squads": _squads.size(), "route": _flag("probe-route", "click"),
				"ground_cap": "on" if SelectionSquads.GROUND_CAP else "off", "squad": squad["number"],
				"crews": (squad["units"] as Array).size(), "start": _xz(squad["start"]), "anchor": _xz(anchor) if anchor is Vector3 else null,
				"anchor_offset_m": snappedf(_flat_d(anchor, _click), 0.1) if anchor is Vector3 else -1.0,
				"plan_drive_m": snappedf(float(squad["path_len"]), 0.1), "driven_m": snappedf(float(squad["driven"]), 0.1),
				"plan_deck": squad["plan_deck"], "deck": squad["deck"], "deck_at": squad.get("deck_at"),
				"arrived_s": snappedf((int(squad["arrived_tick"]) - _order_tick) / float(SimClock.TICK_RATE), 0.1)
						if int(squad["arrived_tick"]) >= 0 else -1.0,
				"foreign_m": snappedf(float(squad.get("foreign", -1.0)), 0.1),
				"enemy_m": snappedf(float(squad.get("enemy", -1.0)), 0.1),
				"shuffle_m": snappedf(float(squad["shuffle"]), 0.1)}
		rows.append(row)
		print("ORDERS_PROBE_SQUAD " + JSON.stringify(row))
	print("ORDERS_PROBE " + JSON.stringify({"map": map, "squads": _squads.size(), "route": _flag("probe-route", "click"),
			"ground_cap": "on" if SelectionSquads.GROUND_CAP else "off", "capped": SelectionSquads.ground_capped,
			"returned": returned, "all_in_s": snappedf((all_in_tick - _order_tick) / float(SimClock.TICK_RATE), 0.1)
					if all_in_tick >= 0 else -1.0, "on_deck": rows.filter(func(r: Dictionary) -> bool: return r["deck"]).size(),
			"worst_offset_m": rows.map(func(r: Dictionary) -> float: return r["anchor_offset_m"]).max(),
			"worst_shuffle_m": rows.map(func(r: Dictionary) -> float: return r["shuffle_m"]).max()}))
	quit(0)


## Every tick: decks crossed, the centre's path, arrival (and the hulls around it then), and the shuffle after it.
func _watch() -> void:
	for squad: Dictionary in _squads:
		var alive: Array = (squad["units"] as Array).filter(func(n: String) -> bool:
			var t := _tank(n)
			return t != null and t.is_alive())
		if alive.is_empty():
			continue
		var centre := _centre(alive)
		squad["driven"] = float(squad["driven"]) + _flat_d(centre, _last_centre[squad["number"]])
		_last_centre[squad["number"]] = centre
		for n: String in alive:
			if not bool(squad["deck"]) and SlotGround.near_deck(_tank(n).global_position, 0.0):
				squad["deck"] = true
				squad["deck_at"] = [_xz(_tank(n).global_position), snappedf((_match.tick - _order_tick) / float(SimClock.TICK_RATE), 0.1)]
		var element := _controls.elements.of(String(alive[0])) if _controls.elements != null else null
		if int(squad["arrived_tick"]) < 0 and element != null and element.arrived and element.queued_tasks.is_empty() \
				and _match.tick > _order_tick + 2:
			squad["arrived_tick"] = _match.tick
			var seats := {}
			for n: String in alive:
				seats[n] = _tank(n).global_position
			squad["at_arrival"] = seats
			squad["foreign"] = _nearest(alive, func(t: Tank) -> bool: return t.team == Match.Team.GREEN \
					and not (squad["units"] as Array).has(String(t.name)))
			squad["enemy"] = _nearest(alive, func(t: Tank) -> bool: return t.team != Match.Team.GREEN)
		if int(squad["arrived_tick"]) >= 0:
			var seats: Dictionary = squad["at_arrival"]
			for n: String in alive:
				if seats.has(n):
					squad["shuffle"] = maxf(float(squad["shuffle"]), _flat_d(_tank(n).global_position, seats[n]))


## The squad's own anchor: its element's last task destination (the route's last waypoint for a queued route).
func _anchor_of(squad: Dictionary) -> Variant:
	var element := _controls.elements.of(String(squad["units"][0])) if _controls.elements != null else null
	if element == null:
		var goal: Variant = _controls.orders.goal_position(String(squad["units"][0]))
		return goal
	var task: Dictionary = element.queued_tasks.back() if not element.queued_tasks.is_empty() else element.task
	var to: Variant = task.get("to")
	return Vector3(float(to[0]), 0.0, float(to[1])) if to is Array and (to as Array).size() >= 2 else null


func _pick_click(map: String, army: Vector3, forward: Vector3) -> Vector3:
	var given := _flag("probe-click", "")
	if given != "":
		var xz := given.split(",")
		return Vector3(float(xz[0]), 0.0, float(xz[1]))
	var best: Variant = null
	for box: Array in SlotGround.deck_boxes():
		var mid := Vector3((float(box[0]) + float(box[2])) * 0.5, 0.0, (float(box[1]) + float(box[3])) * 0.5)
		if best == null or mid.length() < (best as Vector3).length():
			best = mid
	if best == null:
		return Orders.clamp_to_arena(army + forward * 60.0)
	# DECK_BACK_M short of the deck along the player's forward axis, on his side.
	var back := forward * -1.0 if (best as Vector3).dot(forward) > army.dot(forward) else forward
	return Orders.clamp_to_arena((best as Vector3) + back * DECK_BACK_M)


func _shots(label: String) -> void:
	var out := _flag("probe-shots", "")
	if out == "" or DisplayServer.get_name() == "headless" or _shot:
		return
	_shot = true
	DirAccess.make_dir_recursive_absolute(out)
	var everyone: Array = []
	for squad: Dictionary in _squads:
		everyone += squad["units"]
	var centre := _centre(everyone).lerp(_click, 0.5)
	var extent := 40.0
	for n: String in everyone:
		var t := _tank(n)
		if t != null:
			extent = maxf(extent, _flat_d(t.global_position, centre) + 15.0)
	extent = maxf(extent, _flat_d(_click, centre) + 15.0)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = extent * 2.0
	camera.far = 400.0
	current_scene.add_child(camera)
	camera.global_position = Vector3(centre.x, 200.0, centre.z)
	camera.rotation = Vector3(-PI / 2.0, 0.0, 0.0)
	var was := root.get_camera_3d()
	camera.make_current()
	var stem := "%s-%d-%s-cap%s-%s" % [_flag("arena", "locks"), _squads.size(), _flag("probe-route", "click"),
			"on" if SelectionSquads.GROUND_CAP else "off", label]
	for aspect: String in SHOT_SIZES:
		DisplayServer.window_set_size(SHOT_SIZES[aspect])
		for i in 6:
			await process_frame
		var image := root.get_texture().get_image()
		var path := out.path_join("%s-%s.png" % [stem, aspect])
		image.save_png(path)
		print("ORDERS_PROBE_SHOT %s %dx%d" % [path, image.get_width(), image.get_height()])
	camera.queue_free()
	if was != null:
		was.make_current()


func _nearest(alive: Array, keep: Callable) -> float:
	var best := INF
	for t in _match.tanks.get_children():
		if not (t is Tank) or not (t as Tank).is_alive() or not keep.call(t):
			continue
		for n: String in alive:
			best = minf(best, _flat_d((t as Tank).global_position, _tank(n).global_position))
	return best if best < INF else -1.0


func _tank(unit_name: String) -> Tank:
	return _match.tanks.get_node_or_null(NodePath(unit_name)) as Tank if _match != null else null


func _centre(names: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for unit_name: String in names:
		var t := _tank(unit_name)
		if t != null:
			sum += Vector3(t.global_position.x, 0.0, t.global_position.z)
			n += 1
	return sum / maxf(n, 1)


static func _flat_d(a: Variant, b: Variant) -> float:
	return Vector2((a as Vector3).x - (b as Vector3).x, (a as Vector3).z - (b as Vector3).z).length()


static func _xz(p: Vector3) -> Array:
	return [snappedf(p.x, 0.1), snappedf(p.z, 0.1)]
