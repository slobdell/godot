extends SceneTree
## `make switch-arm` (combat, round 9, X1): the arm counter for A2's switching cost.
##
## Lesson 117, paid for twice: round 8 shipped an additive commitment term into a code path a standoff hold could never
## reach, and measured it twice before anyone noticed it was never consulted. So before A2 is measured against anything,
## this proves the term is (a) in the code path, (b) non-zero, and (c) DIFFERENT by hull class — because a cost that
## reads the same for a rat rod and a 14 m war rig is a constant wearing a formula's clothes, and A/B-ing it against
## `main` would be A/B-ing a build against itself.
##
## It runs one real fight (gangs vs law by default, so the roster's extremes are both on the field), reads every
## brain's `switch_probe` once per think, and reports per hull class:
##   thinks            per-think rows seen for that class
##   arm               cost / legacy / fresh (no current choice) / order (an unexecuted player order outranks it)
##   consulted         the share of thinks where the term was actually in the path
##   priced_per_think  how many candidates it charged
##   offered_s         the cost it OFFERED (median and p90 of the dearest candidate priced that think) -- the
##                     class-separation number X2's acceptance reads
##   paid_s            the cost the choice actually taken paid (0 when the crew kept what it had)
##   flipped_per_think how often the term actually CHANGED the decision, against the scores as they stood before it
##                     touched them. A term consulted every think that flips nothing is doing nothing, and no other
##                     number here would say so
##   switches / reversals per unit-minute, counted per physics tick with `make squad-decisions`'s own definitions
##                     (label = option+target, A -> B -> A) so the two instruments measure the same quantity and can
##                     be cross-checked. Both the 3 s window (round 8's, for comparability) and the 4 s window (this
##                     round's bar) are reported. Churn that falls because every crew froze is not a win, which is why
##                     the flip rate and the switch rate are printed beside each other
##
## Prints SWITCH_ARM <json>. The default build is the flat commitment bonus; `--tune=switch.cost=1` selects A2 and
## `--tune=switch.cost=1,switch.price=0` is its control (the cost computed and reported, never charged).

const ARENA := preload("res://game/arena/arena.tscn")
const MATCH := preload("res://game/match/match.tscn")

var game_match: Match
var orders: Orders
var watched: Array[Tank] = []
var time_limit := 120.0
var by_class := {}
var by_unit := {}
## metrics (round 9, A12): the creep is a property of WHEELS, not of a role -- ifv and lancer are almost all creep and
## `tank` produces none -- so every motion-shaped number here is split by locomotion as well as by class.
var by_locomotion := {}
var seen_think := {}
var last_label := {}
var history := {}
var armies_used: Array = ["", ""]
## Every switch this run made, with what the cost PREDICTED for it. metrics reads the hull rotation the unit actually
## performed between the same two ticks; the pair answers whether A2 prices work the vehicle really does, which a
## trajectory log cannot say alone (it does not know what anything was shooting at) and this cannot say alone (it does
## not know what the hull did next).
var switch_events: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % name):
			return arg.trim_prefix("--%s=" % name)
	return fallback


