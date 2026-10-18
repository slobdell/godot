extends SceneTree
## Round 33 (traffic X1, C33.2 (1)): the far ask loop's census on any skirmish workload. Runs main.tscn with the
## command line it was given (fights: `--skirmish --demo-match`; hull-rest: `--skirmish --screen-test=...`), and every
## physics tick picks up the H1B_FAR rows manoeuvre's H1b wrote since the last one (ManoeuvreCensus.h1b_far_rows, read
## only) and adds what the BLOCKER was doing that same tick: set up to fire, its order verb, the brain's option, its
## element's task, how far it stands from its own goal / slot, and why it refused the ask (fire post, just yielded to this
## asker, already giving way). Measurement only: nothing here is read by a decision.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/traffic/far_census.gd -- --skirmish --demo-match
##         --clean --seed=<n> --arena=terminus --mute [--seconds=180]
##   FAR_ROW {...}        one per far loop (H1B_FAR's fields + the blocker's)
##   FAR_CENSUS {...}     once at the end: seed, arena, elements formed per team, h1b and give-way counters
##   --far-trace=A,B[,..] FAR_TRACE {...} every 0.5 s for the named hulls (position, heading, phase, yield, escape stage,
##                        order verb, option, goal and slot distance) from --far-trace-from=<s> to --far-trace-to=<s>


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _v(p: Variant) -> Variant:
	return [snappedf((p as Vector3).x, 0.1), snappedf((p as Vector3).z, 0.1)] if p is Vector3 else null


## The blocker's side of one far row, read the tick the row was written.
static func _blocker_side(game_match: Match, row: Dictionary) -> Dictionary:
	var out := {}
	var tank := game_match.tanks.get_node_or_null(String(row.get("blocker", ""))) as Tank
	if tank == null:
		return {"b_gone": true}
	var mover := Movement.of(tank)
	var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + String(tank.name))) as TankBrain
	var me := String(row.get("unit", ""))
	out["b_deploy"] = snappedf(tank.deploy_ratio, 0.01)
	var asker_tank := game_match.tanks.get_node_or_null(me) as Tank
	if mover != null and asker_tank != null and not mover.is_under_way():
		# The dry run touches two counters and one field of the mover's (measurement only): restored after.
		var saved := [mover._yield_unfit_last, Movement.yield_spots_unfit, Movement.yield_spots_refused]
		out["b_spots"] = _spot_reasons(mover, asker_tank)
		mover._yield_unfit_last = saved[0]
		Movement.yield_spots_unfit = saved[1]
		Movement.yield_spots_refused = saved[2]
	if mover != null:
		out["b_fire_post"] = mover.on_fire_post()
		out["b_yield_to"] = mover.yield_to
		out["b_last_yielded_to_me"] = mover._last_yielded_to == me
		out["b_goal_m"] = snappedf(_flat(tank.global_position, mover._goal), 0.1) if mover._goal != Vector3.INF else -1.0
	if brain != null:
		out["b_order_verb"] = String(brain.order.get("verb", ""))
		out["b_move_type"] = String(brain.move_order.get("type", ""))
		out["b_option"] = String(brain.choice.get("option", ""))
		out["b_engaged"] = brain.engaged_target != ""
		out["b_elem_task"] = String((brain.element.get("task", {}) as Dictionary).get("verb", "")) if brain.element.get("task") is Dictionary else ""
		var slot: Variant = brain.element.get("slot")
		out["b_slot_m"] = snappedf(_flat(tank.global_position, slot), 0.1) if slot is Vector3 else -1.0
		out["b_role"] = String(brain.element.get("role", ""))
	var asker := game_match.brains.get_node_or_null(NodePath("Brain_" + me)) as TankBrain
	if asker != null:
		out["a_order_verb"] = String(asker.order.get("verb", ""))
		out["a_option"] = String(asker.choice.get("option", ""))
		out["a_elem_task"] = String((asker.element.get("task", {}) as Dictionary).get("verb", "")) if asker.element.get("task") is Dictionary else ""
	return out


var _rows := 0
var _formed := {}
var _seconds_run := 0.0
var _printed := false
var _teams := {}


