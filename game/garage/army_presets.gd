class_name ArmyPresets
extends RefCounted
## GA4: army archetypes as data, built into legal, budget-constrained armies with a seed, so CPU
## opponents vary from match to match and players get sensible starting points in the garage.
##
## Archetypes never name unit classes or weapons. They name PREFERENCES that resolve against whatever
## catalog exists: "the fastest class", "the toughest", "the shortest-range weapon a hardpoint accepts",
## "a component whose stats mention heat". When gameplay adds scouts, lasers, or heat sinks, the same
## archetypes start using them.
##
## Per squad: share (of the army's units), formations (one is picked; player presets only), role, close_share (fraction of
## its units that mount the shortest-range weapon instead of the longest), objective (CPU only;
## [min, max] ranges in team-relative meters, mirrored left/right at random when mirror is true), and
## directive (extra Directives keys; [min, max] ranges are rolled). Player presets drop objectives
## and start every squad holding for orders.

const ARCHETYPES := {
	"balanced": {
		"label": "Balanced", "prefer": "cheapest",
		"blurb": "An anvil holds the center while a hammer swings wide.",
		"squads": [
			{"share": 0.6, "formations": ["wedge", "line"], "role": "anchor", "close_share": 0.0,
				"objective": {"right": [-8, 8], "forward": [-16, -8], "radius": 10}},
			{"share": 0.4, "formations": ["vee", "echelon_right", "wedge"], "role": "flanker", "close_share": 0.25, "mirror": true,
				"objective": {"right": [30, 45], "forward": [0, 10], "radius": 10},
				"directive": {"target_priority": "threatening_allies", "cohesion": [0.6, 0.8]}},
		],
	},
	"rush": {
		"label": "Rush", "prefer": "max_forward_speed",
		"blurb": "Everything fast, straight at the enemy.",
		"squads": [
			{"share": 1.0, "formations": ["column", "wedge", "vee"], "role": "assault", "close_share": 0.4,
				"directive": {"aggression": [0.8, 0.95], "caution": [0.15, 0.35], "target_priority": "nearest"}},
		],
	},
	"turtle": {
		"label": "Turtle", "prefer": "max_health",
		"blurb": "Tough units dug in short of center; they let you come to them.",
		"squads": [
			{"share": 0.6, "formations": ["line", "coil"], "role": "anchor", "close_share": 0.0,
				"objective": {"right": [-8, 8], "forward": [-18, -10], "radius": 12},
				"directive": {"caution": [0.55, 0.7]}},
			{"share": 0.4, "formations": ["line", "wedge"], "role": "support", "close_share": 0.0, "mirror": true,
				"objective": {"right": [12, 22], "forward": [-22, -14], "radius": 8},
				"directive": {"cohesion": [0.7, 0.85], "target_priority": "most_exposed"}},
		],
	},
	"flamers": {
		"label": "Flamers", "prefer": "cheapest",
		"blurb": "A gun line draws fire while burners flank in close.",
		"squads": [
			{"share": 0.4, "formations": ["line", "wedge"], "role": "anchor", "close_share": 0.0,
				"objective": {"right": [-5, 5], "forward": [-14, -8], "radius": 10}},
			{"share": 0.6, "formations": ["vee", "echelon_right", "column"], "role": "flanker", "close_share": 1.0, "mirror": true,
				"objective": {"right": [35, 50], "forward": [5, 15], "radius": 8},
				"directive": {"caution": [0.25, 0.4], "target_priority": "threatening_allies", "cohesion": [0.7, 0.9]}},
		],
	},
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in ARCHETYPES:
		result.append(id)
	return result


static func label(archetype: String) -> String:
	return String(ARCHETYPES.get(archetype, {}).get("label", archetype.capitalize()))


## A legal army for `archetype`. The same (archetype, catalog, seed) always gives the same army.
## `for_player`: squads hold for orders and carry no objectives (the player commands them).
static func build(archetype: String, catalog: GarageCatalog, seed_value: int, for_player := false) -> Loadout:
	var spec: Dictionary = ARCHETYPES[archetype]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([archetype, seed_value])
	var squad_specs: Array = spec["squads"].slice(0, catalog.max_squads)
	var loadout := Loadout.new(catalog, {"name": ("%s #%d" if for_player else "CPU %s %d") % [label(archetype), seed_value], "squads": []})

	# Which unit each slot gets, filling the roster while the budget lasts.
	var roster: Array[String] = []
	var spent := 0
	var preferred := _preferred_unit(catalog, String(spec["prefer"]))
	var cheapest := catalog.unit_ids()[0]
	while roster.size() < catalog.max_units:
		var pick := preferred if spent + _base_cost(catalog, preferred) <= catalog.budget else cheapest
		if spent + _base_cost(catalog, pick) > catalog.budget:
			break
		roster.append(pick)
		spent += _base_cost(catalog, pick)

	var counts := _split(roster.size(), squad_specs)
	var next := 0
	for squad_spec_index in squad_specs.size():
		if counts[squad_spec_index] == 0:
			continue
		var squad_spec: Dictionary = squad_specs[squad_spec_index]
		loadout.add_squad()
		var squad_index := loadout.squads().size() - 1
		var formations: Array = squad_spec["formations"]
		loadout.set_formation(squad_index, formations[rng.randi_range(0, formations.size() - 1)])
		loadout.set_squad_role(squad_index, squad_spec["role"])
		var squad_data := loadout.squad(squad_index)
		if not for_player:
			# A doctrine formation means "form up and HOLD here" (Squad.apply_command), so a CPU squad
			# with one never leaves its base. CPU squads rely on objectives and directives instead.
			squad_data.erase("verb")
			squad_data.erase("formation")
			var directive: Dictionary = squad_data["directive"]
			for key: String in squad_spec.get("directive", {}):
				directive[key] = _roll(rng, squad_spec["directive"][key])
			if squad_spec.has("objective"):
				var side := -1.0 if squad_spec.get("mirror", false) and rng.randf() < 0.5 else 1.0
				directive["objective"] = {"right": side * float(_roll(rng, squad_spec["objective"]["right"])),
						"forward": float(_roll(rng, squad_spec["objective"]["forward"])), "radius": float(squad_spec["objective"]["radius"])}
		var close_count := roundi(float(squad_spec.get("close_share", 0.0)) * counts[squad_spec_index])
		for unit_offset in counts[squad_spec_index]:
			loadout.add_unit(squad_index, roster[next])
			next += 1
			var unit_index: int = loadout.squad(squad_index)["tanks"].size() - 1
			var tank := loadout.unit_at(squad_index, unit_index)
			for hardpoint in catalog.hardpoints(tank["unit"]):
				var weapon_id := _weapon_by_range(catalog, hardpoint.get("accepts", []), unit_offset < close_count)
				if weapon_id != "":
					loadout.set_weapon(squad_index, unit_index, hardpoint["id"], weapon_id)
	_fit_components(loadout, String(spec["prefer"]))
	return loadout


## The stat-preferred unit class ("cheapest", or the unit with the highest value of a stat; ties → cheaper).
static func _preferred_unit(catalog: GarageCatalog, prefer: String) -> String:
	var best := catalog.unit_ids()[0]
	if prefer == "cheapest":
		return best
	for unit_id in catalog.unit_ids():  # cheapest first, so ties keep the cheaper class
		if float(catalog.unit(unit_id).get(prefer, 0.0)) > float(catalog.unit(best).get(prefer, 0.0)):
			best = unit_id
	return best


## A unit with its default weapons: what adding it costs before any swaps.
static func _base_cost(catalog: GarageCatalog, unit_id: String) -> int:
	var probe := Loadout.new(catalog, {"name": "probe", "squads": []})
	return probe.unit_cost(probe.new_unit(unit_id))


## Units per squad by share: largest remainders, and every squad gets one while units remain.
static func _split(total: int, squad_specs: Array) -> Array[int]:
	var counts: Array[int] = []
	var assigned := 0
	for squad_spec in squad_specs:
		var count := floori(float(squad_spec["share"]) * total)
		counts.append(count)
		assigned += count
	var index := 0
	while assigned < total:
		counts[index % counts.size()] += 1
		assigned += 1
		index += 1
	# A squad with no units is dropped by the builder; take from the largest to fill it if possible.
	for i in counts.size():
		if counts[i] == 0 and total >= counts.size():
			var largest := counts.find(counts.max())
			counts[largest] -= 1
			counts[i] = 1
	return counts


## The shortest-range (close) or longest-range weapon among those a hardpoint accepts; ties keep list order.
static func _weapon_by_range(catalog: GarageCatalog, accepts: Array, close: bool) -> String:
	var known := accepts.filter(func(weapon_id: String) -> bool: return catalog.weapons.has(weapon_id))
	if known.is_empty():
		return ""
	var ranged := func(weapon_id: String) -> float: return float(catalog.weapon(weapon_id).get("range", 0.0))
	var pick: String = known[0]
	for weapon_id: String in known:
		if (ranged.call(weapon_id) < ranged.call(pick)) if close else (ranged.call(weapon_id) > ranged.call(pick)):
			pick = weapon_id
	return pick


## Spend what's left on components that suit each unit: heat weapons want heat components, ammo weapons
## want ammo, tough armies want health. Matching is by stat-name keywords, so real components slot in.
static func _fit_components(loadout: Loadout, prefer: String) -> void:
	var catalog := loadout.catalog
	if catalog.components.is_empty():
		return
	for squad_index in loadout.squads().size():
		for unit_index in loadout.squad(squad_index)["tanks"].size():
			var tank := loadout.unit_at(squad_index, unit_index)
			var wanted: Array[String] = []
			for weapon_id in tank["weapons"].values():
				for key: String in catalog.weapon(weapon_id):
					if key.contains("heat"):
						wanted.append("heat")
					elif key.contains("ammo"):
						wanted.append("ammo")
			wanted.append("health" if prefer == "max_health" else "shield")
			for keyword in wanted:
				var component_id := _component_matching(catalog, keyword)
				if component_id != "":
					loadout.add_component(squad_index, unit_index, component_id)  # refused quietly when full or broke


static func _component_matching(catalog: GarageCatalog, keyword: String) -> String:
	for component_id in catalog.component_ids():
		for key: String in catalog.component(component_id):
			if key.contains(keyword) or component_id.contains(keyword):
				return component_id
	return ""


static func _roll(rng: RandomNumberGenerator, value: Variant) -> Variant:
	if typeof(value) == TYPE_ARRAY:
		# Twentieths, computed so the double is the nearest one to its decimal (it survives JSON exactly).
		return roundf(rng.randf_range(float(value[0]), float(value[1])) * 20.0) / 20.0
	return value
