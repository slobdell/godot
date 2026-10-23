extends SceneTree
## Round 38 (manoeuvre M7 = O5 v2's trace; measurement only): orders' seat_yield_census.gd (tests/control/, orders' path), copied
## here and extended, so the screen-to-support_by_fire give-ways O5 v1 left (R37.32: 251 -> 255) can be read: each SEAT_YIELD row
## also carries the yielder's seat, the asker crew's position and move goal, the asker element's task `to` and members' centre,
## and how far the seat lies from (way) the asker element's centre-to-task segment (what O5's aside step tests), (crew) the
## asker crew's own segment to its goal, and (goal) the asker's goal itself.
##
## Orders' header follows.
## Round 37 (orders O5, R36.11, measurement only): crews HOLDING a seat that give way to ANOTHER element's crew driving
## through it. Traffic's two-fight trace found 9 of 11 jam:yielding deaths were a crew holding a CPU element's screen /
## support_by_fire seat in a one-hull street while another element's crew drove through it. Showmatch fights (both
## sides CPU, as jam_census runs them); every tick, for every living crew whose element has ARRIVED on a seat task
## (screen, support_by_fire, hold) and whose Movement is giving way (`yield_to`) to a friend of ANOTHER element:
##   SEAT_YIELD {...}  one row per give-way episode: unit, team, verb, the asker, its element's verb, where, how far the
##                     yielder is from its seat when asked, how long the episode lasted, whether the yielder died in it or
##                     within DIED_S after (the R36.11 death).
##   SEAT_YIELD_CENSUS {...}  the fight's totals by verb (episodes, deaths), and all deaths.
##   godot --headless --fixed-fps 30 --path . --script res://tests/control/seat_yield_census.gd -- --skirmish --demo-match \
##         --clean --seed=N --arena=A --mute --seconds=180 [--seat-aside=on]

const SEAT_VERBS := ["screen", "support_by_fire", "hold"]
const DIED_S := 3.0

var _open := {}  # unit -> episode dict
var _closed: Array = []  # episodes awaiting the DIED_S window
var _totals := {}
var _deaths := 0
var _deaths_by_team := {}
var _seconds_run := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		_deaths += 1
		var side := str(event.get("team", -1))
		_deaths_by_team[side] = int(_deaths_by_team.get(side, 0)) + 1)
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
		_seconds_run = (tick - started) / float(SimClock.TICK_RATE)
		_observe(game_match)
		if seconds > 0.0 and _seconds_run > seconds:
			break
	for unit: String in _open.keys():
		_close(unit, game_match.tick, false)
	for episode: Dictionary in _closed:
		_emit(episode)
	_closed.clear()
	print("SEAT_YIELD_CENSUS " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"seconds": snappedf(_seconds_run, 0.1), "deaths": _deaths, "deaths_by_team": _deaths_by_team, "by_verb": _totals,
			"seat_aside": "on" if ElementCommander.SEAT_ASIDE else "off", "seats_aside": ElementCommander.seats_aside,
			"seats_aside_failed": ElementCommander.seats_aside_failed}))
	quit(0)


func _observe(game_match: Match) -> void:
	var tick := game_match.tick
	var elements := Elements.of_match(game_match)
	var alive := {}
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank == null or not tank.is_alive():
			continue
		var name := String(tank.name)
		alive[name] = true
		var mover := Movement.of(tank)
		var mine: Element = elements.of(name) if elements != null else null
		var asker := mover.yield_to if mover != null else ""
		var seated := mine != null and mine.arrived and SEAT_VERBS.has(String(mine.task.get("verb", "")))
		var theirs: Element = elements.of(asker) if elements != null and asker != "" else null
		var other := game_match.tanks.get_node_or_null(NodePath(asker)) as Tank if asker != "" else null
		var counts := seated and other != null and other.team == tank.team and theirs != mine
		if counts and not _open.has(name):
			var seat: Variant = mine.slots.get(name)
			_open[name] = {"unit": name, "team": tank.team, "element": mine.element_name,
					"cpu": tank.team != OrderFeed.player_team(game_match), "verb": String(mine.task.get("verb", "")),
					"asker": asker, "asker_verb": String(theirs.task.get("verb", "")) if theirs != null else "-",
					"at": [snappedf(tank.global_position.x, 0.1), snappedf(tank.global_position.z, 0.1)],
					"seat_m": snappedf(Vector2(tank.global_position.x - (seat as Vector3).x,
							tank.global_position.z - (seat as Vector3).z).length(), 0.1) if seat is Vector3 else -1.0,
					"start": tick, "s": snappedf(_seconds_run, 0.1)}
			_ways(_open[name], seat, other, theirs, game_match)
		elif not counts and _open.has(name):
			_close(name, tick, false)
	for unit: String in _open.keys():
		if not alive.has(unit):
			_close(unit, tick, true)
	# A closed episode whose yielder dies within DIED_S counts as its death too.
	var keep: Array = []
	for episode: Dictionary in _closed:
		if not bool(episode["died"]) and not alive.has(String(episode["unit"])):
			episode["died"] = true
			episode["died_after"] = true
		if bool(episode["died"]) or tick - int(episode["end"]) > int(DIED_S * SimClock.TICK_RATE):
			_emit(episode)
		else:
			keep.append(episode)
	_closed = keep


