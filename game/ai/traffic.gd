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
## pair work from the SAME facts — a shared table of positions and velocities (directions from velocity, the hull's
## heading when it is slower than MOVING_MPS), radii and names — and a crossing's verdict is decided ONCE per pair when
## the conflict is first seen and kept while it lasts (`_pairs`), so both crews read the same answer without asking.
##
## COST (CP1b's pass line: <= 0.5 ms a tick on the GDScript path at 25 a side; perf priced the first draft at ~3.6 ms):
## the table is rebuilt every TABLE_TICKS, a crew re-solves its shaping every SOLVE_TICKS (staggered by its name) and
## applies the last answer in between, and a friend behind the crew's own line is skipped before any other work.
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
## The cadence (cost): the table is at most this many ticks old (0.1 s: under 1.2 m of travel at 12 m/s), and a crew's
## answer at most this many (0.2 s; a meeting is seen up to HORIZON_S ahead, so it is answered 4 s before it).
const TABLE_TICKS := 3
const SOLVE_TICKS := 6

## Arm counters (measurement only): ticks a crew's wish was turned right, and ticks it was slowed.
static var kept_right := 0
static var crossing_yields := 0

## The table, per team, flat: names and PackedFloat64Array columns x, z, dx, dz, speed, radius, plus moving
## (PackedByteArray); `_where` maps a name to [team, row]. Doubles, as the GDScript floats they replace.
static var _frame := -1
static var _root := -1
static var _where := {}
static var _teams := {}
## name -> [physics frame solved, lateral m/s to my right, speed cap (INF = none)].
static var _answers := {}
## "a|b" (names sorted) -> [the yielder's name, the frame the verdict expires].
static var _pairs := {}

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
	_answers = {}


## The convention's preferred velocity for `me` from the route's wish `preferred` (x, z): `preferred` unchanged when no
## friend is a party to a meeting or a crossing. Needs the table (refresh, or load_rows in tests).
static func shape(me: String, preferred: Vector2) -> Vector2:
	var keep := not off("keepright")
	var cross := not off("crossing")
	if not (keep or cross):
		return preferred
	var speed := preferred.length()
	if speed < 0.1:
		return preferred
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	var frame := Engine.get_physics_frames() if _root != -1 else _frame
	var answer: Variant = _answers.get(me)
	if answer == null or frame - int(answer[0]) >= SOLVE_TICKS or (frame + (me.hash() & 0xffff)) % SOLVE_TICKS == 0:
		answer = _solve(me, frame, keep, cross)
		_answers[me] = answer
	var out := preferred
	var lateral_speed: float = answer[1]
	if lateral_speed > 0.0:
		kept_right += 1
		var side_sin := minf(lateral_speed / speed, MAX_SIDE_SIN)
		var along := preferred / speed
		out = (along * sqrt(1.0 - side_sin * side_sin) + Vector2(-along.y, along.x) * side_sin) * speed
	var cap: float = answer[2]
	if cap < speed:
		crossing_yields += 1
		out = out / speed * cap
	if OrderController.profiling:
		OrderController.add_part("sz.tr.shape_gd", Time.get_ticks_usec() - lap)
	return out


## [frame, lateral m/s to my right, speed cap] for `me` against every moving friend in reach, from the table.
static func _solve(me: String, frame: int, keep: bool, cross: bool) -> Array:
	var none := [frame, 0.0, INF]
	var where: Variant = _where.get(me)
	if where == null:
		return none
	var cols: Dictionary = _teams[where[0]]
	var i: int = where[1]
	var moving: PackedByteArray = cols["moving"]
	if moving[i] == 0:
		return none
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var dxs: PackedFloat64Array = cols["dx"]
	var dzs: PackedFloat64Array = cols["dz"]
	var speeds: PackedFloat64Array = cols["speed"]
	var radii: PackedFloat64Array = cols["radius"]
	var names: PackedStringArray = cols["names"]
	var px := xs[i]
	var pz := zs[i]
	var ux := dxs[i]
	var uz := dzs[i]
	var v_me := maxf(speeds[i], MIN_SPEED_MPS)
	var my_radius := radii[i]
	var lateral_speed := 0.0
	var cap := INF
	var reach_sq := REACH_M * REACH_M
	for j in names.size():
		if j == i or moving[j] == 0:
			continue
		var dx := xs[j] - px
		var dz := zs[j] - pz
		var ahead := dx * ux + dz * uz
		var clearance := my_radius + radii[j] + CLEAR_MARGIN_M
		if ahead < -clearance or dx * dx + dz * dz > reach_sq:
			continue  # behind my own line, or out of reach
		var wx := dxs[j]
		var wz := dzs[j]
		var v_it := maxf(speeds[j], MIN_SPEED_MPS)
		var facing := ux * wx + uz * wz
		if facing <= HEAD_ON_COS:
			if not keep or ahead <= 0.0:
				continue
			var lateral := dx * -uz + dz * ux  # its offset toward my right
			if absf(lateral) >= clearance:
				continue
			var meet := ahead / (v_me + v_it)
			if meet > HORIZON_S:
				continue
			# I want it on my LEFT by `clearance` (lateral <= -clearance); half of what is missing is mine.
			lateral_speed = maxf(lateral_speed, (lateral + clearance) * 0.5 / maxf(meet - SETTLE_S, 0.5))
		elif facing < FOLLOW_COS and cross:
			var verdict := _crossing(Vector2(px, pz), Vector2(ux, uz), v_me, Vector2(xs[j], zs[j]), Vector2(wx, wz), v_it,
					clearance, me, names[j], frame)
			if verdict >= 0.0:
				cap = minf(cap, verdict)
	return [frame, lateral_speed, cap]


