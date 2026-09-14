class_name Weapons
extends RefCounted
## Weapon profiles are DATA. A tank carries a weapon id; the rules (Match), the
## order layer (aiming/firing), and the brain (preferred range) all read the
## profile. Adding a weapon should mostly mean adding a row here.
## See _agents/tank_brain.md "Weapons v1".

## PROJECTILE: a Shell flies (travel time). CONE: continuous spray. BEAM: instant hitscan pulse (G7 laser).
## ARC: an indirect round lobbed at a ground point; it flies over obstacles and bursts on landing (artillery).
enum Kind { PROJECTILE, CONE, BEAM, ARC }

const DEFAULT := "cannon"

const PROFILES := {
	"cannon": {
		# R2: armor-piercing power vs a unit's armor thickness on the face it hits (Units "armor").
		"penetration": 10.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		# Shorter than the 84 m between bases, so contact is something you maneuver into.
		"range": 70.0,
		"preferred_min": 20.0,
		"preferred_max": 45.0,
		"damage": 34.0,
		"reload": 2.5,
		"aim_tolerance_deg": 2.5,
		# Shot spread (standard deviation, degrees) when stationary. Firing on the move
		# multiplies it (see Match.MOVING_SPREAD_FACTOR): long-range shots from a moving
		# tank mostly miss, so halting to shoot (hold, overwatch) matters.
		"spread_deg": 0.8,
		"armor": {"front": 0.5, "side": 1.0, "rear": 1.5},
		# G6: damage to shields is (damage x shield_multiplier), evenly from any side; only what
		# gets through the shield meets the armor table. Cannons are hull breakers.
		"shield_multiplier": 0.8,
		# G7: finite shells. Refilled slowly inside the team's base (Match.RESUPPLY_RADIUS), so
		# pulling back is a real decision. Weapons without an "ammo" key never run out.
		# 2026-09-15: 30 -> 45 after G6 measurements: with shields, fights take ~370 shells per 5v5
		# match and 30-shell tanks spent a quarter of the match driving home to refill.
		"ammo": 45,
		"heat_per_shot": 0.0,
	},
	# Round 2 (the lead): the IFV's "equivalent of 30 mm cannons". Fast fire, low penetration, modest range:
	# it shreds light hulls and scouts' shields but can't get through a tank's front armor.
	"autocannon": {
		"penetration": 4.0,
		"splash_radius": 0.0,
		"kind": Kind.PROJECTILE,
		"range": 60.0,
		"preferred_min": 15.0,
		"preferred_max": 45.0,
		"damage": 9.0,
		"reload": 0.35,
		"aim_tolerance_deg": 3.0,
		"spread_deg": 1.0,
		"armor": {"front": 0.4, "side": 1.0, "rear": 1.3},
		"shield_multiplier": 0.9,
		"ammo": 300,
		"heat_per_shot": 0.0,
	},
	# G7: the laser never runs out, but every pulse heats the tank, and a tank can't fire past its
	# heat capacity (a hard cap, no damage). Trade-off vs the cannon: shorter range, less burst, no
	# travel time, armor matters less; sustained fire is limited by heat, not ammo.
	"laser": {
		"penetration": 6.0,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		# Which visual slot draws each pulse (see Match.show_beam).
		"fx": "fx.laser_beam",
		"range": 55.0,
		"preferred_min": 15.0,
		"preferred_max": 40.0,
		"damage": 9.0,
		"reload": 0.5,
		"aim_tolerance_deg": 2.0,
		"spread_deg": 0.3,
		"heat_per_shot": 12.0,
		"armor": {"front": 0.7, "side": 1.0, "rear": 1.3},
		# G6: energy weapons strip shields. 1.5 made lasers win 29/40 vs cannons (above the 65% bar);
		# 1.25 measured 14/24 (58%), swap + team-identity counterbalanced (2026-09-15).
		"shield_multiplier": 1.25,
	},
	# Directive set 2: the scout's light machine gun. Hitscan bursts: cheap, fast, and mostly
	# ineffective against a tank's shield and front armor; fine against other scouts and exposed rears.
	"machine_gun": {
		"penetration": 2.5,
		"splash_radius": 0.0,
		"kind": Kind.BEAM,
		"fx": "fx.tracer",
		"range": 45.0,
		"preferred_min": 12.0,
		"preferred_max": 35.0,
		"damage": 4.0,
		"reload": 0.2,
		"aim_tolerance_deg": 4.0,
		"spread_deg": 1.5,
		"ammo": 600,
		"heat_per_shot": 0.0,
		"armor": {"front": 0.3, "side": 0.7, "rear": 1.0},
		"shield_multiplier": 0.6,
	},
	# Directive set 2: the artillery's mortar. Lobs rounds over cover at a ground point; the burst hurts
	# every enemy within splash_radius (falling off to 30% at the edge). It can only aim at what the
	# TEAM sees (OrderController.spotter), so it needs scouts or tanks to spot for it.
	"mortar": {
		"penetration": 5.0,
		"kind": Kind.ARC,
		"range": 160.0,
		"min_range": 35.0,
		"preferred_min": 60.0,
		"preferred_max": 140.0,
		# A lone battery can't out-damage a recharging shield for long (each hit restarts the recharge
		# delay, though): artillery's job is pressure and finishing what the direct-fire guns wear down.
		# 90 -> 70 (2026-09-15): the Siege archetype (2 artillery) still beat Armor and Balanced 12:4 after
		# the scout counter; at 70 it's 10:6 against each (counterbalanced, 16 per pairing).
		"damage": 70.0,
		"splash_radius": 8.0,
		"reload": 4.5,
		"aim_tolerance_deg": 3.0,
		# Rounds land with this much scatter (meters, standard deviation) plus scatter_per_meter x range.
		"scatter": 2.0,
		"scatter_per_meter": 0.02,
		# Horizontal speed: a 150 m shot is in the air for 3.75 s, so moving targets can dodge.
		"flight_speed": 40.0,
		"ammo": 24,
		"heat_per_shot": 0.0,
		# Rounds come down on top: facing barely matters.
		"armor": {"front": 0.9, "side": 1.0, "rear": 1.1},
		"shield_multiplier": 1.0,
	},
	"flamethrower": {
		"penetration": 3.0,
		"splash_radius": 0.0,
		"kind": Kind.CONE,
		"range": 20.0,
		"preferred_min": 6.0,
		"preferred_max": 16.0,
		# 45 -> 20 (2026-09-15): since the 09-13 rebalance (70 m guns, 400 HP) five flamers crossed gun
		# range almost intact and won 36/36 vs five cannons (4 flamers vs 5 cannons: 20/20). At 20: 10/20,
		# counterbalanced. Still ~4x a cannon's damage per second once it arrives.
		"damage_per_second": 20.0,
		"cone_deg": 30.0,
		"reload": 0.0,
		"aim_tolerance_deg": 12.0,
		# Fire wraps around armor: facing matters much less than for shells.
		"armor": {"front": 0.8, "side": 1.0, "rear": 1.2},
		# G6: fire burns through shields quickly (the flamethrower's niche: finish what it reaches).
		"shield_multiplier": 1.5,
	},
}


