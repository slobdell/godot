class_name Army
extends RefCounted
## Budgeted armies: what an army costs, whether it fits a budget, and seeded CPU armies built from
## archetypes. An army IS a doctrine (army JSON v2: squads of units, see Doctrine), so everything that
## loads doctrines (skirmish, the match runner, the garage) can use them.
##
## CPU army names: "cpu" (a seeded random archetype) or "cpu:<archetype>" (see ARCHETYPES).
##
## L3 (round 4): every archetype belongs to a FACTION. `load_army(..., faction)` picks only that faction's
## archetypes and buys only its units, so a budget turns into the army size the lead asked for (gangs swarm, the
## Syndicate fields the fewest). Without a faction nothing changes: "cpu" stays a Condemned army.

## Each archetype: the faction it belongs to and the unit mix to buy, in purchase order (repeated while money
## lasts). Omitting `faction` means Units.DEFAULT_FACTION.
const ARCHETYPES := {
	"balanced": {"units": ["tank", "ifv", "scout", "artillery", "tank", "lancer", "ifv"]},
	"armor": {"units": ["tank", "tank", "lancer", "tank", "ifv"]},
	"recon_strike": {"units": ["scout", "ifv", "scout", "tank", "scout", "lancer"]},
	"siege": {"units": ["artillery", "scout", "tank", "artillery", "ifv", "scout"]},
	"swarm": {"units": ["scout", "scout", "ifv", "scout", "scout", "ifv"]},
	# Stretch: close-range pressure. Burners charge behind a tank's front armor while an IFV screens scouts.
	"brawl": {"units": ["burner", "tank", "burner", "ifv", "burner", "lancer"]},

	# L3 (round 4). Each faction's armies buy only its own vehicles, and the SIZE falls out of their costs, not out
	# of the list: at Units.BASELINE_BUDGET these come to roughly 39 gang vehicles, 28 Condemned, 24 Law, 15
	# Syndicate. The mixes also carry the faction's automated tactics the lead asked for ("while the different
	# factions might have largely similar vehicle types, we can definitely make them have different automated
	# tactics"): the gangs travel in packs with a tanker in the middle, the Law advances behind suppression, the
	# Syndicate fields almost nothing but guns and the eyes to aim them.
	"gang_pack": {"faction": "gangs",
			"units": ["gang_scout", "gang_ifv", "gang_scout", "gang_tank", "gang_ifv", "gang_support", "gang_scout"]},
	"gang_ram": {"faction": "gangs",
			"units": ["gang_tank", "gang_ifv", "gang_tank", "gang_support", "gang_ifv", "gang_scout"]},
	"gang_hail": {"faction": "gangs",
			"units": ["gang_artillery", "gang_scout", "gang_ifv", "gang_artillery", "gang_scout", "gang_support"]},
	"law_line": {"faction": "law",
			"units": ["law_tank", "law_ifv", "law_scout", "law_suppressor", "law_tank", "law_ifv"]},
	"law_cordon": {"faction": "law",
			"units": ["law_suppressor", "law_ifv", "law_scout", "law_artillery", "law_ifv", "law_tank"]},
	"law_dragnet": {"faction": "law",
			"units": ["law_scout", "law_artillery", "law_scout", "law_tank", "law_suppressor", "law_scout"]},
	"syndicate_demo": {"faction": "syndicate",
			"units": ["syn_tank", "syn_scout", "syn_lancer", "syn_ifv", "syn_scout"]},
	"syndicate_standoff": {"faction": "syndicate",
			"units": ["syn_lancer", "syn_scout", "syn_artillery", "syn_lancer", "syn_scout", "syn_ifv"]},
	"syndicate_escort": {"faction": "syndicate",
			"units": ["syn_ifv", "syn_scout", "syn_tank", "syn_ifv", "syn_artillery"]},
}
## L3/X5: how many vehicles one side may field. Doctrine.MAX_UNITS (25) is the cap on a HAND-WRITTEN five-squad
## army; a faction army at Units.BASELINE_BUDGET is bigger than that, so it is split over as many five-unit squads
## as it needs (see squads_for_scale). Sized for the gangs' swarm at the baseline budget, and for the spawn grid
## (Match.SPAWN_SLOTS): more units than there are slots would stack hulls on top of each other.
const MAX_ARMY_UNITS := 45
## Squad name and directive per role, and per "<faction>/<role>" where a faction's vehicle in that role does a
## different job in its army (looked up faction-first). This is where a faction's *automated tactics* live — the
## lead: "while the different factions might have largely similar vehicle types, we can definitely make them have
## different automated tactics" — and X6 found out the hard way why it matters: the road gangs' rat rods were being
## given the Condemned scout's "spotters first" directive, so 15 assault vehicles sat at standoff range spotting
## while the rest of the swarm died, and the faction won 10-30% of everything.
## Squads are formed by role, in this order.
const SQUADS := {
	"tank": {"name": "Guns", "directive": {"role": "assault", "cohesion": 0.7}},
	"ifv": {"name": "Hunters", "directive": {"role": "assault"}},
	"lancer": {"name": "Lances", "directive": {"role": "support"}},
	"burner": {"name": "Burners", "directive": {"role": "assault", "aggression": 0.9}},
	"scout": {"name": "Eyes", "directive": {"role": "scout"}},
	"artillery": {"name": "Battery", "directive": {"role": "support"}},
	# The gangs' scout is a spear buggy: it spots on the way in, but its job is to reach 30 m and open armor.
	"gangs/scout": {"name": "Spears", "directive": {"role": "assault", "aggression": 0.95, "caution": 0.2}},
	# L3 (round 4): the two roles the new factions added. Both stay behind the line of contact.
	"suppressor": {"name": "Sirens", "directive": {"role": "assault", "caution": 0.7}},
	"support": {"name": "Wrenches", "directive": {"role": "support", "caution": 0.9}},
}


