class_name ArmyPresets
extends RefCounted
## Starter armies that each teach one composition idea (the army builder's PRESETS menu and a first
## visit's army). CPU *opponents* come from the rules stream's `Army` (cpu / cpu:<archetype>).
##
## Presets name ROLES, never unit ids, so they resolve against whatever catalog exists: when rules adds a
## unit with role "ifv", the presets use it. A role the player hasn't unlocked falls back (FALLBACK), so a
## preset always builds a legal army with what this player owns, at any budget.
##
## Per preset: label, tier (the budget tier it's written for; it scales to any budget), blurb (the idea, in
## one sentence a new player understands), squads: [{formation, role (squad directive), mix: [unit role…]}].
## The builder adds units round-robin across the squads, each squad cycling through its mix, until the
## budget runs out; a full squad spills into a new squad with the same spec while squads remain.

const PRESETS := {
	"anvil_hammer": {
		"label": "Anvil & Hammer", "tier": 0,
		"blurb": "Tanks hold the center (the anvil) while fast IFVs swing around a flank (the hammer).",
		"squads": [
			{"formation": "line", "role": "anchor", "mix": ["tank"]},
			{"formation": "wedge", "role": "flanker", "mix": ["ifv", "ifv", "scout"]},
		],
	},
	"scout_screen": {
		"label": "Scout Screen", "tier": 0,
		"blurb": "Scouts find the enemy first; IFVs catch enemy scouts; tanks hit whatever gets found.",
		"squads": [
			{"formation": "line", "role": "scout", "mix": ["scout"]},
			{"formation": "wedge", "role": "assault", "mix": ["tank", "ifv"]},
		],
	},
	"hunter_killers": {
		"label": "Hunter-Killers", "tier": 0,
		"blurb": "IFV packs shred light units fast; a tank group answers their IFVs.",
		"squads": [
			{"formation": "vee", "role": "flanker", "mix": ["ifv"]},
			{"formation": "wedge", "role": "assault", "mix": ["tank", "tank", "ifv"]},
		],
	},
	"siege_line": {
		"label": "Siege Line", "tier": 1,
		"blurb": "Artillery behind a wall of tanks; scouts spot targets for the guns.",
		"squads": [
			{"formation": "line", "role": "anchor", "mix": ["tank"]},
			{"formation": "line", "role": "support", "mix": ["artillery"]},
			{"formation": "vee", "role": "scout", "mix": ["scout"]},
		],
	},
	"lance_and_shield": {
		"label": "Lance & Shield", "tier": 2,
		"blurb": "Lancers burn enemy tanks at range while IFVs keep scouts off them.",
		"squads": [
			{"formation": "line", "role": "support", "mix": ["lancer"]},
			{"formation": "wedge", "role": "anchor", "mix": ["ifv", "ifv", "tank"]},
		],
	},
}
## The army a first visit opens with.
const STARTER := "anvil_hammer"
## When a role has no unlocked unit, try these roles in order.
const FALLBACK := {
	"artillery": ["tank", "ifv"], "lancer": ["tank", "ifv"], "ifv": ["tank", "scout"],
	"scout": ["ifv", "tank"], "tank": ["ifv", "scout"],
}


static func ids() -> Array[String]:
	var result: Array[String] = []
	for id: String in PRESETS:
		result.append(id)
	return result


static func label(preset: String) -> String:
	return String(PRESETS.get(preset, {}).get("label", preset.capitalize()))


## The unit types a preset is built around that this catalog hasn't unlocked (its roles fall back without them).
static func missing_units(preset: String, catalog: ArmyCatalog) -> Array[String]:
	var missing: Array[String] = []
	for squad_spec: Dictionary in PRESETS.get(preset, {}).get("squads", []):
		for role: String in squad_spec["mix"]:
			for unit_id in catalog.units_with_role(role):
				if not catalog.is_unlocked(unit_id) and not missing.has(unit_id):
					missing.append(unit_id)
	return missing


