extends SceneTree
## Round 22 (brains B4): THE RANGE GAP, measured for him (no price moves; C12.6 is his). Round 21 recorded that a full
## Syndicate squad of four out-ranges ten Rat Rods (all ten dead in 13 s for no damage, yard_open seed 3) and that a lone
## spotter platform kites five Rat Rods at 20-30 m. Here both sides fight under their own doctrine's DEFAULT behaviour:
## each is commanded by the computer's squad leader (ElementCommander, its faction's table), nobody gives an order.
##
##   godot --headless --path . --script res://tests/tactics/gap_probe.gd -- --case=squad|spotter --arena=yard_open
##         --seed=1 --duck=on|off --seconds=90 --trace=on
##   case squad:   10 Rat Rods (two squads of five) v 4 Syndicate (one squad: GAP_SQUAD)
##   case spotter:  5 Rat Rods (one squad) v 1 Syndicate spotter platform (syn_lancer)
##   GAP_PROBE {"case", "arena", "seed", "duck", "rods", "rods_alive", "rods_lost", "syn", "syn_alive", "syn_lost",
##              "winner" (rods | syndicate | none), "ended_s", "rods_first_hit_s" (first damage the Rat Rods dealt),
##              "ducks": {"rods": {outcome: crews}, "syn": {...}}}

## One Syndicate squad of four: one of each of its fighting vehicles (the garage's 1000 CR buys three of its tanks; this
## is the squad round 21 measured, the stage's default `--cpu=` list there).
const GAP_SQUAD := ["syn_tank", "syn_ifv", "syn_lancer", "syn_scout"]
const START_M := 80.0

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seed_value := int(_flag("seed", "1"))
	var which := _flag("case", "squad")
	var arena := _flag("arena", "yard_open")
	UnansweredFire.ENABLED = _flag("duck", "on") != "off"
	var trace := _flag("trace", "off") == "on"
	var lab := TacticsLab.create(case, seed_value, arena)
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	home.y = 0.0
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	var rod_squads: Array = []
	for k in (2 if which == "squad" else 1):
		var squad: Array = []
		for i in 5:
			var at := home + right * ((k - 0.5 * ((2 if which == "squad" else 1) - 1)) * 34.0 + (i - 2) * 6.0
					+ jitter.randf_range(-2, 2)) - toward * ((i % 2) * 4.0 + jitter.randf_range(0, 3))
			squad.append(String(lab.unit(Match.Team.GREEN, "Green_%s_%d" % ["AB"[k], i + 1], at, yaw, "gang_scout").name))
		rod_squads.append(squad)
	var them_at := home + toward * (START_M + jitter.randf_range(-5, 5)) + right * jitter.randf_range(-15, 15)
	var kinds: Array = GAP_SQUAD if which == "squad" else ["syn_lancer"]
	var syn: Array = []
	for i in kinds.size():
		var at := them_at + right * ((i - (kinds.size() - 1) * 0.5) * 8.0) + toward * jitter.randf_range(0, 6)
		syn.append(String(lab.unit(Match.Team.RUST, "Rust_Syn_%d" % (i + 1), at, yaw + PI, String(kinds[i])).name))
	await lab.start()
	var gangs: DoctrineTable = DoctrineTable.load_table("gangs")["table"]
	var syndicate: DoctrineTable = DoctrineTable.load_table("syndicate")["table"]
	var rods: Array = []
	for k in rod_squads.size():
		lab.elements.form(rod_squads[k], ["Alpha", "Bravo"][k], gangs)
		rods.append_array(rod_squads[k])
	lab.elements.form(syn, "Syndicate", syndicate)
	ElementCommander.install(lab.game_match, Match.Team.GREEN, lab.elements)
	ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	var rods_hp := lab.strength(rods)
	var syn_hp := lab.strength(syn)
	var ended := -1
	var first_hit := -1
	var ducks := {"rods": {}, "syn": {}}
	var seen := {}
	for tick in int(float(_flag("seconds", "90")) * SimClock.TICK_RATE):
		await lab.step()
		if first_hit < 0 and lab.strength(syn) < syn_hp - 0.5:
			first_hit = tick
		if tick % 3 == 0:
			for element: Element in lab.elements.all():
				for unit_name: String in element.ducks:
					var outcome := String((element.ducks[unit_name] as Dictionary).get("outcome", ""))
					var key := "%s:%s" % [unit_name, outcome]
					if outcome != "" and not seen.has(key):
						seen[key] = true
						var side: Dictionary = ducks["rods" if element.team == Match.Team.GREEN else "syn"]
						side[outcome] = int(side.get(outcome, 0)) + 1
		if trace and tick % (SimClock.TICK_RATE * 2) == 0:
			var parts: Array = []
			for element: Element in lab.elements.all():
				parts.append("%s %s drill=%s at %s alive %d" % [element.element_name, element.task.get("verb", "-"),
						element.drill, _v(lab.center_of(Array(element.members()))), lab.alive(Array(element.members()))])
			print("GAP_TRACE t=%ds | %s" % [tick / SimClock.TICK_RATE, " | ".join(parts)])
		if lab.alive(rods) == 0 or lab.alive(syn) == 0:
			ended = tick
			break
	var winner := "none"
	if lab.alive(rods) == 0 and lab.alive(syn) > 0:
		winner = "syndicate"
	elif lab.alive(syn) == 0 and lab.alive(rods) > 0:
		winner = "rods"
	var report := {"case": which, "arena": arena, "seed": seed_value, "duck": "on" if UnansweredFire.ENABLED else "off",
			"rods": rods.size(), "rods_alive": lab.alive(rods), "rods_lost": snappedf(rods_hp - lab.strength(rods), 1.0),
			"syn": syn.size(), "syn_alive": lab.alive(syn), "syn_lost": snappedf(syn_hp - lab.strength(syn), 1.0),
			"winner": winner, "ended_s": snappedf(ended / float(SimClock.TICK_RATE), 0.1) if ended >= 0 else -1.0,
			"rods_first_hit_s": snappedf(first_hit / float(SimClock.TICK_RATE), 0.1) if first_hit >= 0 else -1.0,
			"ducks": ducks}
	print("GAP_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


func _v(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]
