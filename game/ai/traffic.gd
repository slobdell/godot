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
##   turns       Round 28 T1 (his call: TAKE TURNS): two friendly SQUADS crossing take turns: the squad reaching the
##               crossing later slows as a whole and passes behind the other (one verdict per squad pair).
##   squadheading T1 v2b: a crossing is two SQUADS' mean headings crossing (neither following nor head-on), not two
##               crews deflected at an angle inside a head-on meeting.
##   wholesquad  T1 v2b: a yielding squad slows AS A WHOLE (every crew of it short of the crossing keeps the share of its
##               wish its most-slowed crew keeps), so its rear crews do not run into its own slowed front.
##   streetturns T1 v2c: two squads meeting HEAD-ON in a street take turns like a one-lane bridge: the squad still in
##               the open (else the later one) slows to the floor early, the other comes through (_street_meeting).
##   streetfloor T1 v2d: the waiting squad at a street meeting keeps STREET_FLOOR of its wish (v2c: YIELD_FLOOR).
##   streetright Round 28 T1: friendlies meeting head-on keep right, but only in a street (walls both sides); on open
##               ground ORCA passes them as before.
##
## THE RULE (round 28 T1; round 26's CP1b v4 is the ancestor, branch `traffic-cp1b-v4`). It shapes ORCA's PREFERRED
## velocity in Movement._avoid and nothing else: ORCA still keeps every hull clear, the give-way still sorts a stall.
## Between FRIENDLIES only, both MOVING (under way, not giving way, not in a k-turn): an enemy, a parked friend, a crew in
## a give-way or a k-turn is left to ORCA and the give-way exactly as before. Every crew works from the SAME facts: one
## table of positions, directions, speeds, radii and squads (the element's id; a crew outside an element is its own
## squad), rebuilt every TABLE_TICKS.
##
##   crossing  (turns) two crews of DIFFERENT squads whose straight motions really meet (closest approach inside the
##             pair's clearance within HORIZON_S) at an angle that is neither following nor head-on. ONE decision per
##             squad pair, made the first time any of their crews meet and kept while the squads keep meeting: at the
##             crossing point of that first pair, each squad's first crew to reach it (time along its own line) — the
##             squad there LATER yields; inside TIE_S, the squad whose first crew has the other's on its right yields
##             (priority to the right); if that does not decide it, the element id. Round 26's v4 decided per CREW
##             pair, so crews of both squads yielded to crews of the other at once and the crossing churned. A crew of
##             the yielding squad caps its speed to reach the conflict zone after the crew it meets has cleared it
##             (+ YIELD_MARGIN_S), never under YIELD_FLOOR of its wish (v3's floor: a yield slows, it never stops), and
##             never once it is at the zone's edge (it clears out of the way).
##   head-on   (streetright) directions within HEAD_ON_COS of opposite, meeting within HORIZON_S, the other's centre
##             less than the pair's clearance off my line, AND the room is a street (Traffic.street: static geometry
##             within STREET_SIDE_M on both sides, from the navmesh): each takes half the lateral gap still needed to
##             pass left side to left side, never toward a friend abeam on its right (v4's roomright). On open ground
##             (his head-on case there is solved by ORCA since round 26's CP1a, and keeping right measured worse) the
##             meeting is ORCA's.
##
## COST (C28.4: <= 0.5 ms a tick at 25 a side, GDScript path): the table every TABLE_TICKS, a crew's answer every
## SOLVE_TICKS (staggered by its name), a friend behind the crew's own line skipped before any other work, and the
## street read (navmesh probes) only for a head-on meeting, cached per crew for STREET_TICKS.


## A slot that moves less than this between two reads of the element is the formation sliding, not a re-seat. It is
## Movement's own goal-jump distance (`_track_progress` starts a new progress record when the goal moves more than 2 m),
## so a slide the feed now lets through is one Movement already treats as the same goal; and it is a quarter of the
## tightest doctrine spacing (8 m: doctrine_standard.json, dense terrain; a corridor narrows a shape ACROSS but keeps
## its pitch ALONG), so a re-seat — a crew sent to another slot of the shape — moves it further. Measured slides on
## his head-on case: millimetres per update (T0 trace, streams/archive/round26/traffic.md Status).
const SLOT_SLIDE_M := 2.0

