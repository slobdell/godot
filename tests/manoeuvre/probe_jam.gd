extends "res://tests/orders_probe_group.gd"
## Round 41 (manoeuvre Q1, the jam census; measurement only): orders' group-order probe (tests/orders_probe_group.gd, O1: his five
## full squads at mixed headings, one click across the map; unchanged, its own census rides along) with a
## read of every stretch in which a crew under way is SLOWED BY A FRIEND: ORCA cut its pace (Movement.pace_now < SLOW_PACE) or
## moved its steer point (_deflected), it is giving way (yield_to), or it is held at a street mouth (Traffic.holding). Its
## BLOCKER is read in this order: the crew it yields to; a friendly hull it touches; the nearest friend in its lane ahead
## (LANE_M, both hull radii + LANE_SLACK_M); else the friend ORCA would meet first within HORIZON_S at the route's preferred
## velocity (JamClass.time_to_meet). No friend found = terrain, the route's end or an enemy: not a friend jam, not counted
## (a mouth hold with no friend found is counted apart, `held`).
## An EPISODE is one asker against one blocker, unbroken (gaps up to GAP_TICKS). Per tick the blocker is classed (JamClass:
## head_on / same_way / crossing / turning / stalled / parked); the episode carries the class at its start and its mode.
## The counterfactual his rule asks about ("if the asker held its heading and waited, when would the way clear?") is MEASURED:
## the asker's lane is frozen at the episode's start (origin, way, width) and `t_clear` is the first tick the blocker is out
## of that lane AND will not enter it at the asker's preferred velocity (no time to meet), capped at CLEAR_CAP_S (-1 = never
## within the cap; `lane_start` false = the blocker was not in the lane at the start either: a friend touching from the side, or
## one the asker gives way to). Caveat: the blocker's motion is not independent of what the asker then did.
## Headings are the base probe's `--probe-headings=crew|squad|formed` (crew: every hull a seeded random heading just before the
## click, his "a scout is pointed north and thus blocking a unit that's trying to go West"; formed: the control).
## Rows at quit: JAM_EP per episode (asker, blocker, squads, class_start, class_mode, classes, s, t_clear, action, lateral_m,
## stopped_s, start_s, at), JAM_RUN per run (totals by class and action, the waitable shares at WAIT_N_S, held_s).
## Run with `make manoeuvre-probe-jam` (mk/manoeuvre.mk).
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/manoeuvre/probe_jam.gd -- --arena=terminus --seed=7001 \
##     --probe-squads=5 --probe-army=res://tests/control/orders_probe_group_5.json --probe-headings=crew --probe-target=across \
##     --probe-route=click --probe-arm=main

const JamClass := preload("res://tests/manoeuvre/jam_class.gd")

const SLOW_PACE := 0.85
const LANE_M := 12.0
const LANE_SLACK_M := 0.5
const HORIZON_S := 2.0
const GAP_TICKS := 15
const CLEAR_CAP_S := 20.0
const STILL_MPS := 0.3
const REVERSE_MPS := 0.2
const YAW_WINDOW := 3
const WAIT_N_S: Array[float] = [2.0, 3.0, 5.0, 8.0]
const MIN_EPISODE_TICKS := 3

var _jam_last_tick := -1
var _yaws := {}  # crew -> ring of yaws, the last YAW_WINDOW + 1 ticks
var _open := {}  # asker -> episode
var _pending: Array = []  # closed episodes still waiting for t_clear
var _episodes: Array = []
var _held_ticks := 0
var _slowed_ticks := 0
var _no_blocker_ticks := 0


func _initialize() -> void:
	super()
	_jam_trace.call_deferred()


func _jam_trace() -> void:
	while true:
		await physics_frame
		if _match == null or not is_instance_valid(_match) or _squads.is_empty() or _order_tick <= 0:
			continue
		if _match.tick == _jam_last_tick:
			continue
		_jam_last_tick = _match.tick
		_jam_observe()


func _jam_squad_of(crew: String) -> int:
	for squad: Dictionary in _squads:
		if (squad["units"] as Array).has(crew):
			return int(squad["number"])
	return 0