func _close(unit: String, tick: int, died: bool) -> void:
	var episode: Dictionary = _open[unit]
	_open.erase(unit)
	episode["end"] = tick
	episode["yield_s"] = snappedf((tick - int(episode["start"])) / float(SimClock.TICK_RATE), 0.1)
	episode["died"] = died
	_closed.append(episode)


func _emit(episode: Dictionary) -> void:
	var key := "%s:%s" % ["cpu" if bool(episode["cpu"]) else "player", String(episode["verb"])]
	var row: Dictionary = _totals.get_or_add(key, {"episodes": 0, "deaths": 0})
	row["episodes"] = int(row["episodes"]) + 1
	if bool(episode["died"]):
		row["deaths"] = int(row["deaths"]) + 1
	print("SEAT_YIELD " + JSON.stringify(episode))


static func _seg_m(p: Vector3, a: Vector3, b: Vector3) -> float:
	var q := Vector2(p.x, p.z)
	return snappedf(q.distance_to(Geometry2D.get_closest_point_to_segment(q, Vector2(a.x, a.z), Vector2(b.x, b.z))), 0.1)


func _ways(episode: Dictionary, seat: Variant, asker: Tank, theirs: Element, game_match: Match) -> void:
	if not (seat is Vector3):
		return
	var s: Vector3 = seat
	episode["seat"] = [snappedf(s.x, 0.1), snappedf(s.z, 0.1)]
	var here := asker.global_position
	episode["asker_at"] = [snappedf(here.x, 0.1), snappedf(here.z, 0.1)]
	var mover := Movement.of(asker)
	var order: Dictionary = mover.ctl.move_order if mover != null else {}
	if String(order.get("type", "")) == "move_to":
		var goal := Vector3(float(order.get("x", 0.0)), 0.0, float(order.get("z", 0.0)))
		episode["asker_goal"] = [snappedf(goal.x, 0.1), snappedf(goal.z, 0.1)]
		episode["crew_m"] = _seg_m(s, here, goal)
		episode["goal_m"] = snappedf(Vector2(goal.x - s.x, goal.z - s.z).length(), 0.1)
	if theirs == null:
		return
	episode["asker_arrived"] = theirs.arrived
	var centre := Vector3.ZERO
	var n := 0
	for unit: String in theirs.members():
		var t := game_match.tanks.get_node_or_null(NodePath(unit)) as Tank
		if t != null and t.is_alive():
			centre += t.global_position
			n += 1
	if n == 0:
		return
	centre /= n
	var to: Variant = ElementTask.destination(theirs.task)
	if to is Vector3:
		episode["asker_task_to"] = [snappedf((to as Vector3).x, 0.1), snappedf((to as Vector3).z, 0.1)]
		episode["way_m"] = _seg_m(s, centre, to)
		episode["task_to_m"] = snappedf(Vector2((to as Vector3).x - s.x, (to as Vector3).z - s.z).length(), 0.1)
	var slot: Variant = theirs.slots.get(String(asker.name))
	if slot is Vector3:
		episode["asker_slot_m"] = snappedf(Vector2((slot as Vector3).x - s.x, (slot as Vector3).z - s.z).length(), 0.1)
		episode["slot_way_m"] = _seg_m(s, centre, slot)
