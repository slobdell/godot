extends SceneTree
## Round 27 (scout, C27.4): the gun-lay planner's cost a tick at ~25 a side on Sumps. A CPU v CPU fight set up as
## traffic's census does (both sides under the computer's squad leaders; two factions that field fixed guns), and over
## the window [--from, --seconds] the summed thread time of CombatMotion.plan_lay a tick (`lay_timing`, measurement only),
## the plans made and the fixed guns alive.
##
##   godot --headless --fixed-fps 60 --path . --script res://tests/scout/scout_cost.gd -- --arena=sumps --seed=1
##         --green=condemned --rust=gangs --credits=1000 --from=8 --seconds=60
##   SCOUT_COST {"arena", "seed", "units", "ticks", "lay_ms_per_tick", "plans", "plans_per_tick", "us_per_plan", "fixed_alive_mean"}

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
	var factions := {Match.Team.GREEN: _flag("green", "condemned"), Match.Team.RUST: _flag("rust", "gangs")}
	var army_probe: GDScript = load("res://tests/tactics/army_probe.gd")
	var lab := TacticsLab.create(case, seed_value, arena)
	lab.game_match.control_point = true
	lab.game_match.load_objectives()
	var units := [0, 0]
	for team: int in factions:
		var built: Dictionary = army_probe.army(String(factions[team]), seed_value * 2 + team, credits, "opponent")
		var doctrine: Dictionary = built["doctrine"]
		for squad: Dictionary in doctrine["squads"]:
			units[team] += (squad["units"] as Array).size()
		lab.game_match.load_doctrine(team, doctrine)
	await lab.start()
	for team: int in factions:
		for squad in lab.game_match.team_squads(team):
			lab.elements.form(Array(squad.roster), String(squad.squad_name))
		ElementCommander.install(lab.game_match, team, lab.elements)
	var from_ticks := int(float(_flag("from", "8")) * SimClock.TICK_RATE)
	var to_ticks := int(float(_flag("seconds", "60")) * SimClock.TICK_RATE)
	var ticks := 0
	var fixed_sum := 0
	var plans_from := 0
	for tick in to_ticks:
		if tick == from_ticks:
			CombatMotion.lay_timing = true
			CombatMotion.lay_usec = 0
			plans_from = CombatMotion.lay_plans
		await lab.step()
		if tick < from_ticks:
			continue
		ticks += 1
		for child in lab.game_match.tanks.get_children():
			var t := child as Tank
			if t != null and t.is_alive() and t.mount == "fixed":
				fixed_sum += 1
	CombatMotion.lay_timing = false
	var plans := CombatMotion.lay_plans - plans_from
	print("SCOUT_COST " + JSON.stringify({"arena": arena, "seed": seed_value, "units": units, "ticks": ticks,
			"lay_ms_per_tick": CombatMotion.lay_usec / 1000.0 / maxi(ticks, 1), "plans": plans,
			"plans_per_tick": float(plans) / maxi(ticks, 1), "us_per_plan": float(CombatMotion.lay_usec) / maxi(plans, 1),
			"fixed_alive_mean": float(fixed_sum) / maxi(ticks, 1)}))
	quit(0)
