extends SceneTree
## Round 47 (route R6, R47.12): THE ROUTE CENSUS. Does a crew take the short way, measured over whole fights rather than
## by his eye? CPU v CPU fights (both sides under the computer's squad leaders, set up as tests/control/deploy_census.gd),
## and for every crew its LEGS: a leg starts when its drive is given a new destination (`Movement.last_replan` =
## `goal_jumped`, or a new crew order type / target) and ends at the next one, its death, or the fight's end. Per leg:
## the metres it drove (the flat distance between its positions tick to tick), the navmesh's shortest from where the leg
## started to where it ended (Pathing.query, asked once at the leg's end, from its start), and the brain's option when
## the leg began (a travel leg, MOVE / KEEP_SLOT / ADVANCE / REGROUP / no brain, is the route's question; ORBIT, RETREAT and
## the like drive what the fight asks, and are reported apart).
##
##   ROUTE_LEG {"arena","seed","n","team","unit","option","order","start","end","driven_m","shortest_m","tick0","tick1",
##              "goal_moved_m" (the farthest its drive goal got from the leg's first goal), "replans"}
##   ROUTE_CENSUS {"arena","seed","green","rust","legs","ended_s"}
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/route/route_census.gd -- --arena=locks --seed=12501
##         --green=law --rust=gangs --credits=1000 --seconds=150

## Legs shorter than this (navmesh metres start to end) are turning, not routing: not printed.
const MIN_SHORTEST_M := 15.0

var case: TestCase
var _arena := ""
var _seed := 0
var _legs := 0


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _order_key(order: Dictionary) -> String:
	return "%s|%s" % [String(order.get("type", "")), String(order.get("target", ""))]


func _close(t: Tank, leg: Dictionary, tick: int) -> void:
	var start: Vector3 = leg["start"]
	var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
	var shortest := 0.0
	var route := Pathing.query(t, start, here)
	var points: PackedVector3Array = route["points"]
	for i in range(1, points.size()):
		shortest += Vector2(points[i].x - points[i - 1].x, points[i].z - points[i - 1].z).length()
	if shortest < MIN_SHORTEST_M:
		return
	_legs += 1
	print("ROUTE_LEG " + JSON.stringify({"arena": _arena, "seed": _seed, "n": String(t.name), "team": t.team,
			"unit": String(t.unit_id), "option": leg["option"], "order": leg["order"],
			"start": [snappedf(start.x, 0.1), snappedf(start.z, 0.1)], "end": [snappedf(here.x, 0.1), snappedf(here.z, 0.1)],
			"driven_m": snappedf(float(leg["driven"]), 0.1), "shortest_m": snappedf(shortest, 0.1),
			"tick0": leg["tick"], "tick1": tick, "goal_moved_m": snappedf(float(leg.get("goal_moved", 0.0)), 0.1),
			"replans": int(leg.get("replans", 0))}))


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	_seed = int(_flag("seed", "1"))
	_arena = _flag("arena", "locks")
	var credits := int(_flag("credits", "1000"))
	var factions := {Match.Team.GREEN: _flag("green", "law"), Match.Team.RUST: _flag("rust", "gangs")}
	var army_probe: GDScript = load("res://tests/tactics/army_probe.gd")
	var lab := TacticsLab.create(case, _seed, _arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	for team: int in factions:
		var built: Dictionary = army_probe.army(String(factions[team]), _seed * 2 + team, credits, "opponent")
		if built.has("error"):
			push_error("route census: %s" % built["error"])
			quit(1)
			return
		var error := lab.game_match.load_doctrine(team, built["doctrine"])
		if error != "":
			push_error("route census load_doctrine: %s" % error)
			quit(1)
			return
	await lab.start()
	for team: int in factions:
		for squad in lab.game_match.team_squads(team):
			lab.elements.form(Array(squad.roster), String(squad.squad_name))
		ElementCommander.install(lab.game_match, team, lab.elements)
	var legs := {}  # crew name -> {"start", "last", "driven", "option", "order", "key", "tick"}
	var ended := -1
	var ticks := int(float(_flag("seconds", "150")) * SimClock.TICK_RATE)
	for tick in ticks:
		await lab.step()
		var alive := [0, 0]
		for child in lab.game_match.tanks.get_children():
			var t := child as Tank
			if t == null:
				continue
			var name := String(t.name)
			if not t.is_alive():
				if legs.has(name):
					_close(t, legs[name], tick)
					legs.erase(name)
				continue
			alive[t.team] += 1
			var mover := Movement.of(t)
			if mover == null:
				continue
			var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
			var brain := mover.ctl as TankBrain
			var option := String(brain.choice.get("option", "")) if brain != null else ""
			var key := _order_key(mover.ctl.move_order)
			var leg: Variant = legs.get(name)
			if leg == null or mover.last_replan == &"goal_jumped" or String(leg["key"]) != key:
				if leg != null:
					_close(t, leg, tick)
				leg = {"start": here, "last": here, "driven": 0.0, "option": option, "order": String(mover.ctl.move_order.get("type", "")),
						"key": key, "tick": tick}
				legs[name] = leg
			if mover._path_goal != Vector3.INF:
				var goal := mover._path_goal
				if not leg.has("goal0"):
					leg["goal0"] = goal
				var goal0: Vector3 = leg["goal0"]
				leg["goal_moved"] = maxf(float(leg.get("goal_moved", 0.0)), Vector2(goal.x - goal0.x, goal.z - goal0.z).length())
			if mover.last_replan != &"":
				leg["replans"] = int(leg.get("replans", 0)) + 1
			var last: Vector3 = leg["last"]
			leg["driven"] = float(leg["driven"]) + Vector2(here.x - last.x, here.z - last.z).length()
			leg["last"] = here
		if alive[0] == 0 or alive[1] == 0:
			ended = tick
			break
	for child in lab.game_match.tanks.get_children():
		var t := child as Tank
		if t != null and t.is_alive() and legs.has(String(t.name)):
			_close(t, legs[String(t.name)], ticks if ended < 0 else ended)
	print("ROUTE_CENSUS " + JSON.stringify({"arena": _arena, "seed": _seed, "green": factions[0], "rust": factions[1],
			"credits": credits, "legs": _legs, "ended_s": snappedf(ended / float(SimClock.TICK_RATE), 0.1) if ended >= 0 else -1.0}))
	lab.dispose()
	case.teardown()
	quit(0)
