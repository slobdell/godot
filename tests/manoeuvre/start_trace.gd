extends SceneTree
## Round 43 (manoeuvre S1): REBUILD THE START of a recorded match and trace its crews per tick. The lead's first order
## on Locks 56416 (2026-10-27) had three of five crews arrive, one yield 20 s in the deploy zone and one route the long
## way round; the census in the recording is one row a second with position, phase and blocked-by only, so the chain
## (who yields to whom and why, the seat each crew drives to, the route) has to come from a headless rebuild.
##
## Two workloads:
##   --orders=X.jsonl   a recording's orders at their ticks (tick-0 ones inside the planning pause, as he gave them; the
##                      replay issues them at tick 1), the squads of its first two orders traced by default
##   (no --orders)      HIS FIRST-ORDER SHAPE, synthesised from the deploy (Bar S's workload): the roster's first squad is
##                      sent, in the planning pause, 45 m toward the arena's centre and 25 m away from the rest of the
##                      army (his Guns: the west end of the north edge, clicked south-west); the second squad is sent at
##                      t56 to a point 23 m back toward the deploy from that click (his Hunters' first click) and at t141
##                      to one 17 m past it (his second), through the first squad's zone. Squads 1 and 2 traced.
##   --squad-cap=4      his laptop fields four squads of five (a headless start is the desktop's five)
##   --snap-deploy      (recording) put every unit where the tick-0 census has it before the match starts
##   --crews=Guns,Hunters  the squads traced (name prefixes after the team's); default: the two squads above
##   --every=N          a trace row every N ticks (default 1); --trace-seconds=S how long (default 20)
## Rows (grep the prefix):
##   START_ROW   one per traced crew per tick: pos, heading, speed, phase, blocked_by, yield (to/spot), the mover's goal,
##               distance to it, remaining path, steer point, pace, stalled s, reverse why, k-turn, gate, wedged, the
##               order (verb/source), the element's seat for it (slot and the order the element issued) and its distance
##   START_SEAT  the element's seating whenever it changes: formation, pitch, file, corridor, heading, anchor, reason and
##               every member's slot index + slot
##   START_YIELD every give-way begun (Movement.yield_log's diagnosis row)
##   START_GAP   (recording) once a second: each traced crew's distance from where the census has it (the rebuild's fidelity)
##   START_RUN   at the end, one JSON row: per traced crew its squad, click, first order tick, arrival tick (the first
##               `arrived` within 12 m of its seat after it has driven), distance to its squad's click 15 s after its first
##               order, whether that is within TacticsFormation.seat_bound(its squad) (the yardstick is the same in every arm:
##               seat_bound is a pure function of the hulls), yielding / blocked / k-turn / wedged seconds in those 15 s,
##               seat moves (count, max); and the run's totals. tests/manoeuvre/s_judge.py reads it.
##   START_ORDER / START_SETUP / START_DONE   as the replay
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/start_trace.gd -- [--orders=build/X.jsonl] \
##         --arena=locks --seed=56416 --squad-cap=4 [--crews=Guns,Hunters] [--snap-deploy] --trace-seconds=20 --mute [any game switch]
## --arena and --seed MUST be on the real command line (native, R43.1): Arena._ready reads OS user args, not Main.next_flags,
## so a replay that only sets next_flags builds the DEFAULT map with the recording's deploy zone. The probe refuses to run
## without them.

const MAIN := "res://game/main.tscn"
## His first order's geometry (Locks 56416): the click 45 m toward the arena's centre and 25 m away from the army; the
## second squad's clicks 23 m back toward the deploy and then 17 m past the first click.
const CLICK_TOWARD_M := 45.0
const CLICK_AWAY_M := 25.0
const SECOND_BACK_M := 23.0
const SECOND_PAST_M := 17.0
const SECOND_TICKS := [56, 141]
## The window each crew's START_RUN numbers are read over, from its first order.
const READ_S := 15.0

var _controls: RtsControls
var _match: Match
var _header := {}
var _orders: Array = []
var _census: Array = []
var _next := 0
var _census_i := 0
var _until := 0
var _every := 1
var _crews: PackedStringArray = []
var _team_prefix := "Green_"
var _last_seat := {}
var _yield_rows := 0
var _synth := false
## Per traced crew: the START_RUN bookkeeping.
var _runs := {}
## Squad name -> click (the last `to` ordered to it) and the tick of its first order.
var _clicks := {}
var _first_order_tick := {}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _has(name: String) -> bool:
	return OS.get_cmdline_user_args().has("--" + name)