func _run() -> void:
	time_limit = float(_flag("time-limit", "120"))
	var seed_value := int(_flag("seed", "3"))
	var budget := int(_flag("budget", "6500"))
	var tune := _flag("tune", "")
	if tune != "":
		var tune_error := Units.apply_tuning(tune)
		if tune_error != "":
			push_error("switch-arm: " + tune_error)
			quit(1)
			return
	SwitchingCost.probing = true
	var arena: Arena = ARENA.instantiate()
	arena.layout_name = _flag("arena", "yard")
	root.add_child(arena)
	game_match = MATCH.instantiate()
	root.add_child(game_match)
	game_match.seed_spawns(seed_value, 0.0)
	game_match.set_meta("player_team", Match.Team.GREEN)
	await physics_frame
	for frame in 300:
		if Pathing.is_ready(arena):
			break
		await physics_frame
	# Named archetypes, not a bare "cpu" draft. This probe's whole claim is that the roster's extremes are on the
	# field, and a seeded draft does not guarantee it: seed 3 drew `gang_hail` and fielded NO War Rig at all, so the
	# rig-against-rat-rod number the round wants could not have been read from that run however good it looked.
	var armies := {Match.Team.GREEN: _flag("green-army", "gang_ram"), Match.Team.RUST: _flag("rust-army", "law_line")}
	var factions := {Match.Team.GREEN: _flag("green", "gangs"), Match.Team.RUST: _flag("rust", "law")}
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var loaded := Army.load_army("cpu:" + String(armies[team]), seed_value + team, budget, factions[team])
		var error: String = loaded.get("error", "")
		if error == "":
			error = game_match.load_doctrine(team, loaded["doctrine"])
		if error != "":
			push_error("switch-arm: " + error)
			quit(1)
			return
	orders = Orders.new()
	Orders.attach(game_match, orders)
	Elements.install(game_match, orders)
	# Round 10 (combat, A2's verdict): --trajectory=PATH writes metrics' per-tick log for this fight, so `make metrics`
	# can split the cusps into ordered / creep / unexplained per arm. The writer is metrics'; this only turns it on.
	preload("res://tools/metrics/trajectory_log.gd").install(game_match, _flag("trajectory", ""), "switch-arm",
			{"seed": seed_value, "budget": budget, "time_limit": time_limit, "tune": _flag("tune", "")})
	# Both sides are watched: the counter is about the mechanism, not about who wins, and a one-sided sample would
	# leave out whichever faction happens to die first.
	for tank: Tank in game_match.tanks.get_children():
		watched.append(tank)
	# REFUSE THE RUN IF THE UNIT UNDER TEST IS NOT ON THE FIELD. This probe printed a full, healthy, entirely real set
	# of numbers on a fight that contained no War Rig at all, because a seeded `cpu` draft drew an archetype without
	# one, and nothing in the output said so. Every figure was true; the question it was run to answer was
	# unanswerable. The general shape (metrics' control hit the same thing from the other side: a flag that never
	# reached the probe) is that the thing under test was selected by something nobody read back. So it is read back.
	var fielded := {}
	for tank: Tank in watched:
		fielded[String(tank.unit_id)] = true
	for required: String in _flag("require", "").split(",", false):
		if not fielded.has(required):
			push_error("switch-arm: '%s' is not on the field (armies %s vs %s field %s). Refusing the run rather than "
					% [required, armies[Match.Team.GREEN], armies[Match.Team.RUST], ", ".join(fielded.keys())]
					+ "reporting numbers that cannot answer the question they were asked.")
			quit(1)
			return
	for frame in SimClock.TICK_RATE:
		await physics_frame
	_order_squads(0.45, "move")
	var start := game_match.tick
	while game_match.tick - start < int(time_limit * 0.4 * SimClock.TICK_RATE):
		_sample()
		await physics_frame
	_order_squads(0.85, "attack_move")
	var fight_from := game_match.tick
	while game_match.tick - fight_from < int(time_limit * 0.6 * SimClock.TICK_RATE):
		_sample()
		await physics_frame
	armies_used = [String(armies[Match.Team.GREEN]), String(armies[Match.Team.RUST])]
	_report(seed_value, tune)
	quit(0)


## Every squad to a lane point `depth` of the way toward the enemy base (nav-fight's orders, exactly).
func _order_squads(depth: float, verb: String) -> void:
	for team: int in [Match.Team.GREEN, Match.Team.RUST]:
		var squads := {}
		for tank in watched:
			if not tank.is_alive() or tank.team != team:
				continue
			var parts := String(tank.name).split("_")
			var squad := parts[1] if parts.size() >= 3 else "?"
			(squads.get_or_add(squad, []) as Array).append(String(tank.name))
		var keys := squads.keys()
		keys.sort()
		var home := Match.spawn_position(team, 0)
		var away := Match.spawn_position(1 - team, 0)
		for i in keys.size():
			var lane := (float(i) - (keys.size() - 1) / 2.0) * 28.0
			var point := home.lerp(away, depth)
			orders.issue(UnitCommand.make(squads[keys[i]], verb, {"to": [point.x + lane, point.z]}))


