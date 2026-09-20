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
## X3 (round 3) weak spots: a round arriving within this many degrees of dead astern strikes the engine deck. The deck
## is armored like WEAK_SPOT_ARMOR_FRACTION of the rear, so light guns get through there (a scout's stream on a tank's
## engine: 0.63 -> 1.13 of each round) while heavy rounds, already at the penetration cap from behind, don't turn into
## one-shot kills. The hit is flagged `weak_spot` in Match.projectile_impact for effects and the announcer.
const WEAK_SPOT_ARC_DEG := 25.0
const WEAK_SPOT_ARMOR_FRACTION := 0.5


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


## X3: whether a round travelling along `shell_direction` strikes the engine deck of a hull facing `hull_forward`.
## Round 9 (`--tune=match.no_damage=1`, never set in play): nothing takes damage, nothing dies, and therefore nothing
## respawns. For TIMING BENCHES that sample a live battle: feel's hinge bench and show's layer bench were comparing
## per-cycle deltas while the census walked down as units died (90 -> 77 in six cycles), so every delta disagreed in
## sign and the measurement was of attrition rather than of the thing under test. Freezing the census is a change to
## the simulation, so it lives here rather than in art. `Tank.take_hit` is the single seam every source of damage
## passes through -- shells, splash and hazards alike -- so one guard covers all of them.
static var no_damage := false


## Round 9 diagnostic (`--tune=probe.deck=1`, never set in play): print one line per enemy hit with the three
## quantities that decide who owns a missing engine-deck hit -- the angle between the victim's hull forward and the
## shell's travel, the shooter's bearing relative to the victim, and the range. `is_weak_spot` below is two directions
## and a dot product with NO position and NO hull size, so a deck hit cannot have gone missing because hulls grew;
## the three columns say whether the shooter never gets astern, gets astern and the flag misses, or never closes.
static var deck_probe := false


static func is_weak_spot(hull_forward: Vector3, shell_direction: Vector3) -> bool:
	var forward := Vector3(hull_forward.x, 0.0, hull_forward.z).normalized()
	var travel := Vector3(shell_direction.x, 0.0, shell_direction.z).normalized()
	return forward.dot(travel) >= cos(deg_to_rad(WEAK_SPOT_ARC_DEG))


static func damage(base_damage: float, hull_forward: Vector3, shell_direction: Vector3) -> int:
	return roundi(base_damage * MULTIPLIER[facing(hull_forward, shell_direction)])


## R2 penetration (round 2): how much of a hit's damage gets through armor `thickness` (Units "armor", per face)
## for a round with `penetration` (Weapons "penetration"). Logarithmic in the ratio, so doubling penetration (or
## halving the armor) always adds +0.5: a round with 1.25x the armor's thickness gets half its damage through,
## 2.5x all of it, 5x the capped 1.5 (weak spots). The cannon against the tank reproduces round 1's
## front / side / rear table (0.5 / 1.0 / 1.5). Far below the armor a hit barely scratches (PENETRATION_FLOOR),
## which is what lets light guns lose to heavy fronts without a damage table.
const PENETRATION_FLOOR := 0.05
const PENETRATION_CAP := 1.5


static func penetration_multiplier(penetration: float, thickness: float) -> float:
	if thickness <= 0.0:
		return PENETRATION_CAP
	if penetration <= 0.0:
		return PENETRATION_FLOOR
	return clampf(0.5 * log(1.6 * penetration / thickness) / log(2.0), PENETRATION_FLOOR, PENETRATION_CAP)


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
