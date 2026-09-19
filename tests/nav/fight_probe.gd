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
var halted_as := {}      # brain option while halted -> ticks
var by_verb := {}        # order verb -> {reason -> ticks, "_ticks": ordered ticks under that verb}
var retask_by_verb := {} # order verb -> re-task events
var retask_cause := {}   # "OPTION[ hop][ (switched from X)]" -> re-task events
var last_option := {}    # name -> brain option last tick
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
	# The run's own conditions, checked before any number is produced (arena's positive control, round 7): a number from
	# a run whose conditions weren't met looks exactly like a real one.
	if String(Arena.active.get("name", "")) != _flag("arena", "yard"):
		push_error("nav-fight control FAILED: asked for arena %s, got %s" % [_flag("arena", "yard"), Arena.active.get("name", "?")])
		quit(1)
		return
	var rust := 0
	for tank: Tank in game_match.tanks.get_children():
		rust += 1 if tank.team == Match.Team.RUST else 0
	if green.is_empty() or rust == 0:
		push_error("nav-fight control FAILED: armies of %d and %d units" % [green.size(), rust])
		quit(1)
		return
	var stacked := 0
	var all: Array = game_match.tanks.get_children()
	for i in all.size():
		for j in range(i + 1, all.size()):
			if (all[i] as Tank).global_position.distance_to((all[j] as Tank).global_position) < 1.0:
				stacked += 1
	# Stacked starts separate (Avoidance parts coincident hulls by name), so this is reported, not fatal.
	# The treatment, read live from the code under test (not from the flag passed): an A/B arm is only an arm if this
	# differs between them.
	print("NAV_FIGHT_ARM commit=%s fixed_style=%s avoidance=%s station=%s off=%s" % [CombatMotion.commit_on(),
			CombatMotion.fixed_style, Movement.avoidance_on, Movement.station_on, Movement._off])
	print("NAV_FIGHT_CONTROL arena %s, green %d, rust %d, %d pairs start on top of each other" % [
			Arena.active.get("name", "?"), green.size(), rust, stacked])
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
	var dump := OS.get_cmdline_user_args().has("--where") and (game_match.tick - issued_tick) % (SimClock.TICK_RATE * 6) == 0 \
			and not phase_two_done
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
				var v := String(orders.current(key).get("verb", "?"))
				retask_by_verb[v] = int(retask_by_verb.get(v, 0)) + 1
				# Who moved the target: the same option re-aiming (a CombatMotion hop is `direct`), or a change of mind.
				var option_now := String(brain.choice.get("option", "?"))
				var cause := "%s%s%s" % [option_now, " hop" if bool(move.get("direct", false)) else "",
						"" if option_now == String(last_option.get(key, option_now)) else " (switched from %s)" % last_option[key]]
				retask_cause[cause] = int(retask_cause.get(cause, 0)) + 1
			last_target[key] = target
		last_option[key] = String(brain.choice.get("option", "?")) if not last_option.has(key) else last_option[key]
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
			var why := String(brain.choice.get("option", "?"))
			halted_as[why] = int(halted_as.get(why, 0)) + 1
		elif String(move.get("type", "")) == "move_to" and target.distance_to(Vector3(goal.x, 0.0, goal.z)) > RETASK_M:
			var option := String(brain.choice.get("option", "?"))
			reason = "retasked"
			options[option] = int(options.get(option, 0)) + 1
		else:
			reason = "slow"
		buckets[reason] = int(buckets.get(reason, 0)) + 1
		if dump and not ["progressing", "at_goal"].has(reason):
			print("NAV_FIGHT_WHERE t=%.0f %s at (%.1f, %.1f) goal (%.1f, %.1f) %s by=%s option=%s speed=%.1f stalled=%.1fs reachable=%s steer=%s" % [
					elapsed, key, tank.global_position.x, tank.global_position.z, goal.x, goal.z, reason,
					reading.get("blocked_by", ""), brain.choice.get("option", "?"), tank.speed(), float(reading.get("stalled_s", 0.0)),
					reading.get("reachable"), reading.get("steer_to")])
		last_option[key] = String(brain.choice.get("option", "?"))
		var verb := String(orders.current(key).get("verb", "?"))
		var per_verb: Dictionary = by_verb.get(verb, {})
		per_verb[reason] = int(per_verb.get(reason, 0)) + 1
		per_verb["_ticks"] = int(per_verb.get("_ticks", 0)) + 1
		by_verb[verb] = per_verb
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
	var halted_opt := {}
	for option: String in halted_as:
		halted_opt[option] = snappedf(float(halted_as[option]) / SimClock.TICK_RATE, 0.1)
	var verbs := {}
	for verb: String in by_verb:
		var d: Dictionary = by_verb[verb]
		var total := float(d["_ticks"])
		var row := {"unit_seconds": snappedf(total / SimClock.TICK_RATE, 0.1),
				"retask_events_per_unit_minute": snappedf(int(retask_by_verb.get(verb, 0)) / maxf(0.01, total / SimClock.TICK_RATE / 60.0), 0.01)}
		for reason: String in d:
			if reason != "_ticks":
				row[reason] = snappedf(float(d[reason]) / total, 0.001)
		verbs[verb] = row
	var alive := green.filter(func(t: Tank) -> bool: return t.is_alive()).size()
	var rust_units: Array = game_match.tanks.get_children().filter(func(t: Tank) -> bool: return t.team == Match.Team.RUST)
	var rust_alive := rust_units.filter(func(t: Tank) -> bool: return t.is_alive()).size()
	var hops := 0
	var switches := 0
	for cause: String in retask_cause:
		if cause.contains("(switched"):
			switches += int(retask_cause[cause])
		else:
			hops += int(retask_cause[cause])
	var minutes := maxf(0.01, float(ordered_ticks) / SimClock.TICK_RATE / 60.0)
	var out := {"arena": String(Arena.active.get("name", "?")), "seed": int(_flag("seed", "3")), "green": green.size(),
			"green_alive_end": alive, "rust": rust_units.size(), "rust_alive_end": rust_alive,
			"green_lost": green.size() - alive, "rust_lost": rust_units.size() - rust_alive,
			"shots": game_match.stats.get("shots", []),
			"motion_jumps_per_unit_minute": snappedf(hops / minutes, 0.01),
			"decision_jumps_per_unit_minute": snappedf(switches / minutes, 0.01), "seconds": snappedf(elapsed, 0.1),
			"ordered_unit_seconds": snappedf(float(ordered_ticks) / SimClock.TICK_RATE, 0.1),
			"unit_seconds": seconds, "share": share, "retasked_by_option_unit_seconds": retasked_as,
			"retask_events": retask_events, "retask_cause": retask_cause, "halted_by_option_unit_seconds": halted_opt, "by_verb": verbs,
			"retask_events_per_unit_minute": snappedf(retask_events / maxf(0.01, float(ordered_ticks) / SimClock.TICK_RATE / 60.0), 0.01),
			"unreachable_route_unit_seconds": snappedf(float(unreachable_ticks) / SimClock.TICK_RATE, 0.1)}
	print("NAV_FIGHT %s" % JSON.stringify(out))
	quit(0)