func _run() -> void:
	var path := _flag("orders", "")
	if _flag("arena", "") == "" or _flag("seed", "") == "":
		print("START_DONE {\"error\": \"pass --arena=<name> --seed=<n> on the real command line (Arena._ready reads OS args)\"}")
		quit(2)
		return
	_synth = path == ""
	if not _synth:
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges() == "":
				continue
			var row: Variant = JSON.parse_string(line)
			if not (row is Dictionary):
				continue
			match String(row["t"]):
				"match":
					_header = row
				"order":
					_orders.append(row)
				"census":
					_census.append(row)
	var flags := LaunchFlags.from_environment()
	for extra: String in ["--skirmish", "--enemy=cpu", "--seed=%s" % _flag("seed", str(int(_header.get("seed", 0)))),
			"--arena=%s" % _flag("arena", String(_header.get("arena", "locks"))), "--no-pick-faction", "--hints=off",
			"--player-faction=%s" % _flag("player-faction", "gangs"), "--enemy-faction=%s" % _flag("enemy-faction", "syndicate")]:
		var parts := extra.trim_prefix("--").split("=", true, 1)
		flags.values[parts[0]] = parts[1] if parts.size() > 1 else ""
	Main.next_flags = flags
	change_scene_to_file(MAIN)
	for i in 40:
		await physics_frame
	_controls = current_scene.find_child("TacticalMap", true, false) as RtsControls
	if _controls == null:
		print("START_DONE {\"error\": \"no RtsControls\"}")
		quit(2)
		return
	_match = _controls.game_match
	_every = maxi(int(_flag("every", "1")), 1)
	_until = int(float(_flag("trace-seconds", "20")) * 30.0)
	var snapped := 0
	if _has("snap-deploy") and not _census.is_empty() and int(_census[0]["tick"]) == 0:
		for u: Dictionary in _census[0]["units"]:
			var tank := _match.tanks.get_node_or_null(NodePath(String(u["n"]))) as Tank
			if tank == null:
				continue
			var to := Vector3(float(u["pos"][0]), tank.global_position.y, float(u["pos"][1]))
			var moved := Vector2(to.x - tank.global_position.x, to.z - tank.global_position.z).length()
			if moved > 0.05:
				print("START_SNAP %s moved %.2f m to (%.1f, %.1f)" % [tank.name, moved, to.x, to.z])
				tank.global_position = to
				snapped += 1
	if _synth:
		_orders = _first_order_shape()
	var crews := _flag("crews", "")
	if crews == "":
		crews = ",".join(_squads_of_first_orders())
	_crews = crews.split(",")
	Movement.yield_log = true
	# His first orders were given inside the planning pause (tick 0); issue them there too.
	_issue_due(_match.tick)
	print("START_SETUP " + JSON.stringify({"orders": _orders.size(), "census_rows": _census.size(), "seed": _flag("seed", ""),
			"arena": _flag("arena", ""), "layout": String(Arena.active.get("name", "")), "tick": _match.tick,
			"units": _match.tanks.get_child_count(), "snapped": snapped, "synth": _synth, "crews": Array(_crews),
			"native": NativeBridge.impl != null, "seat_bound": TacticsFormation.SEAT_BOUND, "shape_latch": ElementPlan.SHAPE_LATCH}))
	if paused:
		_controls.set_paused(false, "")
	physics_frame.connect(_step)


## The roster's squads of the player's team, in roster order: [{"name", "units": [...]}].
func _squads() -> Array:
	var by_squad := {}
	var order: Array = []
	for child in _match.tanks.get_children():
		var tank := child as Tank
		if tank == null or not String(tank.name).begins_with(_team_prefix):
			continue
		var squad := String(tank.name).trim_prefix(_team_prefix).rsplit("_", true, 1)[0]
		if not by_squad.has(squad):
			by_squad[squad] = []
			order.append(squad)
		by_squad[squad].append(String(tank.name))
	var out: Array = []
	for squad: String in order:
		out.append({"name": squad, "units": by_squad[squad]})
	return out


