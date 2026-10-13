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
## Round 28 (B1's bar): "on side" is within this many degrees of the side drawn.
const SIDE_DEG := 35.0


## `immortal`: the target is healed every tick (orders' flank probe: a target that cannot die shows whether the attack
## CLOSES, or parks at its guns' reach trading fire).
static func run(case: TestCase, seed_value: int, seconds: float, approach: Variant, trace := false, arena := "yard_open",
		immortal := false, quiet := false, live := false, his: PackedStringArray = [],
		theirs: PackedStringArray = [], moving := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var names: Array = []
	# `live` (orders' flank clips, round 27): his gangs' gun trucks (gang_ifv, five) against a Law squad of five
	# (scout, two tanks, two IFVs), damage on; he attacks one of its IFVs.
	# Round 27 (the orchestrator's re-run): `his` / `theirs` pick the rosters of a live fight (an EVEN one, calibrated on
	# clicked attacks only); the defaults are orders' clip (five gun trucks v a Law squad of five).
	var mine: PackedStringArray = his if not his.is_empty() else (PackedStringArray(["gang_ifv", "gang_ifv", "gang_ifv",
			"gang_ifv", "gang_ifv"]) if live else PackedStringArray(["tank", "tank", "tank", "tank"]))
	for i in mine.size():
		var at := START + Vector3(i * 8.0 - (mine.size() - 1) * 4.0 + jitter.randf_range(-JITTER_M, JITTER_M), 0.0,
				jitter.randf_range(-JITTER_M, JITTER_M))
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, 0.0, mine[i]).name))
	var enemy: Tank = null
	var law: Array = []
	if live:
		# As orders' flank clip stages it: the target HOLDS where it is (a standing gun that fires), its squadmates
		# are idle crews with their own brains and no commander (--no-element-cpu), damage on.
		var kinds: Array = Array(theirs) if not theirs.is_empty() else ["law_ifv", "law_ifv", "law_tank", "law_tank", "law_scout"]
		for i in kinds.size():
			var spot := TARGET + Vector3((i - (kinds.size() - 1) * 0.5) * 9.0, 0.0, -6.0 * (i % 2))
			if i == 0 and not moving:
				law.append(String(lab.gun(Match.Team.RUST, "Rust_L_1", spot, PI, kinds[i]).name))
			else:
				law.append(String(lab.unit(Match.Team.RUST, "Rust_L_%d" % (i + 1), spot, PI, kinds[i]).name))
		enemy = lab.tank_of(law[0])
	else:
		enemy = lab.gun(Match.Team.RUST, "Rust_T_1", TARGET, PI)
		lab.gun(Match.Team.RUST, "Rust_T_2", TARGET + Vector3(10.0, 0.0, -4.0), PI)
	if quiet:
		# Orders' quiet flank probe: the enemy holds its fire (and with `immortal` cannot die): does the attack CLOSE?
		for gun_name: String in ([] if live else ["Rust_T_1", "Rust_T_2"]):
			(lab.game_match.brains.get_node("Orders_" + gun_name) as OrderController).set_orders({"type": "stop"},
					{"type": "hold_fire"})
	lab.gun(Match.Team.GREEN, "Green_Eyes_1", SPOTTER, 0.0, "scout")
	(lab.game_match.brains.get_node("Orders_Green_Eyes_1") as OrderController).set_orders({"type": "stop"},
			{"type": "hold_fire"})
	var alpha := lab.element(names, "Alpha", DoctrineTable.load_table("gangs")["table"] if live else null)
	# `moving` (the orchestrator's reported arm): the target is a crew with a brain in a Law element under the CPU's
	# commander, so it moves (and at times runs), which is what turns an attack into a pursuit.
	if live and moving:
		lab.elements.form(law, "Law", DoctrineTable.load_table("law")["table"])
	await lab.start()
	if live and moving:
		ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	var task := {"verb": "attack", "target": String(enemy.name)}
	if approach != null:
		task["approach"] = approach
	var error := alpha.assign(task)
	var side := Vector3(-float(FROM_EAST[0]), 0.0, -float(FROM_EAST[1])) if approach == null \
			else Vector3(-float(approach[0]), 0.0, -float(approach[1])).normalized()
	# What the flank is for: the share of the target's hits that strike its side or rear armour.
	var faces := {"front": 0, "side": 0, "rear": 0}
	# Round 28 (B1): where on the target's hull each hit landed, as degrees off the side drawn (the impact point's bearing
	# from the target's centre at that tick). The same reading for every arm, whatever its route or its circle (lesson
	# 297: round 27's "first crew within 50 m" fell inside the parked fix's own circle and misread it).
	var hit_offs: Array = []
	lab.game_match.projectile_impact.connect(func(event: Dictionary) -> void:
		if String(event.get("target", "")) == String(enemy.name) and faces.has(String(event.get("face", ""))):
			faces[String(event["face"])] += 1
			if is_instance_valid(enemy):
				var at: Array = event["position"]
				hit_offs.append(absf(ElementPlan.approach_off_deg(Vector3(at[0], 0.0, at[2]), _flat(enemy.global_position),
						-side))))
	var pursuing_ticks := 0
	var rounding_pursuing_ticks := 0
	var target_fastest := 0.0
	var speed_at_pursuit := -1.0
	var in_tick := -1
	var reach_tick := -1
	var reach_off := -1.0
	var closest := INF
	var killed := -1
	var nearest_end := -1.0
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if immortal and enemy.is_alive():
			enemy.health = enemy.max_health
		if immortal:
			nearest_end = INF
			for unit_name: String in names:
				var crew := lab.tank_of(unit_name)
				if crew != null and crew.is_alive():
					nearest_end = minf(nearest_end, _flat(crew.global_position).distance_to(TARGET))
		if enemy.is_alive():
			var target_speed := Vector2(enemy.estimated_velocity.x, enemy.estimated_velocity.z).length()
			target_fastest = maxf(target_fastest, target_speed)
			if alpha.pursuing:
				pursuing_ticks += 1
				if not bool(alpha.approach_round.get("in", false)):
					rounding_pursuing_ticks += 1
				if speed_at_pursuit < 0.0:
					speed_at_pursuit = target_speed
		if in_tick < 0 and bool(alpha.approach_round.get("in", false)):
			in_tick = tick
		if killed < 0 and not enemy.is_alive():
			killed = tick
		if killed >= 0:
			continue
		# Round 28: from where the target IS (under the CPU's commander it moves; TARGET is only where it started).
		var target_at := _flat(enemy.global_position)
		var nearest := INF
		for unit_name: String in names:
			var tank := lab.tank_of(unit_name)
			if tank != null and tank.is_alive():
				nearest = minf(nearest, _flat(tank.global_position).distance_to(target_at))
		if reach_tick < 0:
			if nearest <= REACH_M:
				reach_tick = tick
				reach_off = absf(ElementPlan.approach_off_deg(lab.center_of(names), target_at, -side))
			else:
				closest = minf(closest, nearest)
		if trace and tick % SimClock.TICK_RATE == 0:
			var verbs := []
			for unit_name: String in names:
				verbs.append(String((lab.orders.call("current", unit_name) as Dictionary).get("verb", "-")))
			var options := []
			for unit_name: String in names:
				var brain := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as TankBrain
				options.append(String(brain.choice.get("option", "?")) if brain != null else "-")
			print("APPROACH_TRACE   brains=%s ducks=%s target_mps=%.1f pursuing=%s" % [",".join(options), alpha.ducks.keys(),
					Vector2(enemy.estimated_velocity.x, enemy.estimated_velocity.z).length() if enemy.is_alive() else -1.0,
					alpha.pursuing])
			print("APPROACH_TRACE t=%ds centre %s off %.0f nearest %.0f drill=%s round=%s orders=%s why=%s" % [
					tick / SimClock.TICK_RATE, lab.center_of(names).snappedf(0.1),
					absf(ElementPlan.approach_off_deg(lab.center_of(names), target_at, -side)), nearest, alpha.drill,
					alpha.approach_round, ",".join(verbs), alpha.reason])
	var report := {"seed": seed_value, "approach": "none" if approach == null else "east", "error": error,
			"pursuing_s": _s(pursuing_ticks), "pursuing_before_in_s": _s(rounding_pursuing_ticks),
			"target_fastest_mps": snappedf(target_fastest, 0.1), "target_mps_at_first_pursuit": snappedf(speed_at_pursuit, 0.1),
			"his": ",".join(mine), "theirs": ",".join(law) if live else "",
			"enemy_alive": lab.alive(law) if live else -1,
			"in_s": _s(in_tick), "reach_s": _s(reach_tick), "reach_off_deg": snappedf(reach_off, 0.1),
			"closest_m": snappedf(closest, 0.1) if is_finite(closest) else -1.0, "killed_s": _s(killed),
			"target_hits": faces, "target_flank_share": snappedf(float(faces["side"] + faces["rear"])
					/ maxf(float(faces["front"] + faces["side"] + faces["rear"]), 1.0), 0.01),
			"hits": hit_offs.size(), "hit_off_median_deg": _median(hit_offs),
			"hit_on_side_share": snappedf(float(hit_offs.filter(func(o: float) -> bool: return o <= SIDE_DEG).size())
					/ maxf(float(hit_offs.size()), 1.0), 0.01),
			"alive": lab.alive(names), "nearest_end_m": snappedf(nearest_end, 0.1) if is_finite(nearest_end) else -1.0}
	lab.dispose()
	return report


static func _median(values: Array) -> float:
	if values.is_empty():
		return -1.0
	var sorted := values.duplicate()
	sorted.sort()
	return snappedf(float(sorted[sorted.size() / 2]), 0.1)


static func _s(tick: int) -> float:
	return snappedf(tick / float(SimClock.TICK_RATE), 0.1) if tick >= 0 else -1.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
