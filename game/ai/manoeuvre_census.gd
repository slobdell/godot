class_name ManoeuvreCensus
extends RefCounted
## Round 26 (manoeuvre M0b, C26.5): **turns counted by legs, and by what was in the way.** Measurement only: nothing
## here changes a command.
##
## The lead: *"when vehicles get stuck, they do an N point turn where N is however many iterations it take to go back
## and forth to clear the obstacle"*. Movement's counters count planned legs (`kturns`, `kturn_multi_legs`) and reactive
## reverses (`circle_reverses`, `unstick_fires`, `press_escapes`) apart, but nothing counted what he sees: one TURN, from
## the first change of gear to driving away, and how many legs it took whichever rules drove them.
##
## An EPISODE opens on a hull's first reversal (actual motion, not the command: |speed| over CUSP_DEADBAND in the other
## gear) on a forward order, or on a hull at rest that starts in reverse; it counts a leg per run in one gear, the
## forward leg that ran into the obstacle included (when it ended within PRE_LEG_TICKS of the reversal); it closes when
## the hull has driven CLEAR_M (at least half its length) forward in one leg, when its goal moves, when it is at rest
## for IDLE_CLOSE_TICKS, or when it dies. A three-point turn is 3 legs; a single planned back-up then away is 3; a
## reverse straight onto a point is 1.
##
## KIND (C26.5), read once at the reversal from what lies ahead of the leg that ran in: `friendly` / `enemy` (a hull
## whose centre is within both half-lengths + KIND_REACH_M, inside KIND_CONE_DEG of the way the hull was moving),
## `static` (a wall contact, or the navmesh edge within the hull's half-length + KIND_REACH_M of its leading end),
## else `open` (nothing in the way: the point is inside the turning circle, Steering's geometry, the goal-behind case).
## CAUSE: the rule that drove the reversal (kturn single / fill, circle, unstick, press, yield, creep, face, order, ...).
##
## Tallies (static, in `Movement.route_arms()["turns"]`): per kind, episodes and a legs histogram, the worst; per
## cause, episodes. `log_on` (`--turn-log`) keeps one row per episode.

const CUSP_DEADBAND := 0.3
const PRE_LEG_TICKS := 2 * SimClock.TICK_RATE
const CLEAR_MIN_M := 5.0
const IDLE_CLOSE_TICKS := 3 * SimClock.TICK_RATE
const KIND_REACH_M := 2.5
const KIND_CONE_DEG := 70.0

## OFF unless asked for (`--turn-census`, or `--turn-log` for the rows too; a probe may set `on`): it reads every
## controller tick of every hull, and the laptop's tick is the budget (perf's).
static var log_on := OS.get_cmdline_user_args().has("--turn-log")
static var on := log_on or OS.get_cmdline_user_args().has("--turn-census") or _trace_flag() != "" \
		or OS.get_cmdline_user_args().has("--turn-states")
## With the flag, the running tally is printed every PRINT_EVERY_TICKS (`MANOEUVRE_TURNS <json>`: the last line is the
## run's), so any harness (a match, the drive test) reports it without a hook at its end; rows print as they close.
static var prints := on
## `--turn-trace=<unit name>`: that hull's driving every TRACE_EVERY ticks (measurement only).
static var trace_unit := _trace_flag()
const TRACE_EVERY := 5


## `--turn-states`: every crew's state once a second (`MANOEUVRE_STATE`), so a probe's judging moment can be read per
## crew: what a crew still moving was doing (a face at rest, a drive to its slot, pinned). Measurement only.
static var states_on := OS.get_cmdline_user_args().has("--turn-states")
const STATE_EVERY := SimClock.TICK_RATE


static func _trace_flag() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--turn-trace="):
			return arg.trim_prefix("--turn-trace=")
	return ""
const PRINT_EVERY_TICKS := 10 * SimClock.TICK_RATE
static var _printed_at := 0
static var rows: Array = []
## kind -> {"episodes": n, "legs": {legs: n}, "worst": n, "le3": n}
static var by_kind := {}
static var by_cause := {}


static func reset() -> void:
	rows.clear()
	by_kind = {}
	by_cause = {}


static func report() -> Dictionary:
	var out := {}
	for kind: String in by_kind:
		out[kind] = (by_kind[kind] as Dictionary).duplicate(true)
	return {"by_kind": out, "by_cause": by_cause.duplicate()}


var _gear := 0
var _last_forward_tick := -100000
var _open := false
var _legs := 0
var _seg_m := 0.0
var _rest := 0
var _kind := ""
var _cause := ""
var _start_tick := 0
var _start_at := Vector3.ZERO
var _goal := Vector3.INF
var _last := Vector3.INF
var _other := ""
var _other_speed := 0.0