## Shells a weapon carries, or -1 when it never runs out.
static func max_ammo(weapon: Dictionary) -> int:
	return int(weapon.get("ammo", -1))


static func exists(weapon_id: String) -> bool:
	return PROFILES.has(weapon_id)


## Experiment overrides ("weapon.key" -> value); see Units.apply_tuning. Empty in normal play.
static var tuning := {}


static func profile(weapon_id: String) -> Dictionary:
	var id := weapon_id if PROFILES.has(weapon_id) else DEFAULT
	if tuning.is_empty():
		return PROFILES[id]
	var tuned: Dictionary = PROFILES[id].duplicate(true)
	for key: String in tuning:
		if key.begins_with(id + "."):
			tuned[key.trim_prefix(id + ".")] = tuning[key]
	return tuned


## True if `target` lies within a cone from `origin` along `direction`
## (horizontal plane only).
static func in_cone(origin: Vector3, direction: Vector3, target: Vector3, max_range: float,
		cone_deg: float) -> bool:
	var offset := Vector3(target.x - origin.x, 0.0, target.z - origin.z)
	if offset.length() > max_range:
		return false
	if offset.length_squared() < 0.01:
		return true
	var flat_direction := Vector3(direction.x, 0.0, direction.z)
	return absf(flat_direction.signed_angle_to(offset, Vector3.UP)) <= deg_to_rad(cone_deg / 2.0)