## The rule's numbers (see the doc above; round 26's v3/v4 values, measured there).
const REACH_M := 45.0
const HORIZON_S := 4.5
const HEAD_ON_COS := -0.766  # cos 140 deg: within 40 deg of opposite
const FOLLOW_COS := 0.866  # cos 30 deg: going the same way is following, not crossing
const CLEAR_MARGIN_M := 1.5
const MAX_SIDE_SIN := 0.5  # at most 30 deg off the route
const SETTLE_S := 1.0  # finish the sidestep this long before the meeting
const TIE_S := 0.5
const YIELD_MARGIN_S := 0.4
## v3: the least share of its wish a yielding crew keeps (it slows to pass behind, it does not stop).
const YIELD_FLOOR := 0.4
## A yielding crew this close to the conflict zone's edge (m) does not yield: it is in the way, so it clears out.
const COMMITTED_M := 1.0
## A squad pair's verdict lives this long after their crews last met (s): long enough for a squad's tail to pass.
const VERDICT_KEEP_S := 3.0
## v2c (streetturns): a head-on meeting of two squads in a street is seen this far ahead (s, m), with the other crew
## up to this far across (m: an 18 m street's whole width), so the waiting squad slows before it is in the street.
const STREET_HORIZON_S := 8.0
## v2d: the share of its wish the WAITING squad keeps at a street meeting (it waits in the open; at 0.2 a hull still
## makes ~1.6 m/s, over Movement's stall line of 0.5 m a second, so it never reads as stuck).
const STREET_FLOOR := 0.2
const STREET_REACH_M := 100.0
const STREET_LATERAL_M := 14.0
## v4: how far to the right (in pair clearances) a friend abeam stops a crew keeping right.
const RIGHT_ROOM := 1.5
## A street: the navmesh ends within this far on BOTH sides of the crew (m; probes every STREET_STEP_M). His Terminus
## streets are 18 m between the blocks; the yard's band is 60 m+.
const STREET_SIDE_M := 16.0
const STREET_STEP_M := 4.0
## A probe this far off the navmesh is outside it (m).
const STREET_OFF_M := 1.0
const MOVING_MPS := 1.0
const MIN_SPEED_MPS := 1.0
## The cadence (cost): the table is at most this many ticks old, a crew's answer at most this many, its street read
## at most this many.
const TABLE_TICKS := 3
const SOLVE_TICKS := 6
const STREET_TICKS := 30

## Arm counters (measurement only): crew-ticks a wish was turned right, crew-ticks it was slowed, and squad-pair
## verdicts made.
static var kept_right := 0
static var crossing_yields := 0
static var verdicts := 0

## The table, per team: names and PackedFloat64Array columns x, z, dx, dz, speed, radius, plus moving
## (PackedByteArray) and group (PackedStringArray); `_where` maps a name to [team, row].
static var _frame := -1
static var _root := -1
static var _map := RID()
static var _where := {}
static var _teams := {}
## name -> [physics frame solved, lateral m/s to my right, speed cap (INF = none)].
static var _answers := {}
## "groupA|groupB" (sorted) -> [the yielding group, the frame the verdict expires].
static var _verdicts := {}
## group -> [frame, the least share of its wish a crew of it keeps while yielding, the crossing point] (wholesquad).
static var _shares := {}
## The crossing point of the last _crossing call (wholesquad reads it beside the verdict).
static var _last_point := Vector2.ZERO
## name -> [frame read, is a street].
static var _streets := {}
## Tests: a street answer instead of the navmesh: a bool for everywhere, or a Callable(x, z) -> bool (null = the navmesh).
static var street_override: Variant = null

static var _off := {}
static var _parsed := false