static func blurb(preset: String) -> String:
	return String(PRESETS.get(preset, {}).get("blurb", ""))


## The unlocked unit that plays `role` in this catalog, falling back through FALLBACK, then the cheapest
## unlocked unit; "" if nothing is unlocked.
static func unit_for_role(catalog: ArmyCatalog, role: String) -> String:
	for candidate: String in [role] + Array(FALLBACK.get(role, [])):
		for unit_id in catalog.units_with_role(candidate):
			if catalog.is_unlocked(unit_id):
				return unit_id
	for unit_id in catalog.unit_ids():
		if catalog.is_unlocked(unit_id):
			return unit_id
	return ""


## A legal player army for `preset` at the catalog's budget. The same (preset, catalog) always gives the
## same army. Squads start formed up and holding for orders.
static func build(preset: String, catalog: ArmyCatalog) -> ArmyDraft:
	var spec: Dictionary = PRESETS.get(preset, PRESETS[STARTER])
	var draft := ArmyDraft.new(catalog, {"name": label(preset), "squads": []})
	var squad_specs: Array = spec["squads"].slice(0, catalog.max_squads)
	# One queue of units per squad spec, cycled; squads of that spec in the draft.
	var next_in_mix: Array[int] = []
	var squads_of_spec: Array = []
	for _i in squad_specs.size():
		next_in_mix.append(0)
		squads_of_spec.append([])
	var cheapest := INF
	for unit_id in catalog.unit_ids():
		if catalog.is_unlocked(unit_id):
			cheapest = minf(cheapest, catalog.unit_cost(unit_id))
	var stalled := 0
	var turn := 0
	while stalled < squad_specs.size() and draft.remaining_budget() >= cheapest and draft.unit_count() < catalog.max_units:
		var spec_index := turn % squad_specs.size()
		turn += 1
		var squad_spec: Dictionary = squad_specs[spec_index]
		var mix: Array = squad_spec["mix"]
		var unit_id := unit_for_role(catalog, String(mix[next_in_mix[spec_index] % mix.size()]))
		var squad_index := _squad_with_room(draft, squads_of_spec[spec_index])
		if squad_index < 0 and draft.squads().size() < catalog.max_squads:
			squad_index = draft.squads().size()
			var squad_name: String = ArmyDraft.SQUAD_NAMES[squad_index] if squad_index < ArmyDraft.SQUAD_NAMES.size() else "Squad_%d" % (squad_index + 1)
			draft.squads().append(ArmyDraft.new_squad(squad_name, String(squad_spec["formation"]), String(squad_spec["role"])))
			squads_of_spec[spec_index].append(squad_index)
		if squad_index < 0 or unit_id == "" or draft.add_unit(squad_index, unit_id) != "":
			stalled += 1
			continue
		stalled = 0
		next_in_mix[spec_index] += 1
	# Spend what's left: the cheapest unlocked unit that fits, into the last squad with room.
	var by_cost := catalog.unit_ids().filter(func(id: String) -> bool: return catalog.is_unlocked(id))
	by_cost.sort_custom(func(a: String, b: String) -> bool: return catalog.unit_cost(a) < catalog.unit_cost(b))
	for unit_id: String in by_cost:
		while draft.unit_count() < catalog.max_units and catalog.unit_cost(unit_id) <= draft.remaining_budget():
			var squad_index := -1
			for index in range(draft.squads().size() - 1, -1, -1):
				if draft.units_of(index).size() < catalog.max_squad_size:
					squad_index = index
					break
			if squad_index < 0 or draft.add_unit(squad_index, unit_id) != "":
				break
	draft.drop_empty_squads()
	return draft


static func _squad_with_room(draft: ArmyDraft, indices: Array) -> int:
	for index: int in indices:
		if draft.units_of(index).size() < draft.catalog.max_squad_size:
			return index
	return -1
