class_name TrafficStage
extends RefCounted
## Round 26 (traffic T0): HIS TWO CASES, counted. "if I take 2 squads and have them move in opposing directions such
## that they have to cross each other (i.e. south army goes north, north army goes south) ... vehicles will get stuck
## bumping into each other" and "the same behavior applies when one vehicle is making a 90 degree angle with another
## vehicle's path" (2026-10-10).
##
## Two friendly squads (one team, five crews each, the same mixed hulls in both so neither is faster), each formed as an
## element and given his right-click (a plain move, the doctrine's own shape) through the other's start (`head`), or
## across the other's path at right angles with both squads the same distance from the middle (`cross`). `solo_a` /
## `solo_b` run one squad alone with the same order: the clear-road time the crossing's last arrival is held against.
## No enemy anywhere: this is driving.
##
## Report per run (seconds from the order; -1 = never):
##   arrived / crews          crews that arrived (stayed within ARRIVED_M of where they ended, which is near their slot)
##   arrive_s                 per crew; last_a_s / last_b_s each squad's last arrival (-1 unless every crew of it did)
##   friend_stuck_s           crew-seconds a crew sat under STILL_MPS before it arrived WITH A FRIENDLY HULL IN ITS WAY
##                            (C26.5's label: a friendly box within WAY_GAP_M of its own, ahead of it along where it is
##                            trying to go); stuck_s the same with anything or nothing in the way
##   contacts / contacts_fast friendly hull pairs coming into contact (boxes within CONTACT_GAP_M), and those whose
##                            closing speed at the moment of contact was over FAST_CONTACT_MPS
##   kturns / kturns_friend   planned reverse legs started (Movement.in_kturn going true), and those started with a
##                            friendly hull within WAY_GAP_M ahead of the hull's nose
##   yields                   give-ways begun (Movement.yield_to going non-empty)

const STILL_MPS := 0.5
const WAY_GAP_M := 3.0
const AHEAD_COS := 0.3
const CONTACT_GAP_M := 0.15
const FAST_CONTACT_MPS := 2.0
const ARRIVED_M := 4.0
const SLOT_M := 15.0
const JITTER_M := 1.0
const SQUAD_PITCH_M := 9.0

## The mixed squad: both squads get it (C26.6's "mixed hulls as make skirmish deals": a Law player's squads mix its
## wheeled tank, tracked IFV, scout, suppressor and artillery; lengths 5–9 m, two turning circles).
const HULLS := ["law_tank", "law_ifv", "law_scout", "law_suppressor", "law_tank"]

## Where each map's two squads start and are sent. "a"/"b": [start centre, goal centre, facing at the start].
## yard_open: the band (open ground 60 m+ wide). terminus: an 18 m street (head-on: the west street; crossing: the
## avenue against the ring road, meeting at (0, 30); goals on open street and the plaza, never at a corner, where a
## formation's slots land inside the blocks and even one squad alone never settles).
const STAGES := {
	"yard_open": {
		"head": {"a": [Vector3(0, 0, 60), Vector3(0, 0, -60)], "b": [Vector3(0, 0, -60), Vector3(0, 0, 60)]},
		"cross": {"a": [Vector3(0, 0, 60), Vector3(0, 0, -60)], "b": [Vector3(-60, 0, 0), Vector3(60, 0, 0)]},
	},
	"terminus": {
		"head": {"a": [Vector3(-70, 0, 75), Vector3(-70, 0, -55)], "b": [Vector3(-70, 0, -55), Vector3(-70, 0, 75)]},
		"cross": {"a": [Vector3(0, 0, 75), Vector3(0, 0, -15)], "b": [Vector3(-45, 0, 30), Vector3(45, 0, 30)]},
	},
}