## Every controller tick, after the command is final (Movement.unstick). `order` is the move order the tick drove.
func observe(mover: Movement, cmd: TankCommand, order: Dictionary) -> void:
	var tank := mover.ctl.tank
	if tank == null or not tank.is_alive():
		_close(mover, "dead")
		return
	var here := tank.global_position
	var step := 0.0 if _last == Vector3.INF else Vector2(here.x - _last.x, here.z - _last.z).length()
	_last = here
	var tick := Engine.get_physics_frames()
	if prints and tick - _printed_at >= PRINT_EVERY_TICKS:
		_printed_at = tick
		print("MANOEUVRE_TURNS %s" % JSON.stringify(report()))
	var speed := tank.speed()
	trace(mover, cmd, order)
	if states_on and tick % STATE_EVERY == 0:
		print("MANOEUVRE_STATE f %d %s %s order %s from %s v %.2f moved %.2f cmd %.2f/%.2f face %d/%.1f blocked %s retry %d touch %s stuck %.1f pivot %s esc %.1f goal %.1f real %.2f" % [
				tick, String(tank.name), tank.unit_id, String(order.get("type", "")), String(order.get("from", "")),
				Vector2(tank.velocity.x, tank.velocity.z).length(), tank.estimated_velocity.length(), cmd.throttle, cmd.turn,
				mover._face_legs.size(), mover._face_left_m, str(mover._face_blocked != Vector3.ZERO), mover._face_retry,
				str(mover.contact.touching), mover._stuck_time, str(mover._unstick_pivot), mover._unstick_left,
				Vector2(here.x - float(order.get("x", here.x)), here.z - float(order.get("z", here.z))).length(),
				tank.real_velocity.length()])
	var gear := 1 if speed > CUSP_DEADBAND else (-1 if speed < -CUSP_DEADBAND else 0)
	var type := String(order.get("type", ""))
	var goal := Vector3(float(order.get("x", 0.0)), 0.0, float(order.get("z", 0.0))) if type == "move_to" else Vector3.INF
	if _open and goal != _goal and (goal == Vector3.INF or _goal == Vector3.INF
			or Vector2(goal.x - _goal.x, goal.z - _goal.z).length() > Movement.NEW_GOAL_JUMP):
		_close(mover, "new_goal")
	_goal = goal
	if gear == 0:
		_rest += 1
		if _open and _rest >= IDLE_CLOSE_TICKS:
			_close(mover, "rest")
		return
	_rest = 0
	if gear == _gear:
		_seg_m += step
		if gear > 0:
			_last_forward_tick = tick
		if _open and gear > 0 and _seg_m >= _clear_m(tank):
			_close(mover, "away")
		return
	# A new leg: the gear changed (or the hull started from rest).
	var was := _gear
	_gear = gear
	_seg_m = step
	if gear > 0:
		_last_forward_tick = tick
	if _open:
		_legs += 1
		return
	if gear < 0 and not bool(order.get("reverse", false)) and type in ["move_to", "face", ""]:
		_open = true
		_start_tick = tick
		_start_at = here
		# The forward leg that ran in counts when it ended just now (a reversal); a start from rest is leg 1 itself.
		var ran_in := was > 0 or tick - _last_forward_tick <= PRE_LEG_TICKS
		_legs = 2 if ran_in else 1
		_kind = _kind_of(mover, tank)
		_cause = _cause_of(mover, cmd, order)


func _clear_m(tank: Tank) -> float:
	var size: Array = Movement.hull_box(tank.unit_id)
	return maxf(CLEAR_MIN_M, float(size[2]) * 0.5)


func _close(mover: Movement, why: String) -> void:
	if not _open:
		return
	_open = false
	var tally: Dictionary = by_kind.get(_kind, {"episodes": 0, "legs": {}, "worst": 0, "le3": 0})
	tally["episodes"] = int(tally["episodes"]) + 1
	var hist: Dictionary = tally["legs"]
	hist[_legs] = int(hist.get(_legs, 0)) + 1
	tally["worst"] = maxi(int(tally["worst"]), _legs)
	if _legs <= 3:
		tally["le3"] = int(tally["le3"]) + 1
	by_kind[_kind] = tally
	by_cause[_cause] = int(by_cause.get(_cause, 0)) + 1
	if log_on and mover.ctl != null and mover.ctl.tank != null:
		var tank := mover.ctl.tank
		rows.append({"unit": String(tank.name), "id": tank.unit_id, "team": tank.team, "kind": _kind, "cause": _cause,
				"legs": _legs, "end": why, "start_tick": _start_tick,
				"seconds": snappedf(float(Engine.get_physics_frames() - _start_tick) / SimClock.TICK_RATE, 0.1),
				"at": [snappedf(_start_at.x, 0.1), snappedf(_start_at.z, 0.1)],
				# The hull in the way (friendly / enemy kinds): its name, and whether it was moving (|speed| > 0.5 m/s)
				# or parked at the first reversal (traffic's rule needs to tell the two apart).
				"other": _other, "other_moving": _other_speed > 0.5, "other_speed": snappedf(_other_speed, 0.1)})
		if prints:
			print("MANOEUVRE_TURN %s" % JSON.stringify(rows[-1]))
	_legs = 0