## The crossing of `me` (at p, going u at v_me) with `other` (at q, going w at v_it): the speed `me` must keep under so
## the other clears the conflict zone first, or -1 when `me` does not yield (no conflict, or the other yields). The
## verdict (who yields) is the pair's, decided once and kept while the conflict lasts.
static func _crossing(p: Vector2, u: Vector2, v_me: float, q: Vector2, w: Vector2, v_it: float, clearance: float,
		me: String, other: String, frame: int) -> float:
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
	var key := me + "|" + other if me < other else other + "|" + me
	var kept: Variant = _pairs.get(key)
	var yielder: String
	if kept != null and frame <= int(kept[1]):
		yielder = kept[0]
	else:
		var i_yield: bool
		if absf(t_me - t_it) > TIE_S:
			i_yield = t_me > t_it
		else:
			var it_on_my_right := d.dot(Vector2(-u.y, u.x)) > 0.0
			var me_on_its_right := (-d).dot(Vector2(-w.y, w.x)) > 0.0
			i_yield = it_on_my_right if it_on_my_right != me_on_its_right else me > other
		yielder = me if i_yield else other
	# Kept until both have had time to clear the crossing (renewed while it is still seen).
	_pairs[key] = [yielder, frame + ceili((maxf(t_me, t_it) + occupy) * SimClock.TICK_RATE)]
	if yielder != me:
		return -1.0
	var entry := maxf(s - clearance, 0.0)
	var clear_at := maxf(t_it, 0.0) + clearance / v_it + YIELD_MARGIN_S
	return entry / clear_at


## Rebuild the table from every living hull under `tanks_root` when it is TABLE_TICKS old (or another match's).
static func refresh(tanks_root: Node) -> void:
	var root := tanks_root.get_instance_id()
	var frame := Engine.get_physics_frames()
	if root == _root and frame - _frame < TABLE_TICKS and frame >= _frame:
		return
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	if root != _root:
		_answers = {}
		_pairs = {}
	_root = root
	_frame = frame
	var rows: Array = []
	for child in tanks_root.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		var mover := Movement.of(tank)
		var basis_z := tank.global_basis.z
		var velocity := tank.estimated_velocity
		rows.append([String(tank.name), tank.team, tank.global_position.x, tank.global_position.z, velocity.x, velocity.z,
				-basis_z.x, -basis_z.z, Avoidance.radius_of(tank.unit_id),
				mover != null and mover.is_under_way() and mover.yield_to == "" and not mover.in_kturn()])
	_load(rows)
	for key: String in _pairs.keys():
		if int(_pairs[key][1]) < frame:
			_pairs.erase(key)
	if OrderController.profiling:
		OrderController.add_part("sz.tr.refresh_gd", Time.get_ticks_usec() - lap)


## Tests: load the table directly (and forget every answer and verdict). `rows` = [[name, team, x, z, vx, vz,
## heading_x, heading_z, radius, moving], ...].
static func load_rows(rows: Array) -> void:
	_root = -1
	_frame = 0
	_answers = {}
	_pairs = {}
	_load(rows)


## Rows into the per-team columns: direction from the velocity, or the (normalized) heading under MOVING_MPS. Packed
## arrays are values (trip-up 48): each column is built in a local and stored once.
static func _load(rows: Array) -> void:
	_where = {}
	_teams = {}
	var by_team := {}
	for row: Array in rows:
		(by_team.get_or_add(int(row[1]), []) as Array).append(row)
	for team: int in by_team:
		var names := PackedStringArray()
		var xs := PackedFloat64Array()
		var zs := PackedFloat64Array()
		var dxs := PackedFloat64Array()
		var dzs := PackedFloat64Array()
		var speeds := PackedFloat64Array()
		var radii := PackedFloat64Array()
		var moving := PackedByteArray()
		for row: Array in by_team[team]:
			var velocity := Vector2(float(row[4]), float(row[5]))
			var speed := velocity.length()
			var direction := velocity / speed if speed >= MOVING_MPS else Vector2(float(row[6]), float(row[7])).normalized()
			_where[String(row[0])] = [team, names.size()]
			names.append(String(row[0]))
			xs.append(float(row[2]))
			zs.append(float(row[3]))
			dxs.append(direction.x)
			dzs.append(direction.y)
			speeds.append(speed)
			radii.append(float(row[8]))
			moving.append(1 if bool(row[9]) else 0)
		_teams[team] = {"names": names, "x": xs, "z": zs, "dx": dxs, "dz": dzs, "speed": speeds, "radius": radii,
				"moving": moving}
