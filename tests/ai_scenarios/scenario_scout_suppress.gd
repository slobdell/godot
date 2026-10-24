extends TestCase
## Round 28 (scout S1): a fixed gun under SUPPRESS lays its hull on the point it hoses (`_agents/streams/archive/round28/scout.md`).
##
## Round 27's census: 20 % of a fixed gun's fight time is SUPPRESS, outside the lay planner — the band-and-face chain
## laid a wheeled hull with a `face` order, and a wheeled hull cannot turn standing. Here a scout ordered onto a tank
## that is held pinned (its suppression kept at 0.9, so SUPPRESS is what the scout chooses: brains' `decide` keeps a
## pinned crew pinned) stands with the tank off its nose. Cases (the tank relative to the scout's nose, north):
##   left90    20 m to the left (west), side-on, still. (Written first as `right90`, 20 m east: from there the scout has
##             no sight of the tank at the start, so brains' PURSUE drove it to 6 m before SUPPRESS began — every contact
##             of that case, both arms, was the approach. Mirrored before any arm was judged; disclosed in the brief.)
##   behind    20 m behind (south), still
##   close     8 m dead ahead, inside its turning room, still
##   crossing  20 m ahead, driving west to east across the nose
## Per run, over RUN_S seconds of SUPPRESS:
##   on_point  share of the SUPPRESS time the gun bears on its point (Gunnery's suppress gate: the point in range and
##             within the aim tolerance; no line of sight needed)
##   first_s   seconds until the gun first bears on its point (censored at RUN_S)
##   contacts  hull touches with the tank
## Default: start ticks {1, 6, 11} on one seed; `--scout-pool` every start tick over SEEDS (`make scout-cross
## SCOUT_FILTER=scenario_scout_suppress`).

## The bars (written 2026-10-12 before any measurement): the gun on its point ON_POINT_BAR of the SUPPRESS time, pooled
## [it keeps hosing the spot instead of creeping round]; the first time on it within FIRST_BAR seconds, pooled median
## [it comes round in about a turn, not a shuffle]; no hull contact. With CP-S1 all four passed (pooled n = 18).
## Round 28: CP-S1 (the lay planner under SUPPRESS) did NOT ship by its census bar (branch `scout-s1-suppresslay`);
## main's band-and-face chain fails these two (pooled n = 18: behind first-on 3.5 s, crossing on point 0.48).
## Round 37 (native N5): test_target_behind PROMOTED. It passed identically while still marked pending in every check since at
## least 2026-10-20 (n=3, shots=101, either switch setting; manoeuvre's logs), so it now gates like the others.
## Round 39 (doctrine D5): test_target_crossing PROMOTED. With R1-R3 ON (the default since R38.55) it passed while still
## marked pending (doctrine's R38.55 check, builder0 95a3a8f54); re-read alone on builder0 before promoting (doctrine Status).
const PENDING := []
const ON_POINT_BAR := 0.5
const FIRST_BAR := 3.0

const START_TICKS := [1, 3, 6, 8, 11, 16]
const SEEDS := [1, 2, 3]
const RUN_S := 12.0
const SCOUT_AT := Vector3(-90, 0, 20)


static func _pooled() -> bool:
	return OS.get_cmdline_user_args().has("--scout-pool")


static func case_setup(kind: String) -> Dictionary:
	match kind:
		"left90":
			return {"from": SCOUT_AT + Vector3(-20, 0, 0), "yaw": 0.0, "to": null}
		"behind":
			return {"from": SCOUT_AT + Vector3(0, 0, 20), "yaw": -PI / 2.0, "to": null}
		"close":
			return {"from": SCOUT_AT + Vector3(0, 0, -8), "yaw": -PI / 2.0, "to": null}
		"crossing":
			return {"from": SCOUT_AT + Vector3(-25, 0, -20), "yaw": -PI / 2.0, "to": SCOUT_AT + Vector3(60, 0, -20)}
	push_error("unknown case " + kind)
	return {}


