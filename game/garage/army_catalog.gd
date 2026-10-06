class_name ArmyCatalog
extends RefCounted
## What the army builder can offer: fixed unit types (unit catalog v2, contract C1), their weapons for
## display, the match budget, army limits, and which units this player has unlocked (Progression).
##
## It reads the game's catalog by SHAPE, never a fixed list: when rules adds a unit to `Units.PROFILES`,
## it appears here without army changes. (Round 14, G6: the pre-checkpoint-1 stand-in, ArmyCatalogStub, is deleted;
## `Units` has been catalog v2 since round 2.)
## Tests build catalogs from hand-made dictionaries.

const UNITS_SCRIPT := "res://game/units/units.gd"
const DOCTRINE_SCRIPT := "res://game/ai/doctrine.gd"
## C2: at most 5 squads of at most 5 units.
const MAX_SQUADS := 5
const MAX_SQUAD_SIZE := 5
const FALLBACK_BUDGET := 1000

## Unit stats drawn as bars, in display order: [key, label].
const UNIT_STATS := [["max_health", "Hull"], ["max_shield", "Shield"], ["max_forward_speed", "Speed"],
		["sight_radius", "Sight"]]
## Weapon stats shown as text, in display order: [key, label, unit suffix].
const WEAPON_STATS := [["damage", "Hit", ""], ["damage_per_second", "Dmg/s", ""], ["range", "Range", " m"],
		["reload", "Reload", " s"], ["splash_radius", "Splash", " m"]]
## How a role reads to a player (roles are extensible: unknown ones are capitalized).
const ROLE_LABELS := {"scout": "Scout", "tank": "Tank", "ifv": "IFV", "artillery": "Artillery", "lancer": "Lancer"}

var units: Dictionary
var weapons: Dictionary
var budget: int
var max_units: int
var max_squads: int
var max_squad_size: int
## Unit ids this player may field; null = every unit (tests, previews, CPU armies).
var unlocked: Variant = null
## True for the catalog the game fields (its armies go through the game's loader in ArmyDraft.problems).
var is_game := false
## Round 19 (G1): the faction whose roster this is ("" = whatever `units` holds: tests, legacy callers).
var faction := ""
## Round 19 (G1): one of this catalog's money units in the simulation's points. 1 for a catalog priced in points
## (tests, `from_game`); Credits.POINTS_PER_CREDIT for the garage's catalog (`for_game`), whose costs and budget are
## CREDITS, so every number the player reads adds up to the credit and the fight's budget is `budget_points()`.
var points_per_credit := 1


func _init(p_units: Dictionary, p_weapons: Dictionary, p_budget: int, p_max_squads := MAX_SQUADS,
		p_max_squad_size := MAX_SQUAD_SIZE, p_max_units := -1) -> void:
	units = p_units
	weapons = p_weapons
	budget = p_budget
	max_squads = p_max_squads
	max_squad_size = p_max_squad_size
	max_units = p_max_units if p_max_units > 0 else p_max_squads * p_max_squad_size


## True if `profiles` is catalog v2: every unit names one weapon and none has hardpoints.
static func is_v2(profiles: Dictionary) -> bool:
	if profiles.is_empty():
		return false
	for profile: Dictionary in profiles.values():
		if not profile.has("weapon") or profile.has("hardpoints"):
			return false
	return true


## The catalog the game ships with, at `budget` (-1 = the game's default).
static func from_game(p_budget := -1) -> ArmyCatalog:
	var constants := (load(UNITS_SCRIPT) as Script).get_script_constant_map()
	var profiles: Dictionary = constants.get("PROFILES", {})
	if not is_v2(profiles):
		push_error("ArmyCatalog.from_game: Units.PROFILES is not catalog v2 (a unit has hardpoints or no weapon)")
	var game_weapons: Dictionary = Weapons.PROFILES.duplicate()
	# L3 (round 4, combat): the catalog gained three more factions. The garage is a PAUSED stream and its
	# screens, presets and unlock tiers are all written for one roster, so it keeps offering the default faction
	# until picking a faction is designed. Compatibility fix only; whoever unpauses the garage passes the
	# player's chosen faction in here.
	var own_faction := String(constants.get("DEFAULT_FACTION", "condemned"))
	var mine := {}
	for unit_id: String in profiles:
		if String(profiles[unit_id].get("faction", own_faction)) == own_faction:
			mine[unit_id] = profiles[unit_id]
	if not mine.is_empty():
		profiles = mine
	# Limits follow the game's loader (read by shape: v2 may rename or drop them).
	var loader := (load(DOCTRINE_SCRIPT) as Script).get_script_constant_map()
	var squads := mini(MAX_SQUADS, int(loader.get("MAX_SQUADS", MAX_SQUADS)))
	var size := mini(MAX_SQUAD_SIZE, Formations.MAX_MEMBERS)
	var units_cap := mini(squads * size, int(loader.get("MAX_TANKS", loader.get("MAX_UNITS", squads * size))))
	var catalog := ArmyCatalog.new(profiles, game_weapons,
			p_budget if p_budget > 0 else int(constants.get("DEFAULT_BUDGET", FALLBACK_BUDGET)), squads, size, units_cap)
	catalog.is_game = true
	return catalog


