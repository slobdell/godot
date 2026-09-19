extends SceneTree
## `make squad-decisions` (squad, round 7): what the ~23-45 "re-task events per unit-minute" under attack-move ARE. nav's
## `make nav-fight` counts a unit's drive target jumping > 8 m; nav changed movement a lot and that number did not move,
## so it looked like the decider. But a drive target can jump inside ONE decision too (CombatMotion re-plans its circle,
## swaps strafe side, jinks) — the evasion the lead asked for in round 3. This splits every jump by cause, in nav's own
## fight (same armies, arena, seed and orders), and counts the one shape that is thrash whatever the cause:
##   jumps_decision      the brain's option or target changed on that tick
##   jumps_motion        same option and target: the manoeuvre moved its own steer point
##   reversals           option+target left and RETURNED to within REVERSAL_S (A -> B -> A)
## Measured only while GREEN is attack-moving (the fight phase). Prints DECISION_PROBE <json>.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
const RETASK_M := 8.0
const REVERSAL_S := 3.0

var game_match: Match
var orders: Orders
var green: Array[Tank] = []
var time_limit := 120.0
var fight_from := -1
var last_target := {}
var last_label := {}
var history := {}
var counts := {"jumps_decision": 0, "jumps_motion": 0, "reversals": 0, "switches": 0, "unit_ticks": 0}
var motion_by_option := {}
var reversal_pairs := {}


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
			push_error("squad-decisions: " + error)
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
	_order_squads(0.45, "move")
	var start := game_match.tick
	while game_match.tick - start < int(time_limit * 0.4 * SimClock.TICK_RATE):
		await physics_frame
	_order_squads(0.85, "attack_move")
	fight_from = game_match.tick
	while game_match.tick - fight_from < int(time_limit * 0.6 * SimClock.TICK_RATE):
		_sample()
		await physics_frame
	var minutes := maxf(float(counts["unit_ticks"]) / (SimClock.TICK_RATE * 60.0), 0.01)
	print("DECISION_PROBE " + JSON.stringify({"seed": seed_value, "arena": Arena.active.get("name", "?"),
			"unit_minutes": snappedf(minutes, 0.01),
			"jumps_decision_per_unit_min": snappedf(counts["jumps_decision"] / minutes, 0.1),
			"jumps_motion_per_unit_min": snappedf(counts["jumps_motion"] / minutes, 0.1),
			"switches_per_unit_min": snappedf(counts["switches"] / minutes, 0.1),
			"reversals_per_unit_min": snappedf(counts["reversals"] / minutes, 0.1),
			"motion_jumps_by_option": motion_by_option, "top_reversals": CoherenceProbe.top(reversal_pairs, 8)}))
	quit(0)


## Every GREEN squad to a lane point `depth` of the way toward the enemy base (nav-fight's orders, exactly).
func _order_squads(depth: float, verb: String) -> void:
	var squads := {}
	for tank in green:
		if not tank.is_alive():
			continue
		var parts := String(tank.name).split("_")
		var squad := parts[1] if parts.size() >= 3 else "?"
		(squads.get_or_add(squad, []) as Array).append(String(tank.name))
	var keys := squads.keys()
	keys.sort()
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	var away := Match.spawn_position(Match.Team.RUST, 0)
	for i in keys.size():
		var lane := (float(i) - (keys.size() - 1) / 2.0) * 28.0
		var point := home.lerp(away, depth)
		orders.issue(UnitCommand.make(squads[keys[i]], verb, {"to": [point.x + lane, point.z]}))


func _sample() -> void:
	var window := int(REVERSAL_S * SimClock.TICK_RATE)
	for tank in green:
		if not tank.is_alive():
			continue
		var key := String(tank.name)
		var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + key)) as TankBrain
		if brain == null or brain.choice.is_empty() or orders.current(key).is_empty():
			continue
		counts["unit_ticks"] += 1
		var label := "%s %s" % [brain.choice.get("option", ""), brain.choice.get("target", "")]
		var changed: bool = last_label.has(key) and String(last_label[key]) != label
		if changed:
			counts["switches"] += 1
			var seen: Array = history.get_or_add(key, [])
			if seen.size() >= 2 and String(seen[-2][0]) == label and game_match.tick - int(seen[-1][1]) <= window:
				counts["reversals"] += 1
				var pair := "%s <-> %s" % [label.split(" ")[0], String(seen[-1][0]).split(" ")[0]]
				reversal_pairs[pair] = int(reversal_pairs.get(pair, 0)) + 1
		var seen2: Array = history.get_or_add(key, [])
		if seen2.is_empty() or String(seen2[-1][0]) != label:
			seen2.append([label, game_match.tick])
			if seen2.size() > 3:
				seen2.pop_front()
		last_label[key] = label
		var move: Dictionary = brain.move_order
		if String(move.get("type", "")) == "move_to":
			var target := Vector3(float(move["x"]), 0.0, float(move["z"]))
			if last_target.has(key) and (last_target[key] as Vector3).distance_to(target) > RETASK_M:
				if changed:
					counts["jumps_decision"] += 1
				else:
					counts["jumps_motion"] += 1
					var option := String(brain.choice.get("option", "?"))
					motion_by_option[option] = int(motion_by_option.get(option, 0)) + 1
			last_target[key] = target
		else:
			last_target.erase(key)
