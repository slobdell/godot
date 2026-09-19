extends SceneTree
## `make nav-fight` (nav, round 7): WHY a unit is not getting where it was sent, IN A REAL FIGHT. The lead (2026-09-19):
## *"a lot of them just keep getting stuck in places, and that's I think why I'm feeling like the units aren't obeying
## me."* Round 6 measured 100% arrival and 30/30 order completion — both with no enemy (lesson 23 again). This is the
## configuration he plays: two seeded CPU-rostered armies of ~30 on a shipping arena, fighting, with GREEN commanded
## through control's Orders the way a player right-clicks (and control's elements installed, as in a skirmish).
##
## Every tick, every living GREEN unit that has an order and is not at its goal is put in exactly ONE bucket:
##   progressing        closing on its order's goal at > PROGRESS_MPS
##   yielding           giving way to a friend (nav X4)
##   blocked_<cause>    Movement says blocked: a friend's name → blocked_friend, an enemy's → blocked_enemy,
##                      terrain, or no_path (the goal is unreachable: the route only gets it near)
##   halted_shooting    its move order is stop/face and its gun is engaged
##   halted             stop/face with nothing engaged
##   retasked:<OPTION>  it is driving, but to somewhere else than its order (its brain chose OPTION; > RETASK_M away)
##   slow               driving toward its order's goal but under PROGRESS_MPS (turning, crowded, pathing)
## plus: re-task EVENTS (its move target jumping > RETASK_M), unreachable-route ticks, arrivals per order.
## Prints `NAV_FIGHT <json>`. Diagnosis, not a gate.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const PROGRESS_MPS := 0.7
const RETASK_M := 8.0
const AT_GOAL_M := 8.0

