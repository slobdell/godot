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
##   parked  CP1a2: a crew whose ask a PARKED friend refused does not give way to it (nobody to let past)
##           (Movement._negotiate; counter Movement.parked_refusals).
##   hold    Round 29 T1 (his call, round 28: TAKE TURNS): two friendly squads meeting HEAD-ON in a street take turns
##           like a one-lane bridge, and the waiting squad waits at a real spot beside the street's mouth (below).
##   turns   Round 29 T3 (round 28's v3, `traffic-t1-v3`): two friendly squads CROSSING take turns: one verdict per squad
##           pair; the squad reaching the crossing later slows as a whole and passes behind the other (THE CROSSING).
##
## THE STREET HOLD (round 29 T1; round 28's T1b `traffic-t1b` is the ancestor: its verdict, a creep instead of a spot).
## Between FRIENDLY squads (an element; a crew outside one is its own squad), both moving. Every crew works from the
## SAME table of positions, directions, speeds, radii and squads, rebuilt every TABLE_TICKS.
##
##   the meeting  a crew sees a crew of another squad ahead, coming the other way (within HEAD_ON_COS of opposite, the
##                two SQUADS' mean headings too), within STREET_LATERAL_M across and STREET_HORIZON_S of meeting, and
##                the ground at the middle between them is a street (the navmesh ends within STREET_SIDE_M on both
##                sides). ONE verdict per squad pair: the squad whose lead crew is still in the OPEN waits (it has room
##                to; the other is committed to the street); if both or neither, the one whose lead reaches the middle
##                later; inside TIE_S, the greater id.
##   the spots    the waiting squad finds the street's MOUTH on its lead's route (the first point of it that is a
##                street) and its centre line there. Each crew, lead first, takes the first free spot of a grid behind
##                the mouth (HOLD_BACK_M along its way back from the mouth) and to the RIGHT of the centre line
##                (HOLD_SIDE_M): off the passing squad's line as it comes out, on walkable ground with room for the hull,
##                not on a squadmate's spot or a parked hull. No room on the right: the left. A crew already past the
##                mouth pulls to the right edge where it is.
##   the hold     the crew drives to its spot (ORCA as always), stops there facing its way, and HOLDS until every
##                moving crew of the passing squad is behind it, or HOLD_CAP_S after the verdict (then it goes, and that
##                squad pair gets no new verdict for REMEET_S). `Traffic.holding(crew)` is true meanwhile: brains' stall
##                clock, "blocked" phase and the element's re-seat clock, manoeuvre's unstick, pressing escape and k-turn,
##                and the give-way's asks read it (C29.3), so a holding crew is waiting, not stuck.
##
## THE CROSSING (round 29 T3; round 28's v3, judged there on ALL friendly contacts and missed; here on the contacts
## between the squads, lesson 301). It shapes ORCA's PREFERRED velocity in Movement._avoid and nothing else. Two crews of
## different squads, both moving, whose straight motions really meet (closest approach inside the pair's clearance within
## HORIZON_S), the two SQUADS' mean headings crossing (neither within FOLLOW_COS of the same way nor HEAD_ON_COS of
## opposite). ONE verdict per squad pair, made the first time any of their crews meet and kept while they keep meeting:
## at that pair's crossing point, each squad's first crew to reach it; the later squad yields; inside TIE_S, the squad
## whose first crew has the other's on its right yields; then the id. A crew of the yielding squad caps its speed to reach
## the conflict zone after the other has cleared it (+ YIELD_MARGIN_S), never under YIELD_FLOOR of its wish, never once
## it is at the zone's edge; its whole squad short of the crossing keeps the same share (wholesquad).
##
## COST (C29.5: <= 0.5 ms a tick at 25 a side, GDScript path): the table every TABLE_TICKS; a crew looks for a meeting
## every SOLVE_TICKS (staggered by its name), a friend behind its own line skipped before any other work; the street
## read (navmesh probes) only at a meeting's middle and a lead's position, cached; spots once per verdict.


## A slot that moves less than this between two reads of the element is the formation sliding, not a re-seat. It is
## Movement's own goal-jump distance (`_track_progress` starts a new progress record when the goal moves more than 2 m),
## so a slide the feed now lets through is one Movement already treats as the same goal; and it is a quarter of the
## tightest doctrine spacing (8 m: doctrine_standard.json, dense terrain; a corridor narrows a shape ACROSS but keeps
## its pitch ALONG), so a re-seat — a crew sent to another slot of the shape — moves it further. Measured slides on
## his head-on case: millimetres per update (T0 trace, streams/archive/round26/traffic.md Status).
const SLOT_SLIDE_M := 2.0

## The meeting (T1b's numbers, measured in round 28).
const HEAD_ON_COS := -0.766  # cos 140 deg: within 40 deg of opposite
const CLEAR_MARGIN_M := 1.5
const TIE_S := 0.5
const STREET_HORIZON_S := 8.0
const STREET_REACH_M := 100.0
const STREET_LATERAL_M := 14.0
## A street: the navmesh ends within this far on BOTH sides (m; probes every STREET_STEP_M). His Terminus streets are
## 20 m between the blocks; the yard's band is 60 m+.
const STREET_SIDE_M := 16.0
const STREET_STEP_M := 4.0
## A probe this far off the navmesh is outside it (m).
const STREET_OFF_M := 1.0
const MOVING_MPS := 1.0
const MIN_SPEED_MPS := 1.0
## A squad on the move: at least this share of its crews moving (and two), so a squad settling at its goal, a straggler
## or two still shuffling, is not one (v1's tuning: four spurious verdicts in the Terminus crossing came from squads
## milling at their goals); and each crew of the meeting pair heads within this of its squad's way.
const TRAVELLING_SHARE := 0.6
const WITH_SQUAD_COS := 0.7

