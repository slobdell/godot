class_name Army
extends RefCounted
## Budgeted armies (directive set 2): what an army costs, whether it fits a budget, and seeded CPU
## armies built from archetypes. An army IS a doctrine (squads of loadouts), so everything that loads
## doctrines (skirmish, the match runner, the garage) can use them.
##
## CPU army names: "cpu" (a seeded random archetype) or "cpu:<archetype>" (see ARCHETYPES).

## Each archetype: the unit mix to buy, in order, and how to arm it. The generator buys the list until
## the budget runs out, then spends what's left on components.
##   units: [unit id, ...] purchase order (repeated while money lasts)    lasers: chance a tank or scout takes a laser
const ARCHETYPES := {
	"balanced": {"units": ["tank", "tank", "scout", "artillery", "tank", "scout", "tank"], "lasers": 0.3},
	"armor": {"units": ["tank", "tank", "tank", "tank", "tank", "tank"], "lasers": 0.4},
	"recon_strike": {"units": ["scout", "tank", "scout", "tank", "scout", "tank", "scout"], "lasers": 0.6},
	"siege": {"units": ["artillery", "scout", "tank", "artillery", "tank", "scout", "tank"], "lasers": 0.2},
	"swarm": {"units": ["scout", "scout", "scout", "scout", "scout", "scout", "scout", "scout", "scout"], "lasers": 0.4},
}
## Squad names by unit class, and the directive each class's squad gets.
const SQUADS := {
	"tank": {"name": "Guns", "directive": {"role": "assault", "cohesion": 0.7}, "formation": "wedge"},
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
	var plan: Dictionary = ARCHETYPES[archetype]
	var entries: Array = []
	var spent := 0
	var order: Array = plan["units"]
	var cheapest := INF
	for unit_id: String in order:
		cheapest = minf(cheapest, Units.cost_of({"unit": unit_id}))
	# Cycle through the purchase order until the budget or the army cap runs out.
	for step in order.size() * 4:
		if entries.size() >= Doctrine.MAX_TANKS or spent + cheapest > budget:
			break
		var unit_id: String = order[step % order.size()]
		var entry := {"unit": unit_id}
		var accepts: Array = Units.PROFILES[unit_id]["hardpoints"][0]["accepts"]
		if accepts.has("laser") and rng.randf() < float(plan["lasers"]):
			entry["weapon"] = "laser"
		else:
			entry["weapon"] = accepts[0]
		var cost := Units.cost_of(entry)
		if spent + cost > budget:
			continue
		entries.append(entry)
		spent += cost
	# Leftover points: components where they matter most (heat sinks on lasers first, then shields,
	# then ammo racks on cannons), cheapest useful upgrade first, one pass per slot.
	for pass_index in 2:
		for entry: Dictionary in entries:
			var slots := int(Units.PROFILES[entry["unit"]]["component_slots"])
			var fitted: Array = entry.get("components", [])
			if fitted.size() > pass_index or fitted.size() >= slots:
				continue
			var wish := "shield_booster"
			if entry["weapon"] == "laser" and not fitted.has("heat_sink"):
				wish = "heat_sink"
			elif entry["weapon"] in ["cannon", "mortar"] and not fitted.has("ammo_rack") and pass_index == 1:
				wish = "ammo_rack"
			elif fitted.has("shield_booster"):
				wish = "armor_plating"
			var price := int(Units.COMPONENTS[wish]["cost"])
			if spent + price <= budget:
				fitted.append(wish)
				entry["components"] = fitted
				spent += price
	return {"name": "CPU %s" % archetype.capitalize(), "archetype": archetype, "cost": spent, "squads": _squads_for(entries)}


## Group entries into squads by class, at most Formations.MAX_MEMBERS each (Guns, Guns2, ...).
static func _squads_for(entries: Array) -> Array:
	var by_class := {}
	for entry: Dictionary in entries:
		var unit_class: String = Units.PROFILES[entry["unit"]]["class"]
		if not by_class.has(unit_class):
			by_class[unit_class] = []
		by_class[unit_class].append(entry)
	var squads: Array = []
	for unit_class in ["tank", "scout", "artillery"]:
		var members: Array = by_class.get(unit_class, [])
		var index := 0
		while index < members.size():
			var template: Dictionary = SQUADS[unit_class]
			var squad := {"name": template["name"] + ("" if index == 0 else str(index / Formations.MAX_MEMBERS + 1)),
					"directive": template["directive"].duplicate(), "tanks": members.slice(index, index + Formations.MAX_MEMBERS)}
			squads.append(squad)
			index += Formations.MAX_MEMBERS
	return squads.slice(0, Doctrine.MAX_SQUADS)


## "3 tanks, 1 scout, 1 artillery (980 pts)"
static func describe(doctrine: Dictionary) -> String:
	var counts := {}
	for squad in doctrine.get("squads", []):
		for entry in squad.get("tanks", []):
			var unit_id: String = entry.get("unit", "tank")
			counts[unit_id] = int(counts.get(unit_id, 0)) + 1
	var parts: PackedStringArray = []
	for unit_id in ["tank", "scout", "artillery"]:
		if counts.has(unit_id):
			parts.append("%d %s%s" % [counts[unit_id], unit_id, "" if counts[unit_id] == 1 or unit_id == "artillery" else "s"])
	return "%s (%d pts)" % [", ".join(parts), Units.army_cost(doctrine)]