## Round 19 (G1): the garage's catalog for `p_faction`: that faction's whole roster, every vehicle open from the
## first game, priced in CREDITS (each cost / Credits.POINTS_PER_CREDIT, exact) at the game's Credits.GAME_CREDITS. The
## lead: *"each player is given 1000 credits per game ... Each vehicle has a cost"* (2026-10-05).
static func for_game(p_faction: String = Units.DEFAULT_FACTION) -> ArmyCatalog:
	var base := from_game()
	var profiles := {}
	for unit_id: String in Units.roster(p_faction):
		var profile: Dictionary = (Units.PROFILES[unit_id] as Dictionary).duplicate()
		profile["cost"] = Credits.of_points(int(profile["cost"]))
		profiles[unit_id] = profile
	var catalog := ArmyCatalog.new(profiles, base.weapons, Credits.GAME_CREDITS, base.max_squads, base.max_squad_size,
			base.max_units)
	catalog.is_game = true
	catalog.faction = p_faction
	catalog.points_per_credit = Credits.POINTS_PER_CREDIT
	return catalog


## The faction a saved army belongs to: its `garage.faction` (round 19 saves), else its first vehicle's, else the
## Condemned (every army before round 19 was Condemned).
static func faction_of_army(doctrine: Dictionary) -> String:
	var garage: Variant = doctrine.get("garage")
	if garage is Dictionary and Units.FACTIONS.has(String((garage as Dictionary).get("faction", ""))):
		return String(garage["faction"])
	for item: Dictionary in Doctrine.entries(doctrine):
		var unit_id := String((item["entry"] as Dictionary).get("unit", ""))
		if Units.exists(unit_id):
			return Units.faction_of(unit_id)
	return Units.DEFAULT_FACTION


## The budget in the simulation's points: what the fight is fought at (5,000 for the garage's 1000 credits).
func budget_points() -> int:
	return budget * points_per_credit


## An amount of this catalog's money as the player reads it: "40 CR" for a credits catalog, "40" in points.
func money(amount: int) -> String:
	return Credits.text(amount) if points_per_credit == Credits.POINTS_PER_CREDIT else str(amount)


## A copy with another budget and unlock set (the same units and limits).
func with_budget(p_budget: int, p_unlocked: Variant = unlocked) -> ArmyCatalog:
	var copy := ArmyCatalog.new(units, weapons, p_budget, max_squads, max_squad_size, max_units)
	copy.unlocked = p_unlocked
	copy.is_game = is_game
	copy.faction = faction
	copy.points_per_credit = points_per_credit
	return copy


# ---- Reading ------------------------------------------------------------------------------------

## Unit ids, starters first, then by unlock tier, then cheapest (ties by id): a stable, sensible order.
func unit_ids() -> Array[String]:
	var ids: Array[String] = []
	for id: String in units:
		ids.append(id)
	ids.sort_custom(func(a: String, b: String) -> bool:
		var tier_a := unlock_tier(a)
		var tier_b := unlock_tier(b)
		if tier_a != tier_b:
			return tier_a < tier_b
		return unit_cost(a) < unit_cost(b) if unit_cost(a) != unit_cost(b) else a < b)
	return ids


func has_unit(unit_id: String) -> bool:
	return units.has(unit_id)


func unit(unit_id: String) -> Dictionary:
	return units.get(unit_id, {})


