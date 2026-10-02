extends SceneTree
## Round 15 (squad P1): the gangs' two flipped verdicts, measured over seeds instead of on one.
##
## Round 14 read, on ONE seed each (builder0, dca1d6cc), that the 09-16 verdicts the gangs' table rests on have flipped:
## encircle switched ON left the enemy at 0.002 (it was switched off for leaving 0.66), and the shipped lure against
## chasers kept 0.196 of the pack against 0.258 without it. This probe runs the same pack (an IFV leader and three
## scouts, `TacticsScenarios.gang_pack`'s roster) under one ARM of the gangs' table, against one OPPONENT, on one MAP,
## from one SEED, and prints one line. `make squad-doctrine-series` runs every cell on the same seeds.
##
##   --arm=shipped|encircle|nobait|both   the table as shipped (encircle off, bait on), encircle switched on, bait
##                                        switched off, both flipped. Built in memory; doctrines/*.json is never written
##   --opponent=guns|chasers|standard     two dug-in guns (round 14's encircle reading), two brain IFVs that follow a
##                                        lure (its bait reading), or an element under the standard table (two IFVs and
##                                        a scout, the same classes as the pack: a tank in it decides the matchup, not
##                                        the drills, measured: 0.22 of the pack left whatever the arm) told to attack it
##   --map=lane|yard|terminus             lane = the drills' own ground (the default arena's western strip, round 14's
##                                        staging); yard / terminus = his maps, the pack at GREEN's spawn
##   --seed=1                             jitters every start (±START_JITTER_M, ±START_JITTER_DEG) and seeds the fire
##                                        dispersion; seed 0 on the lane is round 14's drill exactly (no jitter, 53)
##   --seconds=90                         the time limit; the verdict is the first tick one side has nobody left
##   --trace=Green_A_4 --trace-from=14 --trace-to=28 --trace-every=6
##                                        (round 15, P4) one GANG_TRACE line per sample for that unit: where it is, what
##                                        its brain chose and why, the top of its ranking, and the move it handed on
##
##   GANG_PROBE {"arm": ..., "opponent": ..., "arena": ..., "seed": ..., "survival": ..., "enemy_survival": ...,
##               "survival_26s": ..., "verdict": "pack|enemy|time", "verdict_s": ..., "drills": {...}, ...}
##
## The drill counters attribute a result to a mechanism: per drill, how many times it started, the seconds spent in it,
## the shots the pack fired, and the damage dealt and taken while it ran. A table whose encircle arm "wins" but spent no
## tick encircling did not win by encircling.

const START_JITTER_M := 3.0
const START_JITTER_DEG := 15.0
const SAMPLE_TICKS := 10
const DISTANCE_M := 80.0
const ARMS := {"shipped": "gangs", "encircle": "gangs+encircle", "nobait": "gangs-no-bait",
		"both": "gangs+encircle-no-bait"}

var case: TestCase


func _initialize() -> void:
	_run_probe.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run_probe() -> void:
	case = TestCase.new()
	case.tree = self
	var arm := _flag("arm", "shipped")
	if not ARMS.has(arm):
		push_error("gang_probe: unknown --arm=%s" % arm)
		quit(2)
		return
	var trace := {"unit": _flag("trace", ""), "from": float(_flag("trace-from", "0")), "to": float(_flag("trace-to", "1e9")),
			"every": int(_flag("trace-every", "6"))}
	var report := await run(case, arm, _flag("opponent", "guns"), _flag("map", "lane"), int(_flag("seed", "1")),
			float(_flag("seconds", "90")), trace)
	print("GANG_PROBE " + JSON.stringify(report))
	print("GANG_PROBE_DONE")
	case.teardown()
	quit(0)


