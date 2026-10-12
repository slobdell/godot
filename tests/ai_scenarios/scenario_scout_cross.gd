extends TestCase
## Round 27 (scout S0): the lead's showmatch case, reproduced before anything is fixed (`_agents/streams/scout.md`).
##
## The lead: *"the scouts seem to drive super close to their target, leaving no room for them to turn and maintain their
## target, and they don't seem to drive backwards when they have that option to turn and maintain their target (i.e. if
## they're right up against a vehicle, and the vehicle moves east, the car seems to only move forward, so it seems to not
## consider the option of driving in reverse and to the west so that they can maintain the target)"*
##
## A scout ordered to attack (the default fight path: its own brain, fixed gun, wheels) against a tank on a scripted drive, durable both,
## the tank shooting back. Five cases: the tank crosses the scout's nose with a 5 m and a 10 m gap (nose to the tank's
## near side), left to right and right to left; and his exact case, the tank side-on against the scout's nose driving
## away east. The drive starts at a pre-registered start tick (C27.5: {1,3,6,8,11,16}, so the scout's think phase against
## the event varies) and each case pools those ticks over seeds.
##
## Per run, from the start of the tank's drive for RUN_S seconds:
##   on_target   share of the run the gun bears: hull within the gun's aim tolerance, in range, line of sight (exactly
##               Gunnery's `aimed and in_range` gate, so "could fire now")
##   reacquire   seconds from the first moment the gun loses the target to the first moment it bears again (censored
##               at the run's end: reported as the time left, and counted in `never`)
##   contacts    hull touches with the target (rising edges of a slide collision between the two)
##   closest     closest centre-to-centre distance
##   reverse_s   seconds the scout drove backwards (its velocity against its nose, > 0.5 m/s)
##   west_3s     the scout's x displacement over the drive's first 3 s (his case: negative = it backed off west)
##   shots, hits the scout's rounds and the team's hits
##   dies        who would have died (damage against max health + shield; both are durable so the run stays measurable)
##
## Default: one start tick and one seed per case (the check's subset). `--scout-pool` runs every start tick over
## SEEDS seeds (`make scout-cross`, mk/scout.mk). The bars were written before any number was measured (PENDING at S0,
## promoted at CP-S).

## Round 27: promoted at CP-S (CombatMotion.plan_lay); `--scout-off=gunlay` fails four of the five again.
const PENDING := []

const START_TICKS := [1, 3, 6, 8, 11, 16]
const SEEDS := [1, 2, 3]
const RUN_S := 12.0
## Where the scout stands (open ground west of the arena's centre; scenario_cp2's engine deck fights here too), facing
## north (-Z).
const SCOUT_AT := Vector3(-90, 0, 20)
## How far to the side the tank starts a cross, and where it drives to (metres from the scout's line).
const CROSS_FROM := 16.0
const CROSS_TO := 60.0

## The bars (written 2026-10-11 before any measurement; the player's terms in brackets):
## - no hull contact in any run [it never drives into the tank]
## - gun on target at least ON_TARGET_BAR of the run, pooled [it keeps shooting while the tank moves]
## - re-acquired within REACQUIRE_BAR seconds, pooled median [when the tank slides past its nose, the gun is back on
##   it in about the time a car takes to back up and turn, not a loop round]
const ON_TARGET_BAR := 0.5
const REACQUIRE_BAR := 2.0


## S4: which fixed gun plays the scout (`--scout-unit=gang_scout`; default the Condemned scout).
static func _unit() -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--scout-unit="):
			return String(arg).trim_prefix("--scout-unit=")
	return "scout"


static func _pooled() -> bool:
	return OS.get_cmdline_user_args().has("--scout-pool")


## One case: where the tank starts (relative to the scout, in the scout's frame: x right, z ahead), its yaw, and where
## it drives.
static func case_setup(kind: String) -> Dictionary:
	var scout_half := float(Movement.hull_box(_unit())[2]) / 2.0
	var tank_half_width := 2.90 / 2.0
	match kind:
		"cross5_lr", "cross5_rl", "cross10_lr", "cross10_rl":
			var gap := 5.0 if kind.begins_with("cross5") else 10.0
			var ahead := scout_half + gap + tank_half_width
			var sign := 1.0 if kind.ends_with("_lr") else -1.0
			return {"from": Vector3(SCOUT_AT.x - sign * CROSS_FROM, 0.0, SCOUT_AT.z - ahead),
					"yaw": -PI / 2.0 * sign, "to": Vector3(SCOUT_AT.x + sign * CROSS_TO, 0.0, SCOUT_AT.z - ahead)}
		"away_east":
			# Side-on against the scout's nose (a metre of air), facing east, then drives away east.
			var ahead := scout_half + 1.0 + tank_half_width
			return {"from": Vector3(SCOUT_AT.x, 0.0, SCOUT_AT.z - ahead), "yaw": -PI / 2.0,
					"to": Vector3(SCOUT_AT.x + CROSS_TO, 0.0, SCOUT_AT.z - ahead)}
	push_error("unknown case " + kind)
	return {}