## The crossing (round 28 v3's numbers).
const REACH_M := 45.0
const HORIZON_S := 4.5
const FOLLOW_COS := 0.866  # cos 30 deg: going the same way is following, not crossing
const YIELD_MARGIN_S := 0.4
## The least share of its wish a yielding crew keeps (it slows to pass behind, it does not stop).
const YIELD_FLOOR := 0.4
## A yielding crew this close to the conflict zone's edge (m) does not yield: it is in the way, so it clears out.
const COMMITTED_M := 1.0
## A squad pair's crossing verdict lives this long after their crews last met (s): long enough for a squad's tail to pass.
const VERDICT_KEEP_S := 3.0

## The spots. The mouth is looked for along the lead's route this far (m), every MOUTH_STEP_M.
const MOUTH_REACH_M := 80.0
const MOUTH_STEP_M := 2.0
## Back from the mouth along the waiting squad's way (m), nearest first; across to the right of the street's centre line
## (m): the passing squad comes out of an 18-20 m street, so 12 m off its centre line is clear of a hull in it.
const HOLD_BACK_M: Array[float] = [8.0, 15.0, 22.0, 29.0, 36.0, 43.0]
const HOLD_SIDE_M: Array[float] = [12.0, 17.0, 22.0]
## A crew already past the mouth pulls this far right of where it is (m), the first that fits.
const EDGE_SIDE_M: Array[float] = [6.0, 4.0, 2.0]
## Room for the hull at a spot: walkable this far beyond its radius in four directions (m); two spots (or a spot and a
## parked hull) at least both radii + this apart.
const SPOT_ROOM_M := 1.0
const SPOT_GAP_M := 2.0
## ...and clear of the passing squad's way OUT of the street: the run from the mouth's centre to its destination, and a
## disc round the destination as wide as its formation (both + its biggest radius + this, m). v2's worst run (seed 2,
## tick 1): the waiting squad held where the passing squad's formation spreads out on arrival, and the passing crews drove
## into it (38 fast contacts, the cap).
const PASSER_CLEAR_M := 3.0
## At its spot within this (m) a crew stops; it slows to its spot over HOLD_SLOW_M. A spot it has overshot (behind its
## nose, within HOLD_OVERSHOT_M) counts as reached: it stops where it is rather than backing up (seed 1's first trace: a
## wheeled tank came in at 9 m/s, ran 8 m past and reversed into a squadmate).
const HOLD_REACHED_M := 2.5
const HOLD_SLOW_M := 16.0
const HOLD_OVERSHOT_M := 6.0
## The cap: a waiting squad goes this long after its verdict whatever the other is doing (s), and that pair is not
## held again for REMEET_S.
const HOLD_CAP_S := 20.0
const REMEET_S := 30.0
## A crew of the passing squad within this of my line's foot (m, along my way) is not behind me yet.
const BEHIND_M := 2.0
## A crew's hold is live while the mover asked for it this recently (ticks): a crew no longer driving (arrived, a
## reverse order, a fight) is not holding.
const LIVE_TICKS := 3
## The cadence (cost).
const TABLE_TICKS := 3
const SOLVE_TICKS := 6
const STREET_TICKS := 30

## Arm counters (measurement only): squad-pair verdicts, crews sent to a spot, crew-ticks held, releases by cause.
static var verdicts := 0
static var holds := 0
static var hold_ticks := 0
static var released_passed := 0
static var released_cap := 0
static var no_spot := 0
## The crossing's counters (measurement only): squad-pair verdicts made, crew-ticks a wish was slowed.
static var cross_verdicts := 0
static var cross_slowed := 0
## Measurement only: print each wait (its mouth, centre line and spots) and each release as it happens.
static var log_waits := false

## The table, per team: names and PackedFloat64Array columns x, z, dx, dz, speed, radius, plus moving
## (PackedByteArray) and group (PackedStringArray); `_where` maps a name to [team, row]; `_movers` a name to its mover.
static var _frame := -1
static var _root := -1
static var _map := RID()
static var _where := {}
static var _teams := {}
static var _movers := {}
## name -> the physics frame it last looked for a meeting.
static var _looked := {}
## The crossing: name -> [frame solved, speed cap (INF = none)]; "groupA|groupB" -> [the yielding group, the frame the
## verdict expires]; group -> [frame, the least share of its wish a crew of it keeps, the crossing point]; the crossing
## point of the last _crossing call.
static var _cross_answers := {}
static var _cross_kept := {}
static var _shares := {}
static var _last_point := Vector2.ZERO
## "groupA|groupB" (sorted) -> [the waiting group, the frame the verdict was made, the frame it may be made again].
static var _verdicts := {}
## waiting group -> {"passer": group, "key": pair key, "since": frame, "dir": Vector2 (its way), "spots": {name: [Vector2
## spot, Vector2 face]}, "released": {name: true}}.
static var _waits := {}
## name -> the frame its mover last read its hold (holding() is true while that is recent).
static var _live := {}
## name -> [frame read, is a street].
static var _streets := {}
## Tests: a street answer instead of the navmesh: a bool for everywhere, or a Callable(x, z) -> bool (null = the navmesh).
static var street_override: Variant = null
## Tests: walkable ground instead of the navmesh: a Callable(x, z) -> bool (null = the navmesh; no map = everywhere).
static var ground_override: Variant = null
## Tests: squads' destinations by group ([Vector2, spread], else their elements').
static var destinations := {}

static var _off := {}
static var _parsed := false


