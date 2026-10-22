extends SceneTree
## Round 37 (orders O1 trace, R37.17; measurement only): traffic-census's CPU v CPU fight, set up exactly as
## tests/traffic/census_probe.gd sets it up (same calls, same order), with the same friendly-contact count (box gap <=
## TrafficStage.CONTACT_GAP_M, a pair counted when it starts touching), and one CONTACT row per contact: tick, the two
## crews, each one's element, task verb, arrived, formation, pitch, the terrain its element reads (centre and anchor),
## and where. It reproduces the census's own contacts_friend for the same case (printed in CONTACT_TRACE).
##   godot --headless --fixed-fps 30 --path . --script res://tests/control/contact_trace.gd -- --arena=parade --green=gangs \
##         --rust=law --credits=2000 --army=opponent --seed=3704 --seconds=150 [--halt-terrain=anchor]

const NEAR_M := 12.0
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
	BrainSwitches.ensure_parsed()
	TacticsFlags.requested()
	var seed_value := int(_flag("seed", "1"))
	var arena := _flag("arena", "sumps")
	var credits := int(_flag("credits", "1000"))
	var kind := _flag("army", "opponent")
	var factions := {Match.Team.GREEN: _flag("green", "law"), Match.Team.RUST: _flag("rust", "gangs")}
	var army_probe: GDScript = load("res://tests/tactics/army_probe.gd")
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	for team: int in factions:
		var built: Dictionary = army_probe.army(String(factions[team]), seed_value * 2 + team, credits, kind)
		if built.has("error"):
			push_error("trace: %s" % built["error"])
			quit(1)
			return
		var error := lab.game_match.load_doctrine(team, built["doctrine"])
		if error != "":
			push_error("trace load_doctrine: %s" % error)
			quit(1)
			return
	await lab.start()
	for team: int in factions:
		for squad in lab.game_match.team_squads(team):
			lab.elements.form(Array(squad.roster), String(squad.squad_name))
		ElementCommander.install(lab.game_match, team, lab.elements)
	var in_contact := {}
	var contacts := 0
	var by_pair_kind := {}
	var alive := [0, 0]
	for tick in int(float(_flag("seconds", "120")) * SimClock.TICK_RATE):
		await lab.step()
		var hulls: Array = []
		alive = [0, 0]
		for child in lab.game_match.tanks.get_children():
			var t := child as Tank
			if t != null and t.is_alive():
				hulls.append(t)
				alive[t.team] += 1
		for i in hulls.size():
			var a: Tank = hulls[i]
			for j in range(i + 1, hulls.size()):
				var b: Tank = hulls[j]
				if a.team != b.team:
					continue
				var dx := a.global_position.x - b.global_position.x
				var dz := a.global_position.z - b.global_position.z
				if dx * dx + dz * dz > NEAR_M * NEAR_M:
					in_contact.erase("%s|%s" % [a.name, b.name])
					continue
				var pair := "%s|%s" % [a.name, b.name]
				var touching := TrafficStage.box_gap(a, b) <= TrafficStage.CONTACT_GAP_M
				if touching and not in_contact.get(pair, false):
					contacts += 1
					var ea := _state(lab, a)
					var eb := _state(lab, b)
					var key := "%s/%s" % [ea["verb"] if ea["element"] != eb["element"] else "same:" + str(ea["verb"]),
							eb["verb"] if ea["element"] != eb["element"] else ""]
					by_pair_kind[key] = int(by_pair_kind.get(key, 0)) + 1
					print("CONTACT " + JSON.stringify({"tick": tick, "s": snappedf(tick / float(SimClock.TICK_RATE), 0.1),
							"a": String(a.name), "b": String(b.name), "team": a.team, "same_element": ea["element"] == eb["element"],
							"a_el": ea, "b_el": eb, "at": [snappedf(a.global_position.x, 0.1), snappedf(a.global_position.z, 0.1)],
							"fast": TrafficStage.closing_speed(a, b) > TrafficStage.FAST_CONTACT_MPS}))
				in_contact[pair] = touching
		if alive[0] == 0 or alive[1] == 0:
			break
	print("CONTACT_TRACE " + JSON.stringify({"arena": arena, "seed": seed_value, "contacts_friend": contacts,
			"halt_terrain": ElementSituation.HALT_TERRAIN, "by_kind": by_pair_kind}))
	quit(0)


func _state(lab: TacticsLab, t: Tank) -> Dictionary:
	var element: Element = lab.elements.of(String(t.name))
	if element == null:
		return {"element": "-", "verb": "-"}
	var members: Array = []
	var center := Vector3.ZERO
	for n: String in element.members():
		var m := lab.tank_of(n)
		if m != null and m.is_alive():
			center += Vector3(m.global_position.x, 0.0, m.global_position.z)
			members.append(n)
	if not members.is_empty():
		center /= members.size()
	var anchor: Variant = element.anchor
	return {"element": element.element_name, "verb": String(element.task.get("verb", "")), "arrived": element.arrived,
			"formation": element.formation, "drill": element.drill, "pitch": [snappedf(element.pitch.x, 0.1), snappedf(element.pitch.y, 0.1)],
			"terrain_centre": ElementSituation.terrain_at(center),
			"terrain_anchor": ElementSituation.terrain_at(anchor) if anchor is Vector3 else "-",
			"anchor": [snappedf((anchor as Vector3).x, 0.1), snappedf((anchor as Vector3).z, 0.1)] if anchor is Vector3 else null}
