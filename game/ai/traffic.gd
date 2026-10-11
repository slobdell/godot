class_name Traffic
extends RefCounted
## Round 26 (traffic): how friendly vehicles deconflict. The lead, 2026-10-10: *"in a real world scenario, people would
## just generally each turn to the right in order to deconflict. The same case might not be said if we're charging
## toward an enemy"*. The rules live here (`_agents/navigation.md` *Round 26: friendly traffic*); Movement and the
## element feed call into them.
##
## Every behaviour change of the round has an off switch for its A/B, `--traffic-off=<name>[,<name>...]` on any run:
##   slide   CP1a (C26.8): an element slot that SLIDES under SLOT_SLIDE_M between two reads is not a new call from the
##           leader (ElementFeed.changed), so the brain does not interrupt its mover for it.
##   keepright  CP1b (C26.1, C26.4): friendlies meeting head-on both bias to their own right, early.
##   crossing   CP1b: at a crossing at any other angle, the crew reaching the conflict point later slows to pass behind.
##
## THE CONVENTION (CP1b; `_agents/navigation.md` *Round 26: friendly traffic* has the reasons). It shapes ORCA's
## PREFERRED velocity (Movement._avoid) and nothing else: ORCA still keeps every hull clear, the give-way still sorts a
## stall. Between FRIENDLIES only, both MOVING (under way, not giving way, not in a planned reverse leg); an enemy, a
## parked friend, a crew in a k-turn or a give-way are left to ORCA and the give-way exactly as before. Both crews of a
## pair compute it from the SAME facts — this tick's table of positions and velocities (directions from velocity, the
## hull's heading when it is slower than MOVING_MPS), radii and names — so both reach the same answer without asking.
##
##   head-on   their directions within HEAD_ON_COS of opposite, the other ahead of me, meeting within HORIZON_S, and
##             its centre less than the pair's clearance off my line: each takes half of the lateral gap still needed
##             to pass LEFT SIDE TO LEFT SIDE (each keeps right), spread over the time to the meeting so it starts early
##             and smooth; the preferred velocity is ROTATED toward my right (speed kept), at most MAX_SIDE_SIN.
##   crossing  any other angle except following (directions within FOLLOW_COS): both paths' lines meet ahead of both,
##             each reaches the conflict point within HORIZON_S, and their times there overlap (each occupies it for
##             clearance / speed): the one arriving LATER yields; inside TIE_S of a tie, the one with the other on its
##             RIGHT yields (priority to the right, a road rule); if that does not decide it (both or neither), the
##             name does. The yielder's preferred speed is capped so it reaches the conflict zone after the other has
##             cleared it (+ YIELD_MARGIN_S); the other holds its line.

## A slot that moves less than this between two reads of the element is the formation sliding, not a re-seat. It is
## Movement's own goal-jump distance (`_track_progress` starts a new progress record when the goal moves more than 2 m),
## so a slide the feed now lets through is one Movement already treats as the same goal; and it is a quarter of the
## tightest doctrine spacing (8 m: doctrine_standard.json, dense terrain; a corridor narrows a shape ACROSS but keeps
## its pitch ALONG), so a re-seat — a crew sent to another slot of the shape — moves it further. Measured slides on
## his head-on case: millimetres per update (T0 trace, streams/traffic.md Status).
const SLOT_SLIDE_M := 2.0

## The convention's numbers (see the doc above).
const REACH_M := 45.0
const HORIZON_S := 4.5
const HEAD_ON_COS := -0.766  # cos 140 deg: within 40 deg of opposite
const FOLLOW_COS := 0.866  # cos 30 deg: going the same way is following, not crossing (ORCA's and the give-way's)
const CLEAR_MARGIN_M := 1.5
const MAX_SIDE_SIN := 0.5  # at most 30 deg off the route
const SETTLE_S := 1.0  # finish the sidestep this long before the meeting
const TIE_S := 0.5
const YIELD_MARGIN_S := 0.4
const MOVING_MPS := 1.0
const MIN_SPEED_MPS := 1.0
const CELL := 16.0