func run_case(kind: String, start_tick: int, seed_value: int) -> Dictionary:
	var setup := case_setup(kind)
	var s := AiScenario.create(self, seed_value)
	var target := s.shooter(Match.Team.RUST, "Rust_Tank_1", setup["from"], float(setup["yaw"]), {"type": "stop"},
			{"type": "fire_at_will"}, "tank")
	AiScenario.make_durable(target)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_A_1", SCOUT_AT, 0.0, {}, "scout", "", "Alpha")
	AiScenario.make_durable(scout)
	await s.start()
	var brain := s.brain_of(scout)
	var weapon := scout.weapon
	var tolerance := deg_to_rad(float(weapon["aim_tolerance_deg"]))
	var reach := float(weapon["range"])
	var ticks := int(RUN_S * SimClock.TICK_RATE)
	var suppress_ticks := 0
	var on_ticks := 0
	var first := -1
	var contacts := 0
	var contacts_suppress := 0
	var touching := false
	var closest := INF
	for tick in start_tick + ticks:
		target.suppression = 0.9
		if tick == start_tick:
			s.orders().call("issue", {"units": [String(scout.name)], "verb": "attack", "target": String(target.name),
					"queue": false})
			if setup["to"] is Vector3:
				(s.controller_of(target) as OrderController).set_orders(
						{"type": "move_to", "x": (setup["to"] as Vector3).x, "z": (setup["to"] as Vector3).z},
						{"type": "fire_at_will"})
		await s.step()
		if tick < start_tick:
			continue
		var t := tick - start_tick
		var touch := _touching(scout, target) or _touching(target, scout)
		if touch and not touching:
			contacts += 1
			if String(brain.choice.get("option", "")) == "SUPPRESS":
				contacts_suppress += 1
		touching = touch
		closest = minf(closest, Vector2(scout.global_position.x - target.global_position.x,
				scout.global_position.z - target.global_position.z).length())
		if OS.get_environment("SCOUT_PROBE") == "1" and t % 15 == 0:
			var move: Dictionary = brain.get("move_order")
			var to := target.global_position - scout.global_position
			print("SCOUT_PROBE %s t=%.1f at=(%.1f, %.1f) d=%.1f off=%.0f v_fwd=%.1f opt=%s move=%s rev=%s why=%s" % [kind,
					t / 30.0, scout.global_position.x, scout.global_position.z, Vector2(to.x, to.z).length(),
					rad_to_deg((-scout.global_basis.z).signed_angle_to(Vector3(to.x, 0, to.z), Vector3.UP)),
					scout.estimated_velocity.dot(-scout.global_basis.z), String(brain.choice.get("option", "?")),
					String(move.get("type", "?")), str(move.get("reverse", false)), str(brain.get("why"))])
		if String(brain.choice.get("option", "")) != "SUPPRESS":
			continue
		suppress_ticks += 1
		var spot: Variant = brain.get("_suppress_point")
		if not (spot is Vector3):
			continue
		var muzzle := scout.turret.global_position
		var aim_at := Vector3((spot as Vector3).x, muzzle.y, (spot as Vector3).z)
		if muzzle.distance_to(aim_at) <= reach and Ballistics.aim_error(muzzle, scout.turret_forward(), aim_at) <= tolerance:
			on_ticks += 1
			if first < 0:
				first = t
	var seconds := float(SimClock.TICK_RATE)
	var result := {"kind": kind, "suppress_s": suppress_ticks / seconds,
			"on_point": on_ticks / float(maxi(suppress_ticks, 1)), "first_s": (first if first >= 0 else ticks) / seconds,
			"contacts": contacts, "contacts_suppress": contacts_suppress, "closest": closest, "shots": s.shots_by(scout)}
	print("SCOUT_SUPPRESS_RUN %s start=%d seed=%d suppress_s=%.1f on_point=%.2f first_s=%.1f contacts=%d (under SUPPRESS %d) closest=%.1f shots=%d" % [
			kind, start_tick, seed_value, result["suppress_s"], result["on_point"], result["first_s"], contacts, contacts_suppress, closest,
			result["shots"]])
	s.dispose()
	return result


static func _touching(body: Tank, other: Tank) -> bool:
	for i in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_collider() == other:
			return true
	return false


func pool(kind: String) -> Dictionary:
	var ticks: Array = START_TICKS if _pooled() else [START_TICKS[0], START_TICKS[2], START_TICKS[4]]
	var seeds: Array = SEEDS if _pooled() else [SEEDS[0]]
	var runs: Array = []
	for seed_value: int in seeds:
		for start: int in ticks:
			runs.append(await run_case(kind, start, seed_value))
	var suppress_s := 0.0
	var on_s := 0.0
	var firsts: Array = []
	var contacts := 0
	var shots := 0
	for run: Dictionary in runs:
		suppress_s += float(run["suppress_s"])
		on_s += float(run["suppress_s"]) * float(run["on_point"])
		firsts.append(float(run["first_s"]))
		contacts += int(run["contacts"])
		shots += int(run["shots"])
	firsts.sort()
	var out := {"n": runs.size(), "suppress_s": suppress_s / runs.size(), "on_point": on_s / maxf(suppress_s, 0.001),
			"first_median": float(firsts[firsts.size() / 2]), "contacts": contacts, "shots": shots / float(runs.size())}
	print("MEASURE scout_suppress %s n=%d suppress_s=%.1f on_point=%.2f first_median=%.1f contacts=%d shots=%.0f" % [
			kind, out["n"], out["suppress_s"], out["on_point"], out["first_median"], contacts, out["shots"]])
	return out


func _judge(out: Dictionary) -> void:
	# Setup, not a bar: the crossing tank leaves SUPPRESS's reach for part of the run (~6 s of 12), so 30 % (was 50 %,
	# changed on the first one-run probe, which read 5.6 s; disclosed in the brief).
	assert_true(float(out["suppress_s"]) >= RUN_S * 0.3, "setup: it suppresses for a good part of the run (%.1f s)" % float(out["suppress_s"]))
	assert_eq(int(out["contacts"]), 0, "it never drives into the tank (%d contacts)" % int(out["contacts"]))
	assert_true(float(out["on_point"]) >= ON_POINT_BAR, "its gun is on the point %.0f%% of the time (bar %.0f%%)" % [
			100.0 * float(out["on_point"]), 100.0 * ON_POINT_BAR])
	assert_true(float(out["first_median"]) <= FIRST_BAR, "and on it %.1f s in, median (bar %.1f s)" % [
			float(out["first_median"]), FIRST_BAR])


func test_target_off_the_left() -> void:
	_judge(await pool("left90"))


func test_target_behind() -> void:
	_judge(await pool("behind"))


func test_target_close_ahead() -> void:
	_judge(await pool("close"))


func test_target_crossing() -> void:
	_judge(await pool("crossing"))
