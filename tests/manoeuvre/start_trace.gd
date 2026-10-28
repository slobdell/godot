extends SceneTree
## Round 43 (manoeuvre S1): REBUILD THE START of a recorded match and trace its crews per tick. The lead's first order
## on Locks 56416 (2026-10-27) had three of five crews arrive, one yield 20 s in the deploy zone and one route the long
## way round; the census in the recording is one row a second with position, phase and blocked-by only, so the chain
## (who yields to whom and why, the seat each crew drives to, the route) has to come from a headless rebuild.
##
## Like tests/replay_orders.gd (native's) it starts the same seed / arena / factions and issues the recording's orders at
## their ticks, and on top of that:
##   --snap-deploy      put every unit where the recording's tick-0 census has it before the match starts (his census is
##                      the ground truth; a laptop match's spawn can differ by a hull's nudge)
##   tick-0 orders      issued INSIDE the planning pause, as he gave them (the replay issues them at tick 1)
##   --crews=Guns,Hunters  the squads (name prefixes after the team's) whose crews are traced
##   --every=N          a trace row every N ticks (default 1)
##   --trace-seconds=S  how long (default 20)
## Rows (grep the prefix):
##   START_ROW   one per traced crew per tick: pos, heading, speed, phase, blocked_by, yield (to/spot), the mover's goal,
##               distance to it, remaining path, steer point, pace, stalled s, reverse why, k-turn, gate, wedged, the
##               order (verb/source), the element's seat for it (slot and the order the element issued) and its distance
##   START_SEAT  the element's seating whenever it changes: formation, pitch, file, corridor, heading, anchor, reason and
##               every member's slot index + slot
##   START_YIELD every give-way begun (Movement.yield_log's diagnosis row)
##   START_GAP   once a second: each traced crew's distance from where the recording's census has it (the rebuild's fidelity)
##   START_ORDER / START_SETUP / START_DONE   as the replay
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/start_trace.gd -- --orders=build/X.jsonl \
##         --arena=locks --seed=56416 --squad-cap=4 --crews=Guns,Hunters --snap-deploy --trace-seconds=20 --mute [any game switch]
## --arena and --seed MUST be on the real command line (native, R43.1): Arena._ready reads OS user args, not Main.next_flags,
## so a replay that only sets next_flags builds the DEFAULT map with the recording's deploy zone. The probe refuses to run
## without them.

const MAIN := "res://game/main.tscn"

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
	for extra: String in ["--skirmish", "--enemy=cpu", "--seed=%d" % int(_header.get("seed", 0)),
			"--arena=%s" % String(_header.get("arena", "locks")), "--no-pick-faction", "--hints=off",
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
	_crews = _flag("crews", "Guns,Hunters").split(",")
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
	Movement.yield_log = true
	# His first orders were given inside the planning pause (tick 0); issue them there too.
	_issue_due(_match.tick)
	print("START_SETUP " + JSON.stringify({"orders": _orders.size(), "census_rows": _census.size(), "seed": _header.get("seed"),
			"arena": _header.get("arena"), "tick": _match.tick, "units": _match.tanks.get_child_count(), "snapped": snapped,
			"native": NativeBridge.impl != null}))
	if paused:
		_controls.set_paused(false, "")
	physics_frame.connect(_step)


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


func _row(tank: Tank, tick: int) -> void:
	var mover := Movement.of(tank)
	var here := tank.global_position
	var fwd := -tank.global_basis.z
	var order: Dictionary = _controls.orders.current(String(tank.name)) if _controls.orders != null else {}
	var element := _element_of(String(tank.name))
	var seat := "-"
	var dseat := "-"
	var slot := "-"
	if element != null:
		var issued := element.issued_to(String(tank.name))
		var to: Variant = issued.get("to")
		if to is Vector3:
			seat = _v2(to)
			dseat = "%.1f" % _flat(here, to)
		elif to is Array and (to as Array).size() >= 2:
			seat = _v2(to)
			dseat = "%.1f" % Vector2(here.x - float(to[0]), here.z - float(to[1])).length()
		if element.slots.has(String(tank.name)):
			slot = _v2(element.slots[String(tank.name)])
	var line := "START_ROW t=%d n=%s x=%.1f z=%.1f hdg=%.0f spd=%.1f" % [tick, String(tank.name).trim_prefix(_team_prefix), here.x, here.z,
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
		var body := "el=%s form=%s tech=%s drill=%s pitch=(%.1f,%.1f) file=%.2f corr=%s hdg=(%.2f,%.2f) anchor=%s task=%s why=\"%s\" | %s" % [
				element.element_name, element.formation, element.technique, element.drill, element.pitch.x, element.pitch.y, element.file,
				("%.1f" % element.corridor_m) if is_finite(element.corridor_m) else "inf", element.heading.x, element.heading.z,
				_v2(element.anchor), JSON.stringify(element.task), element.reason, " ".join(parts)]
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


func _step() -> void:
	if _match == null:
		return
	_issue_due(_match.tick)
	var tick: int = _match.tick
	if tick % _every == 0:
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
		print("START_DONE " + JSON.stringify({"tick": tick}))
		quit(0)