## Arm counters (route_arms-style; measurement only): ticks a crew's wish was turned right, and ticks it was slowed.
static var kept_right := 0
static var crossing_yields := 0

## This tick's table: [team, x, z, dir_x, dir_z, speed, radius, moving] per row, by name; a grid of rows per team.
static var _frame := -1
static var _root := -1
static var _rows := {}
static var _grid := {}

static var _off := {}
static var _parsed := false


## Is the round-26 behaviour `name` switched off for this run (`--traffic-off=name,...`)?
static func off(name: String) -> bool:
	if not _parsed:
		_parsed = true
		for arg in OS.get_cmdline_user_args():
			if String(arg).begins_with("--traffic-off="):
				for part in String(arg).trim_prefix("--traffic-off=").split(",", false):
					_off[part.strip_edges()] = true
	return _off.has(name)


## Tests: switch a behaviour off (true) or back on, whatever the command line said.
static func set_off(name: String, value: bool) -> void:
	off(name)
	if value:
		_off[name] = true
	else:
		_off.erase(name)


## The convention's preferred velocity for `me` (a moving friendly crew), from the route's wish `preferred` (x, z).
## Returns `preferred` unchanged when no friend is a party to a meeting or a crossing. Needs this tick's table
## (refresh, or load_rows in tests).
static func shape(me: String, preferred: Vector2) -> Vector2:
	var keep := not off("keepright")
	var cross := not off("crossing")
	if not (keep or cross):
		return preferred
	var mine: Variant = _rows.get(me)
	if mine == null or not bool(mine[7]):
		return preferred
	var speed := preferred.length()
	if speed < 0.1:
		return preferred
	var team: int = mine[0]
	var p := Vector2(mine[1], mine[2])
	var u := Vector2(mine[3], mine[4])
	var v_me := maxf(float(mine[5]), MIN_SPEED_MPS)
	var right := Vector2(-u.y, u.x)
	var side_sin := 0.0
	var cap := INF
	var cell_x := floori(p.x / CELL)
	var cell_z := floori(p.y / CELL)
	var span := ceili(REACH_M / CELL)
	var cells: Dictionary = _grid.get(team, {})
	for gx in range(cell_x - span, cell_x + span + 1):
		for gz in range(cell_z - span, cell_z + span + 1):
			var members: Variant = cells.get(Vector2i(gx, gz))
			if members == null:
				continue
			for other: String in members:
				if other == me:
					continue
				var row: Array = _rows[other]
				if not bool(row[7]):
					continue
				var d := Vector2(row[1], row[2]) - p
				var distance := d.length()
				if distance > REACH_M or distance < 0.01:
					continue
				var w := Vector2(row[3], row[4])
				var v_it := maxf(float(row[5]), MIN_SPEED_MPS)
				var clearance := float(mine[6]) + float(row[6]) + CLEAR_MARGIN_M
				var facing := u.dot(w)
				if facing <= HEAD_ON_COS:
					if not keep:
						continue
					var ahead := d.dot(u)
					var lateral := d.dot(right)
					if ahead <= 0.0 or absf(lateral) >= clearance:
						continue
					var meet := ahead / (v_me + v_it)
					if meet > HORIZON_S:
						continue
					# I want it on my LEFT by `clearance` (lateral <= -clearance); half of what is missing is mine.
					var mine_m := (lateral + clearance) * 0.5
					var lateral_speed := mine_m / maxf(meet - SETTLE_S, 0.5)
					side_sin = maxf(side_sin, minf(lateral_speed / speed, MAX_SIDE_SIN))
				elif facing < FOLLOW_COS and cross:
					var verdict := _crossing(p, u, v_me, Vector2(row[1], row[2]), w, v_it, clearance, me, other)
					if verdict >= 0.0:
						cap = minf(cap, verdict)
	var out := preferred
	if side_sin > 0.0:
		kept_right += 1
		var along := preferred / speed
		var side := Vector2(-along.y, along.x)
		out = (along * sqrt(1.0 - side_sin * side_sin) + side * side_sin) * speed
	if cap < INF and cap < speed:
		crossing_yields += 1
		out = out.normalized() * cap if out.length_squared() > 0.0 else out
	return out


