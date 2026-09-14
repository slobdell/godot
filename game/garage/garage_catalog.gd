class_name GarageCatalog
extends RefCounted
## What the garage can offer: unit classes, weapons, components, and the budget.
##
## It reads the unit catalog (game/units/units.gd, owned by gameplay) and Weapons.PROFILES by
## SHAPE, never by a fixed list: when gameplay adds scouts, artillery, lasers, or components, they
## appear in the garage without garage changes. Tests build a catalog from hand-made dictionaries.
##
## Keys the garage understands (all optional except where noted):
##   unit:      display_name, cost (required), hardpoints [{id, accepts}], component_slots, and any
##              numeric stat (max_health, max_shield, max_forward_speed, hull_turn_rate_deg, sight_radius…)
##   weapon:    cost, range, damage / damage_per_second, reload, ammo, heat_per_shot / heat_per_second
##   component: display_name, cost, description, and any numeric effect
## Units may define `COMPONENTS` (id → profile); until then the garage uses STUB_COMPONENTS, which only
## matter for units that declare component_slots > 0 (none do in schema v0).

const UNITS_SCRIPT := "res://game/units/units.gd"

## The garage's guess at directive set 2 components, shown only until Units defines COMPONENTS.
const STUB_COMPONENTS := {
	"heat_sink": {"display_name": "Heat sink", "cost": 30, "description": "Sheds laser heat faster",
			"heat_capacity": 20.0, "heat_dissipation": 4.0},
	"ammo_rack": {"display_name": "Ammo rack", "cost": 25, "description": "More shells before running dry",
			"ammo_bonus": 10},
	"shield_booster": {"display_name": "Shield booster", "cost": 40, "description": "A bigger shield",
			"max_shield": 60.0},
	"armor_plate": {"display_name": "Armor plate", "cost": 35, "description": "More hull, a little slower",
			"max_health": 80.0, "max_forward_speed": -0.8},
}

## Unit stats drawn as bars, in display order: [key, label]. Only stats some unit has are shown.
const UNIT_STATS := [["max_health", "Hull"], ["max_shield", "Shield"], ["max_forward_speed", "Speed"],
		["hull_turn_rate_deg", "Turn"], ["sight_radius", "Sight"]]
## Weapon stats shown as text, in display order: [key, label, unit suffix].
const WEAPON_STATS := [["damage", "Damage", ""], ["damage_per_second", "Damage/s", ""], ["range", "Range", " m"],
		["reload", "Reload", " s"], ["ammo", "Ammo", ""], ["heat_per_shot", "Heat/shot", ""],
		["heat_per_second", "Heat/s", ""]]

var units: Dictionary
var weapons: Dictionary
var components: Dictionary
var budget: int
var max_units: int
var max_squads: int


func _init(p_units: Dictionary, p_weapons: Dictionary, p_components: Dictionary, p_budget: int,
		p_max_units := Doctrine.MAX_TANKS, p_max_squads := Doctrine.MAX_SQUADS) -> void:
	units = p_units
	weapons = p_weapons
	components = p_components
	budget = p_budget
	max_units = p_max_units
	max_squads = p_max_squads


## The catalog the game ships with today.
static func from_game() -> GarageCatalog:
	var constants := (load(UNITS_SCRIPT) as Script).get_script_constant_map()
	var game_components: Dictionary = constants.get("COMPONENTS", STUB_COMPONENTS)
	return GarageCatalog.new(Units.PROFILES, Weapons.PROFILES, game_components,
			int(constants.get("DEFAULT_BUDGET", 1000)))


## Unit ids, cheapest first (ties by id), so the garage lists them in a stable, sensible order.
func unit_ids() -> Array[String]:
	return _sorted_by_cost(units)


func component_ids() -> Array[String]:
	return _sorted_by_cost(components)


func unit(unit_id: String) -> Dictionary:
	return units.get(unit_id, {})


func weapon(weapon_id: String) -> Dictionary:
	return weapons.get(weapon_id, {})


func component(component_id: String) -> Dictionary:
	return components.get(component_id, {})


func display_name(profile: Dictionary, id: String) -> String:
	return String(profile.get("display_name", id.capitalize()))


func unit_cost(unit_id: String) -> int:
	return int(unit(unit_id).get("cost", 0))


func weapon_cost(weapon_id: String) -> int:
	return int(weapon(weapon_id).get("cost", 0))


func component_cost(component_id: String) -> int:
	return int(component(component_id).get("cost", 0))


func hardpoints(unit_id: String) -> Array:
	return unit(unit_id).get("hardpoints", [])


func component_slots(unit_id: String) -> int:
	return int(unit(unit_id).get("component_slots", 0))


## [{key, label, value, ratio}] for the stat bars: ratio is value / the best in the catalog.
func unit_stat_bars(unit_id: String) -> Array[Dictionary]:
	var bars: Array[Dictionary] = []
	for stat in UNIT_STATS:
		var best := 0.0
		for other in units.values():
			best = maxf(best, float(other.get(stat[0], 0.0)))
		if best <= 0.0:
			continue
		var value := float(unit(unit_id).get(stat[0], 0.0))
		bars.append({"key": stat[0], "label": stat[1], "value": value, "ratio": clampf(value / best, 0.0, 1.0)})
	return bars


## "Damage 34 · Range 70 m · Reload 2.5 s" from whichever stats the weapon has.
func weapon_summary(weapon_id: String) -> String:
	var parts: PackedStringArray = []
	var profile := weapon(weapon_id)
	for stat in WEAPON_STATS:
		if profile.has(stat[0]):
			parts.append("%s %s%s" % [stat[1], _number(profile[stat[0]]), stat[2]])
	return "  ".join(parts)


static func _number(value: Variant) -> String:
	var number := float(value)
	return str(int(number)) if is_equal_approx(number, roundf(number)) else "%.1f" % number


static func _sorted_by_cost(profiles: Dictionary) -> Array[String]:
	var ids: Array[String] = []
	for id: String in profiles:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var cost_a := int(profiles[a].get("cost", 0))
		var cost_b := int(profiles[b].get("cost", 0))
		return cost_a < cost_b if cost_a != cost_b else a < b)
	return ids
