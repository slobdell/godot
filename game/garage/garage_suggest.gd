class_name GarageSuggest
extends RefCounted
## Round 19 (garage, G3 + stretch a): the one "suggested army" per faction, the garage's only preset. What a first visit
## opens with and what SUGGESTED rebuilds: the faction's own mix (the archetype its CPU plays most like), bought at the
## catalog's money under the player's limits, then topped up so it spends the 1000 credits exactly where the prices
## allow, split into squads by job (Alpha ... Echo), every squad formed up and holding for his orders.
## Pure and deterministic: the same faction is always the same army.

## The archetype each faction's suggestion is bought from (Army.ARCHETYPES), its most even mix.
const MIX := {"condemned": "balanced", "gangs": "gang_pack", "law": "law_line", "syndicate": "syndicate_escort"}
## Round 20 (R3): how many vehicles a suggested squad aims at (17 Gangs -> 5 squads, 10 Condemned -> 4, 8 Law -> 3,
## 5 Syndicate -> 2).
const SQUAD_TARGET := 3


## The suggested army for `catalog`'s faction, as an ArmyDraft on that catalog (prices in its money).
static func draft(catalog: ArmyCatalog) -> ArmyDraft:
	var faction := catalog.faction if catalog.faction != "" else Units.DEFAULT_FACTION
	var order: Array = Army.ARCHETYPES[MIX.get(faction, "balanced")]["units"]
	order = order.filter(func(unit_id: Variant) -> bool: return catalog.has_unit(String(unit_id)))
	if order.is_empty():
		order = catalog.unit_ids()
	var picked := GarageSuggest.buy(order, catalog)
	# Money-bound (the Law, the Syndicate): top up to spend it. Cap-bound (25 vehicles: the Condemned, the gangs): keep
	# the mix and leave the credits showing; buying dearer vehicles to spend them turned a balanced army into an
	# artillery park (13 of 25, then 7 artillery and 6 burners), which is no suggestion at all.
	if picked.size() < catalog.max_units:
		picked = GarageSuggest.top_up(picked, catalog)
	var entries: Array = picked.map(func(unit_id: String) -> Dictionary: return {"unit": unit_id})
	# Round 20 (R3): squads of about three. At 1.75 points a credit the dear factions buy 5-10 vehicles, and folding by
	# job alone left the Syndicate five squads of one (and the phone scrolling through them).
	var squad_count := clampi(ceili(float(entries.size()) / float(SQUAD_TARGET)), 1, catalog.max_squads)
	var squads := GarageSuggest.even_squads(Army.squads_for(entries), squad_count)
	for index in squads.size():
		squads[index]["name"] = ArmyDraft.SQUAD_NAMES[index]
		squads[index]["formation"] = Formations.DEFAULT
	var result := ArmyDraft.new(catalog, {"name": GarageSuggest.army_name(faction), "squads": squads})
	result.make_player_army()
	return result


## `squads` (Army's job squads) dealt into `count` squads as even as they go (sizes differ by at most one), in job
## order, so like vehicles stay together and no squad is left with one vehicle while another has five.
static func even_squads(squads: Array, count: int) -> Array:
	var flat: Array = []
	var directive_of: Array = []
	for squad: Dictionary in squads:
		for unit: Variant in squad["units"]:
			flat.append(unit)
			directive_of.append(squad.get("directive", {}))
	var result: Array = []
	var start := 0
	for index in count:
		var size := flat.size() / count + (1 if index < flat.size() % count else 0)
		if size <= 0:
			break
		# A squad keeps the job (directive) of its first vehicle's job squad.
		result.append({"directive": (directive_of[start] as Dictionary).duplicate(true),
				"units": flat.slice(start, start + size)})
		start += size
	return result


static func army_name(faction: String) -> String:
	return "%s Army" % String(Units.FACTION_NAMES.get(faction, faction.capitalize()))


## Cycle through `order` buying what still fits, until the money or the vehicle cap runs out.
static func buy(order: Array, catalog: ArmyCatalog) -> Array:
	var picked: Array = []
	var spent := 0
	var cheapest := INF
	for unit_id: String in order:
		cheapest = minf(cheapest, catalog.unit_cost(unit_id))
	for step in order.size() * catalog.max_units:
		if picked.size() >= catalog.max_units or spent + cheapest > catalog.budget:
			break
		var unit_id := String(order[step % order.size()])
		if spent + catalog.unit_cost(unit_id) > catalog.budget:
			continue
		picked.append(unit_id)
		spent += catalog.unit_cost(unit_id)
	return picked


## Spend what is left: swap one vehicle for a dearer one of the roster (the largest step that still fits) while any
## swap helps, so the army lands on the budget exactly where the prices allow it. A swap never takes a job below half
## of what the mix bought, nor grows one past the mix's most common vehicle (a balanced army stays balanced: the first
## version turned every scout into artillery, 13 of 25).
static func top_up(picked: Array, catalog: ArmyCatalog) -> Array:
	var result := picked.duplicate()
	var floor_of := {}
	for unit_id: String in picked:
		floor_of[unit_id] = int(floor_of.get(unit_id, 0)) + 1
	var ceiling := 0
	for unit_id: String in floor_of:
		ceiling = maxi(ceiling, int(floor_of[unit_id]))
		floor_of[unit_id] = ceili(float(floor_of[unit_id]) / 2.0)
	for pass_index in 64:
		var left := catalog.budget
		var counts := {}
		for unit_id: String in result:
			left -= catalog.unit_cost(unit_id)
			counts[unit_id] = int(counts.get(unit_id, 0)) + 1
		if left <= 0:
			break
		var best_gain := 0
		var best := [-1, ""]
		for index in result.size():
			var from := String(result[index])
			if int(counts[from]) <= int(floor_of.get(from, 0)):
				continue
			for other: String in catalog.unit_ids():
				if int(counts.get(other, 0)) >= ceiling:
					continue
				var gain := catalog.unit_cost(other) - catalog.unit_cost(from)
				if gain > best_gain and gain <= left:
					best_gain = gain
					best = [index, other]
		if best[0] < 0:
			break
		result[best[0]] = best[1]
	return result
