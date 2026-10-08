extends SceneTree
## Round 22 (brains B2; orders' request): TEN SQUADS AT THE START. Orders measured on the merged tip (foundry, builder0)
## that ArmyLayout stands ten squads in two rows that OVERLAP front to back, so his first Ctrl+A finds 6-10 of 10 squads
## interleaved. This deploys a full army of ten squads of five on every arena, both teams, and reports, in each team's
## own frame (across, along), every squad's footprint (its hulls' boxes) and the pairs whose footprints overlap.
##
##   godot --headless --path . --script res://tests/tactics/layout_probe.gd -- --arenas=foundry,parade --factions=gangs,law
##   LAYOUT_PROBE {"arena", "faction", "team", "squads", "overlaps": [[a, b, across_m, along_m]] (squads' FOOTPRINTS, the
##                 boxes round their hulls: a measure, not a defect), "hull_overlaps": [[a, b, across_m, along_m]] (two
##                 vehicles on top of each other: a defect)}
##   LAYOUT_PROBE_DONE {"runs", "overlapping_runs", "pairs", "hull_overlaps"}
## The orchestrator's ruling (2026-10-07): the spawn stays two rows of five; orders' untangle deals the first order.

var case: TestCase


func _initialize() -> void:
	_run.call_deferred()


func _flag(name: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if String(arg).begins_with("--%s=" % name):
			return String(arg).split("=", true, 1)[1]
	return fallback


func _run() -> void:
	var arenas: Array = Array(_flag("arenas", ",".join(PackedStringArray(Arena.ROTATION + ["foundry"]))).split(","))
	var factions: Array = Array(_flag("factions", "gangs,condemned,law,syndicate").split(","))
	var runs := 0
	var overlapping := 0
	var pairs := 0
	var hulls := 0
	for arena: String in arenas:
		for faction: String in factions:
			case = TestCase.new()
			case.tree = self
			var lab := TacticsLab.create(case, 1, arena)
			# As the skirmish does: the armies load (and ArmyLayout deploys, by tick DEPLOY_BY_TICK) before the navmesh.
			for team in [Match.Team.GREEN, Match.Team.RUST]:
				var built := LayoutCheck.full_army(faction, 1 + team)
				var error := lab.game_match.load_doctrine(team, built["doctrine"])
				if error != "":
					push_error("load_doctrine %s %s: %s" % [arena, faction, error])
			await lab.start()
			for team in [Match.Team.GREEN, Match.Team.RUST]:
				var report := LayoutCheck.footprints(lab.game_match, team)
				report["arena"] = arena
				report["faction"] = faction
				report["hull_overlaps"] = LayoutCheck.hull_overlaps(lab.game_match, team)
				hulls += (report["hull_overlaps"] as Array).size()
				report.erase("boxes")
				print("LAYOUT_PROBE " + JSON.stringify(report))
				runs += 1
				if not (report["overlaps"] as Array).is_empty():
					overlapping += 1
					pairs += (report["overlaps"] as Array).size()
			lab.dispose()
			case.teardown()
	print("LAYOUT_PROBE_DONE " + JSON.stringify({"runs": runs, "overlapping_runs": overlapping, "pairs": pairs, "hull_overlaps": hulls}))
	quit(0)
