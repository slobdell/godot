extends SceneTree
## Control X4 (round 6): what spawning an army costs, per vehicle. FIGHT → playable was ~6-8 s on the laptop at 30 a
## side and almost all of it was vehicles being spawned; this separates the first vehicle of each type (loading) from
## the rest (per-instance work). `make spawn-cost` (SPAWN_THEME=default for the placeholder boxes, to compare against).
## Headless: it measures CPU work, not drawing.

func _initialize() -> void:
	var arena: Node = load("res://game/arena/arena.tscn").instantiate()
	root.add_child(arena)
	var game_match: Node = load("res://game/match/match.tscn").instantiate()
	root.add_child(game_match)
	await process_frame
	for faction in ["gangs", "law"]:
		var loaded: Dictionary = Army.load_army("cpu", 3, Units.BASELINE_BUDGET, faction)
		var team: int = Match.Team.GREEN if faction == "gangs" else Match.Team.RUST
		var seen := {}
		var firsts := 0.0
		var rest := 0.0
		var n := 0
		for squad in loaded["doctrine"]["squads"]:
			var i := 0
			for entry in squad["units"]:
				i += 1
				var t0 := Time.get_ticks_usec()
				game_match.spawn_tank("%s_%s_%d" % [faction, squad["name"], i], 0, team, String(entry["unit"]), "")
				var ms := (Time.get_ticks_usec() - t0) / 1000.0
				n += 1
				if seen.has(entry["unit"]):
					rest += ms
				else:
					seen[entry["unit"]] = snappedf(ms, 0.1)
					firsts += ms
		print("SPAWN_COST %s vehicles=%d types=%d first_of_each_ms=%.0f %s rest=%d rest_ms=%.0f per_vehicle_ms=%.1f" % [faction, n,
				seen.size(), firsts, seen, n - seen.size(), rest, rest / maxf(n - seen.size(), 1)])
	quit()
