class_name ArmyFormat
extends RefCounted
## Army JSON v2 (contract C2) on the army stream's side: migrating round-1 saves.
##
## v2: {"name", "squads": [{"name", "formation"?, "directive"?, "verb"?, "units": [{"unit", "paint"?, "directive"?}]}]}
## plus the army builder's own top-level "garage": {"schema", "budget", "cost", "tier"} (tools and humans; loaders ignore it).
## v1 (round 1): squads hold "tanks": [{"unit", "weapon"/"weapons", "components", "paint", "directive"}].

## Where a round-1 unit + weapon went in the fixed roster: a laser on anything is a Lancer; a flamethrower
## tank becomes a plain tank (the Burner isn't a unit yet).
const V1_LASER_UNIT := "lancer"


static func is_v1(doctrine: Dictionary) -> bool:
	for squad: Variant in doctrine.get("squads", []):
		if typeof(squad) == TYPE_DICTIONARY and squad.has("tanks") and not squad.has("units"):
			return true
	return false


## A v2 copy of any army dictionary, and sentences for whatever couldn't come along:
## {"doctrine": Dictionary, "notes": PackedStringArray}. Unknown units are dropped (and noted).
static func migrate(doctrine: Dictionary, catalog: ArmyCatalog) -> Dictionary:
	var copy: Dictionary = doctrine.duplicate(true)
	var notes: PackedStringArray = []
	var dropped := {}
	var loadouts_dropped := false
	if typeof(copy.get("squads")) != TYPE_ARRAY:
		copy["squads"] = []
	for squad: Variant in copy["squads"]:
		if typeof(squad) != TYPE_DICTIONARY:
			continue
		var entries: Variant = squad.get("units", squad.get("tanks", []))
		squad.erase("tanks")
		var units := []
		for entry: Variant in (entries if typeof(entries) == TYPE_ARRAY else []):
			if typeof(entry) != TYPE_DICTIONARY:
				continue
			var unit_id := _v2_unit_id(entry)
			if entry.has("weapons") or entry.has("components") or entry.has("weapon"):
				loadouts_dropped = loadouts_dropped or not (entry.get("components", []) as Array).is_empty() \
						or String(entry.get("weapon", "")) not in ["", "cannon", "machine_gun", "mortar"]
			if not catalog.has_unit(unit_id):
				dropped[unit_id] = int(dropped.get(unit_id, 0)) + 1
				continue
			var unit := {"unit": unit_id}
			for key in ["paint", "directive"]:
				if entry.has(key):
					unit[key] = entry[key]
			units.append(unit)
		squad["units"] = units
	if loadouts_dropped:
		notes.append("Weapons and components are gone: units come fixed now.")
	for unit_id: String in dropped:
		notes.append("Removed %d unknown unit%s '%s'." % [dropped[unit_id], "" if dropped[unit_id] == 1 else "s", unit_id])
	var garage: Variant = copy.get("garage")
	if typeof(garage) == TYPE_DICTIONARY:
		garage["schema"] = ArmyDraft.SCHEMA
	return {"doctrine": copy, "notes": notes}


static func _v2_unit_id(entry: Dictionary) -> String:
	var unit_id := String(entry.get("unit", "tank"))
	var weapons: Array = []
	if entry.has("weapon"):
		weapons.append(String(entry["weapon"]))
	if typeof(entry.get("weapons")) == TYPE_DICTIONARY:
		weapons.append_array((entry["weapons"] as Dictionary).values())
	if weapons.has("laser"):
		return V1_LASER_UNIT
	return unit_id


## What the game's loader reads for this v2 army: a copy of it (the game has read army JSON v2 since checkpoint 1; the
## v1 stand-in path went with ArmyCatalogStub in round 14, G6). Kept as the one place a future format change goes.
static func to_game_doctrine(army: Dictionary) -> Dictionary:
	return army.duplicate(true)
