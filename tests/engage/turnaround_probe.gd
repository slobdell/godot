extends SceneTree
## Round 43 (engage A1): HIS WAR RIG'S TURNAROUND, rebuilt from the census. His recording
## (`_agents/streams/references/round42/playtest/2026-10-27T20-00-48-locks.jsonl.gz`, Locks, seed 56416, Gangs v
## Syndicate): under his attack-move to the far quay (-100, -15) at tick 445, Green_Guns_1 reached the west bank at
## (-105, 46) by tick 660, then turned and drove 100 m back to the north-east edge over 20 s, fired nothing, met nothing.
##
## This probe stands EVERY living unit where the census at `--from` put it (hp and shield as recorded, the yaw read from
## its motion), forms both sides' elements, gives each the task row it held at that tick, then replays every later
## TASK row at its tick (his orders as the element tasks they became; the CPU commander's tasks likewise) and prints one
## ENGAGE_TA line per sample tick (and on every change) for `--crew`: the order it holds, the element's task / drill /
## anchor / crossing / route / its slot, the brain's choice and move, the mover's phase, goal and path, the planner
## seam's last refusal. ENGAGE_TA_SUMMARY at the end: the largest drive AWAY from the order's point, the farthest
## north-east, the end. Any game switch on the command line applies (--attack-shot=off, --nav-off=kturn, ...).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/engage/turnaround_probe.gd -- \
##         --recording=build/engage/his.jsonl --from=420 --seconds=40 --every=15 --crew=Green_Guns_1 \
##         [--green-tasks=off] [--rust-tasks=off] [--point=-100.25,-14.6]

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _r(x: float) -> float:
	return snappedf(x, 0.1)


func _xz(v: Variant) -> Variant:
	if v is Vector3:
		return [_r((v as Vector3).x), _r((v as Vector3).z)]
	if v is Array and (v as Array).size() >= 2:
		return [_r(float((v as Array)[0])), _r(float((v as Array)[1]))]
	return null