func _centroid(names: Array) -> Vector3:
	var sum := Vector3.ZERO
	var n := 0
	for name: String in names:
		var tank := _match.tanks.get_node_or_null(NodePath(name)) as Tank
		if tank != null:
			sum += Vector3(tank.global_position.x, 0.0, tank.global_position.z)
			n += 1
	return sum / maxf(n, 1.0)


## Bar S's workload: his first-order shape from this deploy (see the header).
func _first_order_shape() -> Array:
	var squads := _squads()
	if squads.size() < 2:
		return []
	var first: Dictionary = squads[0]
	var second: Dictionary = squads[1]
	var all: Array = []
	for squad: Dictionary in squads:
		all.append_array(squad["units"])
	var c1 := _centroid(first["units"])
	var army := _centroid(all)
	var toward := (Vector3.ZERO - c1)
	toward = toward.normalized() if toward.length() > 1.0 else Vector3.FORWARD
	var away := c1 - army
	away = Vector3(away.x, 0.0, away.z).normalized() if away.length() > 1.0 else Vector3(-toward.z, 0.0, toward.x)
	# His clicks were on open ground: each synthetic click is pulled onto the navmesh (a click on a building or the water would
	# be the slot grounding's workload, not the seat's).
	var click := _on_ground(Orders.clamp_to_arena(c1 + toward * CLICK_TOWARD_M + away * CLICK_AWAY_M))
	var back := _on_ground(Orders.clamp_to_arena(click - toward * SECOND_BACK_M))
	var past := _on_ground(Orders.clamp_to_arena(click + away * SECOND_PAST_M))
	return [{"tick": 0, "verb": "move", "units": first["units"], "to": [click.x, click.z]},
			{"tick": SECOND_TICKS[0], "verb": "move", "units": second["units"], "to": [back.x, back.z]},
			{"tick": SECOND_TICKS[1], "verb": "move", "units": second["units"], "to": [past.x, past.z]}]


## `point` moved onto the navigation mesh (the closest navigable point; itself when the map is not ready).
func _on_ground(point: Vector3) -> Vector3:
	var any: Node3D = null
	for child in _match.tanks.get_children():
		if child is Node3D:
			any = child
			break
	if any == null or not any.is_inside_tree():
		return point
	var map: RID = any.get_world_3d().navigation_map
	if not map.is_valid():
		return point
	var closest := NavigationServer3D.map_get_closest_point(map, point)
	if closest.length_squared() < 0.001 and point.length_squared() > 1.0:
		return point  # no map yet: the origin comes back
	return Vector3(closest.x, 0.0, closest.z)


## The squads named by the first two orders' units (the traced crews when --crews is not given).
func _squads_of_first_orders() -> PackedStringArray:
	var out: PackedStringArray = []
	for o: Dictionary in _orders:
		for n in o.get("units", []):
			var squad := String(n).trim_prefix(_team_prefix).rsplit("_", true, 1)[0]
			if not out.has(squad):
				out.append(squad)
		if out.size() >= 2:
			break
	return out


func _issue_due(tick: int) -> void:
	while _next < _orders.size() and int(_orders[_next]["tick"]) <= tick:
		var o: Dictionary = _orders[_next]
		_next += 1
		if not o.has("to") and not o.has("target"):
			continue
		var names: Array = []
		for n in o["units"]:
			var tank := _match.tanks.get_node_or_null(NodePath(String(n))) as Tank
			if tank != null and tank.is_alive():
				names.append(String(n))
		if names.is_empty():
			print("START_ORDER " + JSON.stringify({"tick": tick, "skipped": o}))
			continue
		_controls.selection.set_units(names)
		var extra := {"queue": bool(o.get("queue", false))}
		if o.has("to"):
			extra["to"] = o["to"]
		if o.has("target"):
			extra["target"] = o["target"]
		var said: String = _controls.order_selection(String(o["verb"]), extra)
		print("START_ORDER " + JSON.stringify({"tick": tick, "at": o["tick"], "verb": o["verb"], "n": names.size(), "to": o.get("to"), "said": said}))
		if o.has("to") and not bool(o.get("queue", false)):
			for n in names:
				var squad := String(n).trim_prefix(_team_prefix).rsplit("_", true, 1)[0]
				_clicks[squad] = Vector3(float(o["to"][0]), 0.0, float(o["to"][1]))
				if not _first_order_tick.has(squad):
					_first_order_tick[squad] = tick


