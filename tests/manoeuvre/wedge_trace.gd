extends SceneTree
## Round 35 (manoeuvre W1, C35.6), measurement only: WHY a crew dies `stuck:wedged`. The showmatch's own match headless
## (main.tscn with the showmatch flags, as fight_census.gd), every crew under way watched every tick for what moved it:
##
##   WEDGE_EP {...}     one row per wedged episode (Movement.wedged true for a run of ticks): crew, unit, ticks, how far it
##                      went, its median speed, the share of its ticks by what shaped the motion (below), what unstick saw
##                      (stall-rule ticks: |throttle| > 0.5 and the honest reading under STUCK_SPEED; fires; escapes), the
##                      order (type, brain option, element), hits taken, the friends/enemies close by, and whether it died.
##   WEDGE_DEATH {...}  a crew lost while wedged (far_census's death_cause stuck:wedged): its last TIMELINE_S, one sample a
##                      SAMPLE_S, with every quantity below.
##   WEDGE_TRACE {...}  the fight's totals.
##
## What shaped a tick (`force`, the first that applies): `unstick` / `press` / `kturn` / `yield` (the drive's own driver
## that tick), `hold` (Traffic's take-turns hold), `orca_turn` (avoidance moved the steering point more than TURN_DEG off
## the route's next point), `orca_slow` (avoidance kept the route's direction and cut the pace under 0.999), `shove` (the
## hull moved more than SHOVE_MPS sideways to its own heading: a depenetration push or a slide), `drive` (none of those:
## the drive's own steer at full pace). `pace_lt_0.5` and `touch_hull` are counted beside.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/wedge_trace.gd -- --skirmish --demo-match
##         --clean --seed=<n> --arena=locks --mute [--seconds=180]
## `--trace-crew=<name>`: also a WEDGE_TICK line for that crew every SAMPLE_S, wedged or not (any stage main.tscn runs,
## e.g. a hull-rest cell's own flags: `make manoeuvre-hull-trace`). The fight's own end (a screen test's quit) ends it.

const TIMELINE_S := 10.0
const SAMPLE_S := 0.5
const TURN_DEG := 15.0
const SHOVE_MPS := 0.5
const NEAR_M := 14.0
const STILL_MPS := 0.3
const HALT_CREEP_MPS := 0.5
const UNDER_FIRE_S := 5.0

var _rows := {}  # crew -> ring of per-tick samples (TIMELINE_S)
var _episodes := {}  # crew -> the open episode
var _moving_at := {}
var _hits_at := {}
var _last_pos := {}
var _trace_crews: PackedStringArray = []
var _totals := {"episodes": 0, "episode_ticks": 0, "deaths": 0, "wedged_deaths": 0, "by_force": {},
		"halt_ticks": 0, "halt_creep_ticks": 0, "halt_creep_held_ticks": 0}


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