func _green_alive() -> Array[Tank]:
	var alive: Array[Tank] = []
	for node in _match.tanks.get_children():
		var tank := node as Tank
		if tank != null and tank.team == Match.Team.GREEN and tank.is_alive():
			alive.append(tank)
	return alive


func _yaw_rate(crew: String) -> float:
	var ring: Array = _yaws.get(crew, [])
	if ring.size() < 2:
		return 0.0
	var dt := (ring.size() - 1) / float(SimClock.TICK_RATE)
	return JamClass.yaw_rate_dps(float(ring[0]), float(ring[-1]), dt)


func _jam_observe() -> void:
	var alive := _green_alive()
	var by_name := {}
	for tank in alive:
		var crew := String(tank.name)
		by_name[crew] = tank
		var ring: Array = _yaws.get_or_add(crew, [])
		ring.append(JamClass.yaw_of(-tank.global_basis.z))
		if ring.size() > YAW_WINDOW + 1:
			ring.pop_front()
	var seen := {}
	for tank in alive:
		var crew := String(tank.name)
		var mover := Movement.of(tank)
		if mover == null or not mover.is_under_way() or mover.phase == "arrived" or mover._goal == Vector3.INF:
			continue
		var way: Vector2 = mover._travel_direction(mover._goal, false)
		if way == Vector2.ZERO:
			continue
		var held := Traffic.holding(crew)
		var slowed: bool = held or mover.pace_now < SLOW_PACE or mover._deflected or mover.yield_to != ""
		if not slowed:
			continue
		_slowed_ticks += 1
		var blocker := _find_blocker(tank, mover, way, alive, by_name)
		if blocker == null:
			if held:
				_held_ticks += 1
			else:
				_no_blocker_ticks += 1
			continue
		seen[crew] = true
		var ep: Dictionary = _open.get(crew, {})
		if not ep.is_empty() and String(ep["blocker"]) != String(blocker.name):
			_close(crew)
			ep = {}
		if ep.is_empty():
			ep = _begin(tank, mover, blocker, way)
			_open[crew] = ep
		_tick_episode(ep, tank, mover, blocker, way)
	# Episodes not seen this tick: a gap, then closed.
	for crew: String in _open.keys():
		if seen.has(crew):
			continue
		var ep: Dictionary = _open[crew]
		if _match.tick - int(ep["last_tick"]) > GAP_TICKS or not by_name.has(crew):
			_close(crew)
	_clears(by_name)


## The friend this crew is up against (see the header), or null.
func _find_blocker(tank: Tank, mover: Movement, way: Vector2, alive: Array[Tank], by_name: Dictionary) -> Tank:
	if mover.yield_to != "" and by_name.has(mover.yield_to):
		return by_name[mover.yield_to]
	for i in tank.get_slide_collision_count():
		var hit := tank.get_slide_collision(i).get_collider() as Tank
		if hit != null and hit != tank and hit.team == tank.team and hit.is_alive():
			return hit
	var here := Vector2(tank.global_position.x, tank.global_position.z)
	var my_r := Avoidance.radius_of(tank.unit_id)
	var best: Tank = null
	var best_along := LANE_M
	for other in alive:
		if other == tank:
			continue
		var off := Vector2(other.global_position.x, other.global_position.z) - here
		var width := my_r + Avoidance.radius_of(other.unit_id) + LANE_SLACK_M
		if JamClass.in_lane(off, way, width, LANE_M) and off.dot(way) < best_along:
			best = other
			best_along = off.dot(way)
	if best != null:
		return best
	var preferred := way * tank.max_forward_speed
	var best_t := HORIZON_S
	for other in alive:
		if other == tank:
			continue
		var off := Vector2(other.global_position.x, other.global_position.z) - here
		if off.length() > LANE_M + 4.0:
			continue
		var v_rel := Vector2(other.real_velocity.x, other.real_velocity.z) - preferred
		var t := JamClass.time_to_meet(off, v_rel, my_r + Avoidance.radius_of(other.unit_id))
		if t < best_t:
			best = other
			best_t = t
	return best


