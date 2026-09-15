class_name MatchReport
extends Node
## What happened in a finished match, in the shape progression and the results screen need (contract C3):
##   {"key", "winner", "reason", "duration_seconds", "budget", "tier",
##    "teams": {"green"|"rust": {"units": {unit: n}, "units_left", "units_lost", "kills",
##              "kills_by_unit": {killer's unit: n}, "losses_by_unit": {unit: n}}},
##    "best_unit": {"name", "unit", "team", "kills", "alive"} or {}}
##
## Add it under the Match before the fight: it listens to `tank_destroyed` to credit kills to tanks. When the
## match ends, build() reads the C3 fields the rules stream adds to `Match.result()` where they exist, and
## counts the rest from the tanks themselves.

## Tank name → unit id, for vehicles whose Tank.unit_id isn't the army's unit (until checkpoint 1 an IFV
## fights as a v1 stand-in chassis). Filled by names_for().
var unit_names := {}
var _kills := {}
var _game_match: Match


func watch(game_match: Match) -> void:
	_game_match = game_match
	game_match.tank_destroyed.connect(_on_tank_destroyed)


func _on_tank_destroyed(_victim: Tank, killer: String) -> void:
	if killer != "":
		_kills[killer] = int(_kills.get(killer, 0)) + 1


## Match's tank names for an army ("Green_Alpha_1" is Alpha's first unit) → the army's unit ids.
static func names_for(team_name: String, army: Dictionary) -> Dictionary:
	var names := {}
	for squad: Dictionary in army.get("squads", []):
		var entries: Array = squad.get("units", squad.get("tanks", []))
		for index in entries.size():
			names["%s_%s_%d" % [team_name, squad.get("name", ""), index + 1]] = String(entries[index].get("unit", "tank"))
	return names


func unit_of(tank: Tank) -> String:
	return String(unit_names.get(String(tank.name), tank.unit_id))


## The report for `result` (Match.finished's dictionary).
func build(result: Dictionary, budget: int, tier: int) -> Dictionary:
	var report := {"key": "%s@%s" % [result.get("state_hash", ""), result.get("tick", 0)],
			"winner": String(result.get("winner", "draw")), "reason": String(result.get("reason", "")),
			"duration_seconds": float(result.get("duration_seconds", result.get("sim_seconds", 0.0))),
			"budget": int(result.get("budget", budget)), "tier": tier, "teams": {}, "best_unit": {}}
	var best := {}
	for team in [Match.Team.GREEN, Match.Team.RUST]:
		var key := String(Match.TEAM_NAMES[team]).to_lower()
		var summary := {"units": {}, "units_left": 0, "units_lost": 0, "kills": 0, "kills_by_unit": {}, "losses_by_unit": {}}
		for tank in (_game_match.team_tanks(team) if _game_match != null else []):
			var unit_id := unit_of(tank)
			summary["units"][unit_id] = int(summary["units"].get(unit_id, 0)) + 1
			var kills := int(_kills.get(String(tank.name), 0))
			summary["kills"] += kills
			if kills > 0:
				summary["kills_by_unit"][unit_id] = int(summary["kills_by_unit"].get(unit_id, 0)) + kills
			if tank.is_alive():
				summary["units_left"] += 1
			else:
				summary["units_lost"] += 1
				summary["losses_by_unit"][unit_id] = int(summary["losses_by_unit"].get(unit_id, 0)) + 1
			# Best unit: most kills; ties go to a survivor, then the tank name (stable).
			var candidate := {"name": String(tank.name), "unit": unit_id, "team": Match.TEAM_NAMES[team], "kills": kills, "alive": tank.is_alive()}
			if kills > 0 and (best.is_empty() or kills > best["kills"] or (kills == best["kills"] and tank.is_alive() and not best["alive"])):
				best = candidate
		# Prefer the rules stream's C3 fields when Match.result() carries them.
		for field in ["units_left", "units_lost"]:
			if typeof(result.get(field)) == TYPE_DICTIONARY and result[field].has(key):
				summary[field] = int(result[field][key])
		if typeof(result.get("kills")) == TYPE_DICTIONARY and result["kills"].has(key):
			summary["kills"] = int(result["kills"][key])
		report["teams"][key] = summary
	report["best_unit"] = best
	return report


## "2 Tanks, 1 Scout" from {unit: n}, using the catalog's names.
static func describe_units(counts: Dictionary, catalog: ArmyCatalog) -> String:
	var parts: PackedStringArray = []
	var ids: Array = counts.keys()
	ids.sort_custom(func(a: String, b: String) -> bool: return int(counts[a]) > int(counts[b]) if counts[a] != counts[b] else a < b)
	for unit_id: String in ids:
		var unit_name := catalog.display_name(unit_id) if catalog.has_unit(unit_id) else unit_id.capitalize()
		parts.append("%d %s" % [counts[unit_id], unit_name if int(counts[unit_id]) == 1 else GarageAdvice._pluralize(unit_name)])
	return ", ".join(parts) if not parts.is_empty() else "nothing"