## Is the behaviour `name` switched off for this run (`--traffic-off=name,...`)?
static func off(name: String) -> bool:
	if not _parsed:
		_parsed = true
		# T1b (round 28): only the street head-on rule ships; the crossing verdicts and keep-right stay in the tree OFF
		# (v3 failed its judged bar on the crossings: Status). `--traffic-on=turns` measures them.
		for name_off: String in OFF_BY_DEFAULT:
			_off[name_off] = true
		for arg in OS.get_cmdline_user_args():
			if String(arg).begins_with("--traffic-on="):
				for part in String(arg).trim_prefix("--traffic-on=").split(",", false):
					_off.erase(part.strip_edges())
			if String(arg).begins_with("--traffic-off="):
				for part in String(arg).trim_prefix("--traffic-off=").split(",", false):
					_off[part.strip_edges()] = true
	return _off.has(name)


## The behaviours in the tree but not in the game (on only with --traffic-on=...).
const OFF_BY_DEFAULT: Array[String] = ["turns", "streetright"]


## Tests: switch a behaviour off (true) or back on, whatever the command line said.
static func set_off(name: String, value: bool) -> void:
	off(name)
	if value:
		_off[name] = true
	else:
		_off.erase(name)
	_answers = {}
	_streets = {}
	_shares = {}


## T1's preferred velocity for `me` from the route's wish `preferred` (x, z): `preferred` unchanged when no friend of
## another squad is a party to a crossing, and no head-on meeting in a street. Needs the table (refresh, or load_rows).
static func shape(me: String, preferred: Vector2) -> Vector2:
	var cross := not off("turns")
	var street := not off("streetturns")
	# v2c: a head-on meeting in a street is taken in turns (streetturns); keep-right (v1, measured worse) only without it.
	var keep := not off("streetright") and not street
	if not (keep or cross or street):
		return preferred
	var speed := preferred.length()
	if speed < 0.1:
		return preferred
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	var frame := Engine.get_physics_frames() if _root != -1 else _frame
	var answer: Variant = _answers.get(me)
	if answer == null or frame - int(answer[0]) >= SOLVE_TICKS or (frame + (me.hash() & 0xffff)) % SOLVE_TICKS == 0:
		answer = _solve(me, frame, keep, cross, street)
		_answers[me] = answer
	var out := preferred
	var lateral_speed: float = answer[1]
	if lateral_speed > 0.0:
		kept_right += 1
		var side_sin := minf(lateral_speed / speed, MAX_SIDE_SIN)
		var along := preferred / speed
		out = (along * sqrt(1.0 - side_sin * side_sin) + Vector2(-along.y, along.x) * side_sin) * speed
	# This crew's own cap, never under its floor; then its squad's share (already floored where it was noted).
	var keep_speed := speed
	var cap: float = answer[2]
	if cap < speed:
		keep_speed = maxf(cap, float(answer[3]) * speed)
	if (cross or street) and not off("wholesquad"):
		keep_speed = minf(keep_speed, _squad_share(me, frame) * speed)
	if keep_speed < speed:
		crossing_yields += 1
		out = out / speed * keep_speed
	if OrderController.profiling:
		OrderController.add_part("sz.tr.shape_gd", Time.get_ticks_usec() - lap)
	return out