static func _flat(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


static func _angle_deg(a: Vector2, b: Vector2) -> float:
	if a.length() < 0.01 or b.length() < 0.01:
		return 0.0
	return rad_to_deg(absf(a.angle_to(b)))


func _run() -> void:
	# A comma list; "+" stands for a space (make remote word-splits: "Green_Eyes+II_5").
	for name in _flag("trace-crew", "").split(",", false):
		_trace_crews.append(name.replace("+", " "))
	var main: Node = (load("res://game/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	var game_match: Match = main.get("game_match")
	game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		if event.has("target"):
			_hits_at.get_or_add(String(event["target"]), []).append(game_match.tick))
	game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		_on_death(game_match, String(event.get("unit", event.get("name", "")))))
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
		_observe(game_match)
		if seconds > 0.0 and (tick - started) / float(SimClock.TICK_RATE) > seconds:
			break
	for crew: String in _episodes.keys():
		_close(crew, false)
	print("WEDGE_TRACE " + JSON.stringify({"seed": int(_flag("seed", "0")), "arena": String(Arena.active.get("name", "")),
			"totals": _totals, "wedged_units": Movement.wedged_units,
			"wheel_halt_on": Manoeuvre.wheel_halt_on(), "wheel_halt_asks": Manoeuvre.wheel_halt_asks, "wheel_halts": Manoeuvre.wheel_halts,
			"stall_intent_on": Manoeuvre.stall_intent_on(), "stall_intent_ticks": Manoeuvre.stall_intent_ticks,
			"esc_fires_hull": Movement.esc_fires_hull, "esc_asks": Movement.esc_asks, "yields_started": Movement.yields_started}))
	quit(0)


func _hits_since(crew: String, tick: int, window_s: float) -> int:
	var n := 0
	for t: int in _hits_at.get(crew, []):
		if tick - t <= int(window_s * SimClock.TICK_RATE):
			n += 1
	return n


func _observe(game_match: Match) -> void:
	var tick := game_match.tick
	var alive: Array[Tank] = []
	for node in game_match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.is_alive():
			alive.append(tank)
	for tank in alive:
		var crew := String(tank.name)
		var here := tank.global_position
		var moved := Vector3.ZERO
		if _last_pos.has(crew):
			moved = (here - (_last_pos[crew] as Vector3)) * float(SimClock.TICK_RATE)
		_last_pos[crew] = here
		if tank.speed() > STILL_MPS or not _moving_at.has(crew):
			_moving_at[crew] = tick
		var mover := Movement.of(tank)
		if mover == null:
			continue
		var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
		var flat_moved := Vector2(moved.x, moved.z)
		var side_mps := absf(flat_moved.cross(forward))
		var decided: Dictionary = mover.contact.decided if mover.contact != null else {}
		var driver := String(decided.get("driver", ""))
		var steer: Variant = mover.steer_to if mover.steer_to != Vector3.INF else null
		var path: PackedVector3Array = mover._path
		var path_i: int = mover._path_index
		var route_pt: Variant = path[path_i] if path_i < path.size() else (mover._goal if mover._goal != Vector3.INF else null)
		var turn_deg := 0.0
		if steer != null and route_pt != null:
			turn_deg = _angle_deg(Vector2((steer as Vector3).x - here.x, (steer as Vector3).z - here.z),
					Vector2((route_pt as Vector3).x - here.x, (route_pt as Vector3).z - here.z))
		var touch_hull := false
		for i in tank.get_slide_collision_count():
			if tank.get_slide_collision(i).get_collider() is Tank:
				touch_hull = true
		if touch_hull:
			for i in tank.get_slide_collision_count():
				var hit_tank := tank.get_slide_collision(i).get_collider() as Tank
				if hit_tank != null and hit_tank.team == tank.team:
					_totals["friendly_contact_ticks"] = int(_totals.get("friendly_contact_ticks", 0)) + 1
					break
		var friends := 0
		var enemies := 0
		var nearest_friend := 999.0
		for other in alive:
			if other == tank:
				continue
			var d := _flat(here, other.global_position)
			if other.team == tank.team:
				nearest_friend = minf(nearest_friend, d)
				if d < NEAR_M:
					friends += 1
			elif d < NEAR_M * 4.0:
				enemies += 1
		var held := Traffic.holding(crew)
		var blocked_kind := "none"
		var blocker_name := mover.blocked_by if mover.phase == "blocked" or mover.phase == "yielding" else ""
		if mover.phase == "yielding" and mover.yield_to != "":
			blocker_name = mover.yield_to
		if blocker_name != "":
			var blocker := game_match.tanks.get_node_or_null(NodePath(blocker_name)) as Tank
			if blocker != null:
				blocked_kind = "friend" if blocker.team == tank.team else "enemy"
			elif blocker_name == "no_path":
				blocked_kind = "no_path"
			else:
				blocked_kind = "static"
		var still_s := (tick - int(_moving_at[crew])) / float(SimClock.TICK_RATE)
		var cause := death_cause(mover.is_under_way(), mover.phase, blocked_kind, still_s, mover.wedged)
		var force := "drive"
		if driver in ["unstick", "press", "kturn", "yield"]:
			force = driver
		elif held:
			force = "hold"
		elif mover._deflected and turn_deg > TURN_DEG:
			force = "orca_turn"
		elif mover.pace_now < 0.999:
			force = "orca_slow"
		elif side_mps > SHOVE_MPS:
			force = "shove"
		var reading: Vector3 = tank.real_velocity
		var stall := absf(float(decided.get("throttle", 0.0))) > 0.5 and reading.length() < Movement.STUCK_SPEED
		var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + crew)) as TankBrain
		var option := String(brain.choice.get("option", "")) if brain != null else ""
		var order_type := String(brain.order.get("type", brain.order.get("verb", ""))) if brain != null and not brain.order.is_empty() else ""
		var sample := {"t": tick, "x": snappedf(here.x, 0.1), "z": snappedf(here.z, 0.1),
				"mps": snappedf(flat_moved.length(), 0.01), "side_mps": snappedf(side_mps, 0.01),
				"real_mps": snappedf(Vector2(reading.x, reading.z).length(), 0.01), "phase": mover.phase,
				"wedged": mover.wedged, "driver": driver, "force": force, "pace": snappedf(mover.pace_now, 0.01),
				"turn_deg": snappedf(turn_deg, 1.0), "thr": snappedf(float(decided.get("throttle", 0.0)), 0.01),
				"steer": snappedf(float(decided.get("turn", 0.0)), 0.01), "stall": stall,
				"stuck_s": snappedf(mover._stuck_time, 0.01), "unstick_left": snappedf(mover._unstick_left, 0.01),
				"touch_hull": touch_hull, "friends": friends, "enemies": enemies, "near_friend_m": snappedf(nearest_friend, 0.1),
				"hits_2s": _hits_since(crew, tick, 2.0), "hits_10s": _hits_since(crew, tick, 10.0), "cause": cause,
				"since_hit_s": snappedf(minf(tank.ticks_since_hit / float(SimClock.TICK_RATE), 999.0), 0.1), "option": option, "order": order_type,
				"wedge_moved_m": snappedf(mover.wedge_moved_m, 0.01), "held": held}
		# W1b's measure, from MOTION (so the rule cannot zero it by construction): a wheeled drive at pace 0, and of those
		# the ticks the hull still moved >= HALT_CREEP_MPS (the plant's creep shuffling it).
		if mover.wheel_radius() > 0.0 and driver in ["route", "direct"] and mover.pace_now <= 0.0:
			_totals["halt_ticks"] = int(_totals["halt_ticks"]) + 1
			if flat_moved.length() >= HALT_CREEP_MPS:
				_totals["halt_creep_ticks"] = int(_totals["halt_creep_ticks"]) + 1
				if held:
					_totals["halt_creep_held_ticks"] = int(_totals["halt_creep_held_ticks"]) + 1
		if _trace_crews.has(crew) and tick % maxi(1, int(SAMPLE_S * SimClock.TICK_RATE)) == 0:
			var row := sample.duplicate()
			row["crew"] = crew
			row["goal"] = [snappedf(mover._goal.x, 0.1), snappedf(mover._goal.z, 0.1)] if mover._goal != Vector3.INF else null
			row["goal_m"] = snappedf(_flat(here, mover._goal), 0.1) if mover._goal != Vector3.INF else -1.0
			row["remaining_m"] = snappedf(mover._remaining, 0.1)
			row["blocked_by"] = mover.blocked_by
			row["yield_to"] = mover.yield_to
			row["move_type"] = String(mover.ctl.move_order.get("type", "")) if mover.ctl != null else ""
			row["unstick_fires"] = mover.unstick_fires
			row["esc_stage"] = mover._esc_stage
			row["kturn_m"] = snappedf(mover._kturn_left_m, 0.1)
			# Game-wide statics (W1c's counter first): stall clocks run by the intent reading, H1 hull escapes, asks.
			row["stall_intent_ticks"] = Manoeuvre.stall_intent_ticks
			row["esc_fires_hull"] = Movement.esc_fires_hull
			row["esc_asks"] = Movement.esc_asks
			var arms := Movement.route_arms()  # traffic T9's yields_unfinished, where the tree has it (-1 where not)
			row["yields_started"] = int(arms.get("yields_started", -1))
			row["yields_unfinished"] = int(arms.get("yields_unfinished", -1))
			row["asks_refused"] = int(arms.get("asks_refused", -1))
			var hulls: Array = []
			for i in tank.get_slide_collision_count():
				var hit := tank.get_slide_collision(i).get_collider()
				if hit is Tank:
					hulls.append(String((hit as Tank).name))
				elif hit != null:
					hulls.append("static:" + String((hit as Node).name))
			row["colliders"] = hulls
			row["wall_touch"] = mover.contact.touching if mover.contact != null else false
			print("WEDGE_TICK " + JSON.stringify(row))
		var ring: Array = _rows.get_or_add(crew, [])
		ring.append(sample)
		while ring.size() > int(TIMELINE_S * SimClock.TICK_RATE):
			ring.pop_front()
		if mover.wedged:
			var ep: Dictionary = _episodes.get_or_add(crew, {"crew": crew, "unit": tank.unit_id, "team": tank.team,
					"from": tick, "x": here.x, "z": here.z, "ticks": 0, "by_force": {}, "stall_ticks": 0, "pace_lt_half": 0,
					"touch_hull": 0, "mps": [], "hits": 0, "options": {}, "orders": {}, "friends_max": 0, "enemies_max": 0,
					"unstick_fires0": mover.unstick_fires, "start": here, "phase": {}})
			ep["ticks"] = int(ep["ticks"]) + 1
			var bf: Dictionary = ep["by_force"]
			bf[force] = int(bf.get(force, 0)) + 1
			var bp: Dictionary = ep["phase"]
			bp[mover.phase] = int(bp.get(mover.phase, 0)) + 1
			ep["stall_ticks"] = int(ep["stall_ticks"]) + (1 if stall else 0)
			ep["pace_lt_half"] = int(ep["pace_lt_half"]) + (1 if mover.pace_now < 0.5 else 0)
			ep["touch_hull"] = int(ep["touch_hull"]) + (1 if touch_hull else 0)
			(ep["mps"] as Array).append(flat_moved.length())
			var bo: Dictionary = ep["options"]
			bo[option] = int(bo.get(option, 0)) + 1
			var bord: Dictionary = ep["orders"]
			bord[order_type] = int(bord.get(order_type, 0)) + 1
			ep["friends_max"] = maxi(int(ep["friends_max"]), friends)
			ep["enemies_max"] = maxi(int(ep["enemies_max"]), enemies)
			ep["end"] = here
			ep["to"] = tick
			ep["unstick_fires1"] = mover.unstick_fires
			var tf: Dictionary = _totals["by_force"]
			tf[force] = int(tf.get(force, 0)) + 1
		elif _episodes.has(crew):
			_close(crew, false)