func _watched(tank: Tank) -> bool:
	var name := String(tank.name)
	if not name.begins_with(_team_prefix):
		return false
	for crew in _crews:
		if name.begins_with(_team_prefix + crew + "_"):
			return true
	return false


func _element_of(name: String) -> Element:
	if _controls.elements == null:
		return null
	for element: Element in _controls.elements.of_team(Match.Team.GREEN):
		if element.has(name):
			return element
	return null


static func _v2(v: Variant) -> String:
	if v is Vector3:
		return "(%.1f,%.1f)" % [(v as Vector3).x, (v as Vector3).z]
	if v is Array and (v as Array).size() >= 2:
		return "(%.1f,%.1f)" % [float(v[0]), float(v[1])]
	return "-"


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _point(v: Variant) -> Variant:
	if v is Vector3:
		return Vector3((v as Vector3).x, 0.0, (v as Vector3).z)
	if v is Array and (v as Array).size() >= 2:
		return Vector3(float(v[0]), 0.0, float(v[1]))
	return null


func _row(tank: Tank, tick: int) -> void:
	var mover := Movement.of(tank)
	var here := tank.global_position
	var fwd := -tank.global_basis.z
	var name := String(tank.name)
	var short := name.trim_prefix(_team_prefix)
	var squad := short.rsplit("_", true, 1)[0]
	var order: Dictionary = _controls.orders.current(name) if _controls.orders != null else {}
	var element := _element_of(name)
	var seat := "-"
	var dseat := "-"
	var slot := "-"
	var seat_point: Variant = null
	if element != null:
		var issued := element.issued_to(name)
		seat_point = _point(issued.get("to"))
		if seat_point is Vector3:
			seat = _v2(seat_point)
			dseat = "%.1f" % _flat(here, seat_point)
		if element.slots.has(name):
			slot = _v2(element.slots[name])
	# START_RUN bookkeeping over READ_S from the crew's squad's first order.
	var started: int = int(_first_order_tick.get(squad, -1))
	if started >= 0:
		var rec: Dictionary = _runs.get(name, {"squad": squad, "order_tick": started, "arrived_tick": -1, "driven": false,
				"yield_s": 0.0, "blocked_s": 0.0, "kturn_s": 0.0, "wedged_s": 0.0, "seat_moves": 0, "seat_move_max_m": 0.0,
				"last_seat": null, "d_click_15s": -1.0, "within_bound_15s": false, "bound_m": -1.0, "min_d_click": INF,
				"nose_room_m": -1.0, "hull_m": snappedf(float(Movement.hull_box(tank.unit_id)[2]), 0.1)})
		if float(rec["nose_room_m"]) < 0.0 and mover != null and Pathing.enabled and Pathing.is_ready(tank):
			# Round 44 (Bar B1): the straight run past the nose at the crew's first traced tick after its order (Movement._free_run,
			# the backout rule's own nose test): the judge's nose-on classifier, the same geometry in every arm.
			var frame: Array = mover._kturn_frame(tank)
			rec["nose_room_m"] = snappedf(Movement._free_run(tank.get_world_3d().navigation_map,
					here + fwd * float(frame[1]), Vector3(fwd.x, 0.0, fwd.z).normalized(), float(frame[2])), 0.1)
		var in_window: bool = tick - started <= int(READ_S * 30.0)
		if mover != null:
			if mover.phase == "driving":
				rec["driven"] = true
			if rec["arrived_tick"] < 0 and bool(rec["driven"]) and mover.phase == "arrived" \
					and (not (seat_point is Vector3) or _flat(here, seat_point) <= 12.0):
				rec["arrived_tick"] = tick
			if in_window:
				if mover.phase == "yielding":
					rec["yield_s"] += 1.0 / 30.0
				elif mover.phase == "blocked":
					rec["blocked_s"] += 1.0 / 30.0
				if mover.in_kturn():
					rec["kturn_s"] += 1.0 / 30.0
				if mover.wedged:
					rec["wedged_s"] += 1.0 / 30.0
		if seat_point is Vector3:
			if rec["last_seat"] is Vector3 and _flat(seat_point, rec["last_seat"]) > 1.0:
				rec["seat_moves"] += 1
				rec["seat_move_max_m"] = maxf(float(rec["seat_move_max_m"]), _flat(seat_point, rec["last_seat"]))
			rec["last_seat"] = seat_point
		if _clicks.has(squad):
			var d := _flat(here, _clicks[squad])
			rec["min_d_click"] = minf(float(rec["min_d_click"]), d)
			if tick - started >= int(READ_S * 30.0) and float(rec["d_click_15s"]) < 0.0:
				rec["d_click_15s"] = d
				var members: Array = []
				for child in _match.tanks.get_children():
					var other := child as Tank
					if other != null and String(other.name).begins_with(_team_prefix + squad + "_"):
						members.append({"name": String(other.name), "unit": other.unit_id})
				rec["bound_m"] = TacticsFormation.seat_bound(members)
				rec["within_bound_15s"] = d <= float(rec["bound_m"])
		_runs[name] = rec
	if tick % _every != 0:
		return
	var line := "START_ROW t=%d n=%s x=%.1f z=%.1f hdg=%.0f spd=%.1f" % [tick, short, here.x, here.z,
			rad_to_deg(atan2(fwd.x, -fwd.z)), tank.speed()]
	if mover == null:
		print(line + " mover=none ord=%s/%s seat=%s dseat=%s" % [String(order.get("verb", "")), String(order.get("source", "")), seat, dseat])
		return
	var goal: Vector3 = mover._goal
	line += " ph=%s bb=%s y=%s/%s g=%s dg=%s rem=%.1f st=%s pace=%.2f stall=%.1f rev=%s kt=%s gate=%s wed=%s defl=%s path=%d/%d" % [
			mover.phase, mover.blocked_by.trim_prefix(_team_prefix), mover.yield_to.trim_prefix(_team_prefix), mover.yield_spot,
			_v2(goal) if goal != Vector3.INF else "-", ("%.1f" % _flat(here, goal)) if goal != Vector3.INF else "-", mover._remaining,
			_v2(mover.steer_to) if mover.steer_to != Vector3.INF else "-", mover.pace_now, float(mover.stalled_ticks) / 30.0,
			mover._reverse_why if mover._reverse_why != "" else "-", "1" if mover.in_kturn() else "0",
			Movement._gate_answer, "1" if mover.wedged else "0", "1" if mover._deflected else "0", mover._path_index, mover._path.size()]
	line += " ord=%s/%s seat=%s dseat=%s slot=%s" % [String(order.get("verb", "")), String(order.get("source", "")), seat, dseat, slot]
	print(line)


