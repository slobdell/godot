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
##   hull_size [w, h, l] meters (the collision box; S1: derived, see scale_reference and SCALE_K below),
##   S1 (round 9) optional scale_reference {vehicle: String, length_m: float, source: String} -- the real-world
##     vehicle this unit is drawn as, its cited length, and where that length comes from. hull_size[2] is
##     length_m x SCALE_K and hull_size[0]/[1] are the approved mesh's proportions at that length
##     (SizeLook.box_at_length). `make roster-scale` prints the whole table; tests/test_units_scale.gd asserts it.
##   max_health, max_shield, shield_recharge_delay (s),
##   shield_recharge_rate (/s), max_forward_speed, max_reverse_speed (m/s), hull_turn_rate_deg (/s),
##   sight_radius (m), weapon (a Weapons.PROFILES id), mount ("turret" or "fixed"),
##   turret_turn_rate_deg (/s: how fast a turret, or a fixed mount's small gimbal, swings),
##   fire_arc_deg (fixed mounts: the full forward arc the gun can point into; the hull aims the rest),
##   muzzle_height (m above the ground where rounds leave; must stay below every hull's top, see
##   MUZZLE_CLEARANCE), armor {front, side, rear} (thickness against Weapons "penetration"),
##   good_vs / weak_vs (role lists: design intent for AI hints and the army UI; mechanics decide outcomes),
##   optional heat_capacity / heat_dissipation (only units whose weapon heats: the Lancer).
##   K3 (round 3): locomotion (LOCOMOTIONS), min_turn_radius_m (wheels: the tightest circle at any speed),
##   acceleration_mps2, braking_mps2, lateral_grip (0..1: the fraction of sideways slide the tires kill each tick; lower
##   drifts). Optional deploy_seconds / pack_seconds (X5: units that must stand and deploy before firing).
##   On wheels, hull_turn_rate_deg is the most yaw per second at any speed (TankMotion.step_in_place).
##   L3 (round 4): faction (FACTIONS; missing = DEFAULT_FACTION), and optional repair_radius_m /
##   repair_hp_per_second for units that mend nearby friendlies in the field (Match._resupply).
##
## Keep existing keys stable. Renaming or removing one is a contract change (_agents/workstreams.md).

const SCHEMA_VERSION := 2
## v2 (2026-09-15, round 2 R1): fixed unit types. Removed: class (now role), hardpoints, component_slots,
## COMPONENTS, loadouts. Added: role, blurb, unlock_tier, weapon, mount, fire_arc_deg, muzzle_height,
## armor, good_vs, weak_vs; the IFV and the Lancer.

## L3 (round 4) added "support" (the gangs' resupply tanker, which repairs what stands near it) and "suppressor"
## (the Law's sonic emitter). Every faction fills scout / tank / ifv / artillery plus one special role, so counters
## stay learnable across factions (game_design.md *Factions*: "same roles, wildly different trade-offs").
const ROLES := ["scout", "tank", "ifv", "artillery", "lancer", "burner", "support", "suppressor"]
## L3 (round 4, contract L3): the four factions (game_design.md *Factions*). Every faction fields the same core
## roles with its own costs and stats, so counters stay learnable while army SIZE falls out of cost: the road gangs
## swarm, then the Condemned, then the Law, and the Syndicate fields the fewest, best vehicles (the lead,
## 2026-09-16). Art for all four already exists (`game/theme/factions/`, K4 slots).
const FACTIONS := ["condemned", "gangs", "law", "syndicate"]
## Units without a `faction` key belong here, so every round-3 army and doctrine keeps working unchanged.
const DEFAULT_FACTION := "condemned"
const FACTION_NAMES := {"condemned": "The Condemned", "gangs": "Road Gangs", "law": "The Law",
		"syndicate": "The Syndicate"}
const MOUNTS := ["turret", "fixed"]
## K3: how a hull moves. Tracks pivot in place with no sideways slide; wheels need speed to turn (a turning circle)
## and slide on low grip. L3 (round 4) implements HOVER for the Syndicate: it swings to face like tracks, because
## nothing needs traction to do it, but nothing grips the ground either, so its momentum carries and it drifts
## (TankMotion.step_in_place). `articulated` is still reserved: the gangs' war rig uses wheels with a very wide
## turning circle instead, which is the part of a tanker-and-trailer that matters in a fight.
const LOCOMOTIONS := ["tracks", "wheels", "hover", "articulated"]
## Rounds fly flat at muzzle height, so every muzzle must sit below the shortest hull's top by this much
## (orientation trip-up 15: shells once flew over every tank).
const MUZZLE_CLEARANCE := 0.1

## S1 (round 9, scale): REAL-WORLD RELATIVE SIZING, the lead's second feedback item -- *"We resized the semi trucks
## for the gang and this makes the game much cooler and awesome. We need to do proportional, real-world relative
## sizing for all of our vehicles. As an example, the bus-tanks and garbage trucks for the condemned definitely need
## resizing, so by extension I'm sure so do the rest."*
##
## ONE factor for the whole world, anchored by the War Rig at the length he RULED (*"yes the war rig stays at 14m"*).
## Its `scale_reference` is a standard US fuel-tanker semi at 19.8 m, so the arena draws vehicles at ~0.707 of real
## size, and **every other hull's length is its own reference vehicle's real length times SCALE_K**. Nothing is sized
## by opinion; the only judgment per unit is WHICH real vehicle it is, and that judgment is written down in the
## profile where anyone can argue with it (`make roster-scale` prints the whole table).
##
## SCALE_K IS DERIVED, NEVER TYPED. A literal here would be a mirror of the rig's reference that drifts from it in
## silence (Invariant 0), and this is the one number that may still move: if the lead prefers real metres,
## RIG_LENGTH_M becomes 19.8 and all 21 hulls re-derive from the same table. It is `NAN` -- loudly, not quietly --
## if the rig ever loses its reference, so every derived length fails rather than defaulting to something plausible.
const RIG_UNIT := "gang_tank"
const RIG_LENGTH_M := 14.0
static var SCALE_K: float = _derive_scale_k()


## `rig` is a parameter only so the derivation can be mutation-checked from a test: PROFILES is a const, hence
## read-only, so there is no other way to move the reference and watch K move with it (Invariant 0 asks for the
## reader to be checked in BOTH directions, and a derivation nobody can perturb is one nobody has checked).
static func _derive_scale_k(rig: Dictionary = PROFILES[RIG_UNIT]) -> float:
	if not rig.has("scale_reference") or not (rig["scale_reference"] as Dictionary).has("length_m"):
		push_error("Units.SCALE_K: %s has no scale_reference.length_m, so no hull length in the game can be " % RIG_UNIT
				+ "derived. Restore it; do not type SCALE_K in by hand (contract S1).")
		return NAN
	var reference := float(rig["scale_reference"]["length_m"])
	if reference <= 0.0:
		push_error("Units.SCALE_K: %s's reference length is %s" % [RIG_UNIT, reference])
		return NAN
	return RIG_LENGTH_M / reference


