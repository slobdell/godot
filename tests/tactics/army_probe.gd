extends SceneTree
## Round 22 (brains B2): THE COMMANDER AT TEN SQUADS A SIDE. A CPU-v-CPU fight of two garage-sized armies at 2000 credits
## (ten squads of five, 50 vehicles; army's CP1), both run by the computer's squad leaders (ElementCommander), on a map
## he plays, to a result. What it checks every second: elements per side (<= 10), members per element (<= 5), every
## vehicle inside the arena; and at the start, ArmyLayout's deployment inside the arena and clear of the other army.
##
##   godot --headless --path . --script res://tests/tactics/army_probe.gd -- --arena=parade --seed=1
##         --green=law --rust=syndicate --credits=2000 --seconds=240 --trace=on
##         --army=opponent (the garage's opponent at --credits) | full (ten squads of five of the faction's roster)
##   ARMY_PROBE {"arena", "seed", "army", "green", "rust", "credits", "units": [g, r], "squads": [g, r], "elements_max": [g, r],
##               "members_max", "outside" (vehicle-seconds outside the arena), "deployed_outside", "alive": [g, r],
##               "winner", "ended_s", "postures": {team: [postures seen]}, "tasks": {verb: count}, "ms_per_tick"}


var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


## The garage's opponent at `credits` (GarageOpponent: army's CP1 buys up to ten squads of five), or a FULL army.
static func army(faction: String, seed_value: int, credits: int, kind := "opponent") -> Dictionary:
	if kind == "full":
		return full_army(faction, seed_value)
	return GarageOpponent.build("cpu", faction, seed_value, credits)


## Ten squads of five, every one full (LayoutCheck.full_army: the stress case).
static func full_army(faction: String, seed_value: int) -> Dictionary:
	return LayoutCheck.full_army(faction, seed_value)


func _run() -> void:
	case = TestCase.new()
	case.tree = self
	var seed_value := int(_flag("seed", "1"))
	var arena := _flag("arena", "parade")
	var credits := int(_flag("credits", "2000"))
	var kind := _flag("army", "opponent")
	var factions := {Match.Team.GREEN: _flag("green", "law"), Match.Team.RUST: _flag("rust", "syndicate")}
	var trace := _flag("trace", "off") == "on"
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	# As the skirmish does: the armies load, and ArmyLayout deploys them (by tick DEPLOY_BY_TICK), before the navmesh is
	# ready; ArmyLayout then checks the hulls against the layout's own obstacle boxes.
	var units := [0, 0]
	var squads := [0, 0]
	for team: int in factions:
		var built := army(String(factions[team]), seed_value * 2 + team, credits, kind)
		if built.has("error"):
			push_error("army: %s" % built["error"])
			quit(1)
			return
		var doctrine: Dictionary = built["doctrine"]
		squads[team] = (doctrine["squads"] as Array).size()
		for squad: Dictionary in doctrine["squads"]:
			units[team] += (squad["units"] as Array).size()
		var error := lab.game_match.load_doctrine(team, doctrine)
		if error != "":
			push_error("load_doctrine: %s" % error)
			quit(1)
			return
	await lab.start()
	var deployed_outside := _outside(lab)
	for team: int in factions:
		for squad in lab.game_match.team_squads(team):
			lab.elements.form(Array(squad.roster), String(squad.squad_name))
		ElementCommander.install(lab.game_match, team, lab.elements)
	var elements_max := [0, 0]
	var members_max := 0
	var outside := 0
	var postures := {Match.Team.GREEN: [], Match.Team.RUST: []}
	var tasks := {}
	var ended := -1
	var started_us := Time.get_ticks_usec()
	var ticks := 0
	for tick in int(float(_flag("seconds", "240")) * SimClock.TICK_RATE):
		await lab.step()
		ticks += 1
		if tick % SimClock.TICK_RATE != 0:
			continue
		outside += _outside(lab)
		var alive := [0, 0]
		for team: int in factions:
			var mine: Array = lab.elements.of_team(team)
			elements_max[team] = maxi(elements_max[team], mine.size())
			for element: Element in mine:
				members_max = maxi(members_max, element.members().size())
				var verb := String(element.task.get("verb", "-"))
				tasks[verb] = int(tasks.get(verb, 0)) + 1
			var commander := _commander(lab, team)
			if commander != null and not (postures[team] as Array).has(String(commander.posture.get("posture", ""))):
				(postures[team] as Array).append(String(commander.posture.get("posture", "")))
			for tank: Tank in lab.game_match.sorted_team_tanks(team):
				if tank.is_alive():
					alive[team] += 1
		if trace and tick % (SimClock.TICK_RATE * 10) == 0:
			print("ARMY_TRACE t=%ds alive %d v %d elements %d v %d" % [tick / SimClock.TICK_RATE, alive[0], alive[1],
					lab.elements.of_team(0).size(), lab.elements.of_team(1).size()])
		if alive[0] == 0 or alive[1] == 0:
			ended = tick
			break
	var elapsed_ms := (Time.get_ticks_usec() - started_us) / 1000.0
	var alive_end := [0, 0]
	for team: int in factions:
		for tank: Tank in lab.game_match.sorted_team_tanks(team):
			if tank.is_alive():
				alive_end[team] += 1
	var winner := "none"
	if alive_end[0] > 0 and alive_end[1] == 0:
		winner = "green"
	elif alive_end[1] > 0 and alive_end[0] == 0:
		winner = "rust"
	var report := {"arena": arena, "seed": seed_value, "army": kind, "green": factions[0], "rust": factions[1], "credits": credits,
			"units": units, "squads": squads, "elements_max": elements_max, "members_max": members_max,
			"outside": outside, "deployed_outside": deployed_outside, "alive": alive_end, "winner": winner,
			"ended_s": snappedf(ended / float(SimClock.TICK_RATE), 0.1) if ended >= 0 else -1.0,
			"postures": postures, "tasks": tasks, "score": lab.game_match.control_score,
			"ms_per_tick": snappedf(elapsed_ms / maxf(ticks, 1), 0.01)}
	print("ARMY_PROBE " + JSON.stringify(report))
	lab.dispose()
	case.teardown()
	quit(0)


## How many living vehicles stand outside the arena's WALL (more than 1 m past its polygon; Orders.clamp_to_arena is the
## polygon inset by a clearance, so a vehicle along the wall is inside it and outside that).
func _outside(lab: TacticsLab) -> int:
	var data: Dictionary = Arena.active
	var kind := String((data.get("shape", {}) as Dictionary).get("kind", ArenaShape.DEFAULT_KIND))
	var bound := float(data.get("half_size", Match.ARENA_HALF_SIZE))
	var count := 0
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		for tank: Tank in lab.game_match.sorted_team_tanks(team):
			if not tank.is_alive():
				continue
			var flat := Vector2(tank.global_position.x, tank.global_position.z)
			if ArenaShape.clamp_into(kind, bound, flat).distance_to(flat) > 1.0:
				count += 1
	return count


func _commander(lab: TacticsLab, team: int) -> ElementCommander:
	for child in lab.game_match.get_children():
		if child is ElementCommander and (child as ElementCommander).team == team:
			return child
	return null