func display_name(unit_id: String) -> String:
	return String(unit(unit_id).get("display_name", unit_id.capitalize()))


func unit_cost(unit_id: String) -> int:
	return int(unit(unit_id).get("cost", 0))


func unlock_tier(unit_id: String) -> int:
	return int(unit(unit_id).get("unlock_tier", 0))


func is_unlocked(unit_id: String) -> bool:
	return has_unit(unit_id) and (unlocked == null or (unlocked as Array).has(unit_id))


func role(unit_id: String) -> String:
	return String(unit(unit_id).get("role", unit_id))


static func role_label(role_id: String) -> String:
	return String(ROLE_LABELS.get(role_id, role_id.capitalize()))


func blurb(unit_id: String) -> String:
	return String(unit(unit_id).get("blurb", ""))


## Roles this unit is designed to beat / to fear (design intent; the mechanics decide real fights).
func good_vs(unit_id: String) -> Array:
	return unit(unit_id).get("good_vs", [])


func weak_vs(unit_id: String) -> Array:
	return unit(unit_id).get("weak_vs", [])


func weapon_id(unit_id: String) -> String:
	return String(unit(unit_id).get("weapon", ""))


func weapon(unit_id: String) -> Dictionary:
	return weapons.get(weapon_id(unit_id), {})


func weapon_name(unit_id: String) -> String:
	var id := weapon_id(unit_id)
	return String(weapon(unit_id).get("display_name", id.replace("_", " ").capitalize()))


## "Fixed forward gun" / "Turret"
func mount_label(unit_id: String) -> String:
	return "fixed forward mount" if String(unit(unit_id).get("mount", "turret")) == "fixed" else "turret"


## Units whose role is `role_id`, in unit_ids() order.
func units_with_role(role_id: String) -> Array[String]:
	var found: Array[String] = []
	for id in unit_ids():
		if role(id) == role_id:
			found.append(id)
	return found


## "Good vs Artillery, Lancer" (roles the catalog has names for), or "" if none.
func matchup_text(unit_id: String, strong: bool) -> String:
	var roles: Array = good_vs(unit_id) if strong else weak_vs(unit_id)
	if roles.is_empty():
		return ""
	return "%s %s" % ["Good vs" if strong else "Weak vs", ", ".join(roles.map(func(r: Variant) -> String: return role_label(String(r))))]


## [{key, label, value, ratio}] for the stat bars: ratio is value / the best in the catalog.
func unit_stat_bars(unit_id: String) -> Array[Dictionary]:
	var bars: Array[Dictionary] = []
	for stat in UNIT_STATS:
		var best := 0.0
		for other: Dictionary in units.values():
			best = maxf(best, float(other.get(stat[0], 0.0)))
		if best <= 0.0:
			continue
		var value := float(unit(unit_id).get(stat[0], 0.0))
		bars.append({"key": stat[0], "label": stat[1], "value": value, "ratio": clampf(value / best, 0.0, 1.0)})
	return bars


## Round 15 (H2; round 14's tour: "is the scout as big as the bus?" -- the turntable frames every unit to its panel):
## the unit's length in metres, the collision box the match uses (`hull_size[2]`), 0 when the catalog has none.
func length_m(unit_id: String) -> float:
	var hull: Variant = unit(unit_id).get("hull_size")
	return float(hull[2]) if hull is Array and (hull as Array).size() >= 3 else 0.0


## "9.7 m long" (one decimal), or "" without a hull size.
func length_text(unit_id: String) -> String:
	var length := length_m(unit_id)
	return "%.1f m long" % length if length > 0.0 else ""


## "Cannon on a turret: Hit 34  Range 70 m  Reload 2.5 s"
func weapon_summary(unit_id: String) -> String:
	var parts: PackedStringArray = []
	var profile := weapon(unit_id)
	for stat in WEAPON_STATS:
		if profile.has(stat[0]) and not is_zero_approx(float(profile[stat[0]])):
			parts.append("%s %s%s" % [stat[1], number(profile[stat[0]]), stat[2]])
	return "%s, %s: %s" % [weapon_name(unit_id), mount_label(unit_id), "  ".join(parts)]


static func number(value: Variant) -> String:
	var n := float(value)
	return str(int(n)) if is_equal_approx(n, roundf(n)) else "%.1f" % n