## S1: the length this unit's hull_size[2] is derived from -- its reference vehicle's real length times SCALE_K.
## Units without a `scale_reference` (there are none today; the key is optional so a new unit can land before its
## reference is chosen) keep whatever length the catalog gives them.
static func target_length_m(unit_id: String) -> float:
	var profile: Dictionary = PROFILES[unit_id]
	if not profile.has("scale_reference"):
		return float(profile["hull_size"][2])
	return snappedf(float(profile["scale_reference"]["length_m"]) * SCALE_K, 0.01)

## Points a player spends on an army per match. A standard tank is 200.
const DEFAULT_BUDGET := 1000
## L3/X5 (round 4): the budget a full-scale battle is fought at. The lead asked for "a baseline of 30 units per
## side"; the Condemned average about 176 points a vehicle, so 5200 buys them ~30, the gangs more, and the
## Syndicate fewer. Free play (skirmish, the match runner's faction matches) uses this; the garage keeps its own
## smaller progression tiers (Progression.BUDGET_TIERS) until that stream unpauses.
const BASELINE_BUDGET := 5200

const PROFILES := {
	# The lead: "the scout vehicles can have no turret, and they just have a machine gun that shoots
	# straight forward, so they can only shoot at what they point at." Fast, fragile, far-sighted.
	"scout": {
		"display_name": "Scout",
		"role": "scout",
		"faction": "condemned",
		"blurb": "Fast rally truck with a hood-mounted machine gun. Sees far; hunts artillery and Lancers.",
		"cost": 110,
		"unlock_tier": 0,
		"hull_size": [1.81, 1.50, 3.04],
		# S1 (round 9): Drawn as a caged desert buggy with a ram spear, not a pickup: the blurb's rally truck is a buggy
		# in the art.
		"scale_reference": {"vehicle": "Dakar-class rally-raid buggy (Prodrive Hunter T1+)",
				"length_m": 4.30, "source": "Prodrive Hunter published dimensions"},
		"max_health": 140,
		"max_shield": 80,
		"shield_recharge_delay": 3.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 14.0,
		"max_reverse_speed": 7.0,
		"hull_turn_rate_deg": 140.0,
		"sight_radius": 110.0,
		# K3 locomotion (round 3 X4). Rally truck: the tightest circle, quick off the line, and loose: it drifts through
		# hard turns.
		"locomotion": "wheels",
		"min_turn_radius_m": 5.0,
		"acceleration_mps2": 16.0,
		"braking_mps2": 22.0,
		"lateral_grip": 0.45,
		"weapon": "machine_gun",
		"mount": "fixed",
		"turret_turn_rate_deg": 200.0,
		"fire_arc_deg": 16.0,
		"muzzle_height": 1.12,
		"armor": {"front": 2.0, "side": 1.0, "rear": 1.0},
		# X4 (round 4): "lancer" removed. game_design.md rules that good_vs claims must be real in the mechanics, and
		# round 3 measured scout > lancer at 0%: scouts hold their spotting standoff and never close. Suppression (L2)
		# is the mechanic that could earn the claim back — a machine gun is the best suppressor in the game and a
		# suppressed Lancer tracks at half speed and scatters — but only once ai suppresses on purpose (X2). Put it
		# back when the matrix shows it.
		"good_vs": ["artillery"],
		"weak_vs": ["ifv"],
	},
	# The prison-bus dozer. The lead: "A tank turret moves slow so it would have a hard time tracking a scout."
	"tank": {
		"display_name": "Tank",
		"role": "tank",
		"faction": "condemned",
		"blurb": "The armored prison-bus dozer. Heavy cannon on a slow turret; thick front armor.",
		"cost": 200,
		"unlock_tier": 0,
		"hull_size": [2.40, 2.40, 8.62],
		# S1 (round 9): The lead's own example: "the bus-tanks ... definitely need resizing". A prison bus is a school bus
		# with the windows welded over.
		"scale_reference": {"vehicle": "Type D school bus, 40 ft (Blue Bird All American)",
				"length_m": 12.19, "source": "40 ft = 12.19 m, the standard full-size US school bus"},
		"max_health": 300,
		"max_shield": 150,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 50.0,
		"max_forward_speed": 9.0,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 80.0,
		# X6 (round 3): 75 -> 62, a welded-slit dozer: it needs spotters to use its 70 m gun, and Lancers at 76-86 m see
		# it first (Lancer > tank).
		"sight_radius": 62.0,
		# K3 locomotion (round 3 X4). The dozer on tracks pivots in place; heavy: 0.9 s to top speed (the scout takes
		# the same to reach 14 m/s).
		"locomotion": "tracks",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 10.0,
		"braking_mps2": 12.0,
		"lateral_grip": 1.0,
		"weapon": "cannon",
		"mount": "turret",
		# R2: 110 -> 50 (the lead's "slow turret"): a scout crossing at 15 m sweeps ~53°/s, faster than it turns.
		"turret_turn_rate_deg": 50.0,
		"muzzle_height": 1.14,
		"armor": {"front": 8.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["ifv", "tank"],
		"weak_vs": ["scout"],
	},
	# The lead: "some in between vehicle (think a Bradley or a Stryker) that has the equivalent of 30 mm cannons."
	"ifv": {
		"display_name": "IFV",
		"role": "ifv",
		"faction": "condemned",
		"blurb": "Armored troop bus with a 30 mm autocannon on a fast turret. Shreds scouts; can't crack tank fronts.",
		"cost": 150,
		"unlock_tier": 0,
		"hull_size": [2.86, 3.70, 7.54],
		# S1 (round 9): The armored troop bus. A 35 ft body also matches what is drawn (a 6x4 boxed truck), so the choice
		# does not turn on which reading wins.
		"scale_reference": {"vehicle": "Type C school/prisoner-transport bus, 35 ft (Blue Bird Vision)",
				"length_m": 10.67, "source": "35 ft = 10.67 m"},
		"max_health": 220,
		"max_shield": 100,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 11.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 100.0,
		"sight_radius": 85.0,
		# K3 locomotion (round 3 X4). Armored bus on big wheels: planted, a wider circle than the scout.
		"locomotion": "wheels",
		"min_turn_radius_m": 7.0,
		"acceleration_mps2": 9.0,
		"braking_mps2": 14.0,
		"lateral_grip": 0.7,
		"weapon": "autocannon",
		"mount": "turret",
		"turret_turn_rate_deg": 180.0,
		"muzzle_height": 1.14,
		# X6 (round 3): front 5 -> 7, so a laser needs longer to cut through an IFV rush (IFV > Lancer 0% -> 75%);
		# flanks unchanged.
		"armor": {"front": 7.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["scout"],
		"weak_vs": ["tank"],
	},
	# Indirect fire at what teammates spot. Slow, fragile, nearly blind, long reach.
	"artillery": {
		"display_name": "Artillery",
		"role": "artillery",
		"faction": "condemned",
		"blurb": "Crane carrier with a mortar battery. Shells what teammates spot; helpless up close.",
		"cost": 220,
		"unlock_tier": 1,
		"hull_size": [2.90, 2.82, 8.20],
		# S1 (round 9): The crane carrier the mortar rack is bolted to; the art is a four-axle flatbed.
		"scale_reference": {"vehicle": "Four-axle all-terrain crane carrier (Liebherr LTM 1070-4.2)",
				"length_m": 11.60, "source": "Liebherr LTM 1070-4.2 datasheet, overall length"},
		"max_health": 200,
		"max_shield": 80,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 6.5,
		"max_reverse_speed": 3.5,
		"hull_turn_rate_deg": 60.0,
		"sight_radius": 60.0,
		# K3 locomotion (round 3 X4). Crane carrier: the widest circle and slowest to get going.
		"locomotion": "wheels",
		"min_turn_radius_m": 9.0,
		"acceleration_mps2": 6.0,
		"braking_mps2": 10.0,
		"lateral_grip": 0.85,
		# X5 (round 3): the crane carrier lowers its outriggers before firing (game_design.md). 2.5 s down, 2 s up: a
		# scout that catches it moving or a battery forced to relocate under fire is a real decision.
		"deploy_seconds": 2.5,
		"pack_seconds": 2.0,
		"weapon": "mortar",
		"mount": "turret",
		"turret_turn_rate_deg": 70.0,
		"muzzle_height": 1.14,
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
		"good_vs": ["tank", "artillery"],
		"weak_vs": ["scout"],
	},
	# The lead: "the laser is awesome, but we'll just move that to a different unit type."
	"lancer": {
		"display_name": "Lancer",
		"role": "lancer",
		"faction": "condemned",
		"blurb": "Converted power-utility truck with a long laser. Strips shields at range; overheats.",
		"cost": 200,
		"unlock_tier": 1,
		"hull_size": [2.76, 3.85, 6.46],
		# S1 (round 9): The converted power-utility truck.
		"scale_reference": {"vehicle": "Utility line truck, 30 ft (International 4300 with an Altec boom)",
				"length_m": 9.14, "source": "30 ft = 9.14 m, a standard two-axle line-crew body"},
		"max_health": 200,
		"max_shield": 120,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 8.5,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 80.0,
		# R7: sight 80 -> 85 (it must see what its 85 m beam reaches); turret 80 -> 55°/s, so fast IFVs get inside it.
		# X6: sees what its 90 m beam reaches.
		"sight_radius": 90.0,
		# K3 locomotion (round 3 X4). Utility truck on wheels.
		"locomotion": "wheels",
		"min_turn_radius_m": 7.5,
		"acceleration_mps2": 8.0,
		"braking_mps2": 12.0,
		"lateral_grip": 0.75,
		"weapon": "laser",
		"mount": "turret",
		"turret_turn_rate_deg": 55.0,
		"muzzle_height": 1.14,
		# X6 (round 3): 4/3/2 -> 3/2/1.5, a utility truck: IFV bursts must hurt it (IFV > Lancer).
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
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
		"faction": "condemned",
		"blurb": "Plow-nosed fire truck with a flamethrower. Melts light hulls and artillery it reaches; tanks and Lancers stop it first.",
		# Stretch tuning (2026-09-14, `make matchups ... --focus burner`): at 160 pts, 12 m/s, front armor 7, hull 260
		# it won
		# 100% of every matchup; at these values it beats IFVs 67% and artillery 83%, loses to tanks and Lancers.
		"cost": 220,
		"unlock_tier": 2,
		"hull_size": [2.40, 2.40, 6.89],
		# S1 (round 9): The plow-nosed fire truck.
		"scale_reference": {"vehicle": "Pumper fire engine, 32 ft (Pierce Enforcer)",
				"length_m": 9.75, "source": "32 ft = 9.75 m, a standard single-axle pumper"},
		"max_health": 220,
		"max_shield": 100,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 10.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 110.0,
		"sight_radius": 70.0,
		# K3 locomotion (round 3 X4). Fire truck on wheels: charges in, slides a little.
		"locomotion": "wheels",
		"min_turn_radius_m": 7.0,
		"acceleration_mps2": 9.0,
		"braking_mps2": 14.0,
		"lateral_grip": 0.65,
		"weapon": "flamethrower",
		"mount": "turret",
		"turret_turn_rate_deg": 120.0,
		"muzzle_height": 1.14,
		# X6 (round 3): plow front 4 -> 6, so it survives the 25 mm while closing on IFVs (Burner > IFV).
		"armor": {"front": 6.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["ifv", "artillery"],
		"weak_vs": ["tank", "lancer"],
	},

	# ================================================================================================================
	# L3 (round 4): the other three factions. The lead: *"different factions should have different unit sizes based on
	# the effectiveness of each unit … the gang is diluted with cheaper units, so it should be a bigger swarm, the
	# condemned have more expensive and smaller unit counts from there, then the law … and the syndicate would have the
	# fewest."* Nothing here is a faction-wide bonus: a faction is a set of COSTS and STATS, and the army size falls
	# out of them (Units.roster_average_cost at BASELINE_BUDGET: gangs ~39 vehicles, Condemned 28, Law ~24,
	# Syndicate ~15). Counters live between units, never between factions (game_design.md *Factions*).
	# Art: game/theme/factions/<faction>/ (K4).
	#
	# S1 (round 9): heights are no longer held at or above 1.4 m by hand -- every box is now the approved mesh's own
	# proportions at the unit's derived length (SizeLook.box_at_length), so the SHORTEST hull in the catalog is
	# whatever the art says it is. It is the Rat Rod at 1.24 m, down from 1.40, which lowers the roster-wide muzzle
	# ceiling (MUZZLE_CLEARANCE below the shortest hull's top) from 1.30 m to 1.14 m: every muzzle above 1.14 came
	# down to it, and `test_every_muzzle_clears_under_every_hull_top` is what keeps that true.
	# ================================================================================================================

	# ---- Road gangs: cheapest, fastest, most numerous. No shields anywhere (game_design.md): scrap and speed. -------
	"gang_scout": {
		"display_name": "Rat Rod",
		"role": "scout",
		"faction": "gangs",
		"blurb": "Stripped hot rod with an explosive spear launcher. The fastest thing in the arena, and made of nothing.",
		"cost": 70,
		"unlock_tier": 0,
		"hull_size": [1.52, 1.24, 2.93],
		# S1 (round 9): The stripped hot rod, chopped and blown.
		"scale_reference": {"vehicle": "1932 Ford Model B hot rod",
				"length_m": 4.14, "source": "1932 Ford Model B, 163 in = 4.14 m"},
		"max_health": 100,
		"max_shield": 0.0,
		"shield_recharge_delay": 0.0,
		"shield_recharge_rate": 0.0,
		"max_forward_speed": 18.0,
		"max_reverse_speed": 8.0,
		"hull_turn_rate_deg": 150.0,
		"sight_radius": 105.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 4.5,
		"acceleration_mps2": 18.0,
		"braking_mps2": 20.0,
		"lateral_grip": 0.4,
		# X6: the spear, not a machine gun. It still spots (105 m of sight) but it can open armor if it gets to 30 m,
		# which is the gangs' answer to heavies and the reason a swarm of them is frightening rather than decorative.
		"weapon": "spear_gun",
		"mount": "fixed",
		"turret_turn_rate_deg": 200.0,
		"fire_arc_deg": 18.0,
		"muzzle_height": 1.05,
		"armor": {"front": 1.5, "side": 1.0, "rear": 1.0},
		# Real in the mechanics: penetration 14 against a dozer's 8 mm front is x0.74, so a pack of these opens a tank
		# — if it survives crossing 40 m of cannon fire in a 100 hp hot rod.
		"good_vs": ["tank", "artillery"],
		"weak_vs": ["ifv"],
	},
	"gang_ifv": {
		"display_name": "Gun Truck",
		"role": "ifv",
		"faction": "gangs",
		"blurb": "1950s pickup with twin salvaged machine guns. Buries a position in fire; folds if anything answers.",
		"cost": 110,
		"unlock_tier": 0,
		"hull_size": [1.59, 2.10, 3.44],
		# S1 (round 9): The 1950s pickup gun truck, named in game_design.md *Factions*.
		"scale_reference": {"vehicle": "1955 Chevrolet 3100 half-ton pickup",
				"length_m": 4.87, "source": "Chevrolet Task Force 3100, 191.7 in = 4.87 m"},
		"max_health": 170,
		"max_shield": 0.0,
		"shield_recharge_delay": 0.0,
		"shield_recharge_rate": 0.0,
		"max_forward_speed": 13.0,
		"max_reverse_speed": 6.0,
		"hull_turn_rate_deg": 110.0,
		"sight_radius": 80.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 6.5,
		"acceleration_mps2": 11.0,
		"braking_mps2": 14.0,
		"lateral_grip": 0.6,
		"weapon": "twin_mg",
		"mount": "turret",
		"turret_turn_rate_deg": 190.0,
		"muzzle_height": 1.14,
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
		"good_vs": ["scout"],
		"weak_vs": ["tank"],
	},
	"gang_tank": {
		"display_name": "War Rig",
		"role": "tank",
		"faction": "gangs",
		"blurb": "A fuel tanker with a naval gun welded to the back. Enormous, fast in a straight line, turns like a barge.",
		"cost": 175,
		"unlock_tier": 0,
		# The biggest hull in the game: it screens half a squad (X3) and it is impossible to miss.
		# ROUND 8, the lead (third time of asking): "the gang tanks are still tiny -- the intent for the semi trucks
		# is that they're huge". These are feel's numbers, not mine, measured with SizeLook.box_at_length() from the
		# approved model's own proportions -- so the box matches what is DRAWN. Do not round them to something tidier:
		# hull_size IS the collider, and a box that does not match the mesh means shells hitting empty air.
		#
		# Why the old [3.0, 4.4, 5.6] read as tiny at 3.14x the gang scout's height: art is fitted by LENGTH so the
		# approved model is never distorted, so a 4.4 m box drew a 2.09 m truck. At the lead's camera the rig
		# rendered 114 px tall against a Condemned tank's 95 -- the "huge" semi was barely taller on screen than a
		# regular tank. Length is what makes a semi, and length was the axis the spawn grid appeared to cap.
		"hull_size": [3.32, 5.24, 14.00],
		# S1 (round 9): THE ANCHOR. The lead ruled this hull at 14.0 m, so SCALE_K = 14.0 / 19.8 and the whole world
		# follows from it.
		"scale_reference": {"vehicle": "Tractor unit with a 42 ft DOT-406 petroleum tanker semi-trailer",
				"length_m": 19.80, "source": "65 ft = 19.8 m, the standard US legal tractor-tanker configuration"},
		"max_health": 420,
		"max_shield": 0.0,
		"shield_recharge_delay": 0.0,
		"shield_recharge_rate": 0.0,
		"max_forward_speed": 12.0,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 55.0,
		"sight_radius": 60.0,
		# `articulated` is reserved; a 12 m turning circle is the part of a tanker-and-trailer that decides fights.
		"locomotion": "wheels",
		"min_turn_radius_m": 12.0,
		"acceleration_mps2": 7.0,
		"braking_mps2": 8.0,
		"lateral_grip": 0.9,
		"weapon": "scrap_cannon",
		"mount": "turret",
		"turret_turn_rate_deg": 60.0,
		"muzzle_height": 1.14,
		"armor": {"front": 7.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["ifv", "tank"],
		"weak_vs": ["scout"],
	},
	"gang_artillery": {
		"display_name": "Wrecker Catapult",
		"role": "artillery",
		"faction": "gangs",
		"blurb": "Tow truck slinging flaming barrels. Half a mortar's reach, twice its splash, and it lands anywhere.",
		"cost": 170,
		"unlock_tier": 1,
		"hull_size": [2.91, 3.36, 6.89],
		# S1 (round 9): The tow-wrecker catapult.
		"scale_reference": {"vehicle": "Heavy-duty tow wrecker on a 6x4 chassis (Century 5030 boom)",
				"length_m": 9.75, "source": "32 ft = 9.75 m over the boom stowed"},
		"max_health": 190,
		"max_shield": 0.0,
		"shield_recharge_delay": 0.0,
		"shield_recharge_rate": 0.0,
		"max_forward_speed": 9.0,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 65.0,
		"sight_radius": 55.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 9.0,
		"acceleration_mps2": 7.0,
		"braking_mps2": 10.0,
		"lateral_grip": 0.85,
		"deploy_seconds": 2.0,
		"pack_seconds": 1.5,
		"weapon": "catapult",
		"mount": "turret",
		"turret_turn_rate_deg": 70.0,
		"muzzle_height": 1.14,
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
		"good_vs": ["tank", "artillery"],
		"weak_vs": ["scout"],
	},
	"gang_support": {
		"display_name": "Resupply Tanker",
		"role": "support",
		"faction": "gangs",
		# The lead's pick for the gangs' special (2026-09-15), over the war-drum truck.
		"blurb": "Crews hanging off a fuel bowser, mending whatever is next to them. Carries a hose, and it is not for you.",
		"cost": 130,
		"unlock_tier": 1,
		# Round 8: a rigid tanker truck with a semi cab, not an articulated rig -- feel's measurement, filling the
		# 3.6 m height it already had. Same rule: the box is the mesh's proportions at the chosen length.
		"hull_size": [3.18, 3.37, 6.58],
		# S1 (round 9): Round 8 settled this as a RIGID tanker with a semi cab and set it at 7.0 m by eye; the rule puts
		# it at 6.58 m.
		"scale_reference": {"vehicle": "Rigid fuel bowser, 3,000 gal (Freightliner M2 106 tank truck)",
				"length_m": 9.30, "source": "~30.5 ft = 9.3 m for a two-axle rigid tanker body"},
		"max_health": 260,
		"max_shield": 0.0,
		"shield_recharge_delay": 0.0,
		"shield_recharge_rate": 0.0,
		"max_forward_speed": 11.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 70.0,
		"sight_radius": 65.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 8.0,
		"acceleration_mps2": 8.0,
		"braking_mps2": 11.0,
		"lateral_grip": 0.8,
		"weapon": "fuel_spray",
		"mount": "turret",
		"turret_turn_rate_deg": 100.0,
		"muzzle_height": 1.14,
		"armor": {"front": 4.0, "side": 3.0, "rear": 2.0},
		# L3: field repair. A faction with no shields at all has to get its hit points back some other way, and this
		# is it: hulls near a living tanker mend at this rate wherever they are, on the same terms as a home base
		# (nothing has hit them for their recharge delay). It is the gangs' answer to attrition, and it dies easily.
		"repair_radius_m": 18.0,
		"repair_hp_per_second": 5.0,
		"good_vs": [],
		"weak_vs": ["artillery"],
	},

	# ---- The Law: fewer, tougher, disciplined. Information and control; their support suppresses. ------------------
	"law_scout": {
		"display_name": "Pursuit Cruiser",
		"role": "scout",
		"faction": "law",
		"blurb": "Up-armored patrol car under a giant light bar. Sees farther than anything else in the arena.",
		"cost": 140,
		"unlock_tier": 0,
		"hull_size": [1.79, 1.33, 3.80],
		# S1 (round 9): The up-armored pursuit sedan.
		"scale_reference": {"vehicle": "Ford Crown Victoria Police Interceptor",
				"length_m": 5.38, "source": "Crown Victoria P71, 212.0 in = 5.38 m"},
		"max_health": 180,
		"max_shield": 90.0,
		"shield_recharge_delay": 3.0,
		"shield_recharge_rate": 42.0,
		"max_forward_speed": 16.0,
		"max_reverse_speed": 7.0,
		"hull_turn_rate_deg": 130.0,
		# The Law's identity is knowing where you are: 125 m against the Condemned scout's 110.
		"sight_radius": 125.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 5.5,
		"acceleration_mps2": 15.0,
		"braking_mps2": 20.0,
		"lateral_grip": 0.55,
		"weapon": "machine_gun",
		"mount": "fixed",
		"turret_turn_rate_deg": 200.0,
		"fire_arc_deg": 20.0,
		"muzzle_height": 1.12,
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
		"good_vs": ["artillery"],
		"weak_vs": ["ifv"],
	},
	"law_ifv": {
		"display_name": "Retired APC",
		"role": "ifv",
		"faction": "law",
		"blurb": "A 6x6 MRAP that outlived its war, with a remote 25 mm. Slow, and very hard to open.",
		"cost": 195,
		"unlock_tier": 0,
		"hull_size": [2.75, 3.29, 5.01],
		# S1 (round 9): Named in game_design.md *The Law roster sketch*.
		"scale_reference": {"vehicle": "Force Protection Cougar 6x6 MRAP",
				"length_m": 7.08, "source": "Cougar 6x6 published length 7.08 m"},
		"max_health": 280,
		"max_shield": 120.0,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 10.5,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 95.0,
		"sight_radius": 90.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 7.5,
		"acceleration_mps2": 8.0,
		"braking_mps2": 13.0,
		"lateral_grip": 0.8,
		"weapon": "autocannon",
		"mount": "turret",
		"turret_turn_rate_deg": 175.0,
		"muzzle_height": 1.14,
		# Mine-resistant: the toughest front in the game after the war rig, on a unit that cannot chase anything.
		# Rear 2.0 like every other hull: "everything hurts from behind" is a rule of the game, not a unit's choice
		# (test_combat_mechanics), and an MRAP you cannot flank would break it.
		"armor": {"front": 9.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["scout"],
		"weak_vs": ["tank"],
	},
	"law_tank": {
		"display_name": "Assault Gun",
		"role": "tank",
		"faction": "law",
		"blurb": "An 8x8 with a real gun: reaches farther and works faster than a dozer, and cannot trade with one.",
		"cost": 260,
		"unlock_tier": 0,
		"hull_size": [2.55, 2.88, 5.55],
		# S1 (round 9): The 8x8 wheeled assault gun with a real gun. game_design.md says Stryker-style; the Stryker MGS is
		# 6.95 m, which would make the Law's tank SHORTER than its own 6x6 MRAP. Centauro is the 8x8 assault gun the blurb
		# describes and keeps the role order legible.
		"scale_reference": {"vehicle": "Centauro B1 8x8 assault gun (hull, gun excluded)",
				"length_m": 7.85, "source": "Centauro B1 hull length 7.85 m"},
		"max_health": 330,
		"max_shield": 140.0,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 50.0,
		"max_forward_speed": 12.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 85.0,
		"sight_radius": 78.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 8.0,
		"acceleration_mps2": 9.0,
		"braking_mps2": 12.0,
		"lateral_grip": 0.85,
		"weapon": "assault_gun",
		"mount": "turret",
		"turret_turn_rate_deg": 70.0,
		"muzzle_height": 1.14,
		"armor": {"front": 7.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["ifv", "tank"],
		"weak_vs": ["scout"],
	},
	"law_artillery": {
		"display_name": "Gas Rocket Truck",
		"role": "artillery",
		"faction": "law",
		"blurb": "Tear gas and smoke by the salvo. It does not kill a position, it shuts it down.",
		"cost": 250,
		"unlock_tier": 1,
		"hull_size": [2.09, 2.64, 4.95],
		# S1 (round 9): The truck rocket launcher; the art is a three-axle truck with a launcher box.
		"scale_reference": {"vehicle": "M142 HIMARS on an FMTV 6x6 chassis",
				"length_m": 7.00, "source": "HIMARS published length 7.0 m"},
		"max_health": 220,
		"max_shield": 90.0,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 40.0,
		"max_forward_speed": 9.0,
		"max_reverse_speed": 4.0,
		"hull_turn_rate_deg": 60.0,
		"sight_radius": 60.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 9.0,
		"acceleration_mps2": 7.0,
		"braking_mps2": 10.0,
		"lateral_grip": 0.85,
		"deploy_seconds": 2.5,
		"pack_seconds": 2.0,
		"weapon": "gas_rockets",
		"mount": "turret",
		"turret_turn_rate_deg": 70.0,
		"muzzle_height": 1.14,
		"armor": {"front": 3.0, "side": 2.0, "rear": 1.5},
		"good_vs": ["tank", "artillery"],
		"weak_vs": ["scout"],
	},
	"law_suppressor": {
		"display_name": "Sonic Emitter",
		"role": "suppressor",
		# The lead's pick for the Law's special (2026-09-15), over the water cannon.
		"faction": "law",
		"blurb": "Riot truck with a wall of sound. Barely scratches paint; nothing in front of it can aim.",
		"cost": 230,
		"unlock_tier": 1,
		"hull_size": [3.32, 6.18, 6.86],
		# S1 (round 9): The riot truck. The sonic horns replace the cannon; the vehicle underneath is the same class.
		"scale_reference": {"vehicle": "Riot-control water cannon (Wasserwerfer 10000, MAN 6x6)",
				"length_m": 9.70, "source": "WaWe 10000 published length 9.7 m"},
		"max_health": 260,
		"max_shield": 120.0,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 10.0,
		"max_reverse_speed": 5.0,
		"hull_turn_rate_deg": 90.0,
		"sight_radius": 70.0,
		"locomotion": "wheels",
		"min_turn_radius_m": 7.0,
		"acceleration_mps2": 8.0,
		"braking_mps2": 13.0,
		"lateral_grip": 0.8,
		"weapon": "sonic_emitter",
		"mount": "turret",
		"turret_turn_rate_deg": 110.0,
		"muzzle_height": 1.14,
		"armor": {"front": 6.0, "side": 3.0, "rear": 2.0},
		"good_vs": [],
		"weak_vs": ["artillery"],
	},

	# ---- The Syndicate: fewest, most expensive, best per unit. Energy, hover, and an ivory shell. ------------------
	"syn_scout": {
		"display_name": "Skimmer",
		"role": "scout",
		"faction": "syndicate",
		"blurb": "An unmanned teardrop that never touches the ground. Sees everything and drifts out of trouble.",
		"cost": 210,
		"unlock_tier": 0,
		"hull_size": [2.18, 1.64, 4.04],
		# S1 (round 9): game_design.md names the Syndicate's hulls by SHAPE (teardrop, supercar, limousine), not by a
		# vehicle they were converted from: they are purpose-built hover platforms. So the whole faction is referenced to
		# the real vehicle that fills the SAME ROLE, consistently, and the table says so.
		"scale_reference": {"vehicle": "BY ROLE (hover, no road ancestry): wheeled recon vehicle, Fennek LGS",
				"length_m": 5.71, "source": "Fennek published length 5.71 m"},
		"max_health": 150,
		# Energy instead of armor: the biggest shield per point in the game on the thinnest hull.
		"max_shield": 160.0,
		"shield_recharge_delay": 2.5,
		"shield_recharge_rate": 60.0,
		"max_forward_speed": 17.0,
		"max_reverse_speed": 10.0,
		"hull_turn_rate_deg": 160.0,
		"sight_radius": 135.0,
		"locomotion": "hover",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 14.0,
		"braking_mps2": 14.0,
		# Hover: it swings to face instantly and then keeps going the way it was going. Grip this low leaves the
		# hull travelling ~25 degrees off its own nose through a hard turn (test_combat_faction_mechanics).
		"lateral_grip": 0.10,
		"weapon": "pulse_repeater",
		"mount": "turret",
		"turret_turn_rate_deg": 200.0,
		"muzzle_height": 1.14,
		# A shell, not a tank: no strong face to find.
		"armor": {"front": 2.0, "side": 2.0, "rear": 2.0},
		"good_vs": ["artillery"],
		"weak_vs": ["ifv"],
	},
	"syn_ifv": {
		"display_name": "Limousine Gunship",
		"role": "ifv",
		"faction": "syndicate",
		"blurb": "Black glass and a pulse cannon. Corporate hospitality at 13 m/s.",
		"cost": 300,
		"unlock_tier": 0,
		"hull_size": [1.82, 1.34, 4.63],
		# S1 (round 9): The limousine gunship: a long low body, and an IFV is what it does.
		"scale_reference": {"vehicle": "BY ROLE (hover, no road ancestry): infantry fighting vehicle, CV90 hull",
				"length_m": 6.55, "source": "CV9035 hull length 6.55 m"},
		"max_health": 240,
		"max_shield": 200.0,
		"shield_recharge_delay": 3.0,
		"shield_recharge_rate": 55.0,
		"max_forward_speed": 13.0,
		"max_reverse_speed": 8.0,
		"hull_turn_rate_deg": 120.0,
		"sight_radius": 95.0,
		"locomotion": "hover",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 11.0,
		"braking_mps2": 12.0,
		"lateral_grip": 0.14,
		"weapon": "pulse_cannon",
		"mount": "turret",
		"turret_turn_rate_deg": 180.0,
		"muzzle_height": 1.14,
		"heat_capacity": 100.0,
		"heat_dissipation": 14.0,
		"armor": {"front": 5.0, "side": 4.0, "rear": 2.0},
		"good_vs": ["scout"],
		"weak_vs": ["tank"],
	},
	"syn_tank": {
		"display_name": "Railgun Platform",
		"role": "tank",
		"faction": "syndicate",
		"blurb": "A supercar the size of a tank with a charge-up railgun. Two shots, then it has to cool down.",
		"cost": 470,
		"unlock_tier": 1,
		"hull_size": [3.55, 1.85, 5.44],
		# S1 (round 9): The blurb already sets the size: "a supercar the size of a tank".
		"scale_reference": {"vehicle": "BY ROLE (hover, no road ancestry): main battle tank hull, Leopard 2A7, gun excluded",
				"length_m": 7.70, "source": "Leopard 2 hull length 7.70 m"},
		"max_health": 320,
		"max_shield": 260.0,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 55.0,
		"max_forward_speed": 11.0,
		"max_reverse_speed": 7.0,
		"hull_turn_rate_deg": 90.0,
		"sight_radius": 105.0,
		"locomotion": "hover",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 10.0,
		"braking_mps2": 11.0,
		"lateral_grip": 0.16,
		"weapon": "railgun",
		"mount": "turret",
		"turret_turn_rate_deg": 55.0,
		"muzzle_height": 1.14,
		"heat_capacity": 100.0,
		"heat_dissipation": 10.0,
		# Thick everywhere a shell is likely to arrive and thin behind: a hover tank you have to get round.
		"armor": {"front": 7.0, "side": 5.0, "rear": 2.0},
		"good_vs": ["ifv", "tank"],
		"weak_vs": ["scout"],
	},
	"syn_artillery": {
		"display_name": "Missile Ring",
		"role": "artillery",
		"faction": "syndicate",
		"blurb": "A wing of missiles that only fires at what somebody is looking at. Blind, it wastes the salvo.",
		"cost": 380,
		"unlock_tier": 1,
		"hull_size": [4.07, 2.08, 4.93],
		# S1 (round 9): The missile-wing ring.
		"scale_reference": {"vehicle": "BY ROLE (hover, no road ancestry): rocket artillery, M270 MLRS",
				"length_m": 6.97, "source": "M270 published length 6.97 m"},
		"max_health": 220,
		"max_shield": 160.0,
		"shield_recharge_delay": 4.0,
		"shield_recharge_rate": 45.0,
		"max_forward_speed": 9.0,
		"max_reverse_speed": 6.0,
		"hull_turn_rate_deg": 80.0,
		"sight_radius": 70.0,
		"locomotion": "hover",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 8.0,
		"braking_mps2": 10.0,
		"lateral_grip": 0.18,
		"deploy_seconds": 2.0,
		"pack_seconds": 1.5,
		"weapon": "guided_missiles",
		"mount": "turret",
		"turret_turn_rate_deg": 80.0,
		"muzzle_height": 1.14,
		"armor": {"front": 3.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["tank", "artillery"],
		"weak_vs": ["scout"],
	},
	"syn_lancer": {
		"display_name": "Spotter Platform",
		# The ROLE stays `lancer` -- it is the faction's long-reach slot, and game_design.md is explicit that "the
		# role is shared across factions, the vehicle is not". What differs is a CAPABILITY, below.
		"role": "lancer",
		"faction": "syndicate",
		# X5 (2026-09-18): this WAS the Syndicate's second Lancer, and it was outranged by its own faction's tank --
		# an 86 m band against the railgun's 104, a cheaper but shorter duplicate of a role the Syndicate already
		# dominated in every slot. Deleting it outright would have left the Syndicate with only the four core roles
		# and no special at all, which test_combat_factions correctly refuses. So the chassis is re-roled rather than
		# retired: same hull, same art, a different job.
		#
		# The job acts on N5's ACQUISITION gate, not on damage. It paints the nearest enemy its team can see, and
		# every Syndicate crew then lays on that contact in a quarter of the usual time. That turns the faction's
		# sight advantage -- syn_scout has the best eyes in the game at 135 m -- into a TEMPO advantage: the Syndicate
		# shoots sooner, not harder. A +x% damage special would have been a stat multiplier wearing a costume.
		#
		# It is worth noting WHY this unit can exist now: before the engagement envelope, acquisition cost nothing, so
		# "your side acquires faster" described a mechanic that was not there. The gate bought the design space.
		"blurb": "Eyes for the syndicate: it paints a target and every gun on your side is already on it.",
		"cost": 340,
		"unlock_tier": 1,
		"hull_size": [1.64, 1.46, 4.04],
		# S1 (round 9): The spotter platform designates rather than shoots, so it takes the recon hull's length.
		"scale_reference": {"vehicle": "BY ROLE (hover, no road ancestry): sensor/designator vehicle, Fennek with the BAA mast",
				"length_m": 5.71, "source": "Fennek published length 5.71 m"},
		"max_health": 220,
		"max_shield": 200.0,
		"shield_recharge_delay": 3.5,
		"shield_recharge_rate": 50.0,
		"max_forward_speed": 12.0,
		"max_reverse_speed": 7.0,
		"hull_turn_rate_deg": 100.0,
		"sight_radius": 95.0,
		"locomotion": "hover",
		"min_turn_radius_m": 0.0,
		"acceleration_mps2": 10.0,
		"braking_mps2": 12.0,
		"lateral_grip": 0.14,
		"weapon": "laser",
		"mount": "turret",
		"turret_turn_rate_deg": 60.0,
		"muzzle_height": 1.14,
		"heat_capacity": 100.0,
		"heat_dissipation": 14.0,
		"armor": {"front": 3.0, "side": 3.0, "rear": 2.0},
		"good_vs": ["tank"],
		"weak_vs": ["scout", "ifv"],
		# X5 (round 6): this unit DESIGNATES. It paints the nearest enemy its team can see and every crew on its side
		# then acquires that contact in a quarter of the usual time (Engagement.DESIGNATED_ACQUIRE_SCALE).
		#
		# A capability flag rather than a new role, and that distinction cost a night to learn. `role` is a TAXONOMY
		# that at least eight places key off -- Units.ROLES, Army.SQUADS, SquadTactics.FRAGILE_ROLES,
		# TacticsFormation.PROTECTED_ROLES, CpuCommander's line/support split, ElementSituation, ArmyCatalog.ROLE_LABELS
		# and the command icons -- across four streams, and none of them reference a single registry. Inventing a role
		# silently dropped this unit from every army (Army.squads_for iterates the TABLE, not the units) and then
		# failed the catalog's known-role check. A capability is read by exactly the systems that care about it.
		"designates": true,
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


## L3: which faction a unit belongs to ("" for an unknown id).
static func faction_of(unit_id: String) -> String:
	if not PROFILES.has(unit_id):
		return ""
	return String(PROFILES[unit_id].get("faction", DEFAULT_FACTION))


## L3: a faction's unit ids in catalog order (empty for a faction that has no units).
static func roster(faction: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for unit_id: String in PROFILES:
		if faction_of(unit_id) == faction:
			result.append(unit_id)
	return result


## L3: the average cost of a faction's vehicles. This is what decides how many of them a budget buys, which is the
## lead's faction identity ("the gang is diluted with cheaper units, so it should be a bigger swarm").
static func roster_average_cost(faction: String) -> float:
	var ids := roster(faction)
	if ids.is_empty():
		return 0.0
	var total := 0.0
	for unit_id in ids:
		total += float(PROFILES[unit_id]["cost"])
	return total / ids.size()


## Unit ids with this role.
static func with_role(role: String) -> PackedStringArray:
	var result: PackedStringArray = []
	for unit_id: String in PROFILES:
		if PROFILES[unit_id]["role"] == role:
			result.append(unit_id)
	return result


## How close a straight shot passes to a hull: the flat distance from the infinite line (`line_origin`,
## `line_direction`) to the hull's OWN ORIENTED FOOTPRINT, and 0.0 when the line crosses it.
##
## ROUND 9, and it replaces a disc. Three consumers modelled a hull as a circle of radius
## `Vector2(width, length).length() / 2` -- `Match` friendly-fire risk, `Match.incoming_projectiles` (whose docstring
## says "within the hull's half-diagonal") and squad's `IncomingFire`. For a War Rig (3.32 x 14.00 m) that disc is
## **7.19 m** against a real half-width of **1.66 m**. The error is NOT a constant: abeam it is 4.3x, end-on the disc
## is 7.19 against a true 7.00 and almost exact. So the AI does not refuse every shot -- it refuses the ones ACROSS a
## rig, which is exactly the shot a gang pack travelling with a rig in the middle wants to take. That is a candidate
## mechanism for the lead's unexplained `gangs vs law` 9/20 -> 0/20, and it is UNTESTED until the series says so.
##
## The maths is a separating axis and it is exact for a line against a box: only the line's own normal can separate
## them, so the hull's extent toward the line is `half_width * |n.x| + half_length * |n.z|` in the hull's frame.
## Four multiplies, two adds, no branches, no trig, deterministic.
##
## `--tune=match.hull_disc=1` restores the disc inside `hull_reach_along`, which BOTH this and squad's longitudinal
## test go through, so every consumer and both axes flip together and a series arm measures the whole change rather
## than the two thirds of it that live in combat's files.
static func hull_distance_to_line(hull_size: Array, hull_forward: Vector3, hull_origin: Vector3,
		line_origin: Vector3, line_direction: Vector3) -> float:
	var along := Vector2(line_direction.x, line_direction.z)
	along = along.normalized() if along.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	var normal := Vector2(-along.y, along.x)
	var offset := Vector2(hull_origin.x - line_origin.x, hull_origin.z - line_origin.z)
	return maxf(absf(offset.dot(normal))
			- hull_reach_along(hull_size, hull_forward, Vector3(normal.x, 0.0, normal.y)), 0.0)


## How far a hull reaches from its own centre along `direction` -- its half-extent projected on that axis. THE SAME
## PROJECTION `hull_distance_to_line` uses, exposed because squad's `IncomingFire` needs it on the OTHER axis: it
## tests the hull's reach along the shell's TRAVEL to decide whether a round with `reach` metres left could touch the
## hull at all, and it used the same disc radius for that as for the perpendicular test. Both are the same bug on
## two axes, and both must move together or someone tightening one will not know the other exists.
##
## Exact for a box, because only one axis can separate a box from a line or a point along a direction:
## `half_width * |d . right| + half_length * |d . forward|`. Four multiplies, two adds, no branches, no trig.
## `--tune=match.hull_disc=1` restores the pre-round-9 disc here, so BOTH consumers and BOTH axes flip together.
static func hull_reach_along(hull_size: Array, hull_forward: Vector3, direction: Vector3) -> float:
	if tuning.get("hull_disc", 0.0) > 0.0:
		return Vector2(float(hull_size[0]), float(hull_size[2])).length() / 2.0
	var forward := Vector2(hull_forward.x, hull_forward.z)
	forward = forward.normalized() if forward.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	var axis := Vector2(direction.x, direction.z)
	axis = axis.normalized() if axis.length_squared() > 0.0001 else Vector2(0.0, -1.0)
	var right := Vector2(-forward.y, forward.x)
	var half := hull_half_extents(hull_size)
	return half.x * absf(axis.dot(right)) + half.y * absf(axis.dot(forward))


## (half width, half length) of a hull, the pair a caller should cache per unit id instead of one radius.
static func hull_half_extents(hull_size: Array) -> Vector2:
	return Vector2(float(hull_size[0]) * 0.5, float(hull_size[2]) * 0.5)


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
##
## A2 (round 9): "switch.<knob>" is a third owner, the switching cost's own knobs (SwitchingCost.TUNABLE). It is here
## rather than in a brain variant because it is the arm switch for a combat measurement, and every tool that measures
## combat already passes --tune; `switch.price=0` is the control arm of the same build.
static func apply_tuning(spec: String) -> String:
	for pair in spec.split(",", false):
		var parts := pair.split("=")
		var path := parts[0].split(".")
		if parts.size() != 2 or path.size() < 2 or path.size() > 3 or not parts[1].is_valid_float():
			return "tune: expected owner.key=number, got '%s'" % pair
		if path[0] == "match":
			if path.size() != 2 or not ["no_damage", "hull_disc"].has(path[1]):
				return "tune: no match knob '%s' (have match.no_damage, match.hull_disc)" % parts[0]
			if path[1] == "no_damage":
				Armor.no_damage = float(parts[1]) > 0.0
			else:
				tuning["hull_disc"] = float(parts[1])
			continue
		if path[0] == "probe":
			if path.size() != 2 or path[1] != "deck":
				return "tune: no probe '%s' (have probe.deck)" % parts[0]
			Armor.deck_probe = float(parts[1]) > 0.0
			continue
		if path[0] == "switch":
			if path.size() != 2 or not SwitchingCost.TUNABLE.has(path[1]):
				return "tune: no switching-cost knob '%s'" % parts[0]
			SwitchingCost.tuning[path[1]] = float(parts[1])
			continue
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
