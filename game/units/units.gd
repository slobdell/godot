class_name Units
extends RefCounted
## The unit catalog: vehicle classes as DATA (like Weapons.PROFILES). Schema v0, written
## 2026-09-14 so the gameplay and garage streams share one vocabulary from the start.
##
## Owned by the gameplay stream (_agents/streams/gameplay.md, directive set 2). The simulation reads
## it (Tank.apply_loadout); the garage stream reads it to build army/loadout UI.
##
## Keep existing keys stable. Renaming or removing one is a contract change (_agents/workstreams.md).

const SCHEMA_VERSION := 1
## v1 (2026-09-15, gameplay directive set 2): the simulation reads this catalog (Tank.apply_loadout).
## Added keys: max_reverse_speed, turret_turn_rate_deg, hull_size, class, shield/heat stats; the
## scout; COMPONENTS; weapon costs live in Weapons.PROFILES ("cost"). v0 keys are unchanged.

## Points a player spends on an army per match. A standard tank is 200.
const DEFAULT_BUDGET := 1000

const PROFILES := {
	"tank": {
		"display_name": "Tank",
		"class": "tank",
		"cost": 200,
		# G6 (2026-09-14): hull 400 -> 300 plus a 150 shield that recharges (effective 450 per fight).
		"max_health": 300,
		"max_shield": 150,
		# The shield refills at shield_recharge_rate per second once no damage has landed for
		# shield_recharge_delay seconds. Hull only repairs at base (Match.REPAIR_HP_PER_SECOND).
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 50.0,
		"max_forward_speed": 9.0,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 80.0,
		"turret_turn_rate_deg": 110.0,
		"sight_radius": 75.0,
		# G7 heat: firing adds weapon heat_per_shot; a shot that would exceed the capacity is refused.
		"heat_capacity": 100.0,
		"heat_dissipation": 12.0,
		# Collision box (width, height, length), meters. Visuals scale to match the tank's.
		"hull_size": [2.4, 1.6, 3.6],
		# Each hardpoint lists the weapon ids (Weapons.PROFILES) it accepts.
		"hardpoints": [{"id": "main", "accepts": ["cannon", "laser", "flamethrower"]}],
		# How many COMPONENTS this chassis can carry.
		"component_slots": 2,
	},
	# Directive set 2: fast, fragile, sees far, light gun. Its job is vision for the guns behind it.
	"scout": {
		"display_name": "Scout",
		"class": "scout",
		"cost": 110,
		"max_health": 140,
		"max_shield": 80,
		"shield_recharge_delay": 3.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 14.0,
		"max_reverse_speed": 7.0,
		"hull_turn_rate_deg": 140.0,
		"turret_turn_rate_deg": 200.0,
		"sight_radius": 110.0,
		"heat_capacity": 80.0,
		"heat_dissipation": 12.0,
		"hull_size": [2.0, 1.4, 3.0],
		"hardpoints": [{"id": "main", "accepts": ["machine_gun", "laser"]}],
		"component_slots": 1,
	},
	# Directive set 2: slow, fragile, nearly blind, long reach. Indirect fire at what teammates spot.
	"artillery": {
		"display_name": "Artillery",
		"class": "artillery",
		# 180 -> 220 (2026-09-15): the Siege archetype (2 artillery) won 81% of a 5-archetype round robin.
		"cost": 220,
		"max_health": 200,
		"max_shield": 80,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 6.5,
		"max_reverse_speed": 3.5,
		"hull_turn_rate_deg": 60.0,
		"turret_turn_rate_deg": 70.0,
		"sight_radius": 60.0,
		"heat_capacity": 100.0,
		"heat_dissipation": 12.0,
		"hull_size": [2.6, 1.6, 4.0],
		"hardpoints": [{"id": "main", "accepts": ["mortar"]}],
		"component_slots": 2,
	},
}

## Components fill a chassis's component_slots. "modifiers" add to a unit stat (Units.PROFILES keys),
## except "ammo_fraction", which adds that fraction of a full ammo load to every weapon that has ammo.
const COMPONENTS := {
	"heat_sink": {"display_name": "Heat sink", "cost": 30, "modifiers": {"heat_capacity": 40.0, "heat_dissipation": 6.0}},
	"ammo_rack": {"display_name": "Ammo rack", "cost": 25, "modifiers": {"ammo_fraction": 0.5}},
	"shield_booster": {"display_name": "Shield booster", "cost": 40, "modifiers": {"max_shield": 60.0}},
	"armor_plating": {"display_name": "Armor plating", "cost": 35, "modifiers": {"max_health": 80.0, "max_forward_speed": -1.0}},
}


## A doctrine tank entry's loadout, normalized: {"unit", "weapons": {hardpoint: weapon}, "components": [], "paint"}.
## Accepts the legacy `weapon` key (the main hardpoint). Doesn't validate (see validate_loadout).
static func loadout_of(entry: Dictionary) -> Dictionary:
	var unit_id: String = entry.get("unit", "tank")
	var weapons := {}
	var first_hardpoint: String = PROFILES[unit_id]["hardpoints"][0]["id"] if PROFILES.has(unit_id) else "main"
	if entry.has("weapon"):
		weapons[first_hardpoint] = entry["weapon"]
	if typeof(entry.get("weapons")) == TYPE_DICTIONARY:
		weapons.merge(entry["weapons"], true)
	if not weapons.has(first_hardpoint) and PROFILES.has(unit_id):
		weapons[first_hardpoint] = PROFILES[unit_id]["hardpoints"][0]["accepts"][0]
	return {"unit": unit_id, "weapons": weapons, "components": entry.get("components", []), "paint": entry.get("paint", "")}


