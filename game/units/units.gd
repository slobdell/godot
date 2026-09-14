class_name Units
extends RefCounted
## The unit catalog: vehicle classes as DATA (like Weapons.PROFILES). Schema v0, written
## 2026-09-14 so the gameplay and garage streams share one vocabulary from the start.
##
## Owned by the gameplay stream (_agents/streams/gameplay.md, directive set 2), which will
## grow it (scout, artillery, components, real costs) and wire it into Tank/Match. Nothing in
## the simulation reads it yet. The garage stream reads it to build army/loadout UI.
##
## Keep existing keys stable. Renaming or removing one is a contract change (_agents/workstreams.md).

const SCHEMA_VERSION := 0

## Points a player spends on an army per match (placeholder until gameplay tunes it).
const DEFAULT_BUDGET := 1000

const PROFILES := {
	"tank": {
		"display_name": "Tank",
		"cost": 200,
		# Mirrors today's Tank exports and Match constants; gameplay makes these authoritative.
		# G6 (2026-09-14): hull 400 -> 300 plus a 150 shield that recharges (effective 450 per fight).
		"max_health": 300,
		"max_shield": 150,
		# The shield refills at shield_recharge_rate per second once no damage has landed for
		# shield_recharge_delay seconds. Hull only repairs at base (Match.REPAIR_HP_PER_SECOND).
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 50.0,
		"max_forward_speed": 9.0,
		"hull_turn_rate_deg": 80.0,
		"sight_radius": 75.0,
		# G7 heat: firing adds weapon heat_per_shot; a shot that would exceed the capacity is refused.
		# Heat sinks (a component, directive set 2) will raise these.
		"heat_capacity": 100.0,
		"heat_dissipation": 12.0,
		# Each hardpoint lists the weapon ids (Weapons.PROFILES) it accepts.
		"hardpoints": [{"id": "main", "accepts": ["cannon", "laser", "flamethrower"]}],
		# Component slots (heat sinks, extra ammo, shield boosters…) arrive with directive set 2.
		"component_slots": 0,
	},
}


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
