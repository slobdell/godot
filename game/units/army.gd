class_name Army
extends RefCounted
## Budgeted armies: what an army costs, whether it fits a budget, and seeded CPU armies built from
## archetypes. An army IS a doctrine (army JSON v2: squads of units, see Doctrine), so everything that
## loads doctrines (skirmish, the match runner, the garage) can use them.
##
## CPU army names: "cpu" (a seeded random archetype) or "cpu:<archetype>" (see ARCHETYPES).

## Each archetype: the unit mix to buy, in purchase order (repeated while money lasts).
const ARCHETYPES := {
	"balanced": {"units": ["tank", "ifv", "scout", "artillery", "tank", "lancer", "ifv"]},
	"armor": {"units": ["tank", "tank", "lancer", "tank", "ifv"]},
	"recon_strike": {"units": ["scout", "ifv", "scout", "tank", "scout", "lancer"]},
	"siege": {"units": ["artillery", "scout", "tank", "artillery", "ifv", "scout"]},
	"swarm": {"units": ["scout", "scout", "ifv", "scout", "scout", "ifv"]},
}
## Squad name and directive per role. Squads are formed by role, in this order.
const SQUADS := {
	"tank": {"name": "Guns", "directive": {"role": "assault", "cohesion": 0.7}},
	"ifv": {"name": "Hunters", "directive": {"role": "assault"}},
	"lancer": {"name": "Lances", "directive": {"role": "support"}},
	"scout": {"name": "Eyes", "directive": {"role": "scout"}},
	"artillery": {"name": "Battery", "directive": {"role": "support"}},
}


static func is_cpu(name: String) -> bool:
	return name == "cpu" or name.begins_with("cpu:")


## Load an army by name: "cpu" / "cpu:<archetype>" (generated from `seed_value` and `budget`), a name in
## res://doctrines/, or a full path. Returns {"doctrine": Dictionary} or {"error": String}.
static func load_army(name_or_path: String, seed_value: int, budget: int = Units.DEFAULT_BUDGET) -> Dictionary:
	if is_cpu(name_or_path):
		var archetype := name_or_path.trim_prefix("cpu:")
		if name_or_path != "cpu" and not ARCHETYPES.has(archetype):
			return {"error": "no CPU army archetype '%s' (have %s)" % [archetype, ARCHETYPES.keys()]}
		return Doctrine.parse(cpu_army(name_or_path, seed_value, budget))
	var path := name_or_path if name_or_path.contains("://") else "res://doctrines/%s.json" % name_or_path
	return Doctrine.load_file(path)


## "" if the doctrine fits the budget, else why not.
static func check_budget(doctrine: Dictionary, budget: int) -> String:
	var cost := Units.army_cost(doctrine)
	if cost > budget:
		return "army costs %d, over the %d budget" % [cost, budget]
	return ""


## A seeded CPU army. `name` is "cpu" or "cpu:<archetype>". Deterministic for a given seed and budget.
static func cpu_army(name: String, seed_value: int, budget: int = Units.DEFAULT_BUDGET) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var archetypes := ARCHETYPES.keys()
	archetypes.sort()
	var archetype := name.trim_prefix("cpu:") if name.begins_with("cpu:") else String(archetypes[rng.randi_range(0, archetypes.size() - 1)])
	if not ARCHETYPES.has(archetype):
		archetype = "balanced"
	var order: Array = ARCHETYPES[archetype]["units"]
	var cheapest := INF
	for unit_id: String in order:
		cheapest = minf(cheapest, Units.cost_of({"unit": unit_id}))
	var entries: Array = []
	var spent := 0
	# Cycle through the purchase order until the budget or the army cap runs out; a seeded rotation of
	# the starting point varies armies of one archetype.
	var start := rng.randi_range(0, order.size() - 1)
	for step in order.size() * Doctrine.MAX_UNITS:
		if entries.size() >= Doctrine.MAX_UNITS or spent + cheapest > budget:
			break
		var entry := {"unit": String(order[(start + step) % order.size()])}
		var cost := Units.cost_of(entry)
		if spent + cost > budget:
			continue
		entries.append(entry)
		spent += cost
	return {"name": "CPU %s" % archetype.capitalize(), "archetype": archetype, "cost": spent, "squads": squads_for(entries)}


## Group entries into at most Doctrine.MAX_SQUADS squads of Doctrine.MAX_SQUAD_UNITS, by role (Guns,
## Guns2, ...). When roles need more squads than allowed, the extra units join squads that have room.
static func squads_for(entries: Array) -> Array:
	var by_role := {}
	for entry: Dictionary in entries:
		var role := Units.role_of(entry["unit"])
		if not by_role.has(role):
			by_role[role] = []
		by_role[role].append(entry)
	var squads: Array = []
	for role: String in SQUADS:
		var members: Array = by_role.get(role, [])
		var index := 0
		while index < members.size():
			var template: Dictionary = SQUADS[role]
			var number := index / Doctrine.MAX_SQUAD_UNITS + 1
			squads.append({"name": template["name"] + ("" if number == 1 else str(number)),
					"directive": template["directive"].duplicate(), "units": members.slice(index, index + Doctrine.MAX_SQUAD_UNITS)})
			index += Doctrine.MAX_SQUAD_UNITS
	# Too many squads: fold the smallest ones into squads with room (≤ 25 units always fit 5 × 5).
	while squads.size() > Doctrine.MAX_SQUADS:
		var smallest := 0
		for i in squads.size():
			if squads[i]["units"].size() < squads[smallest]["units"].size():
				smallest = i
		var homeless: Array = squads.pop_at(smallest)["units"]
		for squad: Dictionary in squads:
			while not homeless.is_empty() and squad["units"].size() < Doctrine.MAX_SQUAD_UNITS:
				squad["units"].append(homeless.pop_front())
	return squads


## "3 tanks, 1 scout, 1 artillery (930 pts)"
static func describe(doctrine: Dictionary) -> String:
	var counts := {}
	for item in Doctrine.entries(doctrine):
		var unit_id: String = item["entry"].get("unit", "")
		counts[unit_id] = int(counts.get(unit_id, 0)) + 1
	var parts: PackedStringArray = []
	for unit_id in Units.ids():
		if counts.has(unit_id):
			var label := String(Units.PROFILES[unit_id]["display_name"]).to_lower() if unit_id != "ifv" else "IFV"
			var plural: bool = counts[unit_id] != 1 and unit_id != "artillery"
			parts.append("%d %s%s" % [counts[unit_id], label, "s" if plural else ""])
	return "%s (%d pts)" % [", ".join(parts), Units.army_cost(doctrine)]