## One run: `kind` with the tank's drive starting at `start_tick`, on `seed_value`.
func run_case(kind: String, start_tick: int, seed_value: int, probe := false) -> Dictionary:
	var setup := case_setup(kind)
	var s := AiScenario.create(self, seed_value)
	var target := s.shooter(Match.Team.RUST, "Rust_Tank_1", setup["from"], float(setup["yaw"]), {"type": "stop"},
			{"type": "fire_at_will"})
	AiScenario.make_durable(target)
	var scout := s.brain_tank(Match.Team.GREEN, "Green_Scout_1", SCOUT_AT, 0.0, {}, _unit())
	var scout_full := float(scout.max_health) + float(scout.max_shield)
	AiScenario.make_durable(scout)
	var orders := s.orders()
	var target_full := float(Units.stat("tank", "max_health", 200)) + float(Units.stat("tank", "max_shield", 0.0))
	await s.start()
	# Ordered onto it, as a squad's attack or the CPU's would: a lone scout with no order SPOTs (backs off and watches).
	orders.call("issue", {"units": [String(scout.name)], "verb": "attack", "target": String(target.name), "queue": false})
	var weapon := scout.weapon
	var tolerance := deg_to_rad(float(weapon["aim_tolerance_deg"]))
	var reach := float(weapon["range"])
	var ticks := int(RUN_S * SimClock.TICK_RATE)
	var on_ticks := 0
	var lost_at := -1
	var back_at := -1
	var contacts := 0
	var touching := false
	var closest := INF
	var reverse_ticks := 0
	var x_at_start := 0.0
	var x_at_3s := 0.0
	var scout_dead_at := -1.0
	var target_dead_at := -1.0
	var shots_before := 0
	var hits_before := 0
	for tick in start_tick + ticks:
		if tick == start_tick:
			(s.controller_of(target) as OrderController).set_orders(
					{"type": "move_to", "x": (setup["to"] as Vector3).x, "z": (setup["to"] as Vector3).z},
					{"type": "fire_at_will"})
			x_at_start = scout.global_position.x
			shots_before = s.shots_by(scout)
			hits_before = int(s.game_match.stats["hits"][Match.Team.GREEN])
		await s.step()
		if tick < start_tick:
			continue
		var t := tick - start_tick
		var muzzle := scout.turret.global_position
		var distance := muzzle.distance_to(target.global_position)
		var bears := Ballistics.aim_error(muzzle, scout.turret_forward(), target.global_position) <= tolerance \
				and distance <= reach and AiScenario.sees(scout, target)
		if bears:
			on_ticks += 1
			if lost_at >= 0 and back_at < 0:
				back_at = t
		elif lost_at < 0:
			lost_at = t
		var touch := _touching(scout, target) or _touching(target, scout)
		if touch and not touching:
			contacts += 1
		touching = touch
		closest = minf(closest, Vector2(scout.global_position.x - target.global_position.x,
				scout.global_position.z - target.global_position.z).length())
		var nose := -scout.global_basis.z
		if scout.estimated_velocity.dot(nose) < -0.5:
			reverse_ticks += 1
		if t == 3 * SimClock.TICK_RATE:
			x_at_3s = scout.global_position.x
		if scout_dead_at < 0.0 and float(1_000_000 - scout.health) + (float(scout.max_shield) - scout.shield) >= scout_full:
			scout_dead_at = t / float(SimClock.TICK_RATE)
		if target_dead_at < 0.0 and float(1_000_000 - target.health) + (float(target.max_shield) - target.shield) >= target_full:
			target_dead_at = t / float(SimClock.TICK_RATE)
		if probe and t % 15 == 0:
			var brain := s.brain_of(scout)
			var move: Dictionary = brain.get("move_order")
			var to := target.global_position - scout.global_position
			print("SCOUT_PROBE %s t=%.1f at=(%.1f, %.1f) d=%.1f off=%.0f v_fwd=%.1f opt=%s move=%s rev=%s why=%s" % [kind,
					t / 30.0, scout.global_position.x, scout.global_position.z, Vector2(to.x, to.z).length(),
					rad_to_deg(Ballistics.aim_error(muzzle, scout.turret_forward(), target.global_position)),
					scout.estimated_velocity.dot(nose),
					String((brain.get("choice") as Dictionary).get("option", "?")) if brain.get("choice") is Dictionary else "?",
					String(move.get("type", "?")), str(move.get("reverse", false)), str(brain.get("why"))])
	var seconds := float(SimClock.TICK_RATE)
	var reacquire := -1.0
	var never := false
	if lost_at >= 0:
		if back_at >= 0:
			reacquire = (back_at - lost_at) / seconds
		else:
			reacquire = (ticks - lost_at) / seconds
			never = true
	var dies := "nobody"
	if scout_dead_at >= 0.0 and (target_dead_at < 0.0 or scout_dead_at <= target_dead_at):
		dies = "scout@%.1f" % scout_dead_at
	elif target_dead_at >= 0.0:
		dies = "tank@%.1f" % target_dead_at
	var result := {"kind": kind, "start": start_tick, "seed": seed_value, "on_target": on_ticks / float(ticks),
			"reacquire": reacquire, "never": never, "lost": lost_at >= 0, "contacts": contacts, "closest": closest,
			"reverse_s": reverse_ticks / seconds, "west_3s": x_at_3s - x_at_start,
			"shots": s.shots_by(scout) - shots_before,
			"hits": int(s.game_match.stats["hits"][Match.Team.GREEN]) - hits_before, "dies": dies}
	print("SCOUT_RUN %s start=%d seed=%d on_target=%.2f reacquire=%s contacts=%d closest=%.1f reverse_s=%.1f dx_3s=%.1f shots=%d hits=%d dies=%s" % [
			kind, start_tick, seed_value, result["on_target"],
			("%.1f%s" % [reacquire, "+" if never else ""]) if lost_at >= 0 else "kept", contacts, closest,
			result["reverse_s"], result["west_3s"], result["shots"], result["hits"], dies])
	s.dispose()
	return result


