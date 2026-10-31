extends "res://tests/replay_orders.gd"
## Round 47 (route R1): his match replayed (tests/replay_orders.gd, unchanged) with a ROUTE trace of named crews.
## `--route-trace=NAME[,NAME...]` (`all` = every crew): one ROUTE_TRACE <json> line whenever what a crew is routed along
## changes -- its crew order, the goal its drive plans to (`Movement._path_goal`), the route it drives (`_path`), its
## element's covered route or transit -- with the route's length by the navmesh, the SHORTEST drivable length from where
## it stands to that same goal and to its order's target (both `Pathing.query`), and why the drive re-planned
## (`last_replan`). `--route-trace-every=N` adds a pose line every N ticks (default 30). Measurement only.
## `--stage-tick=T`: his match does not replay past ~12 s (divergence.py, his Locks: first crew over 3 m at s 20), so the
## trace can START from his census instead: on the first tick every crew stands where his census row at or before T had
## it (hull and shield as there; a crew missing from it is destroyed), the last order he gave each set of units before T
## (with the queued ones after it) is issued again at once, and his later orders follow at their tick - T. A STAGED
## situation (the elements' and the CPU's plans are rebuilt, not his), so what it shows is what the code does from his
## positions, never a replay of his match.
##   make route-trace RECORDING=... ROUTE_CREWS=Green_Hunters_4 [REPLAY_SECONDS=80] [STAGE_TICK=1440]

var _route_names: PackedStringArray = []
var _route_every := 30
var _route_last := {}
var _staged := false


func _trace() -> void:
	super()
	if not _staged:
		_staged = true
		var at := int(_flag("stage-tick", "-1"))
		if at >= 0:
			_stage(at)
	if _route_names.is_empty():
		var wanted := _flag("route-trace", "")
		if wanted == "":
			return
		_route_names = wanted.split(",")
		_route_every = int(_flag("route-trace-every", "30"))
	for tank: Tank in _match.sorted_team_tanks(0) + _match.sorted_team_tanks(1):
		if not tank.is_alive() or not (_route_names.has("all") or _route_names.has(String(tank.name))):
			continue
		_route_one(tank)


static func _length(start: Vector3, points: PackedVector3Array) -> float:
	var total := 0.0
	var prev := start
	for p in points:
		total += Vector2(p.x - prev.x, p.z - prev.z).length()
		prev = p
	return total


static func _pts(points: Variant) -> Array:
	var out: Array = []
	for p: Vector3 in points:
		out.append([snappedf(p.x, 0.1), snappedf(p.z, 0.1)])
	return out


func _shortest(tank: Tank, to: Vector3) -> Dictionary:
	var here := tank.global_position
	var q := Pathing.query(tank, Vector3(here.x, 0.0, here.z), Vector3(to.x, 0.0, to.z))
	var points: PackedVector3Array = q["points"]
	return {"m": snappedf(_length(here, points), 0.1), "reachable": q["reachable"], "via": _pts(points)}


func _route_one(tank: Tank) -> void:
	var name := String(tank.name)
	var mover := Movement.of(tank)
	if mover == null:
		return
	var here := tank.global_position
	var order: Dictionary = mover.ctl.move_order
	var element: Element = _controls.elements.of(name) if _controls.elements != null else null
	var el_route: Array = element.route if element != null else []
	var el_transit: Array = element.transit.get("route", []) if element != null else []
	var key := [JSON.stringify(order), mover._path_goal, mover._path, el_route, el_transit,
			element.task.get("verb", "") if element != null else ""]
	var last: Variant = _route_last.get(name)
	var changed := last == null or str(last) != str(key)
	if not changed and (_route_every <= 0 or _match.tick % _route_every != 0):
		return
	_route_last[name] = key
	var row := {"tick": _match.tick, "n": name, "pos": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)],
			"phase": mover.phase, "order": order, "replan": String(mover.last_replan), "hp": tank.health}
	var brain := mover.ctl as TankBrain
	if brain != null:
		row["brain"] = String(brain.choice.get("option", ""))
		row["why"] = brain.why
	if not changed:
		print("ROUTE_POSE " + JSON.stringify(row))
		return
	var goal := mover._path_goal
	if goal != Vector3.INF:
		row["goal"] = [snappedf(goal.x, 0.1), snappedf(goal.z, 0.1)]
		row["route_m"] = snappedf(_length(here, mover._path.slice(mover._path_index)), 0.1)
		row["route"] = _pts(mover._path)
		row["route_index"] = mover._path_index
		row["shortest_to_goal"] = _shortest(tank, goal)
	var target := String(order.get("target", ""))
	if target != "":
		var victim := _match.tanks.get_node_or_null(NodePath(target)) as Tank
		if victim != null:
			var at := victim.global_position
			row["target_pos"] = [snappedf(at.x, 0.1), snappedf(at.z, 0.1)]
			row["straight_to_target"] = snappedf(Vector2(at.x - here.x, at.z - here.z).length(), 0.1)
			row["shortest_to_target"] = _shortest(tank, at)
	if element != null:
		row["element"] = {"name": element.element_name, "task": element.task, "route": _pts(el_route),
				"route_index": element.route_index, "transit": _pts(el_transit), "technique": element.technique,
				"reason": element.reason}
	print("ROUTE_TRACE " + JSON.stringify(row))


func _stage(at: int) -> void:
	var census := {}
	var census_tick := -1
	var path := _flag("orders", "")
	var file := FileAccess.open(path, FileAccess.READ)
	while file != null and not file.eof_reached():
		var line := file.get_line()
		if not line.contains("\"census\""):
			continue
		var row: Variant = JSON.parse_string(line)
		if row is Dictionary and String(row.get("t", "")) == "census" and int(row.get("tick", -1)) <= at \
				and int(row.get("tick", -1)) > census_tick:
			census_tick = int(row["tick"])
			census = {}
			for unit: Dictionary in row.get("units", []):
				census[String(unit["n"])] = unit
	var placed := 0
	var destroyed := 0
	for tank: Tank in _match.sorted_team_tanks(0) + _match.sorted_team_tanks(1):
		var unit: Variant = census.get(String(tank.name))
		if unit == null:
			if tank.is_alive():
				tank.apply_damage(tank.health)
				destroyed += 1
			continue
		var pos: Array = unit["pos"]
		tank.place(Vector3(float(pos[0]), tank.global_position.y, float(pos[1])), tank.rotation.y)
		tank.health = clampi(int(unit.get("hp", tank.health)), 1, tank.max_health)
		tank.shield = float(unit.get("shield", tank.shield))
		placed += 1
	# His orders: before T, the last unqueued order per set of units and the queued ones after it, issued now; after
	# T, each at its tick - T. Already issued (the planning pause) is issued again: a new order replaces it.
	var before: Array = []
	var after: Array = []
	for o: Dictionary in _orders:
		if int(o["tick"]) < at:
			before.append(o)
		else:
			var shifted := o.duplicate()
			shifted["tick"] = int(o["tick"]) - at + _match.tick
			after.append(shifted)
	var keep: Array = []
	var seen := {}
	for i in range(before.size() - 1, -1, -1):
		var key := ",".join(PackedStringArray(before[i]["units"]))
		if seen.has(key):
			continue
		keep.push_front(before[i].merged({"tick": _match.tick}, true))
		if not bool(before[i].get("queue", false)):
			seen[key] = true
	_orders = keep + after
	_next = 0
	_until += _match.tick
	print("ROUTE_STAGE " + JSON.stringify({"at": at, "census_tick": census_tick, "placed": placed, "destroyed": destroyed,
			"reissued": keep.size(), "later": after.size()}))
	_issue()
