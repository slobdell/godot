class_name AssetContracts
extends RefCounted
## The visual slot contracts (_agents/slot_contracts.md) as data, so the
## normalizer can fit a model to a slot and the checker can enforce it.
##
## Units are meters, forward is −Z, up is +Y. Fields:
##   guide     the size the gameplay collision / placeholder art expects (x = width, y = height, z = length)
##   max       hard bounds a normalized model must fit inside (defaults to guide)
##   fit       "contain": uniform scale into `max` (vehicles keep proportions)
##             "stretch": non-uniform scale to exactly `guide` (props must match their collision box)
##             "length":  uniform scale so the Z extent equals guide.z (barrels: the muzzle position matters)
##             "none":    leave scale alone (world-space dressing)
##   anchor    "ground_center": x/z centered, bottom at y = 0
##             "center":        bounds center at the origin
##             "barrel":        x centered, y centered on `barrel_y`, back end at z = `barrel_back`
##             "turret":        x/z centered, bottom at y = `turret_bottom` (sits on the default hull deck)
##             "world":         untouched
##   tris      triangle budget          textures  max texture edge (px)
##   methods   optional methods the wrapper scene implements
##   elongated "z" or "x": which horizontal axis must be the long one (orientation sanity check)

const MAX_TEXTURE := 1024
## A normalized model is "at the right size" when bounds sit within this fraction of the target.
const SIZE_TOLERANCE := 0.05
## ...and when it fills at least this much of the guide on its tightest axis (contain fits).
const MIN_FILL := 0.8
## From game/tank/tank.tscn: the turret pivot's height above the ground. The turret contract puts the turret's
## bottom at this height − 0.275 (the default hull deck); taller hulls raise turret + cannon visuals by
## (hull roof − that deck) so the turret sits on the roof (options.raise, recorded in the manifest).
const TURRET_PIVOT_Y := 1.22
const DEFAULT_DECK_Y := TURRET_PIVOT_Y - 0.275

## Anchor positions must match within this many meters.
const ANCHOR_TOLERANCE := 0.05

const SLOTS := {
	# 15k (art X1, 2026-09-14): generated hulls keep the generator's detail; 8k flattened the dozer's treads.
	"tank.hull": {
		"guide": Vector3(2.4, 1.6, 3.6), "fit": "contain", "anchor": "ground_center",
		"tris": 15000, "methods": ["set_team_color"], "elongated": "z", "file": "tank_hull",
	},
	"tank.turret": {
		"guide": Vector3(1.4, 0.55, 1.7), "max": Vector3(1.8, 0.9, 2.1), "fit": "contain",
		"anchor": "turret", "turret_bottom": -0.275,
		"tris": 4000, "methods": ["set_team_color"], "file": "tank_turret",
	},
	"weapon.cannon": {
		"guide": Vector3(0.3, 0.3, 2.5), "max": Vector3(0.7, 0.7, 2.5), "fit": "length",
		"anchor": "barrel", "barrel_back": -0.7, "barrel_y": 0.05,
		"tris": 2000, "methods": ["set_team_color", "setup"], "elongated": "z", "file": "weapon_cannon",
	},
	"weapon.laser": {
		"guide": Vector3(0.3, 0.3, 2.5), "max": Vector3(0.8, 0.8, 2.5), "fit": "length",
		"anchor": "barrel", "barrel_back": -0.7, "barrel_y": 0.05,
		"tris": 2000, "methods": ["set_team_color", "setup", "set_firing", "set_heat"], "elongated": "z",
		"file": "weapon_laser",
	},
	"weapon.flamethrower": {
		"guide": Vector3(0.6, 0.6, 1.1), "max": Vector3(0.9, 0.9, 1.1), "fit": "length",
		"anchor": "barrel", "barrel_back": -0.75, "barrel_y": 0.05,
		"tris": 2000, "methods": ["set_team_color", "setup", "set_firing"], "elongated": "z",
		"file": "weapon_flamethrower",
	},
	"fx.shell": {
		"guide": Vector3(0.3, 0.3, 1.0), "fit": "contain", "anchor": "center",
		"tris": 200, "methods": [], "elongated": "z", "file": "fx_shell",
	},
	# Props 2k/3k → 4k/8k (art X6, 2026-09-14): generated props decimated to 2k lost their chains, sandbags and grilles.
	"prop.crate": {
		"guide": Vector3(4.5, 3.0, 4.5), "fit": "stretch", "anchor": "ground_center",
		"tris": 4000, "methods": [], "file": "prop_crate",
	},
	"prop.wall": {
		"guide": Vector3(18.0, 3.0, 1.5), "fit": "stretch", "anchor": "ground_center",
		"tris": 8000, "methods": [], "elongated": "x", "file": "prop_wall",
	},
	# The wreck a destroyed vehicle leaves (assets stretch, approved 2026-09-16): one husk scaled per unit, so it is fitted
	# to the standard tank hull and the wreck effects scale it from there.
	"prop.wreck": {
		"guide": Vector3(2.6, 1.7, 4.2), "fit": "contain", "anchor": "ground_center",
		"tris": 6000, "methods": [], "elongated": "z", "file": "prop_wreck",
	},
	"arena.dressing": {
		"guide": Vector3(320.0, 30.0, 320.0), "fit": "none", "anchor": "world",
		"tris": 50000, "methods": [], "file": "arena_dressing",
	},
}