static func run(case: TestCase, seed_value: int, arena: String, kind: String, which: String, seconds: float,
		side := "green", trace := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, arena)
	var game_match := lab.game_match
	var team := Match.Team.GREEN if side == "green" else Match.Team.RUST
	game_match.set_meta("player_team", team)
	var stage: Dictionary = STAGES[arena][kind]
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var squads := ["a", "b"] if which == "both" else [which.trim_prefix("solo_")]
	var prefix := "Green" if team == Match.Team.GREEN else "Rust"
	var members := {}
	for squad: String in squads:
		var from: Vector3 = stage[squad][0]
		var to: Vector3 = stage[squad][1]
		var along := (to - from).normalized()
		var across := Vector3(-along.z, 0.0, along.x)
		var yaw := atan2(-along.x, -along.z)
		var names: Array = []
		# A loose block, two ranks, facing the way it is about to go (a squad that just finished its last move).
		for i in HULLS.size():
			var rank := float(i / 3)
			var file := float(i % 3) - 1.0
			var at := from + across * file * SQUAD_PITCH_M - along * rank * SQUAD_PITCH_M \
					+ Vector3(jitter.randf_range(-JITTER_M, JITTER_M), 0.0, jitter.randf_range(-JITTER_M, JITTER_M))
			var face := yaw + deg_to_rad(jitter.randf_range(-10.0, 10.0))
			names.append(String(lab.unit(team, "%s_%s_%d" % [prefix, squad.to_upper(), i + 1], at, face, HULLS[i]).name))
		members[squad] = names
	await lab.start()
	var everyone: Array = []
	for squad: String in squads:
		for unit_name: String in members[squad]:
			var t := lab.tank_of(unit_name)
			var at := SlotGround.for_unit(t, t.global_position, String(t.unit_id))
			t.global_position = Vector3(at.x, 0.0, at.z)
			t.velocity = Vector3.ZERO
			everyone.append(unit_name)
	for i in 3:
		await lab.step()
	var elements := {}
	for squad: String in squads:
		var element := lab.elements.form(members[squad], "Squad" + squad.to_upper())
		var to: Vector3 = stage[squad][1]
		element.assign({"verb": "move", "to": [to.x, to.z]})
		elements[squad] = element
	var given: int = game_match.tick
	var trails := {}
	var stuck := {}
	var friend_stuck := {}
	var in_contact := {}
	var contacts := 0
	var contacts_fast := 0
	var kturns := 0
	var kturns_friend := 0
	var yields := 0
	var was_kturn := {}
	var was_yield := {}
	var settled := 0
	for unit_name: String in everyone:
		trails[unit_name] = []
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		var now: int = game_match.tick - given
		var hulls: Array = []
		for unit_name: String in everyone:
			var t := lab.tank_of(unit_name)
			if t != null and t.is_alive():
				hulls.append(t)
		for t: Tank in hulls:
			var unit_name := String(t.name)
			var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
			var trail: Array = trails[unit_name]
			trail.append(here)
			var mover := Movement.of(t)
			var way := _way(t, mover)
			# Real motion over the last second, never estimated_velocity: a hull pressed nose to nose against another
			# keeps a slide velocity of ~6.7 m/s while its position does not change (T0's first trace).
			var back := mini(trail.size() - 1, SimClock.TICK_RATE)
			if back >= SimClock.TICK_RATE and (trail[-1 - back] as Vector3).distance_to(here) < STILL_MPS:
				var ticks: PackedInt32Array = stuck.get_or_add(unit_name, PackedInt32Array())
				ticks.append(now)
				stuck[unit_name] = ticks
				if _friend_in_way(t, way, hulls) != "":
					var f_ticks: PackedInt32Array = friend_stuck.get_or_add(unit_name, PackedInt32Array())
					f_ticks.append(now)
					friend_stuck[unit_name] = f_ticks
			var turning := mover != null and mover.in_kturn()
			if turning and not bool(was_kturn.get(unit_name, false)):
				kturns += 1
				if _friend_in_way(t, Vector2(-t.global_basis.z.x, -t.global_basis.z.z).normalized(), hulls) != "":
					kturns_friend += 1
			was_kturn[unit_name] = turning
			var yielding := mover != null and mover.yield_to != ""
			if yielding and not bool(was_yield.get(unit_name, false)):
				yields += 1
			was_yield[unit_name] = yielding
		for i in hulls.size():
			for j in range(i + 1, hulls.size()):
				var a: Tank = hulls[i]
				var b: Tank = hulls[j]
				var key := "%s|%s" % [a.name, b.name]
				var touching := box_gap(a, b) <= CONTACT_GAP_M
				if touching and not in_contact.get(key, false):
					contacts += 1
					if closing_speed(a, b) > FAST_CONTACT_MPS:
						contacts_fast += 1
				in_contact[key] = touching
		if trace and now % (SimClock.TICK_RATE / 2) == 0:
			for t: Tank in hulls:
				var r := Movement.state(t)
				print("TRAFFIC_TRACK " + JSON.stringify({"t": snappedf(float(now) / SimClock.TICK_RATE, 0.1), "n": String(t.name),
						"at": [snappedf(t.global_position.x, 0.1), snappedf(t.global_position.z, 0.1)],
						"v": snappedf(t.estimated_velocity.length(), 0.1), "phase": String(r.get("phase", "")),
						"blocked": r.get("blocked_by"), "yield": r.get("yield_to"), "kturn": Movement.of(t).in_kturn(),
						"goal": str(r.get("goal")), "steer": str(r.get("steer_to")), "stalled": r.get("stalled_s"),
						"rem": r.get("remaining_m"), "pace": r.get("pace"), "thr": snappedf(t.command.throttle, 0.01),
						"turn": snappedf(t.command.turn, 0.01), "ot": Movement.of(t)._order_ticks, "key": str((Movement.of(t).ctl as TankBrain).element.get("key")) if Movement.of(t).ctl is TankBrain else "", "friend": _friend_in_way(t, _way(t, Movement.of(t)), hulls)}))
		var all_arrived := true
		for squad: String in squads:
			all_arrived = all_arrived and (elements[squad] as Element).arrived
		var still_all := true
		for unit_name: String in everyone:
			var trail: Array = trails[unit_name]
			still_all = still_all and trail.size() > SimClock.TICK_RATE \
					and (trail[-1 - SimClock.TICK_RATE] as Vector3).distance_to(trail[-1]) < STILL_MPS
		settled = settled + 1 if all_arrived and still_all else 0
		if settled >= SimClock.TICK_RATE * 3:
			break
	var end_tick: int = game_match.tick - given
	var arrive_s := {}
	var arrived_ticks := {}
	for squad: String in squads:
		var element: Element = elements[squad]
		var to: Vector3 = stage[squad][1]
		for unit_name: String in members[squad]:
			var trail: Array = trails[unit_name]
			var at := -1
			if not trail.is_empty():
				var last: Vector3 = trail[-1]
				var slot: Variant = element.slots.get(unit_name)
				var target: Vector3 = Vector3(slot.x, 0.0, slot.z) if slot is Vector3 else to
				if last.distance_to(target) <= SLOT_M:
					at = trail.size()
					while at > 0 and (trail[at - 1] as Vector3).distance_to(last) <= ARRIVED_M:
						at -= 1
			arrived_ticks[unit_name] = at
			arrive_s[unit_name] = _s(at)
	var stuck_ticks := 0
	var friend_ticks := 0
	var friend_s := {}
	for unit_name: String in everyone:
		var limit: int = arrived_ticks[unit_name] if int(arrived_ticks[unit_name]) >= 0 else end_tick
		var n := 0
		for at: int in stuck.get(unit_name, PackedInt32Array()):
			if at < limit:
				stuck_ticks += 1
		for at: int in friend_stuck.get(unit_name, PackedInt32Array()):
			if at < limit:
				n += 1
		friend_ticks += n
		friend_s[unit_name] = _s(n)
	var report := {"seed": seed_value, "arena": arena, "kind": kind, "which": which, "side": side, "crews": everyone.size(),
			"arrived": arrived_ticks.values().filter(func(v: int) -> bool: return v >= 0).size(),
			"arrive_s": arrive_s, "end_s": _s(end_tick),
			"friend_stuck_s": _s(friend_ticks), "stuck_s": _s(stuck_ticks), "friend_stuck_by": friend_s,
			"contacts": contacts, "contacts_fast": contacts_fast, "kturns": kturns, "kturns_friend": kturns_friend,
			"yields": yields, "route_arms": Movement.route_arms()}
	for squad: String in squads:
		var last := 0
		for unit_name: String in members[squad]:
			if int(arrived_ticks[unit_name]) < 0:
				last = -1
				break
			last = maxi(last, int(arrived_ticks[unit_name]))
		report["last_%s_s" % squad] = _s(last)
	lab.dispose()
	return report


