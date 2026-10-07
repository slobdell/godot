extends SceneTree
## Round 21 (brains P2): a FIGHT with a target that runs, for the paired series (`make pursuit-series`). His shape from
## his game at 18:38 (foundry, seed 29989): his gang scouts, two squads of five, ordered to attack the Syndicate's
## spotter platform; the Syndicate pair around it (the spotter and a scout; `--cpu=` lists others) commanded by the CPU's
## squad leader (ElementCommander: it attacks, holds, breaks contact when outgunned: the spotter runs). Arms
## `--pursuit=on|off`.
##
##   godot --headless --path . --script res://tests/tactics/pursuit_probe.gd -- --seed=3 --pursuit=on|off
##         --arena=yard_open --seconds=60 --trace=on --cpu=syn_lancer,syn_scout
##         --case=recording (his game's own stage: foundry, tick 1824 of build/recordings/2026-10-06T18-38-40.jsonl)
##   PURSUIT_PROBE {"arena", "seed", "pursuit", "target_killed_s" (-1: alive at the end), "his_lost" (hit points),
##                  "his_alive", "cpu_alive", "cpu_lost", "nearest_worst_m" (his nearest crew to the target, worst after 10 s over the
##                  run while it lived, sampled each second), "reversals" (his crews' hull turns > 120 degrees in 4 s while
##                  driving and farther than 35 m from it)}