## Is the behaviour `name` switched off for this run (`--traffic-off=name,...`)?
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
	_forget()


## Is this crew holding for traffic (waiting at a street mouth for another squad to come through)? C29.3's gates read it.
static func holding(crew: String) -> bool:
	var seen: Variant = _live.get(crew)
	if seen == null:
		return false
	var frame := Engine.get_physics_frames() if _root != -1 else _frame
	return frame - int(seen) <= LIVE_TICKS and frame >= int(seen)


## The counters as one reading (the traffic probe reports it), and back to zero.
static func report() -> Dictionary:
	return {"tr_verdicts": verdicts, "tr_holds": holds, "tr_hold_ticks": hold_ticks, "tr_released_passed": released_passed,
			"tr_released_cap": released_cap, "tr_no_spot": no_spot, "tr_cross_verdicts": cross_verdicts,
			"tr_cross_slowed": cross_slowed}


static func reset_counters() -> void:
	verdicts = 0
	holds = 0
	hold_ticks = 0
	released_passed = 0
	released_cap = 0
	no_spot = 0
	cross_verdicts = 0
	cross_slowed = 0


## The hold for crew `me` this tick: [] when it is not holding; else [spot (x, z), face (x, z), at the spot]. Movement's
## _avoid calls it every tick it steers; it needs the table (refresh, or load_rows).
static func hold_of(me: String) -> Array:
	if off("hold"):
		return []
	var where: Variant = _where.get(me)
	if where == null:
		return []
	var frame := Engine.get_physics_frames() if _root != -1 else _frame
	var cols: Dictionary = _teams[where[0]]
	var i: int = where[1]
	var group: String = (cols["group"] as PackedStringArray)[i]
	if not _waits.has(group):
		var last: Variant = _looked.get(me)
		if last == null or frame - int(last) >= SOLVE_TICKS or frame < int(last) or (frame + (me.hash() & 0xffff)) % SOLVE_TICKS == 0:
			_looked[me] = frame
			if (cols["moving"] as PackedByteArray)[i] == 1:
				var lap := Time.get_ticks_usec() if OrderController.profiling else 0
				_look(me, frame, i, cols)
				if OrderController.profiling:
					OrderController.add_part("sz.tr.look_gd", Time.get_ticks_usec() - lap)
	var wait: Variant = _waits.get(group)
	if wait == null:
		return []
	var spot: Variant = (wait["spots"] as Dictionary).get(me)
	if spot == null or (wait["released"] as Dictionary).has(me):
		return []
	if frame - int(wait["since"]) >= ceili(HOLD_CAP_S * SimClock.TICK_RATE):
		_end_wait(group, frame)
		released_cap += 1
		if log_waits:
			print("TRAFFIC_RELEASE " + JSON.stringify({"frame": frame, "crew": me, "why": "cap", "group": group}))
		return []
	var here := Vector2((cols["x"] as PackedFloat64Array)[i], (cols["z"] as PackedFloat64Array)[i])
	if _passed(here, wait["dir"], wait["passer"], cols):
		(wait["released"] as Dictionary)[me] = true
		released_passed += 1
		if log_waits:
			print("TRAFFIC_RELEASE " + JSON.stringify({"frame": frame, "crew": me, "why": "passed", "held_s": snappedf(float(frame - int(wait["since"])) / SimClock.TICK_RATE, 0.1)}))
		if (wait["released"] as Dictionary).size() >= (wait["spots"] as Dictionary).size():
			_end_wait(group, frame)
		return []
	_live[me] = frame
	hold_ticks += 1
	var at: Vector2 = spot[0]
	var gap := here.distance_to(at)
	var heading := Vector2((cols["dx"] as PackedFloat64Array)[i], (cols["dz"] as PackedFloat64Array)[i])
	var there := gap <= HOLD_REACHED_M or (gap <= HOLD_OVERSHOT_M and (at - here).dot(heading) < 0.0)
	return [at, spot[1], there]


## Is every crew of `passer` still under way behind the crew at `here` going `dir` (or none left moving)?
static func _passed(here: Vector2, dir: Vector2, passer: String, cols: Dictionary) -> bool:
	var groups: PackedStringArray = cols["group"]
	var under_way: PackedByteArray = cols["under_way"]
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	for k in groups.size():
		if groups[k] != passer or under_way[k] == 0:
			continue  # arrived: it is through (a crew giving way or in a k-turn is still coming)
		if (xs[k] - here.x) * dir.x + (zs[k] - here.y) * dir.y > -BEHIND_M:
			return false
	return true


static func _end_wait(group: String, frame: int) -> void:
	var wait: Dictionary = _waits[group]
	var kept: Variant = _verdicts.get(wait["key"])
	if kept != null:
		kept[2] = frame + ceili(REMEET_S * SimClock.TICK_RATE)
	_waits.erase(group)


