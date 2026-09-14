class_name Armor
extends RefCounted
## Where a shell strikes a hull decides how much it hurts. This is the core
## positioning trade-off of tank combat: face your enemy, flank theirs.

enum Facing { FRONT, SIDE, REAR }

const MULTIPLIER := {Facing.FRONT: 0.5, Facing.SIDE: 1.0, Facing.REAR: 1.5}
## G6 directional shields: shields are strongest in front too. An even shield (the first cut) wiped out
## the payoff for flanking, and the flanking doctrine (Anvil & Hammer) fell from ~50% to 8% vs Individuals.
const SHIELD_FACING := {"front": 0.7, "side": 1.0, "rear": 1.4}
const FACING_NAMES := {Facing.FRONT: "front", Facing.SIDE: "side", Facing.REAR: "rear"}
## A hit within this many degrees of dead-ahead counts as front (or dead-behind as rear).
const ARC_DEG := 45.0


## Which armor face a shell travelling along `shell_direction` strikes on a hull
## facing `hull_forward`. Only the horizontal plane matters.
static func facing(hull_forward: Vector3, shell_direction: Vector3) -> Facing:
	var forward := Vector3(hull_forward.x, 0.0, hull_forward.z).normalized()
	# Direction from the hull back toward where the shell came from.
	var toward_shooter := Vector3(-shell_direction.x, 0.0, -shell_direction.z).normalized()
	var alignment := forward.dot(toward_shooter)
	var arc := cos(deg_to_rad(ARC_DEG))
	if alignment >= arc:
		return Facing.FRONT
	if alignment <= -arc:
		return Facing.REAR
	return Facing.SIDE


static func damage(base_damage: float, hull_forward: Vector3, shell_direction: Vector3) -> int:
	return roundi(base_damage * MULTIPLIER[facing(hull_forward, shell_direction)])


## Multiplier for a weapon profile's own armor table (see Weapons.PROFILES).
static func weapon_multiplier(weapon: Dictionary, hull_forward: Vector3, attack_direction: Vector3) -> float:
	return weapon["armor"][FACING_NAMES[facing(hull_forward, attack_direction)]]


## G6 shields: how one hit of `raw` damage splits between a shield holding `shield` points and the
## hull behind it. The shield takes raw x shield_multiplier (the weapon's, times SHIELD_FACING); whatever the shield can't
## absorb continues to the hull as the matching fraction of raw, times the armor multiplier.
## Returns Vector2(shield damage, hull damage).
static func split_shield(raw: float, shield: float, shield_multiplier: float, armor_multiplier: float) -> Vector2:
	var against_shield := raw * shield_multiplier
	if shield <= 0.0 or against_shield <= 0.0:
		return Vector2(0.0, raw * armor_multiplier)
	if against_shield <= shield:
		return Vector2(against_shield, 0.0)
	var absorbed_fraction := shield / against_shield
	return Vector2(shield, raw * (1.0 - absorbed_fraction) * armor_multiplier)
