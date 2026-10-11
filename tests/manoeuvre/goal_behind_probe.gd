extends SceneTree
## `make manoeuvre-behind` (round 26, manoeuvre M0a): the lead's short move behind, counted.
##
## *"if I have a unit selected and I select a point to move to that's immediately behind it, the vehicle will do this
## N point turn to clumsily rotate in place and then eventually drive the very short distance to the point. A smart
## vehicle would have just reversed onto the point or did other 3 point turn maneuver"*
##
## One vehicle of a hull class (HULL: tank = tracks, scout = wheels R 5 m, gang_tank = the War Rig, wheels R 12 m) on the
## open band of `yard_open`, a player's plain move (through control's Orders, source "player", exactly as a right-click)
## to a goal 5 / 10 / 20 m dead astern or 10 m at 120 / 150 degrees off the nose, with no facing or with a drawn facing
## (the start heading: "back onto the spot, keep looking where you looked"). Per case, from the order's tick:
##   done_s     the order completed (Orders says idle)
##   settled_s  the hull at rest for SETTLE_HOLD_S after completion (a post facing turned after arrival counts)
##   legs       motion legs: runs of |speed| > CUSP_DEADBAND in one gear (a forward and a reverse leg = 2)
##   pivot_s    seconds turning in place (|speed| <= dead band, yaw rate > PIVOT_RATE_DEG): a tracked pivot
##   heading_deg  total |yaw change|, start to settled
##   metres     metres driven
##   end_m / end_heading_err   distance from the goal and heading off the start heading when settled
## Pooled over pre-registered start ticks (C26.6, lesson 283: the order lands on tick {1,3,6,8,11,16} after the
## settle) and seeds (SEEDS: seed > 1 jitters the start heading by +/- SEED_JITTER_DEG; even seeds mirror the
## angled goals to the left). One fresh match per case on one arena. Prints `MANOEUVRE_BEHIND <json>` per case and
## `MANOEUVRE_BEHIND_DONE <n>`.

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")
## The open band's middle: nothing within ~30 m (yard_open props are at |x| >= 34 or |z| >= 56 near here).
const START := Vector3(0.0, 0.0, 15.0)
const CASES := [["astern", 5.0, 180.0], ["astern", 10.0, 180.0], ["astern", 20.0, 180.0], ["off120", 10.0, 120.0],
		["off150", 10.0, 150.0]]
const START_TICKS := [1, 3, 6, 8, 11, 16]
const CUSP_DEADBAND := 0.3
const PIVOT_RATE_DEG := 10.0
const SETTLE_HOLD_S := 1.0
const SEED_JITTER_DEG := 6.0
const LIMIT_S := 45.0

var arena: Node3D
var hull := "tank"
var _trace := false


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	hull = _flag("hull", "tank")
	_trace = _flag("trace", "") != ""
	var seeds: Array = Array(_flag("seeds", "1,2,3").split(",")).map(func(s: String) -> int: return int(s))
	var ticks: Array = START_TICKS
	if _flag("ticks", "") != "":
		ticks = Array(_flag("ticks", "").split(",")).map(func(s: String) -> int: return int(s))
	var only := _flag("case", "")
	arena = ARENA.instantiate()
	arena.layout_name = "yard_open"
	root.add_child(arena)
	var n := 0
	for seed_value: int in seeds:
		for c: Array in CASES:
			if only != "" and "%s%d" % [c[0], int(c[1])] != only:
				continue
			for facing: bool in [false, true]:
				for t: int in ticks:
					var row := await _case(seed_value, c, facing, t)
					print("MANOEUVRE_BEHIND %s" % JSON.stringify(row))
					n += 1
	print("MANOEUVRE_BEHIND_DONE %d" % n)
	quit(0)


