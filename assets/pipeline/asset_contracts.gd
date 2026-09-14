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
	"prop.crate": {
		"guide": Vector3(4.5, 3.0, 4.5), "fit": "stretch", "anchor": "ground_center",
		"tris": 2000, "methods": [], "file": "prop_crate",
	},
	"prop.wall": {
		"guide": Vector3(18.0, 3.0, 1.5), "fit": "stretch", "anchor": "ground_center",
		"tris": 3000, "methods": [], "elongated": "x", "file": "prop_wall",
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
}


static func has(slot: String) -> bool:
	return SLOTS.has(slot) or CANDIDATES.has(slot)


static func get_contract(slot: String) -> Dictionary:
	var contract: Dictionary = SLOTS.get(slot, CANDIDATES.get(slot, {})).duplicate()
	if contract.is_empty():
		return contract
	if not contract.has("max"):
		contract["max"] = contract["guide"]
	contract.merge({"methods": [], "elongated": "", "textures": MAX_TEXTURE,
			"file": slot.replace(".", "_")})
	return contract


static func all_slots() -> Array:
	return SLOTS.keys() + CANDIDATES.keys()