func _begin(tank: Tank, mover: Movement, blocker: Tank, way: Vector2) -> Dictionary:
	var here := Vector2(tank.global_position.x, tank.global_position.z)
	return {"asker": String(tank.name), "asker_squad": _jam_squad_of(String(tank.name)), "unit": tank.unit_id,
			"wheeled": mover.wheel_radius() > 0.0, "blocker": String(blocker.name), "blocker_squad": _jam_squad_of(String(blocker.name)),
			"blocker_unit": blocker.unit_id, "start_tick": _match.tick, "last_tick": _match.tick, "ticks": 0,
			"origin": here, "way": way, "width": Avoidance.radius_of(tank.unit_id) + Avoidance.radius_of(blocker.unit_id) + LANE_SLACK_M,
			"preferred": way * tank.max_forward_speed, "classes": {}, "class_start": "", "yield_ticks": 0, "reversed_ticks": 0,
			"stopped_ticks": 0, "max_lateral": 0.0, "phases": {}, "t_clear": -1.0, "blocker_start": Vector2(blocker.global_position.x, blocker.global_position.z),
			"blocker_yaw_start": JamClass.yaw_of(-blocker.global_basis.z), "asker_yaw_start": JamClass.yaw_of(-tank.global_basis.z),
			"blocker_wheeled": Movement.of(blocker) != null and Movement.of(blocker).wheel_radius() > 0.0,
			"reverse_why": {}, "reverse_m": 0.0, "reverse_from": Vector2.INF, "reverse_max_m": 0.0, "last_pos": here,
			"lane_start": _in_my_way(here, way, Avoidance.radius_of(tank.unit_id) + Avoidance.radius_of(blocker.unit_id) + LANE_SLACK_M,
					way * tank.max_forward_speed, blocker)}


## Is `blocker` in the frozen lane from `origin` along `way`, or going to meet me there at `preferred`? (The episode's clearing test.)
func _in_my_way(origin: Vector2, way: Vector2, width: float, preferred: Vector2, blocker: Tank) -> bool:
	var off := Vector2(blocker.global_position.x, blocker.global_position.z) - origin
	var v_rel := Vector2(blocker.real_velocity.x, blocker.real_velocity.z) - preferred
	return JamClass.in_lane(off, way, width, LANE_M) or JamClass.time_to_meet(off, v_rel, width) != INF