var game_match: Match
var orders: Orders
var green: Array[Tank] = []
var buckets := {}        # reason -> ticks
var options := {}        # brain option while retasked -> ticks
var retask_events := 0
var unreachable_ticks := 0
var last_target := {}    # name -> Vector3 (its controller's move_to target last tick)
var last_distance := {}  # name -> distance to its order's goal last tick
var ordered_ticks := 0
var arrivals := 0
var order_count := 0
var issued_tick := 0
var time_limit := 120.0
var phase_two_done := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	time_limit = float(_flag("time-limit", "120"))
	var seed_value := int(_flag("seed", "3"))
	var budget := int(_flag("budget", "6500"))
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = _flag("arena", "yard")
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(seed_value, 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	await physics_frame
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var loaded := Army.load_army("cpu", seed_value + team, budget)
		var error: String = loaded.get("error", "")
		if error == "":
			error = game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			push_error("nav-fight: " + error)
			quit(1)
			return
	orders = Orders.new()
	Orders.attach(game_match, orders)
	Elements.install(game_match, orders)
	for tank: Tank in game_match.tanks.get_children():
		if tank.team == Match.Team.GREEN:
			green.append(tank)
	for frame in SimClock.TICK_RATE:
		await physics_frame
	_order_squads(0.45)  # to the middle of the arena, squads fanned out across it
	issued_tick = game_match.tick
	print("NAV_FIGHT_ISSUED %d green units on %s, seed %d" % [green.size(), Arena.active.get("name", "?"), seed_value])
	physics_frame.connect(_sample)


## Order every GREEN squad (by name: Green_<squad>_<n>) to a lane point `depth` of the way toward the enemy base.
func _order_squads(depth: float) -> void:
	var squads := {}
	for tank in green:
		if not tank.is_alive():
			continue
		var parts := String(tank.name).split("_")
		var squad := parts[1] if parts.size() >= 3 else "?"
		if not squads.has(squad):
			squads[squad] = []
		(squads[squad] as Array).append(String(tank.name))
	var keys := squads.keys()
	keys.sort()
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var away := Match.spawn_position(Match.Team.RUST, 0)
	for i in keys.size():
		var lane := (float(i) - (keys.size() - 1) / 2.0) * 28.0
		var point := home.lerp(away, depth)
		var to := [point.x + lane, point.z]
		var verb := "move" if depth < 0.6 else "attack_move"
		if orders.issue(UnitCommand.make(squads[keys[i]], verb, {"to": to})) == "":
			order_count += (squads[keys[i]] as Array).size()


func _sample() -> void:
	var elapsed := float(game_match.tick - issued_tick) / float(SimClock.TICK_RATE)
	if not phase_two_done and elapsed >= time_limit * 0.4:
		phase_two_done = true
		_order_squads(0.85)  # then attack-move onward: the fight
	var dt := 1.0 / float(SimClock.TICK_RATE)
	for tank in green:
		if not tank.is_alive():
			continue
		var key := String(tank.name)
		var goal_v: Variant = orders.goal_position(key)
		if goal_v == null:
			last_distance.erase(key)
			continue
		var goal: Vector3 = goal_v
		var distance := Vector2(tank.global_position.x - goal.x, tank.global_position.z - goal.z).length()
		var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + key)) as TankBrain
		if brain == null:
			continue
		ordered_ticks += 1
		var move: Dictionary = brain.move_order
		var target := Vector3(float(move.get("x", tank.global_position.x)), 0.0, float(move.get("z", tank.global_position.z)))
		if String(move.get("type", "")) == "move_to":
			if last_target.has(key) and (last_target[key] as Vector3).distance_to(target) > RETASK_M:
				retask_events += 1
			last_target[key] = target
		var reading := Movement.state(tank)
		if reading.get("reachable") == false and String(move.get("type", "")) == "move_to":
			unreachable_ticks += 1
		var closing := (float(last_distance.get(key, distance)) - distance) / dt
		last_distance[key] = distance
		var reason := ""
		if distance <= AT_GOAL_M:
			reason = "at_goal"
		elif closing > PROGRESS_MPS:
			reason = "progressing"
		elif String(reading.get("phase", "")) == "yielding":
			reason = "yielding"
		elif String(reading.get("phase", "")) == "blocked":
			var by := String(reading.get("blocked_by", ""))
			var other := game_match.tanks.get_node_or_null(NodePath(by)) as Tank if by != "" and by != "terrain" and by != "no_path" else null
			reason = "blocked_" + (("friend" if other.team == tank.team else "enemy") if other != null else by)
		elif ["stop", "face"].has(String(move.get("type", ""))):
			reason = "halted_shooting" if brain.engaged_target != "" else "halted"
		elif String(move.get("type", "")) == "move_to" and target.distance_to(Vector3(goal.x, 0.0, goal.z)) > RETASK_M:
			var option := String(brain.choice.get("option", "?"))
			reason = "retasked"
			options[option] = int(options.get(option, 0)) + 1
		else:
			reason = "slow"
		buckets[reason] = int(buckets.get(reason, 0)) + 1
	if elapsed >= time_limit:
		_report(elapsed)


func _report(elapsed: float) -> void:
	physics_frame.disconnect(_sample)
	var seconds := {}
	var share := {}
	for reason: String in buckets:
		seconds[reason] = snappedf(float(buckets[reason]) / SimClock.TICK_RATE, 0.1)
		share[reason] = snappedf(float(buckets[reason]) / maxf(1.0, float(ordered_ticks)), 0.001)
	var retasked_as := {}
	for option: String in options:
		retasked_as[option] = snappedf(float(options[option]) / SimClock.TICK_RATE, 0.1)
	var alive := green.filter(func(t: Tank) -> bool: return t.is_alive()).size()
	var out := {"arena": String(Arena.active.get("name", "?")), "seed": int(_flag("seed", "3")), "green": green.size(),
			"green_alive_end": alive, "seconds": snappedf(elapsed, 0.1),
			"ordered_unit_seconds": snappedf(float(ordered_ticks) / SimClock.TICK_RATE, 0.1),
			"unit_seconds": seconds, "share": share, "retasked_by_option_unit_seconds": retasked_as,
			"retask_events": retask_events,
			"retask_events_per_unit_minute": snappedf(retask_events / maxf(0.01, float(ordered_ticks) / SimClock.TICK_RATE / 60.0), 0.01),
			"unreachable_route_unit_seconds": snappedf(float(unreachable_ticks) / SimClock.TICK_RATE, 0.1)}
	print("NAV_FIGHT %s" % JSON.stringify(out))
	quit(0)