func _seats(tick: int) -> void:
	if _controls.elements == null:
		return
	for element: Element in _controls.elements.of_team(Match.Team.GREEN):
		var mine := false
		for crew in _crews:
			if element.element_name == crew:
				mine = true
		if not mine:
			continue
		var parts: PackedStringArray = []
		var names: Array = Array(element.members())
		names.sort()
		for unit_name: String in names:
			var seat: Variant = element.seats.get(unit_name)
			var idx := int(seat[2]) if seat is Array and (seat as Array).size() >= 3 else -1
			var issued := element.issued_to(unit_name)
			parts.append("%s#%d slot=%s issued=%s" % [unit_name.trim_prefix(_team_prefix), idx, _v2(element.slots.get(unit_name)), _v2(issued.get("to"))])
		var transit: Dictionary = element.transit if typeof(element.transit) == TYPE_DICTIONARY else {}
		var route_text := ""
		for p: Vector3 in transit.get("route", element.route):
			route_text += _v2(p)
		var body := "el=%s form=%s tech=%s drill=%s pitch=(%.1f,%.1f) file=%.2f corr=%s hdg=(%.2f,%.2f) anchor=%s route=%s transit_s=%.1f/%.1f task=%s why=\"%s\" | %s" % [
				element.element_name, element.formation, element.technique, element.drill, element.pitch.x, element.pitch.y, element.file,
				("%.1f" % element.corridor_m) if is_finite(element.corridor_m) else "inf", element.heading.x, element.heading.z,
				_v2(element.anchor), route_text, float(transit.get("s", -1.0)), float(transit.get("start_s", -1.0)),
				JSON.stringify(element.task), element.reason, " ".join(parts)]
		if _last_seat.get(element.element_name, "") != body:
			_last_seat[element.element_name] = body
			print("START_SEAT t=%d %s" % [tick, body])