func _element_of(unit_name: String) -> Array:
	# "Green_Guns_1" -> ["Green", "Guns"]; "Rust_Hunters_4" -> ["Rust", "Hunters"]
	var parts := unit_name.split("_")
	if parts.size() < 3:
		return [parts[0], unit_name]
	return [parts[0], "_".join(parts.slice(1, parts.size() - 1))]


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var path := _flag("recording", "build/engage/his.jsonl")
	var from_tick := int(_flag("from", "420"))
	var seconds := float(_flag("seconds", "40"))
	var every := int(_flag("every", "15"))
	var crew_name := _flag("crew", "Green_Guns_1")
	var green_tasks := _flag("green-tasks", "on") != "off"
	var rust_tasks := _flag("rust-tasks", "on") != "off"
	var point_text := _flag("point", "-100.25,-14.6")
	var order_point := Vector3(float(point_text.split(",")[0]), 0.0, float(point_text.split(",")[1]))

	var header := {}
	var census: Array = []
	var tasks: Array = []
	var orders_rows: Array = []
	for line in FileAccess.get_file_as_string(path).split("\n"):
		if line.strip_edges() == "":
			continue
		var row: Variant = JSON.parse_string(line)
		if not (row is Dictionary):
			continue
		match String(row["t"]):
			"match": header = row
			"census": census.append(row)
			"task": tasks.append(row)
			"order": orders_rows.append(row)
	if header.is_empty() or census.is_empty():
		print("ENGAGE_TA_DONE {\"error\": \"no recording at %s\"}" % path)
		quit(2)
		return
	var roster := {}
	for u: Dictionary in header.get("units", []):
		roster[String(u["name"])] = u
	# The census to stage from: the first at or after --from; its neighbours for the yaw.
	var at := 0
	while at < census.size() - 1 and int(census[at]["tick"]) < from_tick:
		at += 1
	var stage: Dictionary = census[at]
	var before: Dictionary = census[maxi(at - 1, 0)]
	var after: Dictionary = census[mini(at + 1, census.size() - 1)]
	var stage_tick := int(stage["tick"])
	var by_name := func(row: Dictionary, n: String) -> Variant:
		for u: Dictionary in row["units"]:
			if String(u["n"]) == n:
				return u
		return null

	var lab := TacticsLab.create(case, int(header.get("seed", 56416)), String(header.get("arena", "locks")))
	var game_match := lab.game_match
	game_match.set_meta("player_team", Match.Team.GREEN)
	var placed := {}
	var members := {}  # [team, element] -> names
	for u: Dictionary in stage["units"]:
		var n := String(u["n"])
		var info: Dictionary = roster.get(n, {})
		if info.is_empty() or float(u.get("hp", 0.0)) <= 0.0:
			continue
		var team := int(u.get("team", info.get("team", 0)))
		var pos := Vector3(float(u["pos"][0]), 0.0, float(u["pos"][1]))
		var prev: Variant = by_name.call(before, n)
		var next: Variant = by_name.call(after, n)
		var dir := Vector3.ZERO
		if prev != null:
			dir = pos - Vector3(float(prev["pos"][0]), 0.0, float(prev["pos"][1]))
		if dir.length() < 0.5 and next != null:
			dir = Vector3(float(next["pos"][0]), 0.0, float(next["pos"][1])) - pos
		if dir.length() < 0.5:
			dir = Vector3(0.0, 0.0, -1.0) if team == Match.Team.GREEN else Vector3(0.0, 0.0, 1.0)
		var yaw := atan2(-dir.x, -dir.z)
		var tank := lab.unit(team, n, pos, yaw, String(info.get("id", "tank")))
		tank.health = int(float(u.get("hp", tank.health)))
		tank.shield = float(u.get("shield", 0.0))
		placed[n] = {"pos": pos, "yaw": yaw}
		var key := _element_of(n)
		var k := "%d|%s" % [team, key[1]]
		if not members.has(k):
			members[k] = []
		(members[k] as Array).append(n)
	await lab.start()
	# Form the elements and give each the task it held at the stage tick (the latest task row at or before it).
	var elements := {}
	for k: String in members:
		var names: Array = members[k]
		names.sort()
		var team := int(k.split("|")[0])
		var label := k.split("|")[1]
		var element := lab.elements.form(names, label)
		if element == null:
			continue
		elements[k] = element
		var held := {}
		for t: Dictionary in tasks:
			if int(t["team"]) == team and String(t["element"]) == label and int(t["tick"]) <= stage_tick:
				held = t["task"]
		if not held.is_empty() and ((team == Match.Team.GREEN and green_tasks) or (team == Match.Team.RUST and rust_tasks)):
			var err := element.assign(held)
			print("ENGAGE_TA_STAGE %s" % JSON.stringify({"element": label, "team": team, "members": names, "task": held, "error": err}))
		else:
			print("ENGAGE_TA_STAGE %s" % JSON.stringify({"element": label, "team": team, "members": names, "task": held, "skipped": true}))
	var crew := lab.tank_of(crew_name)
	if crew == null:
		print("ENGAGE_TA_DONE {\"error\": \"no crew %s at tick %d\"}" % [crew_name, stage_tick])
		quit(2)
		return
	var crew_key := "%d|%s" % [crew.team, _element_of(crew_name)[1]]
	var brain := game_match.brains.get_node("Brain_" + crew_name) as TankBrain
	var orders := lab.orders
	var pending: Array = []
	for t: Dictionary in tasks:
		if int(t["tick"]) > stage_tick:
			pending.append(t)
	var offset := stage_tick - game_match.tick  # recording tick = lab tick + offset
	print("ENGAGE_TA_SETUP %s" % JSON.stringify({"from": stage_tick, "lab_tick": game_match.tick, "placed": placed.size(),
			"elements": elements.size(), "pending_tasks": pending.size(), "crew": crew_name, "crew_at": _xz(placed[crew_name]["pos"]),
			"crew_yaw_deg": _r(rad_to_deg(placed[crew_name]["yaw"])), "attack_shot": ElementPlan.ATTACK_SHOT,
			"point": _xz(order_point), "arena": String(Arena.active.get("name", ""))}))

	var last := ""
	var rows := 0
	var start_pos: Vector3 = placed[crew_name]["pos"]
	var last_pos := start_pos
	var nearest := start_pos.distance_to(order_point)
	var away_m := 0.0
	var away_from := 0  # the recording tick the largest drive away began
	var away_begin_tick := 0
	var far_ne := start_pos
	var bridge_tick := -1
	var moved_m := 0.0
	for tick in int(seconds * SimClock.TICK_RATE):
		# The later task rows, at their recording ticks (his orders as tasks; the CPU's tasks likewise).
		var rec_tick := game_match.tick + offset
		while not pending.is_empty() and int(pending[0]["tick"]) <= rec_tick:
			var t: Dictionary = pending.pop_front()
			var k := "%d|%s" % [int(t["team"]), String(t["element"])]
			var wanted: bool = (int(t["team"]) == Match.Team.GREEN and green_tasks) or (int(t["team"]) == Match.Team.RUST and rust_tasks)
			if not wanted or not elements.has(k) or (t["task"] as Dictionary).is_empty():
				continue
			var err: String = (elements[k] as Element).assign(t["task"])
			print("ENGAGE_TA_TASK %s" % JSON.stringify({"rec_tick": int(t["tick"]), "lab_tick": game_match.tick, "element": t["element"],
					"team": t["team"], "task": t["task"], "error": err}))
		await lab.step()
		if not crew.is_alive():
			print("ENGAGE_TA_TASK %s" % JSON.stringify({"lab_tick": game_match.tick, "crew_dead": crew_name}))
			break
		var pos := Vector3(crew.global_position.x, 0.0, crew.global_position.z)
		moved_m += pos.distance_to(last_pos)
		last_pos = pos
		var d := pos.distance_to(order_point)
		if d < nearest:
			nearest = d
			away_begin_tick = game_match.tick + offset
		elif d - nearest > away_m:
			away_m = d - nearest
			away_from = away_begin_tick
		if pos.x + pos.z > far_ne.x + far_ne.z:
			far_ne = pos
		if bridge_tick < 0 and absf(pos.x + 92.0) < 10.0 and absf(pos.z) < 12.0:
			bridge_tick = game_match.tick + offset
		var speed := Vector2(crew.estimated_velocity.x, crew.estimated_velocity.z).length()
		var order: Dictionary = orders.call("current", crew_name)
		var element: Element = lab.elements.of(crew_name)
		var mover := Movement.of(crew)
		var reading: Dictionary = mover.reading() if mover != null else {}
		var path_points: PackedVector3Array = reading.get("path_points", PackedVector3Array())
		var path_head: Array = []
		for i in mini(path_points.size(), 4):
			path_head.append(_xz(path_points[i]))
		var issued: Dictionary = element.issued_to(crew_name) if element != null else {}
		var refusal := PlannerSeam.last_refusal(crew_name)
		var row := {
			"t": game_match.tick + offset, "lab": game_match.tick, "pos": _xz(pos), "yaw": _r(rad_to_deg(crew.rotation.y)),
			"speed": _r(speed), "dist": _r(d), "hp": crew.health,
			"order": String(order.get("verb", "")), "order_goal": _xz(order.get("goal")), "order_target": String(order.get("target", "")),
			"order_src": String(order.get("source", "")), "order_tick": int(order.get("issued_tick", -1)) + offset if not order.is_empty() else null,
			"task": element.task.get("verb", "") if element != null else "-", "task_to": _xz(element.task.get("to")) if element != null else null,
			"task_target": String(element.task.get("target", "")) if element != null else "",
			"drill": element.drill if element != null else "-", "why_el": element.reason if element != null else "-",
			"form": element.formation if element != null else "-", "tech": element.technique if element != null else "-",
			"anchor": _xz(element.anchor) if element != null else null, "heading": _xz(element.heading) if element != null else null,
			"el_arrived": element.arrived if element != null else null,
			"crossing": [_xz(element.crossing.get("entry")), _xz(element.crossing.get("exit"))] if element != null and not element.crossing.is_empty() else null,
			"route_n": element.route.size() if element != null else 0, "route_i": element.route_index if element != null else 0,
			"transit": not element.transit.is_empty() if element != null else null,
			"slot": _xz(element.slots.get(crew_name)) if element != null else null,
			"slot_asked": _xz(element.slots_asked.get(crew_name)) if element != null else null,
			"station": _xz(element.stations.get(crew_name)) if element != null else null,
			"pace": element.paces.get(crew_name) if element != null else null,
			"issued": String(issued.get("verb", "")), "issued_to": _xz(issued.get("to")), "issued_tick": int(issued.get("tick", -1)) + offset if not issued.is_empty() else null,
			"choice": String(brain.choice.get("option", "")), "choice_target": String(brain.choice.get("target", "")), "why": brain.why,
			"move": String(brain.move_order.get("type", "")),
			"move_to": [_r(float(brain.move_order.get("x", 0.0))), _r(float(brain.move_order.get("z", 0.0)))] if brain.move_order.has("x") else null,
			"brain_station": _xz(brain.element.get("station")), "role": brain.element.get("role", ""),
			"phase": mover.phase if mover != null else "-", "blocked": mover.blocked_by if mover != null else "-",
			"stalled": mover.stalled_ticks if mover != null else -1, "goal": _xz(reading.get("goal")),
			"path": path_head, "path_n": path_points.size(), "path_end": _xz(path_points[path_points.size() - 1]) if path_points.size() > 0 else null,
			"remaining": _r(float(reading.get("remaining_m", 0.0))), "reachable": reading.get("reachable"),
			"replan": String(reading.get("replan", "")), "kturn": mover._kturn_left_m > 0.0 if mover != null else null,
			"refusal": refusal, "engaged": brain.engaged_target,
		}
		var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [row["order"], row["order_goal"], row["task"], row["drill"], row["choice"], row["move"],
				row["phase"], row["slot"], row["path_end"]]
		if key != last or tick % every == 0:
			print("ENGAGE_TA %s" % JSON.stringify(row))
			rows += 1
		last = key
	print("ENGAGE_TA_SUMMARY %s" % JSON.stringify({"crew": crew_name, "from": stage_tick, "seconds": seconds,
			"start": _xz(start_pos), "end": _xz(last_pos), "moved_m": _r(moved_m), "nearest_m": _r(nearest), "end_dist": _r(last_pos.distance_to(order_point)),
			"away_m": _r(away_m), "away_began": away_from, "far_ne": _xz(far_ne), "on_bridge_tick": bridge_tick,
			"planner": PlannerSeam.report(), "rows": rows, "attack_shot": ElementPlan.ATTACK_SHOT}))
	print("ENGAGE_TA_DONE")
	lab.dispose()
	quit(0)
