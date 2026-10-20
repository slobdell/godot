extends SceneTree
## Round 35 (orders D1, C35.2): THE DEPLOY-STEP FIGHTS CENSUS. The deploy step reaches CPU elements too (any plain move
## with no chosen formation or told facing), so its ship check carries one REPORTED census of CPU-v-CPU fights (both sides
## under the computer's squad leaders, set up as traffic's census_probe does) on a fixed arena: per side the deaths, the
## kills, and the stuck crew-seconds (a crew whose mover is under way and that has not moved STILL_MPS in the last second),
## plus how many squads deployed. Run once per arm (`--deploy-step=off` is the off arm) and pair by seed.
##
##   godot --headless --fixed-fps 30 --path . --script res://tests/control/deploy_census.gd -- --arena=locks --seed=3501
##         --green=law --rust=gangs --credits=1000 --seconds=150 [--deploy-step=off]
##   DEPLOY_CENSUS {"arena", "seed", "arm", "green", "rust", "units", "ended_s", "sides": [{deaths, kills, stuck_s,
##                  alive, deploys}, {...}]}

const STILL_MPS := 0.5

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
	var arena := _flag("arena", "locks")
	var credits := int(_flag("credits", "1000"))
	var factions := {Match.Team.GREEN: _flag("green", "law"), Match.Team.RUST: _flag("rust", "gangs")}
	var army_probe: GDScript = load("res://tests/tactics/army_probe.gd")
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	var units := [0, 0]
	for team: int in factions:
		var built: Dictionary = army_probe.army(String(factions[team]), seed_value * 2 + team, credits, "opponent")
		if built.has("error"):
			push_error("deploy census: %s" % built["error"])
			quit(1)
			return
		var doctrine: Dictionary = built["doctrine"]
		for squad: Dictionary in doctrine["squads"]:
			units[team] += (squad["units"] as Array).size()
		var error := lab.game_match.load_doctrine(team, doctrine)
		if error != "":
			push_error("deploy census load_doctrine: %s" % error)
			quit(1)
			return
	await lab.start()
	for team: int in factions:
		for squad in lab.game_match.team_squads(team):
			lab.elements.form(Array(squad.roster), String(squad.squad_name))
		ElementCommander.install(lab.game_match, team, lab.elements)
	var sides := [{"deaths": 0, "kills": 0, "stuck": 0, "alive": 0, "deploys": 0},
			{"deaths": 0, "kills": 0, "stuck": 0, "alive": 0, "deploys": 0}]
	lab.game_match.unit_destroyed.connect(func(event: Dictionary) -> void:
		var team := int(event.get("team", -1))
		if team == 0 or team == 1:
			sides[team]["deaths"] += 1
		var killer := lab.tank_of(String(event.get("killer", "")))
		if killer != null and String(event.get("cause", "")) == "enemy":
			sides[killer.team]["kills"] += 1)
	var trails := {}
	var deployed := {}  # element id -> deployed last tick
	var ended := -1
	for tick in int(float(_flag("seconds", "150")) * SimClock.TICK_RATE):
		await lab.step()
		var alive := [0, 0]
		for child in lab.game_match.tanks.get_children():
			var t := child as Tank
			if t == null or not t.is_alive():
				continue
			alive[t.team] += 1
			var key := String(t.name)
			var trail: PackedVector3Array = trails.get(key, PackedVector3Array())
			var here := Vector3(t.global_position.x, 0.0, t.global_position.z)
			trail.append(here)
			if trail.size() > SimClock.TICK_RATE + 1:
				trail.remove_at(0)
			trails[key] = trail
			var mover := Movement.of(t)
			if mover == null or not mover.is_under_way():
				continue
			if trail.size() > SimClock.TICK_RATE and trail[0].distance_to(here) < STILL_MPS:
				sides[t.team]["stuck"] += 1
		for element: Element in lab.elements.all():
			if _flag("trace", "") == "on" and tick % (SimClock.TICK_RATE * 5) == 0:
				print("DEPLOY_TRACE t=%d %s team %d verb %s drills %s formation %s arrived %s deploy %s" % [tick / SimClock.TICK_RATE,
						element.element_name, element.team, str(element.task.get("verb", "")), str(element.task.get("drills", "-")),
						str(element.task.get("formation", "-")), str(element.arrived), str(element.deploy)])
			var now := bool(element.deploy.get("deployed", false))
			if now and not bool(deployed.get(element.id, false)) and (element.team == 0 or element.team == 1):
				sides[element.team]["deploys"] += 1
			deployed[element.id] = now
		if alive[0] == 0 or alive[1] == 0:
			ended = tick
			sides[0]["alive"] = alive[0]
			sides[1]["alive"] = alive[1]
			break
		sides[0]["alive"] = alive[0]
		sides[1]["alive"] = alive[1]
	for side: Dictionary in sides:
		side["stuck_s"] = snappedf(float(side["stuck"]) / SimClock.TICK_RATE, 0.1)
		side.erase("stuck")
	print("DEPLOY_CENSUS " + JSON.stringify({"arena": arena, "seed": seed_value, "arm": "on" if ElementPlan.DEPLOY_STEP else "off",
			"green": factions[0], "rust": factions[1], "credits": credits, "units": units,
			"ended_s": snappedf(ended / float(SimClock.TICK_RATE), 0.1) if ended >= 0 else -1.0, "sides": sides}))
	lab.dispose()
	case.teardown()
	quit(0)