func _yields(tick: int) -> void:
	while _yield_rows < Movement.yield_log_rows.size():
		var rec: Dictionary = Movement.yield_log_rows[_yield_rows]
		_yield_rows += 1
		print("START_YIELD t=%d %s" % [tick, JSON.stringify(rec)])


func _gap(row: Dictionary, tick: int) -> void:
	var parts: PackedStringArray = []
	for u: Dictionary in row["units"]:
		var tank := _match.tanks.get_node_or_null(NodePath(String(u["n"]))) as Tank
		if tank == null or not _watched(tank):
			continue
		var mover := Movement.of(tank)
		var gap := Vector2(tank.global_position.x - float(u["pos"][0]), tank.global_position.z - float(u["pos"][1])).length()
		parts.append("%s:%.1f %s/%s" % [String(u["n"]).trim_prefix(_team_prefix), gap, String(u["phase"]).left(4),
				(mover.phase if mover != null else "-").left(4)])
	print("START_GAP t=%d his=%d %s" % [tick, int(row["tick"]), " ".join(parts)])


func _run_row(tick: int) -> void:
	var crews: Array = []
	var seated := 0
	var yield_blocked := 0.0
	var never := 0
	var arrival_sum := 0.0
	var names: Array = _runs.keys()
	names.sort()
	for name: String in names:
		var rec: Dictionary = _runs[name]
		var row := rec.duplicate()
		row.erase("last_seat")
		row.erase("driven")
		row["name"] = name.trim_prefix(_team_prefix)
		var click: Vector3 = _clicks.get(rec["squad"], Vector3.ZERO)
		row["click"] = [snappedf(click.x, 0.1), snappedf(click.z, 0.1)]
		row["arrived_s"] = snappedf((int(rec["arrived_tick"]) - int(rec["order_tick"])) / 30.0, 0.1) if int(rec["arrived_tick"]) >= 0 else -1.0
		row["min_d_click"] = snappedf(float(rec["min_d_click"]), 0.1) if is_finite(float(rec["min_d_click"])) else -1.0
		for key in ["yield_s", "blocked_s", "kturn_s", "wedged_s", "seat_move_max_m", "d_click_15s", "bound_m", "nose_room_m", "hull_m"]:
			row[key] = snappedf(float(row[key]), 0.1)
		crews.append(row)
		if bool(rec["within_bound_15s"]):
			seated += 1
		yield_blocked += float(rec["yield_s"]) + float(rec["blocked_s"])
		if int(rec["arrived_tick"]) < 0:
			never += 1
			arrival_sum += READ_S
		else:
			arrival_sum += minf((int(rec["arrived_tick"]) - int(rec["order_tick"])) / 30.0, READ_S)
	print("START_RUN " + JSON.stringify({"arena": _flag("arena", ""), "seed": int(_flag("seed", "0")), "arm": _flag("probe-arm", ""),
			"tick": tick, "synth": _synth, "crews": crews.size(), "seated_in_bound_15s": seated,
			"yield_blocked_s": snappedf(yield_blocked, 0.1), "never_arrived": never,
			"arrival_mean_s": snappedf(arrival_sum / maxf(crews.size(), 1.0), 0.01), "per_crew": crews}))


func _step() -> void:
	if _match == null:
		return
	_issue_due(_match.tick)
	var tick: int = _match.tick
	for child in _match.tanks.get_children():
		var tank := child as Tank
		if tank != null and tank.is_alive() and _watched(tank):
			_row(tank, tick)
	_seats(tick)
	_yields(tick)
	while _census_i < _census.size() and int(_census[_census_i]["tick"]) <= tick:
		if int(_census[_census_i]["tick"]) == tick:
			_gap(_census[_census_i], tick)
		_census_i += 1
	if tick >= _until:
		_run_row(tick)
		print("START_DONE " + JSON.stringify({"tick": tick}))
		quit(0)