## Crew i (`me`) looks for a head-on meeting in a street with a crew of another squad; a verdict that its squad waits
## starts the squad's wait.
static func _look(me: String, frame: int, i: int, cols: Dictionary) -> void:
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var dxs: PackedFloat64Array = cols["dx"]
	var dzs: PackedFloat64Array = cols["dz"]
	var speeds: PackedFloat64Array = cols["speed"]
	var radii: PackedFloat64Array = cols["radius"]
	var moving: PackedByteArray = cols["moving"]
	var groups: PackedStringArray = cols["group"]
	var headings: Dictionary = cols["gdir"]
	var px := xs[i]
	var pz := zs[i]
	var ux := dxs[i]
	var uz := dzs[i]
	var mine := groups[i]
	var v_me := maxf(speeds[i], MIN_SPEED_MPS)
	var reach_sq := STREET_REACH_M * STREET_REACH_M
	for j in groups.size():
		if j == i or moving[j] == 0 or groups[j] == mine:
			continue
		var dx := xs[j] - px
		var dz := zs[j] - pz
		var ahead := dx * ux + dz * uz
		if ahead <= 0.0 or dx * dx + dz * dz > reach_sq:
			continue
		if ux * dxs[j] + uz * dzs[j] > HEAD_ON_COS:
			continue
		var theirs := groups[j]
		var my_way := headings.get(mine, Vector2.ZERO) as Vector2
		var its_way := headings.get(theirs, Vector2.ZERO) as Vector2
		if my_way.dot(its_way) > HEAD_ON_COS or absf(dx * -uz + dz * ux) > STREET_LATERAL_M:
			continue
		if my_way.dot(Vector2(ux, uz)) < WITH_SQUAD_COS or its_way.dot(Vector2(dxs[j], dzs[j])) < WITH_SQUAD_COS:
			continue
		if not _travelling(mine, cols) or not _travelling(theirs, cols):
			continue
		if ahead / (v_me + maxf(speeds[j], MIN_SPEED_MPS)) > STREET_HORIZON_S:
			continue
		var key := mine + "|" + theirs if mine < theirs else theirs + "|" + mine
		var kept: Variant = _verdicts.get(key)
		if kept != null and frame < int(kept[2]):
			continue  # this pair was decided (and waited, or is waiting): not again yet
		var middle := Vector2((px + xs[j]) * 0.5, (pz + zs[j]) * 0.5)
		if not _street("@" + key, frame, middle.x, middle.y, ux, uz):
			continue
		var waiter := _decide_street(middle, mine, theirs, cols, frame)
		var passer := theirs if waiter == mine else mine
		verdicts += 1
		# A waiting squad's verdict stands until its wait ends (then REMEET_S more: _end_wait).
		_verdicts[key] = [waiter, frame, frame + ceili((HOLD_CAP_S + REMEET_S) * SimClock.TICK_RATE)]
		_begin_wait(waiter, passer, key, frame, cols)
		return


## Is squad `group` travelling: TRAVELLING_SHARE of its crews (and at least two) moving?
static func _travelling(group: String, cols: Dictionary) -> bool:
	var counts: Array = (cols["gcount"] as Dictionary).get(group, [0, 0])
	return int(counts[1]) >= 2 and float(counts[1]) >= TRAVELLING_SHARE * float(counts[0])


## THE CROSSING: crew `me`'s preferred velocity from the route's wish `preferred` (x, z): unchanged unless its squad
## yields at a crossing with another squad (then slowed, its heading kept). Needs the table (refresh, or load_rows).
static func shape(me: String, preferred: Vector2) -> Vector2:
	if off("turns"):
		return preferred
	var speed := preferred.length()
	if speed < 0.1:
		return preferred
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	var frame := Engine.get_physics_frames() if _root != -1 else _frame
	var answer: Variant = _cross_answers.get(me)
	if answer == null or frame - int(answer[0]) >= SOLVE_TICKS or frame < int(answer[0]) \
			or (frame + (me.hash() & 0xffff)) % SOLVE_TICKS == 0:
		answer = [frame, _cross_cap(me, frame)]
		_cross_answers[me] = answer
	var keep_speed := speed
	var cap: float = answer[1]
	if cap < speed:
		keep_speed = maxf(cap, YIELD_FLOOR * speed)
	keep_speed = minf(keep_speed, _squad_share(me, frame) * speed)
	var out := preferred
	if keep_speed < speed:
		cross_slowed += 1
		out = preferred / speed * keep_speed
	if OrderController.profiling:
		OrderController.add_part("sz.tr.shape_gd", Time.get_ticks_usec() - lap)
	return out


## The speed cap (INF = none) for crew `me` against every moving crew of another squad in reach, from the table.
static func _cross_cap(me: String, frame: int) -> float:
	var where: Variant = _where.get(me)
	if where == null:
		return INF
	var cols: Dictionary = _teams[where[0]]
	var i: int = where[1]
	var moving: PackedByteArray = cols["moving"]
	if moving[i] == 0:
		return INF
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var dxs: PackedFloat64Array = cols["dx"]
	var dzs: PackedFloat64Array = cols["dz"]
	var speeds: PackedFloat64Array = cols["speed"]
	var radii: PackedFloat64Array = cols["radius"]
	var groups: PackedStringArray = cols["group"]
	var headings: Dictionary = cols["gdir"]
	var px := xs[i]
	var pz := zs[i]
	var ux := dxs[i]
	var uz := dzs[i]
	var mine := groups[i]
	var v_me := maxf(speeds[i], MIN_SPEED_MPS)
	var cap := INF
	var reach_sq := REACH_M * REACH_M
	for j in groups.size():
		if j == i or moving[j] == 0 or groups[j] == mine:
			continue
		var dx := xs[j] - px
		var dz := zs[j] - pz
		var clearance := radii[i] + radii[j] + CLEAR_MARGIN_M
		if dx * ux + dz * uz < -clearance or dx * dx + dz * dz > reach_sq:
			continue  # behind my own line, or out of reach
		var wx := dxs[j]
		var wz := dzs[j]
		var v_it := maxf(speeds[j], MIN_SPEED_MPS)
		# Only a real meeting: the two straight-line motions come within the pair's clearance inside HORIZON_S.
		var rvx := wx * v_it - ux * v_me
		var rvz := wz * v_it - uz * v_me
		var rv2 := rvx * rvx + rvz * rvz
		var t := 0.0 if rv2 < 0.0001 else clampf(-(dx * rvx + dz * rvz) / rv2, 0.0, HORIZON_S)
		var mx := dx + rvx * t
		var mz := dz + rvz * t
		if mx * mx + mz * mz >= clearance * clearance:
			continue
		# A crossing of the two SQUADS' ways, and of the two crews' (neither following nor head-on).
		var g := (headings.get(mine, Vector2.ZERO) as Vector2).dot(headings.get(groups[j], Vector2.ZERO) as Vector2)
		var facing := ux * wx + uz * wz
		if not (g < FOLLOW_COS and g > HEAD_ON_COS and facing < FOLLOW_COS):
			continue
		var verdict := _crossing(Vector2(px, pz), Vector2(ux, uz), v_me, Vector2(xs[j], zs[j]), Vector2(wx, wz), v_it,
				clearance, mine, groups[j], frame, cols)
		if verdict >= 0.0 and verdict < cap:
			cap = verdict
			_note_share(mine, frame, maxf(verdict / v_me, YIELD_FLOOR), _last_point)
	return cap


