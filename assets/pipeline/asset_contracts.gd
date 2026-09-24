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
	# The Syndicate broadcast airship (round 11, the lead's airship_r11_m). Fitted by LENGTH, because length is the
	# only dimension the lead's camera leaves free: at his pose (21 deg, FOV 35, boom 49 m) the camera sits at 17.56 m
	# and the frame's top edge is 3.5 deg BELOW the horizon, so the hull's deck -- which is where its screens are --
	# must stay under 17.31 m or it turns away from him, while the belly must stay above 6.45 m or it passes through
	# the tallest hull (6.18 m). Those two walls are 10.86 m apart, and this mesh is 0.2704 of its length from belly to
	# deck, which puts a HARD CEILING of 40.2 m on the airship. 38 m is that ceiling with ~0.3 m of margin at each
	# wall (belly 6.74 m, deck 17.02 m, altitude 14.0 m). Seen broadside at 45 m that is ~1446 px of a 1920 frame
	# against the round-10 blimp's ~837 -- GEOMETRY, not a measurement: it is 38 m subtended at that range, and what
	# he actually sees is usually a three-quarter view, often part-occluded. `test_theme_ad_airship.gd` holds the
	# arithmetic so a later resize cannot quietly break the look.
	"arena.airship": {
		"guide": Vector3(14.8, 14.5, 38.0), "max": Vector3(100.0, 100.0, 38.0), "fit": "length",
		"anchor": "center",
		"tris": 30000, "methods": [], "elongated": "z", "file": "arena_airship",
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
## The roster units whose slots the pipeline enforces a contract for. **Ids only: the numbers are NOT here.**
## Round 9 (scale's finding, Invariant 0): this used to be a table carrying its own copy of `hull_size` and
## `muzzle_height`, with no test tying it to `Units.PROFILES` -- and it had already drifted (the tank 1.6 m tall here
## against 2.4 m in the catalog, the IFV 1.6 against 3.0). Inert for gameplay, but every model generated after the
## roster resize would have been normalised to the old toy sizes, silently. The catalog is the only source now.
const UNITS := ["scout", "tank", "ifv", "artillery", "lancer"]
## The hull the turret scale is measured against (`Tank._apply_hull_size`): the Condemned tank's, read from the
## catalog like everything else.
static var STANDARD_HULL: Vector3:
	get: return hull_size_of("tank")


## A unit's collision box from the catalog, as a Vector3.
static func hull_size_of(unit_id: String) -> Vector3:
	var size: Variant = Units.stat(unit_id, "hull_size")
	return Vector3(float(size[0]), float(size[1]), float(size[2])) if size is Array else Vector3.ZERO
const MUZZLE_ABOVE_PIVOT := 0.05
const TURRET_Z := 0.2
## Generated units are taller than their collision box (a garbage truck is taller than wide); their hull art may rise
## this much above hull_size.y so trucks aren't shrunk to toys (art X4 decision; gameplay collision is unchanged).
const UNIT_ART_HEIGHT := 1.35


## K4 (round 3, assets X4): faction art slots `unit.<faction>.<role>.<part>` (gallery only this round) fit the numbers of
## the Condemned unit in the same role until factions get catalog entries of their own. Unit key: "<faction>.<role>".
const FACTIONS := ["gangs", "law", "syndicate"]
## The ART ROLES a faction slot may name. Which UNIT fills each is read from the faction's own roster
## (`catalog_unit`), not from this table -- see `unit_info`.
const ROLE_UNITS := {"scout": "scout", "ifv": "ifv", "tank": "tank", "artillery": "artillery", "special": "lancer"}
## Round 9 (feel): how far a refitted unit hull's SHAPE may differ from its slot's, as a fraction. 6%, because
## `SizeLook.box_at_length` rounds to 0.01 m and an exact match still carries that rounding on a short axis.
const SHAPE_TOLERANCE := 0.06


## The catalog numbers for a roster unit ("ifv") or a faction role ("gangs.tank"). Read from `Units.PROFILES`
## every time -- never cached, never copied.
##
## ROUND 9 (scale, CP2): a faction role resolves to THAT FACTION'S OWN unit. It used to resolve to the Condemned
## unit in the same role -- a round-3 stand-in whose own comment said *"until factions get catalog entries of
## their own"*, which they have had since round 4. So `unit.gangs.tank.hull` was contracted against the Condemned
## tank's box rather than the War Rig's.
##
## It was invisible while every hull was 2.8-5.0 m long: a stand-in is only wrong when the thing it stands in for
## differs. S1 spread the roster from 2.93 m to 14.0 m and **11 of the 14 faction art slots stopped matching their
## stand-in**, while every one of them matches its OWN box. That is the stand-in failing, not the art.
static func unit_info(unit: String) -> Dictionary:
	var unit_id := catalog_unit(unit)
	if unit_id == "":
		return {}
	return {"hull_size": hull_size_of(unit_id), "muzzle_height": float(Units.stat(unit_id, "muzzle_height", 1.27))}


## The catalog unit an art slot is contracted against: "ifv" -> "ifv", "gangs.tank" -> "gang_tank". "" if there
## is none. The faction's roster is READ (Units.roster + Units.role_of + FactionArt.art_role), never tabulated --
## a second table of which unit fills which faction role is exactly the stand-in this replaced.
static func catalog_unit(unit: String) -> String:
	if not unit.contains("."):
		# ANY catalog unit, not just the Condemned five `UNITS` lists: `UNITS` is which SLOTS the pipeline names,
		# and a caller asking for "gang_tank" is asking about a unit, not about a slot.
		return unit if Units.PROFILES.has(unit) else ""
	var faction := unit.get_slice(".", 0)
	var art_role := unit.get_slice(".", 1)
	for unit_id in Units.roster(faction):
		if FactionArt.art_role(Units.role_of(unit_id)) == art_role:
			return unit_id
	return ""


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