## What was in the way of the leg that ran in (the hull's nose direction: it was going forward).
func _kind_of(mover: Movement, tank: Tank) -> String:
	var here := tank.global_position
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
	var mine: Array = Movement.hull_box(tank.unit_id)
	var best := INF
	var best_kind := ""
	_other = ""
	_other_speed = 0.0
	var cone := cos(deg_to_rad(KIND_CONE_DEG))
	if mover.ctl.tanks_root != null:
		for other: Node in mover.ctl.tanks_root.get_children():
			var hull := other as Tank
			if hull == null or hull == tank or not hull.is_alive():
				continue
			var to := Vector2(hull.global_position.x - here.x, hull.global_position.z - here.z)
			var theirs: Array = Movement.hull_box(hull.unit_id)
			var reach := (float(mine[2]) + float(theirs[2])) * 0.5 + KIND_REACH_M
			var d := to.length()
			if d > reach or d < 0.01 or nose.dot(to / d) < cone:
				continue
			if d < best:
				best = d
				best_kind = "friendly" if hull.team == tank.team else "enemy"
				_other = String(hull.name)
				_other_speed = absf(hull.speed())
	if best_kind != "":
		return best_kind
	if mover.contact.touching:
		return "static"
	# The navmesh edge: the leading end's centre walked forward until it is further off the mesh than the clear reach
	# (the planned reverse's own test: the mesh stops the bake radius short of every collider).
	var map := tank.get_world_3d().navigation_map
	var frame := mover._kturn_frame(tank)
	var axis := Vector3(nose.x, 0.0, nose.y)
	if Movement._free_run(map, here + axis * float(frame[1]), axis, float(frame[2])) < KIND_REACH_M:
		return "static"
	return "open"


func _cause_of(mover: Movement, cmd: TankCommand, order: Dictionary) -> String:
	if mover.in_kturn():
		return "kturn_" + String(mover._kturn_plan_kind)
	if mover._escape_gear != 0.0:
		return "press"
	if mover._unstick_left > 0.0:
		return "unstick"
	if mover._yield_point != Vector3.INF:
		return "yield"
	var type := String(order.get("type", ""))
	if type == "face":
		return "face"
	if type != "move_to":
		return "idle"
	if bool(order.get("direct", false)):
		return "direct"
	if mover._circling:
		return "circle"
	if absf(cmd.throttle) < TankMotion.WHEEL_CREEP_THROTTLE * absf(cmd.turn) and mover.wheel_radius() > 0.0:
		return "creep"
	return "route_" + String(mover._reverse_why) if mover._reverse_why != "" else "route"

## The traced hull's driving (`--turn-trace=<unit name>`), every TRACE_EVERY ticks, from observe (every order type: a
## face at rest too). The flag turns the census on, so the trace needs no `--turn-census`. Measurement only.
static func trace(mover: Movement, cmd: TankCommand, order: Dictionary) -> void:
	var tank := mover.ctl.tank
	var tick := Engine.get_physics_frames()
	if trace_unit == "" or tank == null or String(tank.name) != trace_unit or tick % TRACE_EVERY != 0:
		return
	var here := tank.global_position
	var speed := tank.speed()
	var nose := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z)
	print("MANOEUVRE_TRACE f %d at (%.1f, %.1f) nose (%.2f, %.2f) v %.2f cmd %.2f/%.2f order %s goal (%.1f, %.1f) steer %s plan %s left %.1f legs %s circling %s why %s touch %s face %s/%.1f/%d blocked %s retry %d" % [
			tick, here.x, here.z, nose.x, nose.y, speed, cmd.throttle, cmd.turn, String(order.get("type", "")),
			float(order.get("x", 0.0)), float(order.get("z", 0.0)), str(mover.steer_to), mover._kturn_plan_kind,
			mover._kturn_left_m, str(mover._kturn_legs), mover._circling, mover._reverse_why, mover.contact.touching,
			str(mover._face_legs), mover._face_left_m, mover._face_gear, str(mover._face_blocked != Vector3.ZERO),
			mover._face_retry])
