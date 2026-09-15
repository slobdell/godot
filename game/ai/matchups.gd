class_name Matchups
extends RefCounted
## Matchup-aware fighting (A5, _agents/unit_ai.md §6): how much damage a unit can actually put on another right
## now, estimated from the same mechanics the rules use (shields, armor facing and penetration, spread, turret
## tracking vs the target's angular speed, fixed fire arcs, minimum range), plus the catalog's good_vs/weak_vs
## as a prior. Pure: it takes plain profile dictionaries, so it works on hand-built data in tests and on
## catalog v2 (`Units.PROFILES[id]`, `Weapons.PROFILES[id]`) once checkpoint 1 lands.
##
## Geometry (Dictionary): "distance" m, "face" ("front"/"side"/"rear": the defender's face toward the attacker),
## "shield_up" bool, "angular_speed_deg" (how fast the defender sweeps around the attacker, deg/s),
## "aim_error_deg" (how far the attacker's hull/turret is from pointing at it now).

## Round 1/rules' armor model: the multiplier a round with `penetration` gets through armor `thickness`.
## Mirrors rules' Armor.penetration_multiplier (catalog v2); kept here so this file doesn't depend on it.
const PENETRATION_FLOOR := 0.05
const PENETRATION_CAP := 1.5
const SHIELD_FACING := {"front": 0.7, "side": 1.0, "rear": 1.4}
## A hull's half width (m): what a spreading gun has to hit.
const TARGET_HALF_WIDTH := 1.2
## The catalog's design intent nudges the mechanical estimate.
const GOOD_VS := 1.25
const WEAK_VS := 0.8


static func penetration_multiplier(penetration: float, thickness: float) -> float:
	if thickness <= 0.0:
		return PENETRATION_CAP
	if penetration <= 0.0:
		return PENETRATION_FLOOR
	return clampf(0.5 * log(1.6 * penetration / thickness) / log(2.0), PENETRATION_FLOOR, PENETRATION_CAP)


## Expected damage per second `attacker` (unit profile) with `weapon` (weapon profile) does to `defender` (unit
## profile) given `geometry`. 0 when it can't shoot it at all (out of range, inside a mortar's minimum range).
static func effective_dps(attacker: Dictionary, weapon: Dictionary, defender: Dictionary, geometry: Dictionary) -> float:
	var distance := float(geometry.get("distance", 30.0))
	if distance > float(weapon.get("range", 0.0)) or distance < float(weapon.get("min_range", 0.0)):
		return 0.0
	var reload := maxf(float(weapon.get("reload", 1.0)), 0.05)
	var dps := float(weapon["damage_per_second"]) if weapon.has("damage_per_second") else float(weapon.get("damage", 0.0)) / reload
	var face := String(geometry.get("face", "front"))
	if geometry.get("shield_up", false):
		dps *= float(weapon.get("shield_multiplier", 1.0)) * float(SHIELD_FACING.get(face, 1.0))
	elif weapon.has("penetration") and defender.has("armor"):
		dps *= penetration_multiplier(float(weapon["penetration"]), float(defender["armor"].get(face, 1.0)))
	elif weapon.has("armor"):
		dps *= float(weapon["armor"].get(face, 1.0))
	return dps * hit_chance(weapon, distance) * tracking(attacker, weapon, geometry)


## Rough chance a round hits a hull at `distance`: its angular half width over the weapon's spread. Arcs and
## flames don't miss that way.
static func hit_chance(weapon: Dictionary, distance: float) -> float:
	var spread := float(weapon.get("spread_deg", 0.0))
	if spread <= 0.0 or weapon.has("splash_radius") and float(weapon.get("splash_radius", 0.0)) > 0.0:
		return 1.0
	return clampf(rad_to_deg(atan(TARGET_HALF_WIDTH / maxf(distance, 1.0))) / (1.5 * spread), 0.15, 1.0)


## How well the gun stays on a target sweeping around it: 1 while the target's angular speed is under half the
## turn rate, falling to 0.1 at the full rate. A fixed mount turns with the hull (its hull_turn_rate_deg), and a
## target outside its fire arc right now only gets a fraction.
static func tracking(attacker: Dictionary, weapon: Dictionary, geometry: Dictionary) -> float:
	var fixed := String(attacker.get("mount", "turret")) == "fixed"
	var rate := float(attacker.get("hull_turn_rate_deg" if fixed else "turret_turn_rate_deg", 110.0))
	var omega := absf(float(geometry.get("angular_speed_deg", 0.0)))
	var result := 1.0 if rate <= 0.0 else clampf(1.0 - (omega - 0.5 * rate) / (0.5 * rate), 0.1, 1.0)
	if fixed and absf(float(geometry.get("aim_error_deg", 0.0))) > float(attacker.get("fire_arc_deg", 360.0)) / 2.0:
		result *= 0.3
	if weapon.get("kind", -1) == Weapons.Kind.ARC:
		result = 1.0 if omega < 5.0 else 0.6  # rounds in the air: moving targets dodge
	return result


## The catalog prior for `attacker` against `defender`: GOOD_VS if it lists the defender's role, WEAK_VS if it's
## weak against it, else 1.
static func prior(attacker: Dictionary, defender: Dictionary) -> float:
	var role := String(defender.get("role", defender.get("class", "")))
	if (attacker.get("good_vs", []) as Array).has(role):
		return GOOD_VS
	if (attacker.get("weak_vs", []) as Array).has(role):
		return WEAK_VS
	return 1.0


## How much better I do in a straight duel: the time I need to kill it over the time it needs to kill me
## (> 1: I win). Toughness = hull + shield.
static func duel_advantage(me: Dictionary, my_weapon: Dictionary, my_toughness: float, my_geometry: Dictionary,
		them: Dictionary, their_weapon: Dictionary, their_toughness: float, their_geometry: Dictionary) -> float:
	var mine := effective_dps(me, my_weapon, them, my_geometry) * prior(me, them)
	var theirs := effective_dps(them, their_weapon, me, their_geometry) * prior(them, me)
	if theirs <= 0.0:
		return 4.0 if mine > 0.0 else 1.0
	if mine <= 0.0:
		return 0.25
	return clampf((my_toughness / theirs) / (their_toughness / mine), 0.25, 4.0)