## Candidate props that don't fill a gameplay slot yet (A4 procedural kit): same pipeline, looser rules.
## Look & feel decides whether they become slots or dressing.
const CANDIDATES := {
	"kit.container": {"guide": Vector3(2.4, 2.6, 6.1), "fit": "contain", "anchor": "ground_center", "tris": 1500},
	"kit.barrier": {"guide": Vector3(3.0, 1.1, 0.8), "fit": "contain", "anchor": "ground_center", "tris": 800},
	"kit.light_pole": {"guide": Vector3(1.2, 8.0, 3.0), "fit": "contain", "anchor": "ground_center", "tris": 800},
	"kit.billboard": {"guide": Vector3(8.0, 6.0, 3.0), "fit": "contain", "anchor": "ground_center", "tris": 1000},
	"kit.scrap_pile": {"guide": Vector3(5.0, 2.0, 5.0), "fit": "contain", "anchor": "ground_center", "tris": 1500},
	# Gladiator arena dressing (art X5, the lead's approved concepts): modules placed around the perimeter by the dressing.
	"kit.scrap_heap": {"guide": Vector3(4.5, 3.0, 4.5), "max": Vector3(4.5, 3.4, 4.5), "fit": "contain", "anchor": "ground_center", "tris": 4000},
	"kit.stands": {"guide": Vector3(24.0, 16.0, 20.0), "fit": "contain", "anchor": "ground_center", "tris": 12000},
	"kit.gate": {"guide": Vector3(24.0, 12.0, 5.0), "fit": "contain", "anchor": "ground_center", "tris": 10000},
	"kit.floodlight_tower": {"guide": Vector3(9.0, 24.0, 9.0), "fit": "contain", "anchor": "ground_center", "tris": 8000},
}


## Round 2 unit types (rules' catalog v2, contract C1, `Units.PROFILES` on stream/rules 2026-09-14): the numbers art
## needs to fit `unit.<id>.hull/turret/weapon` (_agents/slot_contracts.md). The tank places per-unit art this way:
## the hull is not rescaled; the turret node sits at (0, muzzle_height − 0.05, 0.2) and is scaled by
## min(width, length) ratio to the standard tank hull (2.4 × 3.6); rounds leave 3.2 m ahead of it (× that scale).
const UNITS := {
	"scout": {"hull_size": Vector3(2.0, 1.4, 3.0), "muzzle_height": 1.12},
	"tank": {"hull_size": Vector3(2.4, 1.6, 3.6), "muzzle_height": 1.27},
	"ifv": {"hull_size": Vector3(2.4, 1.6, 3.8), "muzzle_height": 1.27},
	"artillery": {"hull_size": Vector3(2.6, 1.6, 4.0), "muzzle_height": 1.27},
	"lancer": {"hull_size": Vector3(2.4, 1.6, 3.8), "muzzle_height": 1.27},
}
const STANDARD_HULL := Vector3(2.4, 1.6, 3.6)
const MUZZLE_ABOVE_PIVOT := 0.05
const TURRET_Z := 0.2
## Generated units are taller than their collision box (a garbage truck is taller than wide); their hull art may rise
## this much above hull_size.y so trucks aren't shrunk to toys (art X4 decision; gameplay collision is unchanged).
const UNIT_ART_HEIGHT := 1.35


