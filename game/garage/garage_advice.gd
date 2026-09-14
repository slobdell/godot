class_name GarageAdvice
extends RefCounted
## Makes the garage's trade-offs readable: per-unit hints ("runs hot: add a heat sink") and the
## comparison tables. Pure data over the catalog's SHAPE (stat-name keywords, not weapon ids), so
## lasers, ammo, and heat sinks from gameplay's directive set 2 get advice without garage changes.

## Weapon columns in the comparison: [key, header]. "dps" is derived (damage / reload, or damage_per_second).
const WEAPON_COLUMNS := [["cost", "Cost"], ["dps", "Dmg/s"], ["damage", "Hit"], ["range", "Range"],
		["reload", "Reload"], ["ammo", "Ammo"], ["heat_per_shot", "Heat/shot"], ["heat_per_second", "Heat/s"]]
## Stats where LOWER is better (highlighting picks the minimum).
const LOWER_IS_BETTER := ["cost", "reload", "heat_per_shot", "heat_per_second"]


## Short hints for one unit: what its weapons need and whether it has it.
static func tradeoffs(catalog: GarageCatalog, tank: Dictionary) -> PackedStringArray:
	var hints: PackedStringArray = []
	var components: Array = tank.get("components", [])
	var slots := catalog.component_slots(String(tank.get("unit", "")))
	for weapon_id in tank.get("weapons", {}).values():
		var weapon := catalog.weapon(weapon_id)
		var name := catalog.display_name(weapon, weapon_id)
		if _has_key(weapon, "heat"):
			if _has_component(catalog, components, "heat"):
				hints.append("%s runs hot; your heat sink helps." % name)
			elif slots > 0:
				hints.append("%s runs hot: add a heat sink to keep firing." % name)
			else:
				hints.append("%s runs hot and this chassis can't carry heat sinks." % name)
		if _has_key(weapon, "ammo"):
			if _has_component(catalog, components, "ammo"):
				hints.append("%s has finite ammo; your extra ammo helps." % name)
			else:
				hints.append("%s has finite ammo%s." % [name, ": consider extra ammo" if slots > 0 else ""])
		var weapon_range := float(weapon.get("range", 0.0))
		if weapon_range > 0.0 and weapon_range < 30.0:
			hints.append("%s is close range (%d m): flank or ambush, don't trade shots." % [name, int(weapon_range)])
	return hints


static func dps(weapon: Dictionary) -> float:
	if weapon.has("damage_per_second"):
		return float(weapon["damage_per_second"])
	if weapon.has("damage") and float(weapon.get("reload", 0.0)) > 0.0:
		return float(weapon["damage"]) / float(weapon["reload"])
	return 0.0


## {"headers": [String], "rows": [[label, value text…]], "best": [[bool…]]} for the unit classes.
static func unit_table(catalog: GarageCatalog) -> Dictionary:
	var columns := [["cost", "Cost"]]
	for stat in GarageCatalog.UNIT_STATS:
		if catalog.units.values().any(func(u: Dictionary) -> bool: return float(u.get(stat[0], 0.0)) > 0.0):
			columns.append(stat)
	columns.append(["component_slots", "Slots"])
	var ids := catalog.unit_ids()
	return _table(columns, ids.map(func(id: String) -> String: return catalog.display_name(catalog.unit(id), id)),
			ids.map(func(id: String) -> Dictionary: return catalog.unit(id)), func(profile: Dictionary, key: String) -> Variant:
				return profile.get(key))


static func weapon_table(catalog: GarageCatalog) -> Dictionary:
	var ids: Array = catalog.weapons.keys()
	ids.sort()
	var profiles := ids.map(func(id: String) -> Dictionary: return catalog.weapon(id))
	var columns := WEAPON_COLUMNS.filter(func(column: Array) -> bool:
		return column[0] == "dps" or column[0] == "cost" or profiles.any(func(p: Dictionary) -> bool: return p.has(column[0])))
	return _table(columns, ids.map(func(id: String) -> String: return catalog.display_name(catalog.weapon(id), id)), profiles,
			func(profile: Dictionary, key: String) -> Variant:
				if key == "dps":
					return dps(profile)
				if key == "reload" and float(profile.get(key, 0.0)) <= 0.0:
					return null  # continuous weapons (flamethrower) have no reload to compare
				return profile.get(key, 0) if key == "cost" else profile.get(key))


static func _table(columns: Array, labels: Array, profiles: Array, value_of: Callable) -> Dictionary:
	var headers := [""]
	for column in columns:
		headers.append(column[1])
	var rows := []
	var best := []
	for i in profiles.size():
		var row := [labels[i]]
		var marks := [false]
		for column in columns:
			var value: Variant = value_of.call(profiles[i], column[0])
			row.append("-" if value == null else GarageCatalog._number(value))
			marks.append(value != null and profiles.size() > 1 and _is_best(profiles, column[0], float(value), value_of))
		rows.append(row)
		best.append(marks)
	return {"headers": headers, "rows": rows, "best": best}


## True if `value` is the best in its column, and the column isn't all ties.
static func _is_best(profiles: Array, key: String, value: float, value_of: Callable) -> bool:
	var differs := false
	for profile in profiles:
		var other: Variant = value_of.call(profile, key)
		if other != null and not is_equal_approx(float(other), value):
			differs = true
	if not differs:
		return false
	for profile in profiles:
		var other: Variant = value_of.call(profile, key)
		if other == null:
			continue
		if (float(other) < value) if key in LOWER_IS_BETTER else (float(other) > value):
			return false
	return true


## True if a stat named like `keyword` is really there: a zero (the game's cannon has heat_per_shot 0.0)
## doesn't count, and nested dictionaries (Units.COMPONENTS "modifiers") are searched too.
static func _has_key(profile: Dictionary, keyword: String) -> bool:
	for key: String in profile:
		var value: Variant = profile[key]
		if typeof(value) == TYPE_DICTIONARY:
			if _has_key(value, keyword):
				return true
		elif key.contains(keyword):
			var numeric := typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT
			if not numeric or not is_zero_approx(float(value)):
				return true
	return false


static func _has_component(catalog: GarageCatalog, components: Array, keyword: String) -> bool:
	return components.any(func(id: String) -> bool: return id.contains(keyword) or _has_key(catalog.component(id), keyword))