static func _touching(body: Tank, other: Tank) -> bool:
	for i in body.get_slide_collision_count():
		if body.get_slide_collision(i).get_collider() == other:
			return true
	return false


## Every run of `kind` (the check's one, or the pool), and the pooled line.
func pool(kind: String) -> Dictionary:
	var ticks: Array = START_TICKS if _pooled() else [START_TICKS[0]]
	var seeds: Array = SEEDS if _pooled() else [SEEDS[0]]
	var probe := OS.get_environment("SCOUT_PROBE") == "1"
	var runs: Array = []
	for seed_value: int in seeds:
		for start: int in ticks:
			runs.append(await run_case(kind, start, seed_value, probe))
	var on_target := 0.0
	var contacts := 0
	var touched_runs := 0
	var reacquires: Array = []
	var never := 0
	var reverse_s := 0.0
	var west := 0.0
	var shots := 0
	var hits := 0
	var scout_dies := 0
	for run: Dictionary in runs:
		on_target += float(run["on_target"])
		contacts += int(run["contacts"])
		touched_runs += 1 if int(run["contacts"]) > 0 else 0
		if bool(run["lost"]):
			reacquires.append(float(run["reacquire"]))
		never += 1 if bool(run["never"]) else 0
		reverse_s += float(run["reverse_s"])
		west += float(run["west_3s"])
		shots += int(run["shots"])
		hits += int(run["hits"])
		scout_dies += 1 if String(run["dies"]).begins_with("scout") else 0
	var n := runs.size()
	reacquires.sort()
	var median := float(reacquires[reacquires.size() / 2]) if not reacquires.is_empty() else 0.0
	var out := {"n": n, "on_target": on_target / n, "contacts": contacts, "touched_runs": touched_runs,
			"reacquire_median": median, "lost_runs": reacquires.size(), "never": never, "reverse_s": reverse_s / n,
			"west_3s": west / n, "shots": shots / float(n), "hits": hits / float(n), "scout_dies": scout_dies}
	print("MEASURE scout_cross %s unit=%s n=%d on_target=%.2f reacquire_median=%.1f (lost in %d, never back %d) contacts=%d in %d runs reverse_s=%.1f dx_3s=%.1f shots=%.0f hits=%.0f scout_dies=%d" % [
			kind, _unit(), n, out["on_target"], median, reacquires.size(), never, contacts, touched_runs, out["reverse_s"],
			out["west_3s"], out["shots"], out["hits"], scout_dies])
	return out


func _judge(out: Dictionary, west: bool) -> void:
	assert_eq(int(out["contacts"]), 0, "the scout never drives into the tank (%d contacts)" % int(out["contacts"]))
	assert_true(float(out["on_target"]) >= ON_TARGET_BAR, "its gun bears %.0f%% of the fight (bar %.0f%%)" % [
			100.0 * float(out["on_target"]), 100.0 * ON_TARGET_BAR])
	assert_true(float(out["reacquire_median"]) <= REACQUIRE_BAR, "and is back on it in %.1f s, median (bar %.1f s)" % [
			float(out["reacquire_median"]), REACQUIRE_BAR])
	if west:
		assert_true(float(out["west_3s"]) < -0.5, "his case: it backs off west as the tank drives east (%.1f m)" % float(out["west_3s"]))


func test_crossing_5m_left_to_right() -> void:
	_judge(await pool("cross5_lr"), false)


func test_crossing_5m_right_to_left() -> void:
	_judge(await pool("cross5_rl"), false)


func test_crossing_10m_left_to_right() -> void:
	_judge(await pool("cross10_lr"), false)


func test_crossing_10m_right_to_left() -> void:
	_judge(await pool("cross10_rl"), false)


func test_target_drives_away_east_from_contact() -> void:
	_judge(await pool("away_east"), true)