func _close(crew: String, died: bool) -> void:
	var ep: Dictionary = _episodes.get(crew, {})
	_episodes.erase(crew)
	if ep.is_empty():
		return
	var speeds: Array = ep["mps"]
	speeds.sort()
	var row := {"crew": crew, "unit": ep["unit"], "team": ep["team"], "from": ep["from"], "to": ep.get("to", ep["from"]),
			"s": snappedf(int(ep["ticks"]) / float(SimClock.TICK_RATE), 0.01), "x": snappedf(float(ep["x"]), 0.1),
			"z": snappedf(float(ep["z"]), 0.1), "net_m": snappedf(_flat(ep["start"], ep.get("end", ep["start"])), 0.01),
			"mps_med": snappedf(float(speeds[speeds.size() / 2]) if not speeds.is_empty() else 0.0, 0.01),
			"by_force": ep["by_force"], "phase": ep["phase"], "stall_ticks": ep["stall_ticks"], "pace_lt_half": ep["pace_lt_half"],
			"touch_hull": ep["touch_hull"], "unstick_fires": int(ep.get("unstick_fires1", ep["unstick_fires0"])) - int(ep["unstick_fires0"]),
			"options": ep["options"], "orders": ep["orders"], "friends_max": ep["friends_max"], "enemies_max": ep["enemies_max"],
			"died": died, "arena": String(Arena.active.get("name", "")), "seed": int(_flag("seed", "0"))}
	_totals["episodes"] = int(_totals["episodes"]) + 1
	_totals["episode_ticks"] = int(_totals["episode_ticks"]) + int(ep["ticks"])
	print("WEDGE_EP " + JSON.stringify(row))