static func is_cpu(name: String) -> bool:
	return name == "cpu" or name.begins_with("cpu:")


## L3: the archetype names belonging to `faction`, sorted (a deterministic pick order).
static func archetypes_for(faction: String) -> PackedStringArray:
	var names: PackedStringArray = []
	for archetype: String in ARCHETYPES:
		if String(ARCHETYPES[archetype].get("faction", Units.DEFAULT_FACTION)) == faction:
			names.append(archetype)
	names.sort()
	return names


## Load an army by name: "cpu" / "cpu:<archetype>" (generated from `seed_value` and `budget`), a name in
## res://doctrines/, or a full path. `faction` (L3, optional) restricts a CPU army to one faction's archetypes and
## units, and lets it grow past Doctrine.MAX_UNITS. Returns {"doctrine": Dictionary} or {"error": String}.
static func load_army(name_or_path: String, seed_value: int, budget: int = Units.DEFAULT_BUDGET,
		faction: String = "") -> Dictionary:
	if is_cpu(name_or_path):
		var archetype := name_or_path.trim_prefix("cpu:")
		if name_or_path != "cpu" and not ARCHETYPES.has(archetype):
			return {"error": "no CPU army archetype '%s' (have %s)" % [archetype, ARCHETYPES.keys()]}
		if faction == "":
			return Doctrine.parse(cpu_army(name_or_path, seed_value, budget))
		if not Units.FACTIONS.has(faction):
			return {"error": "no faction '%s' (have %s)" % [faction, ", ".join(Units.FACTIONS)]}
		if archetypes_for(faction).is_empty():
			return {"error": "faction '%s' has no armies yet" % faction}
		if name_or_path != "cpu" and not archetypes_for(faction).has(archetype):
			return {"error": "archetype '%s' is not a %s army (have %s)" % [archetype, faction,
					", ".join(archetypes_for(faction))]}
		return parse_scaled(cpu_army(name_or_path, seed_value, budget, faction))
	var path := name_or_path if name_or_path.contains("://") else "res://doctrines/%s.json" % name_or_path
	return Doctrine.load_file(path)


## L3/X5: validate an army that may hold more than Doctrine.MAX_SQUADS squads. Doctrine.parse owns every rule
## (names, directives, formations, unit entries) but caps the squad COUNT at five, which is a player-UI number, not
## a simulation one; a 30-a-side faction army needs six or more. Rather than copy those rules, the squads are
## validated in slices of Doctrine.MAX_SQUADS and duplicate names are checked across the whole army.
## Requested of the doctrine stream: raise Doctrine.MAX_SQUADS so this wrapper can go away (see the brief's Status).
static func parse_scaled(doctrine: Dictionary) -> Dictionary:
	var squads: Variant = doctrine.get("squads")
	if typeof(squads) != TYPE_ARRAY or (squads as Array).is_empty():
		return Doctrine.parse(doctrine)
	var all_squads: Array = squads
	if all_squads.size() > MAX_ARMY_UNITS:
		return {"error": "an army of %d squads is past the %d unit cap" % [all_squads.size(), MAX_ARMY_UNITS]}
	var seen := {}
	for squad: Variant in all_squads:
		var squad_name: Variant = (squad as Dictionary).get("name") if typeof(squad) == TYPE_DICTIONARY else null
		if typeof(squad_name) == TYPE_STRING:
			if seen.has(squad_name):
				return {"error": "duplicate squad name '%s'" % squad_name}
			seen[squad_name] = true
	var index := 0
	while index < all_squads.size():
		var slice := {"name": doctrine.get("name", ""), "squads": all_squads.slice(index, index + Doctrine.MAX_SQUADS)}
		var parsed := Doctrine.parse(slice)
		if parsed.has("error"):
			return parsed
		index += Doctrine.MAX_SQUADS
	if Doctrine.entries(doctrine).size() > MAX_ARMY_UNITS:
		return {"error": "an army of %d units is past the %d cap" % [Doctrine.entries(doctrine).size(), MAX_ARMY_UNITS]}
	return {"doctrine": doctrine}