func _tick_episode(ep: Dictionary, tank: Tank, mover: Movement, blocker: Tank, way: Vector2) -> void:
	ep["last_tick"] = _match.tick
	ep["ticks"] = int(ep["ticks"]) + 1
	var bv := Vector2(blocker.real_velocity.x, blocker.real_velocity.z)
	var speed := bv.length()
	var cos_way := bv.dot(way) / speed if speed > 0.001 else 0.0
	var bm := Movement.of(blocker)
	var under_way := bm != null and bm.is_under_way() and bm.phase != "arrived"
	var cls := JamClass.blocker_class(speed, _yaw_rate(String(blocker.name)), cos_way, under_way)
	var classes: Dictionary = ep["classes"]
	classes[cls] = int(classes.get(cls, 0)) + 1
	if String(ep["class_start"]) == "":
		ep["class_start"] = cls
	var phases: Dictionary = ep["phases"]
	phases[mover.phase] = int(phases.get(mover.phase, 0)) + 1
	if mover.yield_to != "":
		ep["yield_ticks"] = int(ep["yield_ticks"]) + 1
	var v := Vector2(tank.real_velocity.x, tank.real_velocity.z)
	if v.length() < STILL_MPS:
		ep["stopped_ticks"] = int(ep["stopped_ticks"]) + 1
	var forward := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
	var pos := Vector2(tank.global_position.x, tank.global_position.z)
	if v.dot(forward) < -REVERSE_MPS:
		ep["reversed_ticks"] = int(ep["reversed_ticks"]) + 1
		# Round 41 (the orchestrator's reversing report): which rule has the hull in reverse gear this tick, from the drive's own
		# reads: a planned three-point-turn leg (_kturn_left_m), the blind back-off (_unstick_left), H1's escape (_esc_stage), else
		# the drive's _reverse_why (order = Manoeuvre's short move behind / a reverse order, circle = Steering's circle test on a
		# forward order, station, other); and how far it backed, from where, and whether it came back to that spot.
		# ...and "shoved": the hull moves backward with no reverse throttle commanded (pushed by a friend, or rolling after a reverse).
		var why := "other"
		if float(tank.command.throttle) >= 0.0:
			why = "shoved" if tank.get_slide_collision_count() > 0 else "coasting"
		elif float(mover._kturn_left_m) > 0.0:
			why = "kturn"
		elif float(mover._unstick_left) > 0.0:
			why = "unstick"
		elif int(mover._esc_stage) != 0:
			why = "escape"
		elif mover.yield_to != "":
			why = "yield"
		elif String(mover.ctl.move_order.get("type", "")) != "move_to":
			why = "order:" + String(mover.ctl.move_order.get("type", "?"))  # a face / hold / stop order's own gears (not the drive)
		elif String(mover._reverse_why) != "":
			why = String(mover._reverse_why)
		if tank.get_slide_collision_count() > 0 and why != "shoved":
			why += "+touch"
		var whys: Dictionary = ep["reverse_why"]
		whys[why] = int(whys.get(why, 0)) + 1
		ep["reverse_m"] = float(ep["reverse_m"]) + pos.distance_to(ep["last_pos"])
		if ep["reverse_from"] == Vector2.INF:
			ep["reverse_from"] = pos
	if ep["reverse_from"] != Vector2.INF:
		ep["reverse_max_m"] = maxf(float(ep["reverse_max_m"]), pos.distance_to(ep["reverse_from"]))
		ep["reverse_end_m"] = pos.distance_to(ep["reverse_from"])
	ep["last_pos"] = pos
	var off := Vector2(tank.global_position.x, tank.global_position.z) - (ep["origin"] as Vector2)
	ep["max_lateral"] = maxf(float(ep["max_lateral"]), absf(off.cross(ep["way"] as Vector2)))


func _close(crew: String) -> void:
	var ep: Dictionary = _open[crew]
	_open.erase(crew)
	if int(ep["ticks"]) < MIN_EPISODE_TICKS:
		return
	_episodes.append(ep)
	if float(ep["t_clear"]) < 0.0:
		_pending.append(ep)


## Every open or pending episode whose blocker has not yet cleared the frozen lane: has it now?
func _clears(by_name: Dictionary) -> void:
	var still: Array = []
	var watched: Array = _pending.duplicate()
	for ep: Dictionary in _open.values():
		watched.append(ep)
	for ep: Dictionary in watched:
		if float(ep["t_clear"]) >= 0.0:
			continue
		var since := (_match.tick - int(ep["start_tick"])) / float(SimClock.TICK_RATE)
		var blocker: Tank = by_name.get(String(ep["blocker"]))
		var cleared := blocker == null or not _in_my_way(ep["origin"], ep["way"], float(ep["width"]), ep["preferred"], blocker)
		if cleared:
			ep["t_clear"] = snappedf(since, 0.01)
		elif since >= CLEAR_CAP_S:
			ep["t_clear"] = -2.0  # never within the cap
	for ep: Dictionary in _pending:
		if float(ep["t_clear"]) == -1.0:
			still.append(ep)
	_pending = still


func _mode(counts: Dictionary) -> String:
	var top := ""
	for k: String in counts:
		if top == "" or int(counts[k]) > int(counts[top]):
			top = k
	return top