## [frame, lateral m/s to my right, speed cap] for `me` against every moving friend in reach, from the table.
static func _solve(me: String, frame: int, keep: bool, cross: bool, street: bool) -> Array:
	var none := [frame, 0.0, INF, YIELD_FLOOR]
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
	var groups: PackedStringArray = cols["group"]
	var px := xs[i]
	var pz := zs[i]
	var ux := dxs[i]
	var uz := dzs[i]
	var v_me := maxf(speeds[i], MIN_SPEED_MPS)
	var my_radius := radii[i]
	var lateral_speed := 0.0
	var cap := INF
	var floor_share := YIELD_FLOOR
	var reach_sq := REACH_M * REACH_M
	var street_turns := street
	var street_reach_sq := STREET_REACH_M * STREET_REACH_M
	for j in names.size():
		if j == i or moving[j] == 0:
			continue
		var dx := xs[j] - px
		var dz := zs[j] - pz
		var ahead := dx * ux + dz * uz
		var clearance := my_radius + radii[j] + CLEAR_MARGIN_M
		var wx := dxs[j]
		var wz := dzs[j]
		var facing := ux * wx + uz * wz
		var d2 := dx * dx + dz * dz
		if ahead < -clearance:
			continue  # behind my own line
		# v2c: a head-on meeting of two squads in a street is seen further out (the waiting squad must stop short of it).
		var street_case := street_turns and facing <= HEAD_ON_COS and groups[i] != groups[j] and ahead > 0.0
		if d2 > (street_reach_sq if street_case else reach_sq):
			continue  # out of reach
		var v_it := maxf(speeds[j], MIN_SPEED_MPS)
		if street_case:
			var head_cap := _street_meeting(me, frame, i, j, ahead, dx * -uz + dz * ux, v_me, v_it, cols)
			if head_cap >= 0.0:
				cap = minf(cap, head_cap)
				floor_share = minf(floor_share, _street_floor())
				continue
		# Only a real meeting: the two straight-line motions come within the pair's clearance inside HORIZON_S.
		var rvx := wx * v_it - ux * v_me
		var rvz := wz * v_it - uz * v_me
		var rv2 := rvx * rvx + rvz * rvz
		var t := 0.0 if rv2 < 0.0001 else clampf(-(dx * rvx + dz * rvz) / rv2, 0.0, HORIZON_S)
		var mx := dx + rvx * t
		var mz := dz + rvz * t
		if mx * mx + mz * mz >= clearance * clearance:
			continue
		if facing <= HEAD_ON_COS:
			if not keep or ahead <= 0.0:
				continue
			var lateral := dx * -uz + dz * ux  # its offset toward my right
			if absf(lateral) >= clearance:
				continue
			var meet := ahead / (v_me + v_it)
			if meet > HORIZON_S:
				continue
			if _friend_on_right(i, px, pz, ux, uz, my_radius, cols):
				continue
			if not _street(me, frame, px, pz, ux, uz):
				continue
			# I want it on my LEFT by `clearance` (lateral <= -clearance); half of what is missing is mine.
			lateral_speed = maxf(lateral_speed, (lateral + clearance) * 0.5 / maxf(meet - SETTLE_S, 0.5))
		elif cross and groups[i] != groups[j] and _crossing_kind(facing, groups[i], groups[j], cols):
			var verdict := _crossing(Vector2(px, pz), Vector2(ux, uz), v_me, Vector2(xs[j], zs[j]), Vector2(wx, wz), v_it,
					clearance, groups[i], groups[j], frame, cols)
			if verdict >= 0.0 and verdict < cap:
				cap = verdict
				_note_share(groups[i], frame, maxf(verdict / v_me, YIELD_FLOOR), _last_point)
	return [frame, lateral_speed, cap, floor_share]


## v2d: the waiting squad's share at a street meeting (v2c's was YIELD_FLOOR: --traffic-off=streetfloor).
static func _street_floor() -> float:
	return YIELD_FLOOR if off("streetfloor") else STREET_FLOOR


## Is this a crossing the rule decides? With squadheading, the two SQUADS' mean headings must cross (neither within
## FOLLOW_COS of the same way nor within HEAD_ON_COS of opposite); without it, the two crews' directions (v1).
static func _crossing_kind(facing: float, mine: String, theirs: String, cols: Dictionary) -> bool:
	if off("squadheading"):
		return facing < FOLLOW_COS
	var headings: Dictionary = cols["gdir"]
	var g := (headings.get(mine, Vector2.ZERO) as Vector2).dot(headings.get(theirs, Vector2.ZERO) as Vector2)
	return g < FOLLOW_COS and g > HEAD_ON_COS and facing < FOLLOW_COS