func _fight_row(team: int) -> Dictionary:
	return _teams.get_or_add(str(team), {"shots": 0, "hits": 0, "kills": 0, "deaths": 0})


## Printed here as well as at the end of _run, so a workload that quits the tree itself (hull-rest's screen test) still
## reports.
func _finalize() -> void:
	_report()


func _report() -> void:
	if _printed:
		return
	_printed = true
	print("FAR_CENSUS " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"seconds": snappedf(_seconds_run, 0.1), "elements": _formed, "far_rows": _rows,
			"h1b": ManoeuvreCensus.h1b_report(), "h1b_on": Movement.h1b_on(),
			"setup_refusals": Movement.setup_refusals,
			"yields_started": Movement.yields_started, "asks_refused": Movement.asks_refused, "teams": _teams}))


static func _trace_row(game_match: Match, name: String) -> Dictionary:
	var tank := game_match.tanks.get_node_or_null(name) as Tank
	if tank == null:
		return {"unit": name, "gone": true}
	var mover := Movement.of(tank)
	var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + name)) as TankBrain
	var forward := -tank.global_basis.z
	var row := {"unit": name, "at": _v(tank.global_position), "hdg": snappedf(rad_to_deg(atan2(forward.x, -forward.z)), 1.0),
			"v": snappedf(tank.speed(), 0.1), "deploy": snappedf(tank.deploy_ratio, 0.01), "id": tank.unit_id,
			"box": [snappedf(float(Movement.hull_box(tank.unit_id)[0]), 0.1), snappedf(float(Movement.hull_box(tank.unit_id)[2]), 0.1)]}
	if mover != null:
		row.merge({"phase": mover.phase, "yield_to": mover.yield_to, "spot": mover.yield_spot,
				"yield_pt": _v(mover._yield_point) if mover._yield_point != Vector3.INF else null,
				"last_yielded": mover._last_yielded_to, "esc": mover._esc_stage, "blocked_by": mover.blocked_by,
				"goal": _v(mover._goal) if mover._goal != Vector3.INF else null, "left_m": snappedf(mover._remaining, 0.1),
				"h1b_failed": mover._h1b_failed})
	if brain != null:
		var slot: Variant = brain.element.get("slot")
		row.merge({"verb": String(brain.order.get("verb", "")), "option": String(brain.choice.get("option", "")),
				"move": String(brain.move_order.get("type", "")),
				"slot": _v(slot) if slot is Vector3 else null})
	return row


## A dry run of `_begin_yield`'s spot search for the blocker asked by `asker` (the escape's ask: along = asker → blocker),
## each candidate with the first predicate that rejected it ("ok" = it would be taken). Reads only; never starts a yield.
static func _spot_reasons(mover: Movement, asker: Tank) -> Array:
	var out := []
	var tank := mover.ctl.tank
	var here := tank.global_position
	var from := asker.global_position
	var along := Vector2(here.x - from.x, here.z - from.z).normalized()
	if along == Vector2.ZERO:
		return out
	var across := Vector2(-along.y, along.x)
	var side := 1.0 if across.dot(Vector2(here.x - from.x, here.z - from.z)) >= 0.0 else -1.0
	var line_clear := Avoidance.radius_of(tank.unit_id) + Avoidance.radius_of(asker.unit_id) + Movement.YIELD_LINE_MARGIN
	var check := func(point: Vector3, on_line: bool) -> String:
		if on_line and Movement._distance_to_ray(point, from, along) < line_clear:
			return "line"
		if _flat(point, from) < _flat(here, from):
			return "toward"
		if mover.wheel_radius() > 0.0 and not mover._ahead_of_wheels(point) and not mover._straight_behind(point):
			return "wheels"
		if not mover._free_spot(point, String(tank.name), String(asker.name)):
			if Pathing.enabled and Pathing.is_ready(tank):
				var on_mesh := Pathing.closest_point(tank.get_world_3d().navigation_map, point, "yield")
				if _flat(on_mesh, point) > Movement.YIELD_MESH_SLACK:
					return "offmesh"
			return "crowded"
		if not mover._yield_fits(point):
			return "nofit"
		return "ok"
	for spot: Vector2 in Movement.YIELD_SPOTS:
		for flip: float in ([side, -side] if spot.y != 0.0 else [side]):
			var offset := along * spot.x + across * (spot.y * flip)
			out.append("s(%d,%d):%s" % [int(spot.x), int(spot.y * flip),
					check.call(Vector3(here.x + offset.x, 0.0, here.z + offset.y), spot.y != 0.0)])
	var back := Vector2(tank.global_basis.z.x, tank.global_basis.z.z).normalized()
	for distance: float in Movement.YIELD_BACK_UP:
		out.append("b(%d):%s" % [int(distance), check.call(Vector3(here.x + back.x * distance, 0.0, here.z + back.y * distance), false)])
	return out