func _sample() -> void:
	for tank in watched:
		if not tank.is_alive():
			continue
		var key := String(tank.name)
		var brain := game_match.brains.get_node_or_null(NodePath("Brain_" + key)) as TankBrain
		if brain == null or brain.choice.is_empty():
			continue
		var unit := String(tank.unit_id)
		var hull_class := Units.role_of(unit)
		# The denominator, counted per PHYSICS TICK exactly as `make squad-decisions` counts it, so churn per
		# unit-minute from this probe and from squad's instrument are the same quantity and can be cross-checked.
		var locomotion := String(Units.profile(unit).get("locomotion", "wheels"))
		var option := String(brain.choice.get("option", ""))
		_tick(by_class, hull_class, option)
		_tick(by_unit, unit, option)
		_tick(by_locomotion, locomotion, option)
		var label := "%s %s" % [option, brain.choice.get("target", "")]
		if last_label.has(key) and String(last_label[key]) != label:
			var was := String(last_label[key]).split(" ")[0]
			_switch(by_class, hull_class, key, label, was)
			_switch(by_unit, unit, key, label, was)
			_switch(by_locomotion, locomotion, key, label, was)
			var seen: Array = history.get_or_add(key, [])
			seen.append([label, game_match.tick])
			if seen.size() > 3:
				seen.pop_front()
		elif not last_label.has(key):
			(history.get_or_add(key, []) as Array).append([label, game_match.tick])
		last_label[key] = label
		if brain.switch_probe.is_empty():
			continue
		var row: Dictionary = brain.switch_probe
		# The controller runs every tick but a brain thinks every few, so the same row sits on the brain for several
		# samples. Count each think once, or every per-think rate is multiplied by the tick/think ratio.
		if int(seen_think.get(key, -1)) == int(row["tick"]):
			continue
		seen_think[key] = int(row["tick"])
		if bool(row["switched"]):
			switch_events.append({"tick": int(row["tick"]), "name": key, "unit": unit,
					"angle_deg": snappedf(float(row.get("angle_deg", 0.0)), 0.01),
					"cost_s": snappedf(float(row["cost_s"]), 0.001),
					"slew_s": snappedf(float(row.get("slew_s", 0.0)), 0.001),
					"brake_s": snappedf(float(row.get("brake_s", 0.0)), 0.001),
					"lay_s": snappedf(float(row.get("lay_s", 0.0)), 0.001),
					"team": tank.team, "arm": String(row["arm"])})
		_record(by_class, hull_class, row)
		_record(by_unit, unit, row)
		_record(by_locomotion, String(row["locomotion"]), row)


func _bucket(into: Dictionary, key: String) -> Dictionary:
	return into.get_or_add(key, {"thinks": 0, "arm": {}, "priced": 0, "switched": 0, "flipped": 0,
			"unit_ticks": 0, "switches": 0, "reversals_3s": 0, "reversals_4s": 0, "option_seconds": {},
			"transitions": {}, "offered": [] as Array, "paid": [] as Array})


func _tick(into: Dictionary, key: String, option: String) -> void:
	var bucket := _bucket(into, key)
	bucket["unit_ticks"] = int(bucket["unit_ticks"]) + 1
	# How long each option is actually RUN, not just how often it is chosen. A cost that suppresses a manoeuvre shows
	# up here as seconds lost from FLANK or ORBIT, which no switch counter can see -- round 9's duel scenario lost
	# 60% of its flanking to the stance floor and the churn tables said nothing at all.
	var seconds: Dictionary = bucket["option_seconds"]
	seconds[option] = int(seconds.get(option, 0)) + 1


## A switch, and the shape that is thrash whatever the cause: leaving A for B and going straight back (A -> B -> A).
## Both windows are reported — 3 s is round 8's window, so its numbers stay comparable; 4 s is this round's bar.
func _switch(into: Dictionary, key: String, unit_key: String, label: String, was: String) -> void:
	var bucket := _bucket(into, key)
	bucket["switches"] = int(bucket["switches"]) + 1
	# Which switches a cost suppresses is the question; "how many" is only its shadow.
	var pair := "%s->%s" % [was, label.split(" ")[0]]
	var transitions: Dictionary = bucket["transitions"]
	transitions[pair] = int(transitions.get(pair, 0)) + 1
	var seen: Array = history.get(unit_key, [])
	if seen.size() >= 2 and String(seen[-2][0]) == label:
		var gap := game_match.tick - int(seen[-1][1])
		if gap <= int(3.0 * SimClock.TICK_RATE):
			bucket["reversals_3s"] = int(bucket["reversals_3s"]) + 1
		if gap <= int(4.0 * SimClock.TICK_RATE):
			bucket["reversals_4s"] = int(bucket["reversals_4s"]) + 1


func _record(into: Dictionary, key: String, row: Dictionary) -> void:
	var bucket := _bucket(into, key)
	bucket["thinks"] = int(bucket["thinks"]) + 1
	var arm := String(row["arm"])
	bucket["arm"][arm] = int((bucket["arm"] as Dictionary).get(arm, 0)) + 1
	bucket["priced"] = int(bucket["priced"]) + int(row["priced"])
	if bool(row["switched"]):
		bucket["switched"] = int(bucket["switched"]) + 1
	if bool(row["flipped"]):
		bucket["flipped"] = int(bucket["flipped"]) + 1
	if arm == "cost" and int(row["priced"]) > 0:
		(bucket["offered"] as Array).append(float(row["max_cost_s"]))
		(bucket["paid"] as Array).append(float(row["cost_s"]))