static func run(test: TestCase, arm: String, opponent: String, arena: String, seed_value: int,
		seconds: float, trace := {}) -> Dictionary:
	var lane := arena == "lane"
	# Seed 0 on the lane is the drill's own fight (TacticsScenarios.gang_pack seeds 53, no jitter).
	var exact := lane and seed_value == 0
	var lab := TacticsLab.create(test, 53 if exact else seed_value, "" if lane else arena)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var home: Vector3
	var toward: Vector3
	if lane:
		home = Vector3(TacticsScenarios.LANE_X, 0.0, 45.0)
		toward = Vector3.FORWARD
	else:
		home = Match.spawn_position(Match.Team.GREEN, 0)
		toward = TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var names: Array = []
	for i in 4:
		var at := home + right * ((i - 1.5) * 8.0)
		var turn := 0.0
		if not exact:
			at += right * jitter.randf_range(-START_JITTER_M, START_JITTER_M) \
					+ toward * jitter.randf_range(-START_JITTER_M, START_JITTER_M)
			turn = deg_to_rad(jitter.randf_range(-START_JITTER_DEG, START_JITTER_DEG))
		names.append(String(lab.unit(Match.Team.GREEN, "Green_A_%d" % (i + 1), at, yaw + turn,
				"scout" if i > 0 else "ifv").name))
	await lab.start()
	# The enemy DISTANCE_M ahead, abreast at 12 m, on ground a hull stands on (his maps have blocks where the lane has none).
	var enemy_ids: Array = {"guns": ["lancer", "artillery"], "chasers": ["ifv", "ifv"],
			"standard": ["ifv", "ifv", "scout"]}.get(opponent, ["lancer", "artillery"])
	var enemy: Array = []
	var centre := home + toward * DISTANCE_M
	if lane:
		centre = Vector3(TacticsScenarios.LANE_X, 0.0, -35.0)
	for i in enemy_ids.size():
		var spot := centre + right * ((i - (enemy_ids.size() - 1) * 0.5) * 12.0)
		if not exact:
			spot += right * jitter.randf_range(-START_JITTER_M, START_JITTER_M) \
					+ toward * jitter.randf_range(-START_JITTER_M, START_JITTER_M)
		if not lane:
			spot = SlotGround.for_unit(lab.arena, spot, String(enemy_ids[i]))
		var face := yaw + PI
		var unit_name := "Rust_%s_%d" % ["Gun" if opponent == "guns" else "Hunt", i + 1]
		if opponent == "guns":
			enemy.append(String(lab.gun(Match.Team.RUST, unit_name, spot, face, String(enemy_ids[i])).name))
		else:
			enemy.append(String(lab.unit(Match.Team.RUST, unit_name, spot, face, String(enemy_ids[i])).name))
	var pack := lab.element(names, "Pack", TacticsScenarios.table_for(String(ARMS[arm])))
	if opponent == "standard":
		var line := lab.element(enemy, "Line")
		line.assign({"verb": "attack", "target": names[0]})
	pack.assign({"verb": "attack", "target": enemy[0]})
	var started := lab.strength(names)
	var enemy_started := lab.strength(enemy)
	var shots := {"pack": 0, "enemy": 0}
	var by_drill := {}
	var drill_now := {"name": "none"}
	var on_fired := func(event: Dictionary) -> void:
		var shooter := String(event.get("shooter", ""))
		if names.has(shooter):
			shots["pack"] = int(shots["pack"]) + 1
			var row: Dictionary = by_drill.get_or_add(String(drill_now["name"]), _row())
			row["shots"] = int(row["shots"]) + 1
		elif enemy.has(shooter):
			shots["enemy"] = int(shots["enemy"]) + 1
	lab.game_match.weapon_fired.connect(on_fired)
	var enemy_centre := lab.center_of(enemy)
	var arcs := {}
	var widest := 0.0
	var survival_26 := -1.0
	var enemy_survival_26 := -1.0
	var verdict := "time"
	var verdict_tick := -1
	var pack_was := started
	var enemy_was := enemy_started
	var total := int(seconds * SimClock.TICK_RATE)
	var ticks := 0
	for tick in total:
		await lab.step()
		ticks = tick + 1
		var drill := String(pack.drill) if pack.drill != "" else "none"
		drill_now["name"] = drill
		var row: Dictionary = by_drill.get_or_add(drill, _row())
		row["ticks"] = int(row["ticks"]) + 1
		if String(trace.get("unit", "")) != "" and tick % int(trace["every"]) == 0:
			var t := tick / float(SimClock.TICK_RATE)
			if t >= float(trace["from"]) and t <= float(trace["to"]):
				_trace(lab, String(trace["unit"]), t, String(pack.drill))
		if tick == 26 * SimClock.TICK_RATE - 1:
			survival_26 = lab.survival(names, started)
			enemy_survival_26 = lab.survival(enemy, enemy_started)
		if tick % SAMPLE_TICKS == 0 or tick == total - 1:
			var pack_now := lab.strength(names)
			var enemy_now := lab.strength(enemy)
			row["dealt"] = float(row["dealt"]) + maxf(enemy_was - enemy_now, 0.0)
			row["taken"] = float(row["taken"]) + maxf(pack_was - pack_now, 0.0)
			pack_was = pack_now
			enemy_was = enemy_now
			widest = maxf(widest, lab.spread_of(names))
			if lab.alive(enemy) > 0:
				enemy_centre = lab.center_of(enemy)
			for unit_name: String in names:
				var tank := lab.tank_of(unit_name)
				if tank != null and tank.is_alive() and tank.global_position.distance_to(enemy_centre) < 90.0:
					var bearing := ElementSituation.bearing_deg(toward, tank.global_position - enemy_centre)
					arcs[int(floor((bearing + 180.0) / 45.0)) % 8] = true
			if lab.alive(enemy) == 0 or lab.alive(names) == 0:
				verdict = "pack" if lab.alive(enemy) == 0 else "enemy"
				verdict_tick = tick
				break
	if survival_26 < 0.0:
		# Decided inside 26 s: what stood at the verdict stands at 26 s.
		survival_26 = lab.survival(names, started)
		enemy_survival_26 = lab.survival(enemy, enemy_started)
	var drills := {}
	for entry: Array in lab.drill_log.get(pack.id, []):
		var name := String(entry[0])
		var counts: Dictionary = drills.get_or_add(name, {"starts": 0, "first_s": snappedf(int(entry[1]) / float(SimClock.TICK_RATE), 0.1)})
		counts["starts"] = int(counts["starts"]) + 1
	for name: String in by_drill:
		var row: Dictionary = by_drill[name]
		var counts: Dictionary = drills.get_or_add(name, {"starts": 0, "first_s": null})
		counts["s"] = snappedf(int(row["ticks"]) / float(SimClock.TICK_RATE), 0.1)
		counts["shots"] = row["shots"]
		counts["dealt"] = snappedf(float(row["dealt"]), 1.0)
		counts["taken"] = snappedf(float(row["taken"]), 1.0)
	lab.game_match.weapon_fired.disconnect(on_fired)
	var result := {"arm": arm, "table": ARMS[arm], "opponent": opponent, "arena": arena, "seed": seed_value,
			"seconds": seconds, "survival": snappedf(lab.survival(names, started), 0.001),
			"enemy_survival": snappedf(lab.survival(enemy, enemy_started), 0.001),
			"survivors": lab.alive(names), "enemy_left": lab.alive(enemy),
			"survival_26s": snappedf(survival_26, 0.001), "enemy_survival_26s": snappedf(enemy_survival_26, 0.001),
			"verdict": verdict, "verdict_s": snappedf(verdict_tick / float(SimClock.TICK_RATE), 0.1) if verdict_tick >= 0 else null,
			"ran_s": snappedf(ticks / float(SimClock.TICK_RATE), 0.1), "arcs_covered": arcs.size(),
			"widest_spread_m": snappedf(widest, 0.1), "shots": shots, "drills": drills,
			"first_contact_m": snappedf(home.distance_to(centre), 0.1)}
	lab.dispose()
	return result