## v2c (streetturns): crew i meets crew j of another squad head-on, `ahead` m along my way, `lateral` m to my right.
## When the two SQUADS meet head-on (mean headings within HEAD_ON_COS of opposite), inside STREET_HORIZON_S, within
## STREET_LATERAL_M across, and the ground between them is a street, the squad pair takes turns like a one-lane
## bridge: one verdict, kept; the waiting squad is the one whose lead crew is still in the OPEN (it has room to wait
## and the other is already committed to the street); if both or neither, the one whose lead reaches the middle later;
## inside TIE_S, the greater id. Returns 0.0 (slow to the floor) when my squad waits, -1 when it does not (or no case).
static func _street_meeting(me: String, frame: int, i: int, j: int, ahead: float, lateral: float, v_me: float,
		v_it: float, cols: Dictionary) -> float:
	var groups: PackedStringArray = cols["group"]
	var headings: Dictionary = cols["gdir"]
	var mine := groups[i]
	var theirs := groups[j]
	var g := (headings.get(mine, Vector2.ZERO) as Vector2).dot(headings.get(theirs, Vector2.ZERO) as Vector2)
	if g > HEAD_ON_COS or absf(lateral) > STREET_LATERAL_M:
		return -1.0
	var meet := ahead / (v_me + v_it)
	if meet > STREET_HORIZON_S:
		return -1.0
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var dxs: PackedFloat64Array = cols["dx"]
	var dzs: PackedFloat64Array = cols["dz"]
	var middle := Vector2((xs[i] + xs[j]) * 0.5, (zs[i] + zs[j]) * 0.5)
	var key := mine + "|" + theirs if mine < theirs else theirs + "|" + mine
	var kept: Variant = _verdicts.get(key)
	var waiter: String
	if kept != null and frame <= int(kept[1]):
		waiter = kept[0]
	else:
		# Is the ground between us a street? Read once, at the middle, along my way (the verdict is then kept).
		if not _street("@" + key, frame, middle.x, middle.y, dxs[i], dzs[i]):
			return -1.0
		waiter = _decide_street(middle, mine, theirs, cols, frame)
		verdicts += 1
	_verdicts[key] = [waiter, frame + ceili((meet + VERDICT_KEEP_S) * SimClock.TICK_RATE)]
	if waiter != mine:
		return -1.0
	# The whole waiting squad slows (wholesquad), every crew of it: the point is far down its own way, so none is past it.
	_note_share(mine, frame, _street_floor(), middle + Vector2(dxs[i], dzs[i]) * 1000.0)
	return 0.0


## v2c: which squad waits for a head-on meeting in a street at `middle`.
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


## wholesquad: record that a crew of `group` keeps `share` of its wish to yield at `point` this frame.
static func _note_share(group: String, frame: int, share: float, point: Vector2) -> void:
	var known: Variant = _shares.get(group)
	if known == null or frame - int(known[0]) > SOLVE_TICKS or share <= float(known[1]):
		_shares[group] = [frame, share, point]


## wholesquad: the share of its wish crew `me` keeps because its squad is yielding (1.0 = none): the squad's least
## share while it is fresh, for a crew still short of the crossing point.
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


## v4: is a friend abeam on this crew's right, close enough that keeping right would close on it? Its centre within
## RIGHT_ROOM x (both radii + margin) to the right and within that clearance ahead or behind.
static func _friend_on_right(i: int, px: float, pz: float, ux: float, uz: float, my_radius: float, cols: Dictionary) -> bool:
	var xs: PackedFloat64Array = cols["x"]
	var zs: PackedFloat64Array = cols["z"]
	var radii: PackedFloat64Array = cols["radius"]
	for k in xs.size():
		if k == i:
			continue
		var dx := xs[k] - px
		var dz := zs[k] - pz
		var clearance := my_radius + radii[k] + CLEAR_MARGIN_M
		var right := dx * -uz + dz * ux
		if right <= 0.0 or right > RIGHT_ROOM * clearance:
			continue
		if absf(dx * ux + dz * uz) <= clearance:
			return true
	return false