func _summary(bucket: Dictionary) -> Dictionary:
	var thinks := maxi(int(bucket["thinks"]), 1)
	var minutes := maxf(float(bucket["unit_ticks"]) / (SimClock.TICK_RATE * 60.0), 0.001)
	var offered: Array = bucket["offered"]
	var paid: Array = bucket["paid"]
	return {"thinks": int(bucket["thinks"]), "unit_minutes": snappedf(minutes, 0.01), "arm": bucket["arm"],
			"consulted": snappedf(float(int((bucket["arm"] as Dictionary).get("cost", 0))) / thinks, 0.01),
			"priced_per_think": snappedf(float(bucket["priced"]) / thinks, 0.01),
			# The one that says whether the term is doing anything at all: how often it changed the decision.
			"flipped_per_think": snappedf(float(bucket["flipped"]) / thinks, 0.001),
			"switches_per_unit_min": snappedf(float(bucket["switches"]) / minutes, 0.1),
			"reversals_3s_per_unit_min": snappedf(float(bucket["reversals_3s"]) / minutes, 0.01),
			"reversals_4s_per_unit_min": snappedf(float(bucket["reversals_4s"]) / minutes, 0.01),
			"offered_s_median": _quantile(offered, 0.5), "offered_s_p90": _quantile(offered, 0.9),
			"paid_s_median": _quantile(paid, 0.5), "paid_s_max": _quantile(paid, 1.0),
			"option_share": _share(bucket["option_seconds"], int(bucket["unit_ticks"])),
			"transitions_per_unit_min": _rates(bucket["transitions"], minutes)}


## What share of its time a class spent running each option: the direct read on "did this cost suppress a manoeuvre".
func _share(counts: Dictionary, total: int) -> Dictionary:
	var out := {}
	for key: String in counts:
		out[key] = snappedf(float(counts[key]) / maxf(total, 1), 0.001)
	return out


func _rates(counts: Dictionary, minutes: float) -> Dictionary:
	var out := {}
	for key: String in counts:
		out[key] = snappedf(float(counts[key]) / minutes, 0.1)
	return out


func _quantile(values: Array, fraction: float) -> float:
	if values.is_empty():
		return 0.0
	var sorted := values.duplicate()
	sorted.sort()
	var index := clampi(int(floor(fraction * (sorted.size() - 1))), 0, sorted.size() - 1)
	return snappedf(float(sorted[index]), 0.001)


func _report(seed_value: int, tune: String) -> void:
	var classes := {}
	for key: String in by_class:
		classes[key] = _summary(by_class[key])
	var units := {}
	for key: String in by_unit:
		units[key] = _summary(by_unit[key])
	# The separation X2's acceptance is read from: the dearest hull's median offered cost against the cheapest's.
	var locomotions := {}
	for key: String in by_locomotion:
		locomotions[key] = _summary(by_locomotion[key])
	var best := ["", 0.0]
	var worst := ["", 0.0]
	for key: String in units:
		var median := float(units[key]["offered_s_median"])
		if median <= 0.0:
			continue
		if median > float(best[1]):
			best = [key, median]
		if float(worst[1]) <= 0.0 or median < float(worst[1]):
			worst = [key, median]
	# No INF and no NAN in the JSON: the legacy arm prices nothing, so every median is 0 and there is no spread to
	# report. A tool that emits `inf` here is a tool whose output the next reader has to hand-repair.
	var spread := {"dearest": best[0], "dearest_s": best[1], "cheapest": worst[0], "cheapest_s": worst[1],
			"ratio": snappedf(float(best[1]) / float(worst[1]), 0.01) if float(worst[1]) > 0.0 else 0.0}
	# metrics' `--switches` wants {unit NAME: [tick, ...]}; the detailed records sit beside it in the same file so a
	# pair can never be assembled from two different runs.
	var events_path := _flag("switch-events", "")
	if events_path != "":
		var ticks := {}
		for event: Dictionary in switch_events:
			(ticks.get_or_add(event["name"], []) as Array).append(event["tick"])
		var handle := FileAccess.open(events_path, FileAccess.WRITE)
		if handle == null:
			push_error("switch-arm: cannot write %s" % events_path)
		else:
			handle.store_string(JSON.stringify({"seed": seed_value, "arena": Arena.active.get("name", "?"),
					"tune": tune, "switches": ticks, "events": switch_events}, "\t"))
			handle.close()
			print("switch-arm: %d switch events -> %s" % [switch_events.size(), events_path])
	print("SWITCH_ARM " + JSON.stringify({"seed": seed_value, "arena": Arena.active.get("name", "?"),
			"tune": tune, "seconds": time_limit, "green_army": armies_used[0], "rust_army": armies_used[1],
			"by_class": classes, "by_locomotion": locomotions, "by_unit": units, "spread": spread}))
