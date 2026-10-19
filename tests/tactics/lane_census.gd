extends SceneTree
## Round 34 (brains B9, R34.15, MEASUREMENT ONLY): how the CPU commander feeds squads through the Locks' and the
## Terminus' lanes. Traffic's T5 census found the worst jam-death episodes all one shape: two or three squads of ONE side
## fed through one lane under fire (locks-1209 Rust: 7 deaths in 12 s). Showmatch fights (both sides CPU elements):
##   LANE_PICK  each time an element takes a task whose planned route (its navmesh path from its centre to the task's
##              spot) crosses the middle line (z = 0): team, element, lane (the x it crosses at, snapped to the nearest
##              of the arena's north-south lanes), the time.
##   LANE_CENSUS the fight's totals per team: picks, STACKED picks (another squad of the same team picked the same lane
##              within STACK_S before it), deaths, kills, jam deaths (yielding, or blocked by a friend, the tick before).
##   godot --headless --fixed-fps 30 --path . --script res://tests/tactics/lane_census.gd -- --skirmish --demo-match --clean --seed=N --arena=locks --mute --seconds=180

const STACK_S := 20.0
## The north-south lanes' x where they cross the middle (arenas/*.json "lanes").
const LANES_X := {"locks": [-92.0, 0.0, 92.0], "terminus": [-70.0, 0.0, 70.0]}

var _teams := {}
var _picks: Array = []
var _seen := {}
var _printed := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _row(team: int) -> Dictionary:
	return _teams.get_or_add(str(team), {"picks": 0, "stacked": 0, "deaths": 0, "kills": 0, "jam_deaths": 0,
			"stuck_deaths": 0, "first_shot_s": -1.0, "contact_spread_s": 0.0})


## B9's bar: each element's first shot (s), for the side's contact spread (piecemeal arrival).
var _element_first := {}
var _t := 0.0
var _finished_s := -1.0


func _finalize() -> void:
	_report()


func _report() -> void:
	if _printed:
		return
	_printed = true
	for team_key: String in _teams:
		var firsts: Array = []
		for key: String in _element_first:
			if key.begins_with(team_key + ":"):
				firsts.append(float(_element_first[key]))
		if firsts.size() >= 2:
			_teams[team_key]["contact_spread_s"] = snappedf(float(firsts.max()) - float(firsts.min()), 0.1)
	print("LANE_CENSUS " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"finished_s": _finished_s, "ran_s": snappedf(_t, 0.1),
			"teams": _teams, "lane_spread": ElementCommander.LANE_SPREAD, "spread": ElementCommander.lanes_spread}))


## The lane a route takes: where its path first crosses z = 0, snapped to the nearest lane ("" when it does not cross).
static func lane_of(path: PackedVector3Array, lanes: Array) -> String:
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		if (a.z > 0.0) == (b.z > 0.0) or absf(b.z - a.z) < 1e-4:
			continue
		var x := a.x + (b.x - a.x) * (0.0 - a.z) / (b.z - a.z)
		var best := ""
		var gap := INF
		for lx: float in lanes:
			if absf(x - lx) < gap:
				gap = absf(x - lx)
				best = "x%+d" % int(lx)
		return best
	return ""


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		var team := int(event.get("team", -1))
		var row := _row(team)
		row["deaths"] = int(row["deaths"]) + 1
		var victim := game_match.tanks.get_node_or_null(String(event.get("name", event.get("unit", "")))) as Tank
		var mover := Movement.of(victim) if victim != null else null
		if mover != null and (mover.phase == "yielding" or (mover.phase == "blocked" and mover.blocked_by != "")):
			row["jam_deaths"] = int(row["jam_deaths"]) + 1
		elif mover != null and mover.is_under_way() and ((mover.phase == "blocked" and mover.blocked_by == "") \
				or bool(mover.get("wedged"))):
			row["stuck_deaths"] = int(row["stuck_deaths"]) + 1
		var killer := game_match.tanks.get_node_or_null(String(event.get("killer", ""))) as Tank
		if killer != null and String(event.get("cause", "")) == "enemy":
			var k := _row(killer.team)
			k["kills"] = int(k["kills"]) + 1)
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter == null:
			return
		var row := _row(shooter.team)
		if float(row["first_shot_s"]) < 0.0:
			row["first_shot_s"] = snappedf(_t, 0.1)
		var elements := Elements.of_match(game_match)
		var element := elements.of(String(shooter.name)) if elements != null else null
		if element != null:
			var key := "%d:%d" % [shooter.team, element.id]
			if not _element_first.has(key):
				_element_first[key] = _t)
	game_match.finished.connect(func(_result: Dictionary) -> void:
		if _finished_s < 0.0:
			_finished_s = snappedf(_t, 0.1))
	var seconds := float(_flag("seconds", "180"))
	var started := -1
	var last_tick := -1
	var frames := 0
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 10:
				break
			continue
		last_tick = tick
		if started < 0:
			started = tick
		var t := (tick - started) / float(SimClock.TICK_RATE)
		_t = t
		if tick % 15 == 0:
			_observe(game_match, t)
		if seconds > 0.0 and t > seconds:
			break
	_report()
	quit(0)


func _observe(game_match: Match, t: float) -> void:
	var elements := Elements.of_match(game_match)
	if elements == null:
		return
	var lanes: Array = LANES_X.get(String(Arena.active.get("name", "")), [])
	if lanes.is_empty():
		return
	for element: Element in elements.all():
		var key := "%d:%d" % [element.id, element.task_seq]
		if _seen.has(key):
			continue
		var to: Variant = ElementTask.destination(element.task)
		var members := element.members()
		if not (to is Vector3) or members.is_empty():
			continue
		var lead := game_match.tanks.get_node_or_null(NodePath(String(members[0]))) as Tank
		if lead == null or not lead.is_alive():
			continue
		_seen[key] = true
		var path := Pathing.find_path(lead, Vector3(lead.global_position.x, 0.0, lead.global_position.z), to)
		var lane := lane_of(path, lanes)
		# B9: a task sent `via` another lane takes that lane.
		var via: Variant = ElementTask.via(element.task)
		if via is Vector3:
			lane = lane_of(PackedVector3Array([Vector3((via as Vector3).x, 0, 1), Vector3((via as Vector3).x, 0, -1)]), lanes)
		if lane == "":
			continue
		var row := _row(element.team)
		row["picks"] = int(row["picks"]) + 1
		var stacked := false
		for pick: Dictionary in _picks:
			if int(pick["team"]) == element.team and String(pick["lane"]) == lane and int(pick["element"]) != element.id \
					and t - float(pick["t"]) <= STACK_S:
				stacked = true
		if stacked:
			row["stacked"] = int(row["stacked"]) + 1
		var pick := {"team": element.team, "element": element.id, "lane": lane, "t": snappedf(t, 0.1), "stacked": stacked,
				"verb": String(element.task.get("verb", "")), "via": via is Vector3}
		_picks.append(pick)
		print("LANE_PICK " + JSON.stringify(pick))