static func _trace(lab: TacticsLab, unit_name: String, t: float, drill: String) -> void:
	var tank := lab.tank_of(unit_name)
	var brain := lab.game_match.brains.get_node_or_null(NodePath("Brain_" + unit_name)) as TankBrain
	if tank == null or brain == null or not tank.is_alive():
		return
	var top: Array = []
	for entry: Dictionary in brain.ranked.slice(0, 4):
		top.append("%s %s %.3f" % [entry.get("option", ""), entry.get("target", ""), float(entry.get("score", 0.0))])
	var move: Dictionary = brain.move_order
	print("GANG_TRACE " + JSON.stringify({"t": snappedf(t, 0.01), "unit": unit_name,
			"x": snappedf(tank.global_position.x, 0.1), "z": snappedf(tank.global_position.z, 0.1),
			"yaw": snappedf(rad_to_deg(tank.global_rotation.y), 1.0), "mps": snappedf(tank.estimated_velocity.length(), 0.1),
			"option": TankBrain.label(brain.choice), "why": brain.why, "drill": drill, "top": top,
			"move": {"type": move.get("type", ""), "x": snappedf(float(move.get("x", 0.0)), 0.1),
					"z": snappedf(float(move.get("z", 0.0)), 0.1)}}))


static func _row() -> Dictionary:
	return {"ticks": 0, "shots": 0, "dealt": 0.0, "taken": 0.0}