## Is the crew at (px, pz) going (ux, uz) in a street: the navmesh ends within STREET_SIDE_M on its left AND its right?
## Read from facts (the map's walkable ground), never a map name; cached per crew for STREET_TICKS.
static func _street(me: String, frame: int, px: float, pz: float, ux: float, uz: float) -> bool:
	if street_override is Callable:
		return bool((street_override as Callable).call(px, pz))
	if street_override != null:
		return bool(street_override)
	var known: Variant = _streets.get(me)
	if known != null and frame - int(known[0]) < STREET_TICKS and frame >= int(known[0]):
		return bool(known[1])
	var answer := false
	if _map.is_valid():
		answer = _walled(px, pz, -uz, ux) and _walled(px, pz, uz, -ux)
	_streets[me] = [frame, answer]
	return answer


## Does the navmesh end within STREET_SIDE_M from (px, pz) along (sx, sz)?
static func _walled(px: float, pz: float, sx: float, sz: float) -> bool:
	var reach := STREET_STEP_M
	while reach <= STREET_SIDE_M + 0.01:
		var probe := Vector3(px + sx * reach, 0.0, pz + sz * reach)
		var on := Pathing.closest_point(_map, probe, "traffic")
		if Vector2(on.x - probe.x, on.z - probe.z).length() > STREET_OFF_M:
			return true
		reach += STREET_STEP_M
	return false


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
	var kept: Variant = _verdicts.get(key)
	var yielder: String
	if kept != null and frame <= int(kept[1]):
		yielder = kept[0]
	else:
		yielder = _decide(p + u * s, mine, theirs, cols)
		verdicts += 1
	# Kept while the squads keep meeting, and VERDICT_KEEP_S after (a squad's tail is still passing).
	_verdicts[key] = [yielder, frame + ceili((maxf(t_me, t_it) + occupy + VERDICT_KEEP_S) * SimClock.TICK_RATE)]
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


## [seconds, position, direction] of squad `group`'s moving crew that reaches `x` first, or [] when none is short of it.
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
			best = [seconds, Vector2(xs[k], zs[k]), Vector2(dxs[k], dzs[k])]
	return best


## Rebuild the table from every living hull under `tanks_root` when it is TABLE_TICKS old (or another match's).
static func refresh(tanks_root: Node) -> void:
	var root := tanks_root.get_instance_id()
	var frame := Engine.get_physics_frames()
	if root == _root and frame - _frame < TABLE_TICKS and frame >= _frame:
		return
	var lap := Time.get_ticks_usec() if OrderController.profiling else 0
	if root != _root:
		_answers = {}
		_verdicts = {}
		_streets = {}
		_shares = {}
	_root = root
	_frame = frame
	var world := (tanks_root as Node3D).get_world_3d() if tanks_root is Node3D else null
	_map = world.navigation_map if world != null and Pathing.enabled else RID()
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
				mover != null and mover.is_under_way() and mover.yield_to == "" and not mover.in_kturn(),
				_group_of(tank, mover)])
	_load(rows)
	for key: String in _verdicts.keys():
		if int(_verdicts[key][1]) < frame:
			_verdicts.erase(key)
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


## Tests: load the table directly (and forget every answer and verdict). `rows` = [[name, team, x, z, vx, vz,
## heading_x, heading_z, radius, moving, group], ...]; a row without a group is its own squad.
static func load_rows(rows: Array) -> void:
	_root = -1
	_frame = 0
	_map = RID()
	_answers = {}
	_verdicts = {}
	_streets = {}
	_shares = {}
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
		var groups := PackedStringArray()
		var sums := {}
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
			var group := String(row[10]) if row.size() > 10 else "u:" + String(row[0])
			groups.append(group)
			if bool(row[9]):
				sums[group] = (sums.get(group, Vector2.ZERO) as Vector2) + direction
		# Each squad's mean heading over its moving crews (squadheading).
		var gdir := {}
		for group: String in sums:
			gdir[group] = (sums[group] as Vector2).normalized()
		_teams[team] = {"names": names, "x": xs, "z": zs, "dx": dxs, "dz": dzs, "speed": speeds, "radius": radii,
				"moving": moving, "group": groups, "gdir": gdir}