func _finalize() -> void:
	for crew: String in _open.keys():
		_close(crew)
	var seed := int(_flag("seed", "0"))
	var arena := _flag("arena", "")
	var arm := _flag("probe-arm", "")
	var headings := _flag("probe-headings", "crew")
	var route := _flag("probe-route", "click")
	var by_class := {}
	var by_action := {}
	var waitable := {}
	for n: float in WAIT_N_S:
		waitable["%d" % int(n)] = 0.0
	var faster := 0.0
	var total := 0.0
	var start_tick := _order_tick
	for ep: Dictionary in _episodes:
		var s := int(ep["ticks"]) / float(SimClock.TICK_RATE)
		var t_clear := float(ep["t_clear"])
		if t_clear == -1.0:
			t_clear = -2.0  # the run ended first
		var action := JamClass.asker_action(int(ep["ticks"]), int(ep["yield_ticks"]), int(ep["reversed_ticks"]),
				float(ep["max_lateral"]), int(ep["stopped_ticks"]))
		var cls := _mode(ep["classes"])
		total += s
		by_class[cls] = float(by_class.get(cls, 0.0)) + s
		by_action[action] = float(by_action.get(action, 0.0)) + s
		if t_clear >= 0.0:
			for n: float in WAIT_N_S:
				if t_clear <= n:
					waitable["%d" % int(n)] = float(waitable["%d" % int(n)]) + s
			if t_clear < s:
				faster += s
		print("JAM_EP " + JSON.stringify({"seed": seed, "arena": arena, "route": route, "arm": arm, "headings": headings,
				"asker": ep["asker"], "asker_squad": ep["asker_squad"], "unit": ep["unit"], "wheeled": ep["wheeled"],
				"blocker": ep["blocker"], "blocker_squad": ep["blocker_squad"], "blocker_unit": ep["blocker_unit"],
				"same_squad": int(ep["asker_squad"]) == int(ep["blocker_squad"]), "blocker_wheeled": ep["blocker_wheeled"],
				"lane_start": ep["lane_start"], "class_start": ep["class_start"], "class_mode": cls,
				"classes": ep["classes"], "s": snappedf(s, 0.01), "t_clear": t_clear, "action": action,
				"lateral_m": snappedf(float(ep["max_lateral"]), 0.1), "stopped_s": snappedf(int(ep["stopped_ticks"]) / float(SimClock.TICK_RATE), 0.1),
				"yield_s": snappedf(int(ep["yield_ticks"]) / float(SimClock.TICK_RATE), 0.1), "phases": ep["phases"],
				"start_s": snappedf((int(ep["start_tick"]) - start_tick) / float(SimClock.TICK_RATE), 0.1),
				"at": [snappedf((ep["origin"] as Vector2).x, 0.1), snappedf((ep["origin"] as Vector2).y, 0.1)],
				"blocker_heading_off_deg": snappedf(rad_to_deg(absf(angle_difference(float(ep["asker_yaw_start"]), float(ep["blocker_yaw_start"])))), 1.0),
				"reverse_why": ep["reverse_why"], "reverse_m": snappedf(float(ep["reverse_m"]), 0.1), "reverse_max_m": snappedf(float(ep["reverse_max_m"]), 0.1),
				"reverse_end_m": snappedf(float(ep.get("reverse_end_m", -1.0)), 0.1),
				"reverse_reentered": ep["reverse_from"] != Vector2.INF and float(ep["reverse_max_m"]) > 3.0 and float(ep.get("reverse_end_m", 99.0)) < 2.0}))
	print("JAM_RUN " + JSON.stringify({"seed": seed, "arena": arena, "route": route, "arm": arm, "headings": headings,
			"episodes": _episodes.size(), "jam_s": snappedf(total, 0.1), "by_class": by_class, "by_action": by_action,
			"waitable_s": waitable, "faster_s": snappedf(faster, 0.1), "held_s": snappedf(_held_ticks / float(SimClock.TICK_RATE), 0.1),
			"slowed_s": snappedf(_slowed_ticks / float(SimClock.TICK_RATE), 0.1),
			"no_blocker_s": snappedf(_no_blocker_ticks / float(SimClock.TICK_RATE), 0.1), "native_drive": BrainSwitches.native_drive,
			"wait_queued": Movement.wait_queued, "waits": Movement.waits, "wait_timeouts": Movement.wait_timeouts, "wait_long": Movement.wait_long, "holdlane_skips": Movement.holdlane_skips, "holdlane_holds": Movement.holdlane_holds,
			"wait_longest": Movement.wait_longest, "wait_by_kind": Movement.wait_by_kind}))