## The crossing of my crew (at p, going u at v_me, squad `mine`) with a crew of squad `theirs` (at q, going w at v_it):
## the speed my crew must keep under so the other clears the conflict zone first, or -1 when it does not yield (no
## conflict, my squad passes first, or I am already at the zone). The verdict is the SQUAD pair's, decided once.
static func _crossing(p: Vector2, u: Vector2, v_me: float, q: Vector2, w: Vector2, v_it: float, clearance: float,
		mine: String, theirs: String, frame: int, cols: Dictionary) -> float:
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
	_last_point = p + u * s
	var key := mine + "|" + theirs if mine < theirs else theirs + "|" + mine
	var kept: Variant = _cross_kept.get(key)
	var yielder: String
	if kept != null and frame <= int(kept[1]):
		yielder = kept[0]
	else:
		yielder = _decide(p + u * s, mine, theirs, cols)
		cross_verdicts += 1
	# Kept while the squads keep meeting, and VERDICT_KEEP_S after (a squad's tail is still passing).
	_cross_kept[key] = [yielder, frame + ceili((maxf(t_me, t_it) + occupy + VERDICT_KEEP_S) * SimClock.TICK_RATE)]
	if yielder != mine:
		return -1.0
	var entry := s - clearance
	if entry <= COMMITTED_M:
		return -1.0  # at the zone already: clear out of the way, never stop in it
	var clear_at := maxf(t_it, 0.0) + clearance / v_it + YIELD_MARGIN_S
	return entry / clear_at


## Which of two squads yields at the crossing point `x`: each squad's FIRST moving crew to reach it (time along its own
## line, crews already past it skipped); the later squad yields. Inside TIE_S, the squad whose first crew has the
## other's on its right; if that does not decide it, the greater id. Pure over the table: every crew asking gets this.
static func _decide(x: Vector2, a: String, b: String, cols: Dictionary) -> String:
	var first_a := _first_to(x, a, cols)
	var first_b := _first_to(x, b, cols)
	if first_a.is_empty() or first_b.is_empty():
		return b if first_a.is_empty() else a  # a squad already through the point holds; the other yields
	var ta: float = first_a[0]
	var tb: float = first_b[0]
	if absf(ta - tb) > TIE_S:
		return a if ta > tb else b
	var pa: Vector2 = first_a[1]
	var ua: Vector2 = first_a[2]
	var pb: Vector2 = first_b[1]
	var ub: Vector2 = first_b[2]
	var b_on_a_right := (pb - pa).dot(Vector2(-ua.y, ua.x)) > 0.0
	var a_on_b_right := (pa - pb).dot(Vector2(-ub.y, ub.x)) > 0.0
	if b_on_a_right != a_on_b_right:
		return a if b_on_a_right else b
	return a if a > b else b


## wholesquad: record that a crew of `group` keeps `share` of its wish to yield at `point` this frame.
static func _note_share(group: String, frame: int, share: float, point: Vector2) -> void:
	var known: Variant = _shares.get(group)
	if known == null or frame - int(known[0]) > SOLVE_TICKS or share <= float(known[1]):
		_shares[group] = [frame, share, point]


## wholesquad: the share of its wish crew `me` keeps because its squad is yielding (1.0 = none): the squad's least share
## while it is fresh, for a crew still short of the crossing point.
static func _squad_share(me: String, frame: int) -> float:
	var where: Variant = _where.get(me)
	if where == null:
		return 1.0
	var cols: Dictionary = _teams[where[0]]
	var i: int = where[1]
	if (cols["moving"] as PackedByteArray)[i] == 0:
		return 1.0
	var known: Variant = _shares.get((cols["group"] as PackedStringArray)[i])
	if known == null or frame - int(known[0]) > SOLVE_TICKS or frame < int(known[0]):
		return 1.0
	var point: Vector2 = known[2]
	var along := (point.x - (cols["x"] as PackedFloat64Array)[i]) * (cols["dx"] as PackedFloat64Array)[i] \
			+ (point.y - (cols["z"] as PackedFloat64Array)[i]) * (cols["dz"] as PackedFloat64Array)[i]
	if along - (cols["radius"] as PackedFloat64Array)[i] - CLEAR_MARGIN_M <= COMMITTED_M:
		return 1.0  # at or past the crossing: clear out
	return float(known[1])