static func _s(ticks: int) -> float:
	return -1.0 if ticks < 0 else snappedf(float(ticks) / SimClock.TICK_RATE, 0.1)


## Where this crew is trying to go (flat, unit): toward its route's next point; its nose when it has none.
static func _way(t: Tank, mover: Movement) -> Vector2:
	if mover != null and mover._goal != Vector3.INF:
		var way := mover._travel_direction(mover._goal, false)
		if way != Vector2.ZERO:
			return way
	return Vector2(-t.global_basis.z.x, -t.global_basis.z.z).normalized()


## The nearest friendly hull whose box is within WAY_GAP_M of this one's and whose centre lies ahead along `way`, or "".
static func _friend_in_way(t: Tank, way: Vector2, hulls: Array) -> String:
	var best := ""
	var best_gap := INF
	for other: Tank in hulls:
		if other == t or other.team != t.team:
			continue
		var offset := Vector2(other.global_position.x - t.global_position.x, other.global_position.z - t.global_position.z)
		var distance := offset.length()
		if distance < 0.01 or offset.dot(way) / distance < AHEAD_COS:
			continue
		var gap := box_gap(t, other)
		if gap <= WAY_GAP_M and gap < best_gap:
			best = String(other.name)
			best_gap = gap
	return best


## The flat gap between two hulls' boxes (metres; <= 0 overlapping), by separating axes. Pure geometry.
static func box_gap(a: Tank, b: Tank) -> float:
	var ra := _rect(a)
	var rb := _rect(b)
	var gap := -INF
	for axis: Vector2 in [ra[1], ra[2], rb[1], rb[2]]:
		var pa := _project(ra, axis)
		var pb := _project(rb, axis)
		gap = maxf(gap, maxf(pb.x - pa.y, pa.x - pb.y))
	return gap