func _run() -> void:
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	# L3's fight counters (manoeuvre's fight_census's definitions): shots, hits on an enemy hull, kills, deaths per team.
	var shooter_of := {}
	game_match.weapon_fired.connect(func(event: Dictionary) -> void:
		var shooter := game_match.tanks.get_node_or_null(String(event.get("shooter", ""))) as Tank
		if shooter == null:
			return
		var row_shots := _fight_row(shooter.team)
		row_shots["shots"] = int(row_shots["shots"]) + 1
		shooter_of[event.get("projectile_id", -1)] = shooter.team)
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		var team: Variant = shooter_of.get(event.get("projectile_id", -1))
		if team == null or not event.has("target"):
			return
		var victim := game_match.tanks.get_node_or_null(String(event["target"])) as Tank
		if victim != null and victim.team != int(team):
			var row_hits := _fight_row(int(team))
			row_hits["hits"] = int(row_hits["hits"]) + 1)
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		var row_deaths := _fight_row(int(event.get("team", -1)))
		row_deaths["deaths"] = int(row_deaths["deaths"]) + 1
		var killer := game_match.tanks.get_node_or_null(String(event.get("killer", ""))) as Tank
		if killer != null and String(event.get("cause", "")) == "enemy":
			var row_kills := _fight_row(killer.team)
			row_kills["kills"] = int(row_kills["kills"]) + 1)
	var seconds := float(_flag("seconds", "180"))
	var started := -1
	var last_tick := -1
	var frames := 0
	var seen := ManoeuvreCensus.h1b_far_rows.size()
	var traced := _flag("far-trace", "").replace("+", " ").split(",", false)  # '+' for a space ("Green_Eyes+II_3")
	var trace_from := float(_flag("far-trace-from", "0"))
	var trace_to := float(_flag("far-trace-to", "100000"))
	while true:
		await physics_frame
		frames += 1
		if game_match == null or not is_instance_valid(game_match):
			break
		while seen < ManoeuvreCensus.h1b_far_rows.size():
			var row: Dictionary = (ManoeuvreCensus.h1b_far_rows[seen] as Dictionary).duplicate()
			row.merge(_blocker_side(game_match, row))
			row["tick"] = game_match.tick
			print("FAR_ROW " + JSON.stringify(row))
			seen += 1
			_rows += 1
		var tick := game_match.tick
		if tick == last_tick:
			if frames > 60 * 60 * 10:
				break
			continue
		last_tick = tick
		if started < 0:
			started = tick
		var elements := Elements.of_match(game_match)
		if elements != null and tick % 30 == 0:
			for team in [0, 1]:
				_formed[str(team)] = maxi(int(_formed.get(str(team), 0)), elements.of_team(team).size())
		_seconds_run = (tick - started) / float(SimClock.TICK_RATE)
		if not traced.is_empty() and tick % (SimClock.TICK_RATE / 2) == 0 and _seconds_run >= trace_from and _seconds_run <= trace_to:
			for name in traced:
				var t := _trace_row(game_match, name)
				t["s"] = snappedf(_seconds_run, 0.1)
				print("FAR_TRACE " + JSON.stringify(t))
		if seconds > 0.0 and (tick - started) / float(SimClock.TICK_RATE) > seconds:
			break
	_report()
	quit(0)
