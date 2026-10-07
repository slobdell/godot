class_name DuckStage
extends RefCounted
## Round 22 (brains B1): the sitting duck's stage, shared by tests/tactics/duck_probe.gd (the series) and
## tests/test_tactics_unanswered.gd (make test). His recording's gunship on its post, a Lancer lasing it from beyond the
## gunship's reach. See duck_probe.gd for the recording and the report's fields.

const GUNSHIP_AT := Vector3(-6.7, 0.0, 51.7)
const LANCER_AT := Vector3(-90.7, 0.0, 52.4)
## The recorded ambush (tick 841): lying at `from`, the kill zone at `to`.
const AMBUSH_FROM := [-2.25, 51.8]
const AMBUSH_TO := [-25.5, 34.7]
const MOVED_M := 2.0
const DUCK := "Rust_Hunters_2"


static func run(case: TestCase, seed_value: int, side: String, task_verb: String, lancers: int, seconds: float,
		trace := false) -> Dictionary:
	var lab := TacticsLab.create(case, seed_value, "foundry")
	var his := side == "his"
	# His arm: the gunship's team is the player's, so the element's task is HIS order.
	lab.game_match.set_meta("player_team", Match.Team.RUST if his else Match.Team.GREEN)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var toward := (LANCER_AT - GUNSHIP_AT).normalized()
	var duck := lab.unit(Match.Team.RUST, DUCK, GUNSHIP_AT, atan2(-toward.x, -toward.z), "syn_ifv")
	var shooters: Array = []
	for i in maxi(lancers, 1):
		var at := LANCER_AT + Vector3(jitter.randf_range(-1.5, 1.5), 0.0, (i - (lancers - 1) * 0.5) * 9.0 + jitter.randf_range(-1.5, 1.5))
		shooters.append(String(lab.gun(Match.Team.GREEN, "Green_Charlie_%d" % (i + 1), at, atan2(toward.x, toward.z), "lancer").name))
	await lab.start()
	var element := lab.elements.form([DUCK], "Hunters", DoctrineTable.load_table("syndicate")["table"])
	if task_verb == "ambush":
		element.assign({"verb": "ambush", "from": AMBUSH_FROM, "to": AMBUSH_TO})
	else:
		element.assign({"verb": "hold"})
	var start_hp := float(duck.health) + duck.shield
	var lancer_hp := lab.strength(shooters)
	var first_hit := -1
	var moved := -1
	var died := -1
	var readout := ""
	var outcome := ""
	for tick in int(seconds * SimClock.TICK_RATE):
		await lab.step()
		if not duck.is_alive():
			if died < 0:
				died = tick
			continue
		if first_hit < 0 and float(duck.health) + duck.shield < start_hp - 0.5:
			first_hit = tick
		var off := Vector3(duck.global_position.x, 0.0, duck.global_position.z).distance_to(GUNSHIP_AT)
		if moved < 0 and off > MOVED_M:
			moved = tick
		var reacting := String((element.ducks.get(DUCK, {}) as Dictionary).get("outcome", ""))
		if reacting != "" and outcome == "":
			outcome = reacting
			readout = element.describe()
		if trace and tick % SimClock.TICK_RATE == 0:
			print("DUCK_TRACE t=%.0fs at %s off %.1f hp %.0f+%.0f outcome %s to %s order %s | %s" % [tick / float(SimClock.TICK_RATE),
					_v(duck.global_position), off, float(duck.health), duck.shield, reacting, (element.ducks.get(DUCK, {}) as Dictionary).get("point"), lab.orders.call("current", DUCK).get("verb", ""), element.describe()])
	var end_m := INF
	var covered := false
	var map := CoverMap.of(lab.game_match)
	var here := Vector3(duck.global_position.x, 0.0, duck.global_position.z)
	var lancer_reach := float(Weapons.profile("laser").get("range", 90.0))
	var own := float(duck.weapon.get("effective_range", 55.0))
	var any_reaches := false
	for shooter: String in shooters:
		var tank := lab.tank_of(shooter)
		if tank == null or not tank.is_alive():
			continue
		var there := Vector3(tank.global_position.x, 0.0, tank.global_position.z)
		end_m = minf(end_m, here.distance_to(there))
		any_reaches = any_reaches or here.distance_to(there) <= lancer_reach
		# Out of its line of fire: no clear sight line from it to the hull's centre (what the Lancer needs to lase it;
		# TacticalQuery.hull_hidden, the whole hull with margins, is stricter than the gun).
		covered = covered or not map.clear_line(there, here)
	var alive := duck.is_alive()
	var in_own := alive and end_m <= own
	var out_of_reach := alive and not any_reaches
	var report := {"seed": seed_value, "side": side, "task": task_verb, "lancers": lancers,
			"first_hit_s": _s(first_hit), "moved_s": _s(moved),
			"react_s": snappedf((moved - first_hit) / float(SimClock.TICK_RATE), 0.1) if moved >= 0 and first_hit >= 0 else -1.0,
			"outcome": outcome, "end_m": snappedf(end_m, 0.1) if end_m < INF else -1.0, "in_own_range": in_own,
			"out_of_reach": out_of_reach, "covered": alive and covered, "answered": in_own or out_of_reach or (alive and covered),
			"lost": snappedf(start_hp - (float(duck.health) + duck.shield if alive else 0.0), 1.0), "alive": alive,
			"died_s": _s(died), "unhit_s": snappedf(duck.ticks_since_hit / float(SimClock.TICK_RATE), 0.1) if alive else 0.0,
			"readout": readout if readout != "" else element.describe(),
			"lancers_lost": snappedf(lancer_hp - lab.strength(shooters), 1.0)}
	lab.dispose()
	return report


static func _s(tick: int) -> float:
	return snappedf(tick / float(SimClock.TICK_RATE), 0.1) if tick >= 0 else -1.0


static func _v(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]