## Which squad waits for a head-on meeting in a street at `middle` (T1b's verdict).
static func _decide_street(middle: Vector2, a: String, b: String, cols: Dictionary, frame: int) -> String:
	var first_a := _first_to(middle, a, cols)
	var first_b := _first_to(middle, b, cols)
	if first_a.is_empty() or first_b.is_empty():
		return b if first_a.is_empty() else a
	var pa: Vector2 = first_a[1]
	var ua: Vector2 = first_a[2]
	var pb: Vector2 = first_b[1]
	var ub: Vector2 = first_b[2]
	var a_open := not _street("@lead:" + a, frame, pa.x, pa.y, ua.x, ua.y)
	var b_open := not _street("@lead:" + b, frame, pb.x, pb.y, ub.x, ub.y)
	if a_open != b_open:
		return a if a_open else b
	var ta: float = first_a[0]
	var tb: float = first_b[0]
	if absf(ta - tb) > TIE_S:
		return a if ta > tb else b
	return a if a > b else b


## [seconds, position, direction, row] of squad `group`'s moving crew that reaches `x` first, or [] when none is short of it.
static func _first_to(x: Vector2, group: String, cols: Dictionary) -> Array:
	var groups: PackedStringArray = cols["group"]
	var moving: PackedByteArray = cols["moving"]
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var dxs: PackedFloat64Array = cols["dx"]
	var dzs: PackedFloat64Array = cols["dz"]
	var speeds: PackedFloat64Array = cols["speed"]
	var radii: PackedFloat64Array = cols["radius"]
	var best: Array = []
	for k in groups.size():
		if groups[k] != group or moving[k] == 0:
			continue
		var along := (x.x - xs[k]) * dxs[k] + (x.y - zs[k]) * dzs[k]
		if along < -radii[k]:
			continue
		var seconds := maxf(along, 0.0) / maxf(speeds[k], MIN_SPEED_MPS)
		if best.is_empty() or seconds < float(best[0]):
			best = [seconds, Vector2(xs[k], zs[k]), Vector2(dxs[k], dzs[k]), k]
	return best


## The waiting squad's spots: the mouth on its lead's route, the street's centre line there, then a spot for each crew.
static func _begin_wait(waiter: String, passer: String, key: String, frame: int, cols: Dictionary) -> void:
	var groups: PackedStringArray = cols["group"]
	var moving: PackedByteArray = cols["moving"]
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var radii: PackedFloat64Array = cols["radius"]
	var dir := (cols["gdir"] as Dictionary).get(waiter, Vector2.ZERO) as Vector2
	var wait := {"passer": passer, "key": key, "since": frame, "dir": dir, "spots": {}, "released": {}}
	_waits[waiter] = wait
	if dir == Vector2.ZERO:
		return
	# The lead: the waiting squad's crew furthest along its way.
	var lead := -1
	var lead_along := -INF
	for k in groups.size():
		if groups[k] == waiter and moving[k] == 1:
			var along := xs[k] * dir.x + zs[k] * dir.y
			if along > lead_along:
				lead_along = along
				lead = k
	if lead < 0:
		return
	var names: PackedStringArray = cols["names"]
	var mouth := _mouth(names[lead], Vector2(xs[lead], zs[lead]), dir, frame)
	if mouth == Vector2.INF:
		_end_wait(waiter, frame)  # no street on its way within reach: not a meeting it can wait for (ORCA's)
		return
	var right := Vector2(-dir.y, dir.x)
	var centre := _centre(mouth, right)
	# Crews nearest the mouth first (furthest along their way).
	var order: Array = []
	for k in groups.size():
		if groups[k] == waiter and moving[k] == 1:
			order.append([-(xs[k] * dir.x + zs[k] * dir.y), k])
	order.sort()
	var taken: Array[Vector3] = []  # x, z, radius
	# The passing squad's way out of the mouth: [from, to, clearance] runs (a crew's own leg to the destination's
	# centre line, and a disc round the destination as wide as the squad's formation).
	var runs: Array = []
	var biggest := 0.0
	for k in groups.size():
		if groups[k] == passer:
			biggest = maxf(biggest, radii[k])
	var destination: Array = _destination(passer, cols)
	if not destination.is_empty():
		var to: Vector2 = destination[0]
		runs.append([centre, to, biggest + PASSER_CLEAR_M])
		runs.append([to, to, biggest + float(destination[1]) + PASSER_CLEAR_M])
	for entry: Array in order:
		var k: int = entry[1]
		var here := Vector2(xs[k], zs[k])
		var spot := Vector2.INF
		if (here - centre).dot(dir) < 0.0:
			spot = _spot_behind(centre, dir, right, radii[k], taken, runs, cols)
		else:
			spot = _spot_edge(here, right, radii[k], taken, runs, cols)
		if spot == Vector2.INF:
			no_spot += 1
			spot = here  # nowhere to pull aside: wait where it is
		taken.append(Vector3(spot.x, spot.y, radii[k]))
		(wait["spots"] as Dictionary)[names[k]] = [spot, spot + dir * 20.0]
		holds += 1
	if log_waits:
		var listed := {}
		for name: String in wait["spots"]:
			var at: Vector2 = wait["spots"][name][0]
			listed[name] = [snappedf(at.x, 0.1), snappedf(at.y, 0.1)]
		print("TRAFFIC_WAIT " + JSON.stringify({"frame": frame, "waiter": waiter, "passer": passer, "dir": [snappedf(dir.x, 0.01),
				snappedf(dir.y, 0.01)], "mouth": str(mouth), "centre": str(centre), "spots": listed,
				"runs": runs.map(func(r: Array) -> String: return str(r[1]))}))