func _case(seed_value: int, c: Array, facing: bool, start_tick: int) -> Dictionary:
	var game_match: Match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(seed_value, 0.0)
	game_match.elimination = true
	game_match.set_meta("player_team", Match.Team.GREEN)
	var orders := Orders.new()
	Orders.attach(game_match, orders)
	var executor := OrderExecutor.new()
	executor.game_match = game_match
	executor.orders = orders
	game_match.add_child(executor)
	var tank_name := "Green_M_1"
	var tank := game_match.add_brain_tank(Match.Team.GREEN, "M", hull, [{}], tank_name)
	# yaw 0 = nose north (-z); seed > 1 turns the start by a jitter that alternates sign.
	var yaw := 0.0
	if seed_value > 1:
		yaw = deg_to_rad(SEED_JITTER_DEG * (1.0 if seed_value % 2 == 0 else -1.0) * float(seed_value - 1) / 2.0)
	tank.place(START, yaw)
	for i in 30:
		await physics_frame
		if Pathing.is_ready(tank):
			break
	for i in SimClock.TICK_RATE + start_tick:
		await physics_frame
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	# The goal: `off` degrees off the nose, to the right on odd seeds and the left on even (a right turn of the nose is
	# a negative angle in x/z here: rotate the nose clockwise seen from above).
	var off := deg_to_rad(float(c[2])) * (1.0 if seed_value % 2 == 1 else -1.0)
	var dir := nose.rotated(off)
	var here := Vector2(tank.global_position.x, tank.global_position.z)
	var to := here + dir * float(c[1])
	var command := {"units": [tank_name], "verb": "move", "to": [to.x, to.y], "queue": false, "source": "player"}
	if facing:
		command["facing"] = [nose.x, nose.y]
	var error := orders.issue(command)
	if error != "":
		push_error("manoeuvre-behind: " + error)
	var issued := game_match.tick
	var goal: Variant = null
	var done := -1.0
	var settled := -1.0
	var still := 0
	var legs := 0
	var gear := 0
	var pivot_ticks := 0
	var heading_total := 0.0
	var metres := 0.0
	var last_pos := tank.global_position
	var last_nose := nose
	var reverse_m := 0.0
	var kturns0 := Movement.kturns
	var multi0 := Movement.kturn_multi
	var circle0 := Movement.circle_reverses
	for frame in int(LIMIT_S * SimClock.TICK_RATE):
		await physics_frame
		var t := float(game_match.tick - issued) / float(SimClock.TICK_RATE)
		var g: Variant = orders.goal_position(tank_name)
		if g != null:
			goal = g
		var speed := tank.speed()
		var now_nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
		var turned := absf(last_nose.angle_to(now_nose))
		heading_total += turned
		var step := Vector2(tank.global_position.x - last_pos.x, tank.global_position.z - last_pos.z).length()
		metres += step
		if speed < -CUSP_DEADBAND:
			reverse_m += step
		last_pos = tank.global_position
		last_nose = now_nose
		var g_now := 0
		if speed > CUSP_DEADBAND:
			g_now = 1
		elif speed < -CUSP_DEADBAND:
			g_now = -1
		if g_now != 0 and g_now != gear:
			legs += 1
			gear = g_now
		if g_now == 0 and rad_to_deg(turned) * SimClock.TICK_RATE > PIVOT_RATE_DEG:
			pivot_ticks += 1
		if _trace and frame % (SimClock.TICK_RATE / 2) == 0:
			var brain := game_match.brains.get_node_or_null("Brain_" + tank_name) as TankBrain
			var r := Movement.state(tank)
			print("MANOEUVRE_TRACE t %.1f at (%.1f, %.1f) nose (%.2f, %.2f) speed %.2f cmd %.2f/%.2f phase %s option %s move %s idle %s" % [
					t, tank.global_position.x, tank.global_position.z, now_nose.x, now_nose.y, speed, tank.command.throttle,
					tank.command.turn, r.get("phase"), brain.choice.get("option", "") if brain else "-",
					JSON.stringify(brain.move_order) if brain else "-", orders.is_idle(tank_name)])
		# Done when Orders says idle again (an order completed on its first tick never shows a goal: still done).
		if done < 0.0 and frame >= 1 and orders.is_idle(tank_name):
			done = t
		var resting := absf(speed) < 0.1 and rad_to_deg(turned) * SimClock.TICK_RATE < 1.0
		still = still + 1 if resting else 0
		if done >= 0.0 and still >= int(SETTLE_HOLD_S * SimClock.TICK_RATE):
			settled = t - SETTLE_HOLD_S
			break
	var at := Vector2(tank.global_position.x, tank.global_position.z)
	var end_m := at.distance_to(to) if goal == null else at.distance_to(Vector2((goal as Vector3).x, (goal as Vector3).z))
	var end_nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var row := {"hull": hull, "seed": seed_value, "case": "%s%d" % [c[0], int(c[1])], "facing": facing,
			"start_tick": start_tick, "done_s": snappedf(done, 0.01), "settled_s": snappedf(settled, 0.01), "legs": legs,
			"pivot_s": snappedf(float(pivot_ticks) / SimClock.TICK_RATE, 0.01),
			"heading_deg": snappedf(rad_to_deg(heading_total), 1.0), "metres": snappedf(metres, 0.1),
			"reverse_m": snappedf(reverse_m, 0.1), "end_m": snappedf(end_m, 0.1),
			"end_heading_err": snappedf(rad_to_deg(absf(nose.angle_to(end_nose))), 1.0),
			"kturns": Movement.kturns - kturns0, "kturn_multi": Movement.kturn_multi - multi0,
			"circle_reverses": Movement.circle_reverses - circle0,
			"start": [snappedf(here.x, 0.1), snappedf(here.y, 0.1), snappedf(rad_to_deg(atan2(nose.x, -nose.y)), 0.1)]}
	game_match.free()
	await physics_frame
	return row