## "" if the doctrine fits the budget, else why not.
static func check_budget(doctrine: Dictionary, budget: int) -> String:
	var cost := Units.army_cost(doctrine)
	if cost > budget:
		return "army costs %d, over the %d budget" % [cost, budget]
	return ""


## A seeded CPU army. `name` is "cpu" or "cpu:<archetype>". Deterministic for a given seed and budget. With a
## `faction` (L3) it buys from that faction's archetypes and may field up to MAX_ARMY_UNITS vehicles; without one it
## is a five-squad Condemned army exactly as in round 3.
static func cpu_army(name: String, seed_value: int, budget: int = Units.DEFAULT_BUDGET,
		faction: String = "") -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# No faction asked for means the default one: a plain "cpu" army has to stay the Condemned army it was in round
	# 3, or every skirmish and garage opponent would silently become a different faction (caught by test_army).
	var archetypes: Array = Array(archetypes_for(faction if faction != "" else Units.DEFAULT_FACTION))
	archetypes.sort()
	var archetype := name.trim_prefix("cpu:") if name.begins_with("cpu:") else String(archetypes[rng.randi_range(0, archetypes.size() - 1)])
	if not ARCHETYPES.has(archetype):
		archetype = "balanced"
	var unit_cap := MAX_ARMY_UNITS if faction != "" else Doctrine.MAX_UNITS
	var order: Array = ARCHETYPES[archetype]["units"]
	var cheapest := INF
	for unit_id: String in order:
		cheapest = minf(cheapest, Units.cost_of({"unit": unit_id}))
	var entries: Array = []
	var spent := 0
	# Cycle through the purchase order until the budget or the army cap runs out; a seeded rotation of
	# the starting point varies armies of one archetype.
	var start := rng.randi_range(0, order.size() - 1)
	for step in order.size() * unit_cap:
		if entries.size() >= unit_cap or spent + cheapest > budget:
			break
		var entry := {"unit": String(order[(start + step) % order.size()])}
		var cost := Units.cost_of(entry)
		if spent + cost > budget:
			continue
		entries.append(entry)
		spent += cost
	# Without a faction the army folds into the player's five squads (round-3 behaviour); a faction army takes as
	# many five-unit squads as it needs.
	var squads := squads_for(entries) if faction == "" else squads_for_scale(entries)
	return {"name": "CPU %s" % archetype.capitalize(), "archetype": archetype,
			"faction": String(ARCHETYPES[archetype].get("faction", Units.DEFAULT_FACTION)), "cost": spent,
			"squads": squads}


## L3/X5: group a big army into as many five-unit squads as it needs, by role, in role order. Unlike squads_for
## (which folds everything into Doctrine.MAX_SQUADS for the player's five-squad UI), this keeps every squad pure so
## elements and formations stay meaningful at 30+ a side: Guns, Guns2, Guns3, ...
static func squads_for_scale(entries: Array) -> Array:
	var by_role := {}
	for entry: Dictionary in entries:
		var role := squad_key(entry["unit"])
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
					"directive": template["directive"].duplicate(),
					"units": members.slice(index, index + Doctrine.MAX_SQUAD_UNITS)})
			index += Doctrine.MAX_SQUAD_UNITS
	return squads


## L3: roughly how many vehicles `budget` buys a faction, from its roster's average cost. Reporting and design
## checks: the counts must fall out of cost, not out of a table (the lead, 2026-09-16).
static func typical_size(faction: String, budget: int) -> int:
	var average := Units.roster_average_cost(faction)
	return 0 if average <= 0.0 else mini(MAX_ARMY_UNITS, int(floor(float(budget) / average)))


## The SQUADS key for a unit: its faction's own entry for that role if there is one, else the role.
static func squad_key(unit_id: String) -> String:
	var faction_key := "%s/%s" % [Units.faction_of(unit_id), Units.role_of(unit_id)]
	return faction_key if SQUADS.has(faction_key) else Units.role_of(unit_id)


## Group entries into at most Doctrine.MAX_SQUADS squads of Doctrine.MAX_SQUAD_UNITS, by role (Guns,
## Guns2, ...). When roles need more squads than allowed, the extra units join squads that have room.
static func squads_for(entries: Array) -> Array:
	var by_role := {}
	for entry: Dictionary in entries:
		var role := squad_key(entry["unit"])
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