## K4 (round 3, assets X4): faction art slots `unit.<faction>.<role>.<part>` (gallery only this round) fit the numbers of
## the Condemned unit in the same role until factions get catalog entries of their own. Unit key: "<faction>.<role>".
const FACTIONS := ["gangs", "law", "syndicate"]
const ROLE_UNITS := {"scout": "scout", "ifv": "ifv", "tank": "tank", "artillery": "artillery", "special": "lancer"}


## UNITS numbers for a roster unit ("ifv") or a faction role ("gangs.tank").
static func unit_info(unit: String) -> Dictionary:
	if UNITS.has(unit):
		return UNITS[unit]
	return UNITS[ROLE_UNITS[unit.get_slice(".", 1)]] if unit.contains(".") else {}


## Where a unit's turret node sits in hull space, and its scale (both from Tank._apply_hull_size on stream/rules).
static func unit_pivot(unit: String) -> Dictionary:
	var info := unit_info(unit)
	var size: Vector3 = info["hull_size"]
	var turret_scale := 1.0 if size.is_equal_approx(STANDARD_HULL) else minf(size.x / STANDARD_HULL.x, size.z / STANDARD_HULL.z)
	return {"pivot": Vector3(0.0, float(info["muzzle_height"]) - MUZZLE_ABOVE_PIVOT, TURRET_Z), "turret_scale": turret_scale}


## "unit.scout.hull" → "scout", "unit.gangs.tank.hull" → "gangs.tank" (or "" for any other slot).
static func unit_of(slot: String) -> String:
	var parts := slot.split(".")
	if parts.size() == 3 and parts[0] == "unit" and UNITS.has(parts[1]):
		return parts[1]
	if parts.size() == 4 and parts[0] == "unit" and FACTIONS.has(parts[1]) and ROLE_UNITS.has(parts[2]):
		return "%s.%s" % [parts[1], parts[2]]
	return ""


static func _unit_contract(slot: String) -> Dictionary:
	var unit := unit_of(slot)
	if unit == "":
		return {}
	var file := slot.replace(".", "_")
	var info := unit_info(unit)
	match slot.get_slice(".", slot.get_slice_count(".") - 1):
		"hull":
			return {"guide": info["hull_size"], "max": (info["hull_size"] as Vector3) * Vector3(1.0, UNIT_ART_HEIGHT, 1.0),
					"fit": "contain", "anchor": "ground_center", "tris": 15000,
					"methods": ["set_team_color"], "elongated": "z", "file": file}
		"turret":
			var turret: Dictionary = SLOTS["tank.turret"].duplicate()
			turret["file"] = file
			return turret
		"weapon":
			var weapon: Dictionary = SLOTS["weapon.cannon"].duplicate()
			weapon["file"] = file
			return weapon
	return {}


static func has(slot: String) -> bool:
	return SLOTS.has(slot) or CANDIDATES.has(slot) or not _unit_contract(slot).is_empty()


static func get_contract(slot: String) -> Dictionary:
	var contract: Dictionary = SLOTS.get(slot, CANDIDATES.get(slot, _unit_contract(slot))).duplicate()
	if contract.is_empty():
		return contract
	if not contract.has("max"):
		contract["max"] = contract["guide"]
	contract.merge({"methods": [], "elongated": "", "textures": MAX_TEXTURE,
			"file": slot.replace(".", "_")})
	return contract


static func all_slots() -> Array:
	var unit_slots := []
	for unit in UNITS:
		for part in ["hull", "turret", "weapon"]:
			unit_slots.append("unit.%s.%s" % [unit, part])
	for faction in FACTIONS:
		for role in ROLE_UNITS:
			for part in ["hull", "turret", "weapon"]:
				unit_slots.append("unit.%s.%s.%s" % [faction, role, part])
	return SLOTS.keys() + CANDIDATES.keys() + unit_slots