## The first point of a street on the lead's route (its mover's path ahead, then straight on along `dir`), or INF.
static func _mouth(lead: String, from: Vector2, dir: Vector2, frame: int) -> Vector2:
	var points: Array[Vector2] = [from]
	var mover: Movement = _movers.get(lead)
	if mover != null:
		for p in range(mover._path_index, mover._path.size()):
			points.append(Vector2(mover._path[p].x, mover._path[p].z))
	# The path ends at the crew's next slot (an element moves in legs): beyond it, straight on along the squad's way.
	points.append(points[points.size() - 1] + dir * MOUTH_REACH_M)
	var walked := 0.0
	for s in range(1, points.size()):
		var a: Vector2 = points[s - 1]
		var b: Vector2 = points[s]
		var leg := a.distance_to(b)
		if leg < 0.01:
			continue
		var u := (b - a) / leg
		var t := 0.0
		while t < leg and walked + t <= MOUTH_REACH_M:
			var at := a + u * t
			if _street_at(at.x, at.y, u.x, u.y):
				return at
			t += MOUTH_STEP_M
		walked += leg
		if walked > MOUTH_REACH_M:
			break
	return Vector2.INF


## The street's centre line through `mouth`: half way between its two edges along `right`.
static func _centre(mouth: Vector2, right: Vector2) -> Vector2:
	var to_right := _edge(mouth, right)
	var to_left := _edge(mouth, -right)
	return mouth + right * (to_right - to_left) * 0.5


## How far walkable ground goes from `at` along `side` (m, 1 m steps, at most STREET_SIDE_M).
static func _edge(at: Vector2, side: Vector2) -> float:
	var reach := 1.0
	while reach <= STREET_SIDE_M:
		var p := at + side * reach
		if not _walkable(p.x, p.y):
			return reach - 1.0
		reach += 1.0
	return STREET_SIDE_M


## The first free spot behind the mouth's centre line and to its right (then its left), or INF.
static func _spot_behind(centre: Vector2, dir: Vector2, right: Vector2, radius: float, taken: Array[Vector3],
		runs: Array, cols: Dictionary) -> Vector2:
	for sign_side: float in [1.0, -1.0]:
		for back: float in HOLD_BACK_M:
			for side: float in HOLD_SIDE_M:
				var spot := centre - dir * back + right * side * sign_side
				if _fits(spot, dir, radius, taken, runs, cols):
					return spot
	return Vector2.INF


## A crew already past the mouth: pulled right of where it is (first that fits), or INF.
static func _spot_edge(here: Vector2, right: Vector2, radius: float, taken: Array[Vector3], runs: Array,
		cols: Dictionary) -> Vector2:
	for side: float in EDGE_SIDE_M:
		var spot := here + right * side
		if _fits(spot, Vector2(right.y, -right.x), radius, taken, [], cols):
			return spot
	return Vector2.INF


