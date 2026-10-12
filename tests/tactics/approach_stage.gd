class_name ApproachStage
extends RefCounted
## Round 27 (brains B0, C27.3): HIS attack with a drawn approach, as a stage. Orders' gesture (press on an enemy, drag,
## release) puts `task["approach"]` on the attack. Here his squad of four tanks stands 100 m south of a pair of enemy
## tanks on open ground (yard_open), his scout watching them from 73 m (south-west), and is told to attack one coming in from the
## EAST (approach [-1, 0]: the run in drives west), or with no approach (the control: it drives straight up from the south). Shared by tests/tactics/approach_probe.gd
## (the pooled series, `make approach-series`) and tests/test_tactics_approach_live.gd.
##
## Report: "in_s" (when the element came round onto the side drawn; -1 never), "reach_off_deg" (the element centre's
## bearing from the target, degrees off the side drawn, when its first crew came within REACH_M of the target, closing in to fight:
## the side it actually attacked from; -1 = never in reach), "reach_s", "closest_m" before reach (how near any crew got
## while going round), "killed_s" (-1 alive at the end), "alive" (his crews at the end).

const TARGET := Vector3(0.0, 0.0, -30.0)
const START := Vector3(0.0, 0.0, 70.0)
## His scout, watching from the band 73 m off with its fire held: the team sees the target before the squad does (he orders an
## attack on what his side sees; a tank sees 62 m, so the squad 100 m out would otherwise know nothing).
const SPOTTER := Vector3(-20.0, 0.0, 40.0)
## East: the run in drives west, so the squad comes in from the target's east side.
const FROM_EAST := [-1.0, 0.0]
const JITTER_M := 2.0
## Inside a tank's effective reach (45 m) and a margin: a crew this close is attacking, not going round.
const REACH_M := 50.0


## `immortal`: the target is healed every tick (orders' flank probe: a target that cannot die shows whether the attack
## CLOSES, or parks at its guns' reach trading fire).
static func run(case: TestCase, seed_value: int, seconds: float, approach: Variant, trace := false, arena := "yard_open",
		immortal := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var names: Array = []
	for i in 4:
		var at := START + Vector3(i * 8.0 - 12.0 + jitter.randf_range(-JITTER_M, JITTER_M), 0.0,
				jitter.randf_range(-JITTER_M, JITTER_M))
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, 0.0).name))
	var enemy := lab.gun(Match.Team.RUST, "Rust_T_1", TARGET, PI)
	lab.gun(Match.Team.RUST, "Rust_T_2", TARGET + Vector3(10.0, 0.0, -4.0), PI)
	lab.gun(Match.Team.GREEN, "Green_Eyes_1", SPOTTER, 0.0, "scout")
	(lab.game_match.brains.get_node("Orders_Green_Eyes_1") as OrderController).set_orders({"type": "stop"},
			{"type": "hold_fire"})
	var alpha := lab.element(names, "Alpha")
	await lab.start()
	var task := {"verb": "attack", "target": String(enemy.name)}
	if approach != null:
		task["approach"] = approach
	var error := alpha.assign(task)
	var side := Vector3(-float(FROM_EAST[0]), 0.0, -float(FROM_EAST[1])) if approach == null \
			else Vector3(-float(approach[0]), 0.0, -float(approach[1])).normalized()
	var in_tick := -1
	var reach_tick := -1
	var reach_off := -1.0
	var closest := INF
	var killed := -1
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if immortal and enemy.is_alive():
			enemy.health = enemy.max_health
		if in_tick < 0 and bool(alpha.approach_round.get("in", false)):
			in_tick = tick
		if killed < 0 and not enemy.is_alive():
			killed = tick
		if killed >= 0:
			continue
		var nearest := INF
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank != null and tank.is_alive():
				nearest = minf(nearest, _flat(tank.global_position).distance_to(TARGET))
		if reach_tick < 0:
			if nearest <= REACH_M:
				reach_tick = tick
				reach_off = absf(ElementPlan.approach_off_deg(lab.center_of(names), TARGET, -side))
			else:
				closest = minf(closest, nearest)
		if trace and tick % SimClock.TICK_RATE == 0:
			var verbs := []
			for unit_name: String in names:
				verbs.append(String((lab.orders.call("current", unit_name) as Dictionary).get("verb", "-")))
			print("APPROACH_TRACE t=%ds centre %s off %.0f nearest %.0f drill=%s round=%s orders=%s why=%s" % [
					tick / SimClock.TICK_RATE, lab.center_of(names).snappedf(0.1),
					absf(ElementPlan.approach_off_deg(lab.center_of(names), TARGET, -side)), nearest, alpha.drill,
					alpha.approach_round, ",".join(verbs), alpha.reason])
	var report := {"seed": seed_value, "approach": "none" if approach == null else "east", "error": error,
			"in_s": _s(in_tick), "reach_s": _s(reach_tick), "reach_off_deg": snappedf(reach_off, 0.1),
			"closest_m": snappedf(closest, 0.1) if is_finite(closest) else -1.0, "killed_s": _s(killed),
			"alive": lab.alive(names)}
	lab.dispose()
	return report


static func _s(tick: int) -> float:
	return snappedf(tick / float(SimClock.TICK_RATE), 0.1) if tick >= 0 else -1.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