## The crossing of `me` (at p, going u at v_me) with `other` (at q, going w at v_it): the speed `me` must keep under so
## the other clears the conflict zone first, or -1 when `me` does not yield (no conflict, or the other yields).
static func _crossing(p: Vector2, u: Vector2, v_me: float, q: Vector2, w: Vector2, v_it: float, clearance: float,
		me: String, other: String) -> float:
	var denominator := u.x * w.y - u.y * w.x
	if absf(denominator) < 0.05:
		return -1.0
	var d := q - p
	var s := (d.x * w.y - d.y * w.x) / denominator  # metres along my line to the crossing
	var t := (d.x * u.y - d.y * u.x) / denominator  # metres along its line
	if s <= -clearance or t <= -clearance:
		return -1.0  # one of us is already past it
	var t_me := s / v_me
	var t_it := t / v_it
	if minf(t_me, t_it) > HORIZON_S or s > REACH_M:
		return -1.0
	var occupy := clearance / v_me + clearance / v_it
	if absf(t_me - t_it) >= occupy:
		return -1.0  # one clears before the other arrives: no conflict
	var i_yield: bool
	if absf(t_me - t_it) > TIE_S:
		i_yield = t_me > t_it
	else:
		var it_on_my_right := d.dot(Vector2(-u.y, u.x)) > 0.0
		var me_on_its_right := (-d).dot(Vector2(-w.y, w.x)) > 0.0
		i_yield = it_on_my_right if it_on_my_right != me_on_its_right else me > other
	if not i_yield:
		return -1.0
	var entry := maxf(s - clearance, 0.0)
	var clear_at := maxf(t_it, 0.0) + clearance / v_it + YIELD_MARGIN_S
	return entry / clear_at


## Build this tick's table (once per physics frame) from every living hull under `tanks_root`.
static func refresh(tanks_root: Node) -> void:
	var root := tanks_root.get_instance_id()
	var frame := Engine.get_physics_frames()
	if root == _root and frame == _frame:
		return
	_root = root
	_frame = frame
	var rows: Array = []
	for child in tanks_root.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		var mover := Movement.of(tank)
		var moving := mover != null and mover.is_under_way() and mover.yield_to == "" and not mover.in_kturn()
		var heading := Vector2(-tank.global_basis.z.x, -tank.global_basis.z.z).normalized()
		rows.append([String(tank.name), tank.team, tank.global_position.x, tank.global_position.z,
				tank.estimated_velocity.x, tank.estimated_velocity.z, heading.x, heading.y,
				Avoidance.radius_of(tank.unit_id), moving])
	_load(rows)


## Tests: load the table directly. `rows` = [[name, team, x, z, vx, vz, heading_x, heading_z, radius, moving], ...].
static func load_rows(rows: Array) -> void:
	_root = -1
	_frame = -1
	_load(rows)


static func _load(rows: Array) -> void:
	_rows = {}
	_grid = {}
	for row: Array in rows:
		var velocity := Vector2(float(row[4]), float(row[5]))
		var speed := velocity.length()
		var direction := velocity / speed if speed >= MOVING_MPS else Vector2(float(row[6]), float(row[7]))
		var name := String(row[0])
		var team := int(row[1])
		_rows[name] = [team, float(row[2]), float(row[3]), direction.x, direction.y, speed, float(row[8]), bool(row[9])]
		var cells: Dictionary = _grid.get_or_add(team, {})
		var cell := Vector2i(floori(float(row[2]) / CELL), floori(float(row[3]) / CELL))
		var members: PackedStringArray = cells.get(cell, PackedStringArray())
		members.append(name)
		cells[cell] = members
