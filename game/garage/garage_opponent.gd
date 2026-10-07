class_name GarageOpponent
extends RefCounted
## Round 19 (garage, G1): the CPU army the garage fights. Same money, same rules as the player: a faction, the game's
## credits (2000 since round 22), at most ten squads of at most five vehicles (ArmyCatalog.MAX_SQUADS x MAX_SQUAD_SIZE). "Matches are
## fought at a shared budget tier" (the lead, 2026-09-15) means the same rules too.
## Round 20 (R1): it buys in CREDITS at the player's prices (Credits.of_unit, rounded up), not in points, so the two
## sides are charged the same number for the same vehicle and its army always fits the fight's points.
##
## It buys like `Army.cpu_army` (an archetype's purchase order, a seeded starting point, skip what no longer fits)
## from the faction's own archetypes, and folds the vehicles into five squads with `Army.squads_for`. Pure and seeded:
## the same (spec, faction, seed) is the same army, so a REMATCH meets it again. The baselines never come through here.

const UNIT_CAP := ArmyCatalog.MAX_UNITS


## The army for `spec` ("cpu" = a seeded archetype of `faction`, "cpu:<archetype>" = that one, when it is the
## faction's) at `credits`. {"doctrine": Dictionary} or {"error": String}.
static func build(spec: String, faction: String, seed_value: int, credits: int = Credits.GAME_CREDITS) -> Dictionary:
	if not Units.FACTIONS.has(faction):
		return {"error": "no faction '%s'" % faction}
	var archetypes: Array = Array(Army.archetypes_for(faction))
	if archetypes.is_empty():
		return {"error": "faction '%s' has no armies" % faction}
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var archetype := spec.trim_prefix("cpu:") if spec.begins_with("cpu:") else ""
	if not archetypes.has(archetype):
		# A named archetype of another faction (ENEMY=cpu:siege against a Law pick) is read as "any of this faction's".
		archetype = String(archetypes[rng.randi_range(0, archetypes.size() - 1)])
	var order: Array = Army.ARCHETYPES[archetype]["units"]
	var cheapest := INF
	for unit_id: String in order:
		cheapest = minf(cheapest, Credits.of_unit(unit_id))
	var entries: Array = []
	var spent := 0
	var start := rng.randi_range(0, order.size() - 1)
	for step in order.size() * UNIT_CAP:
		if entries.size() >= UNIT_CAP or spent + cheapest > credits:
			break
		var entry := {"unit": String(order[(start + step) % order.size()])}
		var cost := Credits.of_unit(String(entry["unit"]))
		if spent + cost > credits:
			continue
		entries.append(entry)
		spent += cost
	# "cost" stays in points (what the skirmish's loader reads); `spent` was the credits.
	var doctrine := {"name": "CPU %s" % archetype.capitalize(), "archetype": archetype, "faction": faction,
			"cost": Units.army_cost({"squads": [{"units": entries}]}),
			"squads": GarageOpponent.fold(Army.squads_for(entries), ArmyCatalog.MAX_SQUADS)}
	var parsed := Doctrine.parse(doctrine)
	if parsed.has("error"):
		return parsed
	return {"doctrine": doctrine}


## Fold `squads` (Army's role squads: Guns, Guns2, Eyes, ...) into at most `max_squads`, the smallest joining squads with
## room, the way Army.squads_for folds into Doctrine.MAX_SQUADS (12 since round 4; the player's cap is five).
## A full army always fits: ArmyCatalog.MAX_UNITS vehicles are MAX_SQUADS squads of five.
static func fold(squads: Array, max_squads: int) -> Array:
	var result := squads.duplicate(true)
	while result.size() > max_squads:
		var smallest := 0
		for i in result.size():
			if (result[i]["units"] as Array).size() < (result[smallest]["units"] as Array).size():
				smallest = i
		var homeless: Array = result.pop_at(smallest)["units"]
		for squad: Dictionary in result:
			while not homeless.is_empty() and (squad["units"] as Array).size() < ArmyCatalog.MAX_SQUAD_SIZE:
				(squad["units"] as Array).append(homeless.pop_front())
	return result
