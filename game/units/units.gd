class_name Units
extends RefCounted
## The unit catalog: fixed unit types as DATA (like Weapons.PROFILES). Contract C1 in
## _agents/workstreams.md; owned by the rules stream. The simulation reads it (Tank.apply_unit), the army
## builder lists it, the AI reads roles and mounts, and art fills `unit.<id>.*` visual slots for it.
##
## Round 2 (2026-09-15, the lead): *"simple units … static throughout gameplay … like rock-paper-scissors."*
## Every unit is a fixed package: chassis, ONE weapon, how that weapon is mounted, armor, speed, sight, cost.
## No loadouts, components, or hardpoints. Counters come from mechanics (turret tracking, fixed arcs,
## penetration vs armor facing, minimum range), never from a damage table (see _agents/balance.md).
##
## Keys (all required unless marked optional):
##   display_name, role (ROLES), blurb (one line for the army UI), cost (points), unlock_tier (0 = starter)
##   hull_size [w, h, l] meters (the collision box), max_health, max_shield, shield_recharge_delay (s),
##   shield_recharge_rate (/s), max_forward_speed, max_reverse_speed (m/s), hull_turn_rate_deg (/s),
##   sight_radius (m), weapon (a Weapons.PROFILES id), mount ("turret" or "fixed"),
##   turret_turn_rate_deg (/s: how fast a turret, or a fixed mount's small gimbal, swings),
##   fire_arc_deg (fixed mounts: the full forward arc the gun can point into; the hull aims the rest),
##   muzzle_height (m above the ground where rounds leave; must stay below every hull's top, see
##   MUZZLE_CLEARANCE), armor {front, side, rear} (thickness against Weapons "penetration"),
##   good_vs / weak_vs (role lists: design intent for AI hints and the army UI; mechanics decide outcomes),
##   optional heat_capacity / heat_dissipation (only units whose weapon heats: the Lancer).
##   K3 (round 3): locomotion (LOCOMOTIONS), min_turn_radius_m (wheels: the tightest circle at any speed),
##   acceleration_mps2, braking_mps2, lateral_grip (0..1: how much sideways slide the tires kill per second; lower drifts).
##
## Keep existing keys stable. Renaming or removing one is a contract change (_agents/workstreams.md).

const SCHEMA_VERSION := 2
## v2 (2026-09-15, round 2 R1): fixed unit types. Removed: class (now role), hardpoints, component_slots,
## COMPONENTS, loadouts. Added: role, blurb, unlock_tier, weapon, mount, fire_arc_deg, muzzle_height,
## armor, good_vs, weak_vs; the IFV and the Lancer.

const ROLES := ["scout", "tank", "ifv", "artillery", "lancer", "burner"]
const MOUNTS := ["turret", "fixed"]
## K3: how a hull moves. Tracks pivot in place; wheels need speed to turn (a turning circle). Hover and articulated
## are reserved for later factions.
const LOCOMOTIONS := ["tracks", "wheels", "hover", "articulated"]
## Rounds fly flat at muzzle height, so every muzzle must sit below the shortest hull's top by this much
## (orientation trip-up 15: shells once flew over every tank).
const MUZZLE_CLEARANCE := 0.1

## Points a player spends on an army per match. A standard tank is 200.
const DEFAULT_BUDGET := 1000