## [centre, forward, right, half length, half width] in the ground plane.
static func _rect(t: Tank) -> Array:
	var box: Array = Movement.hull_box(String(t.unit_id))
	var forward := Vector2(-t.global_basis.z.x, -t.global_basis.z.z).normalized()
	return [Vector2(t.global_position.x, t.global_position.z), forward, Vector2(-forward.y, forward.x),
			float(box[2]) * 0.5, float(box[0]) * 0.5]


static func _project(rect: Array, axis: Vector2) -> Vector2:
	var centre: float = (rect[0] as Vector2).dot(axis)
	var reach: float = float(rect[3]) * absf((rect[1] as Vector2).dot(axis)) + float(rect[4]) * absf((rect[2] as Vector2).dot(axis))
	return Vector2(centre - reach, centre + reach)


## How fast a and b are closing along the line between them (m/s; > 0 closing).
static func closing_speed(a: Tank, b: Tank) -> float:
	var d := Vector2(b.global_position.x - a.global_position.x, b.global_position.z - a.global_position.z)
	if d.length_squared() < 0.0001:
		return 0.0
	var dv := Vector2(b.estimated_velocity.x - a.estimated_velocity.x, b.estimated_velocity.z - a.estimated_velocity.z)
	return -dv.dot(d.normalized())