## "" or a human-readable reason a tank entry's loadout is invalid.
static func validate_loadout(entry: Dictionary) -> String:
	var unit_id: Variant = entry.get("unit", "tank")
	if typeof(unit_id) != TYPE_STRING or not PROFILES.has(unit_id):
		return "unknown unit '%s' (have %s)" % [unit_id, PROFILES.keys()]
	if entry.has("weapon") and (typeof(entry["weapon"]) != TYPE_STRING or not Weapons.exists(entry["weapon"])):
		return "unknown weapon '%s' (have %s)" % [entry["weapon"], Weapons.PROFILES.keys()]
	if entry.has("weapons") and typeof(entry["weapons"]) != TYPE_DICTIONARY:
		return "weapons must be {hardpoint: weapon}"
	var loadout := loadout_of(entry)
	var hardpoints := {}
	for hardpoint: Dictionary in PROFILES[unit_id]["hardpoints"]:
		hardpoints[hardpoint["id"]] = hardpoint["accepts"]
	for hardpoint_id in loadout["weapons"]:
		var weapon_id: Variant = loadout["weapons"][hardpoint_id]
		if not hardpoints.has(hardpoint_id):
			return "%s has no hardpoint '%s' (has %s)" % [unit_id, hardpoint_id, hardpoints.keys()]
		if typeof(weapon_id) != TYPE_STRING or not Weapons.exists(weapon_id):
			return "unknown weapon '%s' (have %s)" % [weapon_id, Weapons.PROFILES.keys()]
		if not (hardpoints[hardpoint_id] as Array).has(weapon_id):
			return "%s's %s hardpoint doesn't take a %s (takes %s)" % [unit_id, hardpoint_id, weapon_id, hardpoints[hardpoint_id]]
	var components: Variant = loadout["components"]
	if typeof(components) != TYPE_ARRAY:
		return "components must be a list"
	if components.size() > int(PROFILES[unit_id]["component_slots"]):
		return "%s has %d component slots, got %d" % [unit_id, PROFILES[unit_id]["component_slots"], components.size()]
	for component in components:
		if typeof(component) != TYPE_STRING or not COMPONENTS.has(component):
			return "unknown component '%s' (have %s)" % [component, COMPONENTS.keys()]
	var paint: Variant = loadout["paint"]
	if typeof(paint) != TYPE_STRING or (paint != "" and not Color.html_is_valid(paint)):
		return "paint must be an HTML color like \"#3a5f2b\""
	return ""


## Points one tank entry costs: chassis + weapons + components.
static func cost_of(entry: Dictionary) -> int:
	var loadout := loadout_of(entry)
	if not PROFILES.has(loadout["unit"]):
		return 0
	var total := int(PROFILES[loadout["unit"]]["cost"])
	for hardpoint_id in loadout["weapons"]:
		total += int(Weapons.profile(loadout["weapons"][hardpoint_id]).get("cost", 0))
	for component in loadout["components"]:
		total += int(COMPONENTS.get(component, {}).get("cost", 0))
	return total


## Points a whole doctrine costs.
static func army_cost(doctrine: Dictionary) -> int:
	var total := 0
	for squad in doctrine.get("squads", []):
		for entry in squad.get("tanks", []):
			total += cost_of(entry)
	return total


## Experiment overrides ("unit.key" -> value), set from `--tune=` by the match runner and skirmish.
## Never set in normal play. Read through stat(); Tank reads its stats at spawn.
static var tuning := {}


## A unit's stat, honoring `tuning`.
static func stat(unit_id: String, key: String) -> Variant:
	var tuned_key := "%s.%s" % [unit_id, key]
	if tuning.has(tuned_key):
		return tuning[tuned_key]
	return PROFILES[unit_id][key]


## Parse "tank.max_shield=0,cannon.ammo=60" into Units.tuning and Weapons.tuning.
## Returns "" or an error. Keys must exist; values become numbers.
static func apply_tuning(spec: String) -> String:
	for pair in spec.split(",", false):
		var parts := pair.split("=")
		var path := parts[0].split(".")
		if parts.size() != 2 or path.size() != 2 or not parts[1].is_valid_float():
			return "tune: expected owner.key=number, got '%s'" % pair
		if PROFILES.has(path[0]) and PROFILES[path[0]].has(path[1]):
			tuning[parts[0]] = float(parts[1])
		elif Weapons.PROFILES.has(path[0]) and Weapons.PROFILES[path[0]].has(path[1]):
			Weapons.tuning[parts[0]] = float(parts[1])
		else:
			return "tune: no stat '%s'" % parts[0]
	return ""


static func exists(unit_id: String) -> bool:
	return PROFILES.has(unit_id)


static func profile(unit_id: String) -> Dictionary:
	return PROFILES.get(unit_id, {})