const PROFILES := {
	# The lead: "the scout vehicles can have no turret, and they just have a machine gun that shoots
	# straight forward, so they can only shoot at what they point at." Fast, fragile, far-sighted.
	"scout": {
		"display_name": "Scout",
		"role": "scout",
		"blurb": "Fast rally truck with a hood-mounted machine gun. Sees far; hunts artillery and Lancers.",
		"cost": 110,
		"unlock_tier": 0,
		"hull_size": [2.0, 1.4, 3.0],
		"max_health": 140,
		"max_shield": 80,
		"shield_recharge_delay": 3.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 14.0,
		"max_reverse_speed": 7.0,
		"hull_turn_rate_deg": 140.0,
		"sight_radius": 110.0,
		# K3 locomotion (round 3 X1: today's driving, tracks for all; combat X4 moves the light units to wheels).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		"lateral_grip": 1.0,
		"weapon": "machine_gun",
		"mount": "fixed",
		"turret_turn_rate_deg": 200.0,
		"fire_arc_deg": 16.0,
		"muzzle_height": 1.12,
		"armor": {"front": 2.0, "side": 1.0, "rear": 1.0},
		"good_vs": ["artillery", "lancer"],
		"weak_vs": ["ifv"],
	},
	# The prison-bus dozer. The lead: "A tank turret moves slow so it would have a hard time tracking a scout."
	"tank": {
		"display_name": "Tank",
		"role": "tank",
		"blurb": "The armored prison-bus dozer. Heavy cannon on a slow turret; thick front armor.",
		"cost": 200,
		"unlock_tier": 0,
		"hull_size": [2.4, 1.6, 3.6],
		"max_health": 300,
		"max_shield": 150,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 50.0,
		"max_forward_speed": 9.0,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 80.0,
		"sight_radius": 75.0,
		# K3 locomotion (round 3 X1: today's driving, tracks for all; combat X4 moves the light units to wheels).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		"lateral_grip": 1.0,
		"weapon": "cannon",
		"mount": "turret",
		# R2: 110 -> 50 (the lead's "slow turret"): a scout crossing at 15 m sweeps ~53°/s, faster than it turns.
		"turret_turn_rate_deg": 50.0,
		"muzzle_height": 1.27,
		"armor": {"front": 8.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["ifv", "tank"],
		"weak_vs": ["scout"],
	},
	# The lead: "some in between vehicle (think a Bradley or a Stryker) that has the equivalent of 30 mm cannons."
	"ifv": {
		"display_name": "IFV",
		"role": "ifv",
		"blurb": "Armored troop bus with a 30 mm autocannon on a fast turret. Shreds scouts; can't crack tank fronts.",
		"cost": 150,
		"unlock_tier": 0,
		"hull_size": [2.4, 1.6, 3.8],
		"max_health": 220,
		"max_shield": 100,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 11.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 100.0,
		"sight_radius": 85.0,
		# K3 locomotion (round 3 X1: today's driving, tracks for all; combat X4 moves the light units to wheels).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		"lateral_grip": 1.0,
		"weapon": "autocannon",
		"mount": "turret",
		"turret_turn_rate_deg": 180.0,
		"muzzle_height": 1.27,
		"armor": {"front": 5.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["scout"],
		"weak_vs": ["tank"],
	},
	# Indirect fire at what teammates spot. Slow, fragile, nearly blind, long reach.
	"artillery": {
		"display_name": "Artillery",
		"role": "artillery",
		"blurb": "Crane carrier with a mortar battery. Shells what teammates spot; helpless up close.",
		"cost": 220,
		"unlock_tier": 1,
		"hull_size": [2.6, 1.6, 4.0],
		"max_health": 200,
		"max_shield": 80,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 6.5,
		"max_reverse_speed": 3.5,
		"hull_turn_rate_deg": 60.0,
		"sight_radius": 60.0,
		# K3 locomotion (round 3 X1: today's driving, tracks for all; combat X4 moves the light units to wheels).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		"lateral_grip": 1.0,
		"weapon": "mortar",
		"mount": "turret",
		"turret_turn_rate_deg": 70.0,
		"muzzle_height": 1.27,
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
		"good_vs": ["tank", "artillery"],
		"weak_vs": ["scout"],
	},
	# The lead: "the laser is awesome, but we'll just move that to a different unit type."
	"lancer": {
		"display_name": "Lancer",
		"role": "lancer",
		"blurb": "Converted power-utility truck with a long laser. Strips shields at range; overheats.",
		"cost": 200,
		"unlock_tier": 1,
		"hull_size": [2.4, 1.6, 3.8],
		"max_health": 200,
		"max_shield": 120,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 8.5,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 80.0,
		# R7: sight 80 -> 85 (it must see what its 85 m beam reaches); turret 80 -> 55°/s, so fast IFVs get inside it.
		"sight_radius": 85.0,
		# K3 locomotion (round 3 X1: today's driving, tracks for all; combat X4 moves the light units to wheels).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		"lateral_grip": 1.0,
		"weapon": "laser",
		"mount": "turret",
		"turret_turn_rate_deg": 55.0,
		"muzzle_height": 1.27,
		"armor": {"front": 4.0, "side": 3.0, "rear": 2.0},
		"heat_capacity": 100.0,
		"heat_dissipation": 12.0,
		"good_vs": ["tank"],
		"weak_vs": ["scout", "ifv"],
	},
	# Stretch (rules, 2026-09-14): the Burner, the flamethrower's own unit (game_design.md "a close-range Burner").
	# A close-range brawler: it must cross open ground under fire, then out-damages what it reaches and burns through
	# shields. A cannon through its thin front and a Lancer's standoff range stop it.
	"burner": {
		"display_name": "Burner",
		"role": "burner",
		"blurb": "Plow-nosed fire truck with a flamethrower. Melts light hulls and artillery it reaches; tanks and Lancers stop it first.",
		# Stretch tuning (2026-09-14, `make matchups ... --focus burner`): at 160 pts, 12 m/s, front armor 7, hull 260 it won
		# 100% of every matchup; at these values it beats IFVs 67% and artillery 83%, loses to tanks and Lancers.
		"cost": 220,
		"unlock_tier": 2,
		"hull_size": [2.4, 1.6, 3.8],
		"max_health": 220,
		"max_shield": 100,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 10.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 110.0,
		"sight_radius": 70.0,
		# K3 locomotion (round 3 X1: today's driving, tracks for all; combat X4 moves the light units to wheels).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		"lateral_grip": 1.0,
		"weapon": "flamethrower",
		"mount": "turret",
		"turret_turn_rate_deg": 120.0,
		"muzzle_height": 1.27,
		"armor": {"front": 4.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["ifv", "artillery"],
		"weak_vs": ["tank", "lancer"],
	},
}

## The unit a bare spawn (network players, legacy bots) drives.
const DEFAULT := "tank"
## Keys a v1 army entry used. Army JSON v2 rejects them with V1_KEY_HELP.
const V1_UNIT_KEYS := ["weapon", "weapons", "components"]
const V1_KEY_HELP := "units have fixed weapons since army JSON v2: pick a unit type (%s) instead of '%s'"


## "" or a human-readable reason one army entry ({"unit", "paint"?, "directive"?}) is invalid. The
## directive is validated by the doctrine parser (it knows Directives).
static func validate_entry(entry: Dictionary) -> String:
	for key: String in V1_UNIT_KEYS:
		if entry.has(key):
			return V1_KEY_HELP % [", ".join(ids()), key]
	if not entry.has("unit"):
		return "every unit needs a 'unit' type (%s)" % ", ".join(ids())
	var unit_id: Variant = entry["unit"]
	if typeof(unit_id) != TYPE_STRING or not PROFILES.has(unit_id):
		return "unknown unit '%s' (have %s)" % [unit_id, ", ".join(ids())]
	var paint: Variant = entry.get("paint", "")
	if typeof(paint) != TYPE_STRING or (paint != "" and not Color.html_is_valid(paint)):
		return "paint must be an HTML color like \"#3a5f2b\""
	return ""


## Points one army entry costs (0 for an unknown unit).
static func cost_of(entry: Dictionary) -> int:
	var unit_id: Variant = entry.get("unit", "")
	return int(PROFILES[unit_id]["cost"]) if typeof(unit_id) == TYPE_STRING and PROFILES.has(unit_id) else 0


## Points a whole army (doctrine) costs.
static func army_cost(doctrine: Dictionary) -> int:
	var total := 0
	for squad in doctrine.get("squads", []):
		for entry in squad.get("units", []):
			total += cost_of(entry)
	return total


## Unit ids in catalog order (cheap and early roles first).
static func ids() -> PackedStringArray:
	var result: PackedStringArray = []
	for unit_id: String in PROFILES:
		result.append(unit_id)
	return result


## Unit ids with this role.
static func with_role(role: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for unit_id: String in PROFILES:
		if PROFILES[unit_id]["role"] == role:
			result.append(unit_id)
	return result


## A unit's role ("" for an unknown id).
static func role_of(unit_id: String) -> String:
	return String(PROFILES.get(unit_id, {}).get("role", ""))


## Experiment overrides ("unit.key" -> value), set from `--tune=` by the match runner and skirmish.
## Never set in normal play. Read through stat(); Tank reads its stats at spawn.
static var tuning := {}


## A unit's stat, honoring `tuning`. Optional keys a unit lacks read as `fallback`.
static func stat(unit_id: String, key: String, fallback: Variant = null) -> Variant:
	var tuned_key := "%s.%s" % [unit_id, key]
	if tuning.has(tuned_key):
		return tuning[tuned_key]
	return PROFILES[unit_id].get(key, fallback)


## Parse "tank.max_shield=0,cannon.ammo=60,tank.armor.front=6" into Units.tuning and Weapons.tuning.
## Returns "" or an error. Keys must exist; values become numbers. One level of nesting is allowed
## (armor facings).
static func apply_tuning(spec: String) -> String:
	for pair in spec.split(",", false):
		var parts := pair.split("=")
		var path := parts[0].split(".")
		if parts.size() != 2 or path.size() < 2 or path.size() > 3 or not parts[1].is_valid_float():
			return "tune: expected owner.key=number, got '%s'" % pair
		var is_unit := PROFILES.has(path[0])
		var owner: Dictionary = PROFILES.get(path[0], Weapons.PROFILES.get(path[0], {}))
		var value: Variant = owner.get(path[1])
		if path.size() == 3:
			value = value.get(path[2]) if typeof(value) == TYPE_DICTIONARY else null
		if value == null:
			return "tune: no stat '%s'" % parts[0]
		if is_unit:
			tuning[parts[0]] = float(parts[1])
		else:
			Weapons.tuning[parts[0]] = float(parts[1])
	return ""


## A unit's armor on one face ("front"/"side"/"rear"), honoring `--tune=unit.armor.face=`.
static func armor(unit_id: String, face: String) -> float:
	var tuned_key := "%s.armor.%s" % [unit_id, face]
	if tuning.has(tuned_key):
		return float(tuning[tuned_key])
	return float(PROFILES.get(unit_id, PROFILES[DEFAULT])["armor"][face])


static func exists(unit_id: String) -> bool:
	return PROFILES.has(unit_id)


static func profile(unit_id: String) -> Dictionary:
	return PROFILES.get(unit_id, {})