## Room for a hull of `radius` at `spot`: walkable there and SPOT_ROOM_M past its radius four ways; clear of the spots
## already taken, of every parked hull of the team, and of the passing squad's `runs` out of the mouth.
static func _fits(spot: Vector2, dir: Vector2, radius: float, taken: Array[Vector3], runs: Array, cols: Dictionary) -> bool:
	var room := radius + SPOT_ROOM_M
	var right := Vector2(-dir.y, dir.x)
	for probe: Vector2 in [spot, spot + dir * room, spot - dir * room, spot + right * room, spot - right * room]:
		if not _walkable(probe.x, probe.y):
			return false
	for other: Vector3 in taken:
		if Vector2(other.x, other.y).distance_to(spot) < radius + other.z + SPOT_GAP_M:
			return false
	for run: Array in runs:
		var a: Vector2 = run[0]
		var b: Vector2 = run[1]
		var ab := b - a
		var t := clampf((spot - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(spot) < radius + float(run[2]):
			return false
	var moving: PackedByteArray = cols["moving"]
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var radii: PackedFloat64Array = cols["radius"]
	for k in moving.size():
		if moving[k] == 0 and Vector2(xs[k], zs[k]).distance_to(spot) < radius + radii[k] + SPOT_GAP_M:
			return false
	return true


## Where squad `group` is going: [its destination (x, z), its formation's spread (m: the furthest slot from the slots'
## centre)], or [] (not an element, or no destination). A crew's own order is only its current LEG's slot (an element
## moves in legs: v3's null, the spots never moved), so this reads the element's task. Tests: `destinations` first.
static func _destination(group: String, cols: Dictionary) -> Array:
	if destinations.has(group):
		return destinations[group]
	if not group.begins_with("e:"):
		return []
	var names: PackedStringArray = cols["names"]
	var groups: PackedStringArray = cols["group"]
	for k in groups.size():
		if groups[k] != group:
			continue
		var mover: Movement = _movers.get(names[k])
		var brain := mover.ctl as TankBrain if mover != null else null
		if brain == null or brain.game_match == null:
			continue
		var elements := Elements.of_match(brain.game_match)
		var element: Element = elements.get_element(int(group.trim_prefix("e:"))) if elements != null else null
		if element == null or not (element.task.get("to") is Array or element.task.get("to") is Vector3):
			return []
		var to: Variant = element.task["to"]
		var at := Vector2((to as Vector3).x, (to as Vector3).z) if to is Vector3 else Vector2(float(to[0]), float(to[1]))
		var middle := Vector2.ZERO
		var count := 0
		for slot: Variant in element.slots.values():
			if slot is Vector3:
				middle += Vector2((slot as Vector3).x, (slot as Vector3).z)
				count += 1
		var spread := 0.0
		if count > 0:
			middle /= float(count)
			for slot: Variant in element.slots.values():
				if slot is Vector3:
					spread = maxf(spread, middle.distance_to(Vector2((slot as Vector3).x, (slot as Vector3).z)))
		return [at, spread]
	return []


## Is (x, z) walkable ground (the navmesh)?
static func _walkable(x: float, z: float) -> bool:
	if ground_override is Callable:
		return bool((ground_override as Callable).call(x, z))
	if not _map.is_valid():
		return true
	var probe := Vector3(x, 0.0, z)
	var on := Pathing.closest_point(_map, probe, "traffic")
	return Vector2(on.x - probe.x, on.z - probe.z).length() <= STREET_OFF_M


## Is the crew at (px, pz) going (ux, uz) in a street: the navmesh ends within STREET_SIDE_M on its left AND its right?
## Read from facts (the map's walkable ground), never a map name; cached per key for STREET_TICKS.
static func _street(key: String, frame: int, px: float, pz: float, ux: float, uz: float) -> bool:
	if street_override != null:
		return _street_at(px, pz, ux, uz)
	var known: Variant = _streets.get(key)
	if known != null and frame - int(known[0]) < STREET_TICKS and frame >= int(known[0]):
		return bool(known[1])
	var answer := _street_at(px, pz, ux, uz)
	_streets[key] = [frame, answer]
	return answer


## The street read itself, uncached.
static func _street_at(px: float, pz: float, ux: float, uz: float) -> bool:
	if street_override is Callable:
		return bool((street_override as Callable).call(px, pz))
	if street_override != null:
		return bool(street_override)
	if not _map.is_valid() and not (ground_override is Callable):
		return false
	return _walled(px, pz, -uz, ux) and _walled(px, pz, uz, -ux)


## Does walkable ground end within STREET_SIDE_M from (px, pz) along (sx, sz)?
static func _walled(px: float, pz: float, sx: float, sz: float) -> bool:
	var reach := STREET_STEP_M
	while reach <= STREET_SIDE_M + 0.01:
		if not _walkable(px + sx * reach, pz + sz * reach):
			return true
		reach += STREET_STEP_M
	return false


## Rebuild the table from every living hull under `tanks_root` when it is TABLE_TICKS old (or another match's).
static func refresh(tanks_root: Node) -> void:
	var root := tanks_root.get_instance_id()
	var frame := Engine.get_physics_frames()
	if root == _root and frame - _frame < TABLE_TICKS and frame >= _frame:
		return
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	if root != _root:
		_forget()
	_root = root
	_frame = frame
	var world := (tanks_root as Node3D).get_world_3d() if tanks_root is Node3D else null
	_map = world.navigation_map if world != null and Pathing.enabled else RID()
	var rows: Array = []
	_movers = {}
	for child in tanks_root.get_children():
		var tank := child as Tank
		if tank == null or not tank.is_alive():
			continue
		var mover := Movement.of(tank)
		var basis_z := tank.global_basis.z
		var velocity := tank.estimated_velocity
		if mover != null:
			_movers[String(tank.name)] = mover
		rows.append([String(tank.name), tank.team, tank.global_position.x, tank.global_position.z, velocity.x, velocity.z,
				-basis_z.x, -basis_z.z, Avoidance.radius_of(tank.unit_id),
				mover != null and mover.is_under_way() and mover.yield_to == "" and not mover.in_kturn(),
				_group_of(tank, mover), mover != null and mover.is_under_way()])
	_load(rows)
	for key: String in _cross_kept.keys():
		if int(_cross_kept[key][1]) < frame:
			_cross_kept.erase(key)
	# A wait whose squad is gone (no crew left in the table) ends.
	for group: String in _waits.keys():
		var alive := false
		for name: String in (_waits[group]["spots"] as Dictionary):
			if _where.has(name):
				alive = true
				break
		if not alive:
			_end_wait(group, frame)
	if OrderController.profiling:
		OrderController.add_part("sz.tr.refresh_gd", Time.get_ticks_usec() - lap)


## The squad a crew drives with: its element's id, or its own name outside an element.
static func _group_of(tank: Tank, mover: Movement) -> String:
	var brain := mover.ctl as TankBrain if mover != null else null
	if brain != null and not brain.element.is_empty():
		var id := String(str(brain.element.get("id", "")))
		if id != "" and id != "<null>":
			return "e:" + id
	return "u:" + String(tank.name)


static func _forget() -> void:
	_cross_answers = {}
	_cross_kept = {}
	_shares = {}
	_looked = {}
	_verdicts = {}
	_waits = {}
	_live = {}
	_streets = {}


## Tests: load the table directly (and forget every verdict and wait). `rows` = [[name, team, x, z, vx, vz, heading_x,
## heading_z, radius, moving, group, under way], ...]; a row without a group is its own squad, one without `under way`
## is under way when it is moving. `frame` = the table's frame.
static func load_rows(rows: Array, frame := 0, forget := true) -> void:
	_root = -1
	_frame = frame
	_map = RID()
	_movers = {}
	if forget:
		_forget()
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
		var under_way := PackedByteArray()
		var groups := PackedStringArray()
		var sums := {}
		var gcount := {}  # group -> [crews, moving]
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
			under_way.append(1 if bool(row[11] if row.size() > 11 else row[9]) else 0)
			var group := String(row[10]) if row.size() > 10 else "u:" + String(row[0])
			groups.append(group)
			var counts: Array = gcount.get_or_add(group, [0, 0])
			counts[0] = int(counts[0]) + 1
			if bool(row[9]):
				counts[1] = int(counts[1]) + 1
				sums[group] = (sums.get(group, Vector2.ZERO) as Vector2) + direction
		# Each squad's mean heading over its moving crews.
		var gdir := {}
		for group: String in sums:
			gdir[group] = (sums[group] as Vector2).normalized()
		_teams[team] = {"names": names, "x": xs, "z": zs, "dx": dxs, "dz": dzs, "speed": speeds, "radius": radii,
				"moving": moving, "under_way": under_way, "group": groups, "gdir": gdir, "gcount": gcount}