const REVERSAL_DEG := 120.0
const FIGHTING_M := 35.0

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
	var seed_value := int(_flag("seed", "3"))
	ElementPlan.PURSUIT_ENABLED = _flag("pursuit", "on") != "off"
	var trace := _flag("trace", "off") == "on"
	var recording := _flag("case", "stage") == "recording"
	var arena := "foundry" if recording else _flag("arena", "yard_open")
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	# {element name: [units]} per side, and the target.
	var his_squads := {}
	var cpu_squads := {}
	var target := ""
	if recording:
		target = _recorded(lab, his_squads, cpu_squads)
	else:
		target = _staged(lab, seed_value, his_squads, cpu_squads)
	var his: Array = []
	for squad: String in his_squads:
		his.append_array(his_squads[squad])
	var cpu: Array = []
	for squad: String in cpu_squads:
		cpu.append_array(cpu_squads[squad])
	await lab.start()
	var gangs: DoctrineTable = DoctrineTable.load_table("gangs")["table"]
	var syndicate: DoctrineTable = DoctrineTable.load_table("syndicate")["table"]
	var elements: Array = []
	for squad: String in his_squads:
		elements.append(lab.elements.form(his_squads[squad], squad, gangs))
	for squad: String in cpu_squads:
		lab.elements.form(cpu_squads[squad], squad, syndicate)
	ElementCommander.install(lab.game_match, Match.Team.RUST, lab.elements)
	for element: Element in elements:
		element.assign({"verb": "attack", "target": target, "formation": "vee"})
	var his_hp := lab.strength(his)
	var cpu_hp := lab.strength(cpu)
	var killed := -1
	var closest_worst := 0.0
	var headings := {}
	for unit_name: String in his:
		headings[unit_name] = []
	var per_s := 2
	for tick in int(float(_flag("seconds", "60")) * SimClock.TICK_RATE):
		await lab.step()
		var target_tank := lab.tank_of(target)
		var alive := target_tank != null and target_tank.is_alive()
		if not alive:
			if killed < 0:
				killed = tick
			continue
		if tick % (SimClock.TICK_RATE / per_s) != 0:
			continue
		var there := _flat(target_tank.global_position)
		var nearest := INF
		for unit_name: String in his:
			var tank := lab.tank_of(unit_name)
			var on := tank != null and tank.is_alive()
			var d := _flat(tank.global_position).distance_to(there) if on else INF
			nearest = minf(nearest, d)
			var moving := on and _flat(tank.estimated_velocity).length() >= 4.0 and d > FIGHTING_M
			(headings[unit_name] as Array).append(_flat(-tank.global_basis.z).normalized() if moving else Vector3.ZERO)
		if nearest < INF:
			closest_worst = maxf(closest_worst, nearest) if tick > SimClock.TICK_RATE * 10 else closest_worst
		if trace and tick % SimClock.TICK_RATE == 0:
			var parts: Array = []
			for element: Element in elements:
				parts.append("%s %s drill=%s at %s alive %d" % [element.element_name, element.reason, element.drill,
						_v(lab.center_of(Array(element.members()))), lab.alive(Array(element.members()))])
			for element: Element in lab.elements.of_team(Match.Team.RUST):
				parts.append("CPU %s %s drill=%s at %s" % [element.element_name, element.task.get("verb", "-"), element.drill,
						_v(lab.center_of(Array(element.members())))])
			print("PURSUIT_TRACE t=%.0fs target %s nearest %.0f | %s" % [tick / float(SimClock.TICK_RATE), _v(there), nearest,
					" | ".join(parts)])
	var reversals := 0
	for unit_name: String in his:
		var h: Array = headings[unit_name]
		var i := 0
		while i < h.size():
			var turned := false
			if (h[i] as Vector3) != Vector3.ZERO:
				for j in range(i + 1, mini(h.size(), i + 4 * per_s + 1)):
					if (h[j] as Vector3) != Vector3.ZERO and rad_to_deg((h[i] as Vector3).angle_to(h[j])) > REVERSAL_DEG:
						turned = true
						reversals += 1
						i = j
						break
			if not turned:
				i += 1
	var report := {"arena": "foundry-recorded" if recording else arena, "seed": seed_value, "pursuit": "on" if ElementPlan.PURSUIT_ENABLED else "off",
			"target_killed_s": snappedf(killed / float(SimClock.TICK_RATE), 0.1) if killed >= 0 else -1.0,
			"his_lost": snappedf(his_hp - lab.strength(his), 1.0), "his_alive": lab.alive(his),
			"cpu_alive": lab.alive(cpu), "cpu_lost": snappedf(cpu_hp - lab.strength(cpu), 1.0),
			"nearest_worst_m": snappedf(closest_worst, 0.1), "reversals": reversals}
	print("PURSUIT_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


## The made-up stage: his two squads of five at his spawn, the Syndicate pair 80 m ahead (jittered by the seed).
func _staged(lab: TacticsLab, seed_value: int, his_squads: Dictionary, cpu_squads: Dictionary) -> String:
	var jitter := RandomNumberGenerator.new()
	jitter.seed = seed_value
	var home := Match.spawn_position(Match.Team.GREEN, 0)
	home.y = 0.0
	var toward := TacticsFormation.flat(Vector3(-home.x, 0.0, -home.z))
	var right := Vector3(-toward.z, 0.0, toward.x)
	var yaw := atan2(-toward.x, -toward.z)
	for k in 2:
		var squad: Array = []
		for i in 5:
			var at := home + right * ((k - 0.5) * 34.0 + (i - 2) * 6.0 + jitter.randf_range(-2, 2)) \
					- toward * ((i % 2) * 4.0 + jitter.randf_range(0, 3))
			squad.append(String(lab.unit(Match.Team.GREEN, "Green_%s_%d" % ["AB"[k], i + 1], at, yaw, "gang_scout").name))
		his_squads[["Alpha", "Bravo"][k]] = squad
	# The Syndicate pair 80 m ahead, a little off his axis; the spotter in it. Outnumbered five to one, so its leader
	# breaks contact and the spotter runs (a full Syndicate squad of four simply out-ranged ten Rat Rods: all ten dead in
	# 13 s for no damage, seed 3, laptop; that stage never tested a chase).
	var them_at := home + toward * (80.0 + jitter.randf_range(-5, 5)) + right * jitter.randf_range(-15, 15)
	var kinds := _flag("cpu", "syn_lancer,syn_scout").split(",")
	var eyes: Array = []
	for i in kinds.size():
		var at := them_at + right * ((i - 1.5) * 8.0) + toward * jitter.randf_range(0, 6)
		eyes.append(String(lab.unit(Match.Team.RUST, "Rust_Eyes_%d" % (i + 1), at, yaw + PI, kinds[i]).name))
	cpu_squads["Eyes"] = eyes
	return String(eyes[0])


## His game at 18:38 (foundry, seed 29989, build/recordings/2026-10-06T18-38-40.jsonl), census at tick 1824, two ticks
## before his last attack (on Rust_Eyes_3, a Syndicate scout that then retreated from (-33, 6) to (15, -112)): every
## living vehicle where it stood, with its hit points, in its squad. Headings are not in the census: his face the
## target, the CPU's face him.
const RECORDED := [
	["Bravo", "Green_Bravo_1", "gang_scout", -99.1, 44.5, 100.0], ["Bravo", "Green_Bravo_4", "gang_scout", -99.8, 30.9, 100.0],
	["Bravo", "Green_Bravo_5", "gang_scout", -84.7, 49.8, 67.0], ["Delta", "Green_Delta_1", "gang_scout", -84.3, 82.5, 100.0],
	["Delta", "Green_Delta_4", "gang_scout", -65.4, 87.8, 1.0], ["Echo", "Green_Echo_1", "gang_scout", -45.6, 85.6, 100.0],
	["Echo", "Green_Echo_3", "gang_scout", -33.3, 77.5, 100.0],
	["Guns", "Rust_Guns_1", "syn_tank", 6.2, 3.0, 189.0], ["Lances", "Rust_Lances_1", "syn_lancer", -3.5, 6.1, 116.0],
	["Eyes", "Rust_Eyes_1", "syn_scout", -36.6, 2.3, 150.0], ["Eyes", "Rust_Eyes_2", "syn_scout", -33.6, -1.0, 150.0],
	["Eyes", "Rust_Eyes_3", "syn_scout", -32.6, 5.5, 150.0]]


func _recorded(lab: TacticsLab, his_squads: Dictionary, cpu_squads: Dictionary) -> String:
	var target_at := Vector3(-32.6, 0.0, 5.5)
	for row: Array in RECORDED:
		var at := Vector3(float(row[3]), 0.0, float(row[4]))
		var mine := String(row[1]).begins_with("Green")
		var facing: Vector3 = (target_at - at) if mine else (Vector3(-70.0, 0.0, 65.0) - at)
		var tank := lab.unit(Match.Team.GREEN if mine else Match.Team.RUST, String(row[1]), at,
				atan2(-facing.x, -facing.z), String(row[2]))
		tank.health = float(row[5])
		var squads: Dictionary = his_squads if mine else cpu_squads
		if not squads.has(row[0]):
			squads[row[0]] = []
		(squads[row[0]] as Array).append(String(tank.name))
	return "Rust_Eyes_3"


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _v(point: Vector3) -> String:
	return "(%.0f,%.0f)" % [point.x, point.z]
