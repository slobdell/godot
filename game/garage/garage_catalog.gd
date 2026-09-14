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
## The game's components come from `Units.COMPONENTS` (schema v1); STUB_COMPONENTS only fill the preview catalog.

const UNITS_SCRIPT := "res://game/units/units.gd"

## Components for the preview catalog (the game's own are Units.COMPONENTS).
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
## Army limits. Today's come from the doctrine loader (5 units, 3 squads); the lead wants ~20 units once
## cheaper classes exist, and the garage already handles that (tests and the preview catalog use 20).
var max_units: int
var max_squads: int
## A squad holds at most this many units (formations place up to Formations.MAX_MEMBERS).
var max_squad_size: int
## False for catalogs the game can't field yet (the preview): FIGHT is refused and problems skip Doctrine.parse.
var playable := true
## True only for from_game(): the one catalog whose armies Doctrine.parse (the game's loader) can judge.
## Hand-made test catalogs follow the garage's rules but not the game's units.
var is_game := false


func _init(p_units: Dictionary, p_weapons: Dictionary, p_components: Dictionary, p_budget: int,
		p_max_units := Doctrine.MAX_TANKS, p_max_squads := Doctrine.MAX_SQUADS,
		p_max_squad_size := Formations.MAX_MEMBERS) -> void:
	units = p_units
	weapons = p_weapons
	components = p_components
	budget = p_budget
	max_units = p_max_units
	max_squads = p_max_squads
	max_squad_size = p_max_squad_size


## The catalog the game ships with today.
static func from_game() -> GarageCatalog:
	var constants := (load(UNITS_SCRIPT) as Script).get_script_constant_map()
	var game_components: Dictionary = constants.get("COMPONENTS", STUB_COMPONENTS)
	var catalog := GarageCatalog.new(Units.PROFILES, Weapons.PROFILES, game_components,
			int(constants.get("DEFAULT_BUDGET", 1000)))
	catalog.is_game = true
	return catalog


## A catalog shaped like gameplay's directive set 2 plans: scout, tank, artillery, a laser with heat, heat
## sinks, and a 20-unit army in up to 6 squads. For previewing the garage at the size the lead wants
## (`make garage CATALOG=preview`); the game can't field it, so it isn't playable.
static func preview() -> GarageCatalog:
	var units := {
		"scout": {"display_name": "Scout", "cost": 90, "max_health": 180, "max_shield": 60, "max_forward_speed": 15.0,
				"hull_turn_rate_deg": 140.0, "sight_radius": 120.0, "component_slots": 1,
				"hardpoints": [{"id": "main", "accepts": ["machine_gun", "laser"]}]},
		"tank": {"display_name": "Tank", "cost": 200, "max_health": 400, "max_shield": 120, "max_forward_speed": 9.0,
				"hull_turn_rate_deg": 80.0, "sight_radius": 75.0, "component_slots": 2,
				"hardpoints": [{"id": "main", "accepts": ["cannon", "laser", "flamethrower"]}]},
		"artillery": {"display_name": "Artillery", "cost": 260, "max_health": 250, "max_shield": 40, "max_forward_speed": 6.0,
				"hull_turn_rate_deg": 50.0, "sight_radius": 60.0, "component_slots": 1,
				"hardpoints": [{"id": "main", "accepts": ["mortar"]}]},
	}
	var weapons: Dictionary = Weapons.PROFILES.duplicate(true)
	weapons["machine_gun"] = {"display_name": "Machine gun", "range": 45.0, "damage": 6.0, "reload": 0.2, "ammo": 400}
	weapons["laser"] = {"display_name": "Laser", "cost": 25, "range": 55.0, "damage": 14.0, "reload": 0.8, "heat_per_shot": 9.0}
	weapons["mortar"] = {"display_name": "Mortar", "range": 110.0, "damage": 60.0, "reload": 5.0, "ammo": 24}
	weapons["cannon"]["ammo"] = 40
	var components := STUB_COMPONENTS.duplicate(true)
	var catalog := GarageCatalog.new(units, weapons, components, 4000, 20, 6)
	catalog.playable = false
	return catalog


## The all-rounder: the unit whose hardpoints accept the most weapons (ties → cheaper). With the game's
## catalog that's the tank, not the scout (cheapest) or the artillery (a specialist).
func workhorse() -> String:
	var best := ""
	var best_options := -1
	for unit_id in unit_ids():  # cheapest first, so ties keep the cheaper unit
		var options := 0
		for hardpoint: Dictionary in hardpoints(unit_id):
			options += (hardpoint.get("accepts", []) as Array).size()
		if options > best_options:
			best = unit_id
			best_options = options
	return best


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