## far_census.gd's death_cause, verbatim (traffic X1, round 34; as tests/traffic/jam_census.gd on round34/traffic).
static func death_cause(under_way: bool, phase: String, blocked_kind: String, still_s: float, wedged: bool) -> String:
	if not under_way:
		return "open:parked"
	if phase == "yielding":
		return "jam:yielding"
	if phase == "blocked":
		if blocked_kind == "friend":
			return "jam:friend"
		if blocked_kind == "enemy":
			return "open:enemy"
		return "stuck:" + ("no_path" if blocked_kind == "no_path" else "static")
	if wedged:
		return "stuck:wedged"
	if still_s >= Movement.BLOCKED_SECONDS:
		return "stuck:still"
	return "open:driving"


func _on_death(game_match: Match, crew: String) -> void:
	_totals["deaths"] = int(_totals["deaths"]) + 1
	var ring: Array = _rows.get(crew, [])
	if ring.is_empty():
		return
	var last: Dictionary = ring[ring.size() - 1]
	var cause := String(last["cause"])
	var bc: Dictionary = _totals.get_or_add("by_cause", {})
	bc[cause] = int(bc.get(cause, 0)) + 1
	# Round 35 (the joint W1c+T9 bar's guards, from traffic's T9 x T7 note): deaths by cause UNDER FIRE, hit within
	# UNDER_FIRE_S of the death (traffic T6's window), so jam-under-fire and jam:yielding deaths read from the same rows.
	if float(last.get("since_hit_s", 999.0)) <= UNDER_FIRE_S:
		var bf: Dictionary = _totals.get_or_add("by_cause_under_fire", {})
		bf[cause] = int(bf.get(cause, 0)) + 1
	if cause != "stuck:wedged":
		_close(crew, false)
		return
	_totals["wedged_deaths"] = int(_totals["wedged_deaths"]) + 1
	var bh: Dictionary = _totals.get_or_add("wedged_death_force", {})
	bh[String(last["force"])] = int(bh.get(String(last["force"]), 0)) + 1
	_close(crew, true)
	var step := maxi(1, int(SAMPLE_S * SimClock.TICK_RATE))
	var timeline: Array = []
	var i := ring.size() - 1
	while i >= 0:
		timeline.push_front(ring[i])
		i -= step
	print("WEDGE_DEATH " + JSON.stringify({"crew": crew, "tick": game_match.tick, "arena": String(Arena.active.get("name", "")),
			"seed": int(_flag("seed", "0")), "timeline": timeline}))
