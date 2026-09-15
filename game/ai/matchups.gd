class_name Matchups
extends RefCounted
## Matchup-aware fighting (A5, _agents/unit_ai.md §6): how fast a unit can actually kill another right now,
## estimated from the same mechanics the rules use (shields, armor facing and penetration, spread, turret tracking
## vs the target's angular speed, fixed fire arcs, minimum range), plus the catalog's good_vs/weak_vs as a prior.
## Pure over plain profile dictionaries (`Units.PROFILES[id]`, `Weapons.PROFILES[id]`), so tests use hand-built data.
##
## PORTABILITY (_agents/determinism.md): no trig. Angles arrive as flags ("in_arc") or rates the caller computed
## with cross products; the small-angle approximation stands in for atan in hit_chance.
##
## Geometry (Dictionary): "distance" m, "face" ("front"/"side"/"rear": the defender's face toward the attacker),
## "angular_speed_deg" (how fast the defender sweeps around the attacker, deg/s), "in_arc" (fixed mounts: is the
## defender inside the fire arc right now; default true), "weak_spot" (rounds strike the engine deck: within the
## weak-spot arc of dead astern; only counts with face "rear").

## Mirrors rules' Armor.penetration_multiplier (catalog v2).
const PENETRATION_FLOOR := 0.05
const PENETRATION_CAP := 1.5
## Mirrors Armor's round-3 engine deck: cos(WEAK_SPOT_ARC_DEG = 25°) (a constant, no runtime trig) and the deck's share of
## the rear armor.
const WEAK_SPOT_COS := 0.906307787
const WEAK_SPOT_ARMOR_FRACTION := 0.5
const SHIELD_FACING := {"front": 0.7, "side": 1.0, "rear": 1.4}
## A hull's half width (m): what a spreading gun has to hit.
const TARGET_HALF_WIDTH := 1.2
## The catalog's design intent nudges the mechanical estimate.
const GOOD_VS := 1.25
const WEAK_VS := 0.8
## A fixed gun whose target is outside its arc gets this fraction (it has to turn first).
const OUT_OF_ARC := 0.3
const NEVER := 1.0e9


static func penetration_multiplier(penetration: float, thickness: float) -> float:
	if thickness <= 0.0:
		return PENETRATION_CAP
	if penetration <= 0.0:
		return PENETRATION_FLOOR
	return clampf(0.5 * log(1.6 * penetration / thickness) / log(2.0), PENETRATION_FLOOR, PENETRATION_CAP)


## Expected damage per second `attacker` (unit profile) with `weapon` does to `defender` (unit profile), against its
## shield (`on_shield`) or its hull. 0 when it can't shoot it at all (out of range, inside a minimum range).
static func effective_dps(attacker: Dictionary, weapon: Dictionary, defender: Dictionary, geometry: Dictionary,
		on_shield: bool) -> float:
	var distance := float(geometry.get("distance", 30.0))
	if distance > float(weapon.get("range", 0.0)) or distance < float(weapon.get("min_range", 0.0)):
		return 0.0
	var reload := maxf(float(weapon.get("reload", 1.0)), 0.05)
	var per_pull := float(weapon.get("damage", 0.0)) * maxf(float(weapon.get("burst_count", 1)), 1.0)
	var dps := float(weapon["damage_per_second"]) if weapon.has("damage_per_second") else per_pull / reload
	var face := String(geometry.get("face", "front"))
	if on_shield:
		dps *= float(weapon.get("shield_multiplier", 1.0)) * float(SHIELD_FACING.get(face, 1.0))
	elif weapon.has("penetration") and defender.has("armor"):
		var thickness := float(defender["armor"].get(face, 1.0))
		if face == "rear" and geometry.get("weak_spot", false):
			thickness *= WEAK_SPOT_ARMOR_FRACTION
		dps *= penetration_multiplier(float(weapon["penetration"]), thickness)
	elif weapon.has("armor"):
		dps *= float(weapon["armor"].get(face, 1.0))
	return dps * hit_chance(weapon, distance) * tracking(attacker, weapon, geometry)


## Whether a round travelling along `shell_direction` strikes the engine deck of a hull facing `hull_forward` (mirrors
## Armor.is_weak_spot without trig).
static func is_weak_spot(hull_forward: Vector3, shell_direction: Vector3) -> bool:
	var forward := Vector2(hull_forward.x, hull_forward.z).normalized()
	return forward.dot(Vector2(shell_direction.x, shell_direction.z).normalized()) >= WEAK_SPOT_COS


## How much more of `weapon`'s damage gets through `defender`'s engine deck than its rear plate (1 = no gain: heavy
## rounds already at the cap). Brains seek the deck when this is worth the drive (TankBrain.DECK_SEEK_GAIN).
static func deck_gain(weapon: Dictionary, defender: Dictionary) -> float:
	if not weapon.has("penetration") or not defender.has("armor") or weapon.get("kind", -1) == Weapons.Kind.ARC:
		return 1.0
	var penetration := float(weapon["penetration"])
	var rear := float(defender["armor"].get("rear", 1.0))
	return penetration_multiplier(penetration, rear * WEAK_SPOT_ARMOR_FRACTION) / penetration_multiplier(penetration, rear)


## Rough chance a round hits a hull at `distance`: its angular half width (small-angle: width / distance, radians)
## over 1.5 × the weapon's spread. Splash and flames don't miss that way.
static func hit_chance(weapon: Dictionary, distance: float) -> float:
	var spread := deg_to_rad(float(weapon.get("spread_deg", 0.0)))
	if spread <= 0.0 or float(weapon.get("splash_radius", 0.0)) > 0.0:
		return 1.0
	return clampf((TARGET_HALF_WIDTH / maxf(distance, 1.0)) / (1.5 * spread), 0.15, 1.0)


## How well the gun stays on a target sweeping around it: 1 while the target's angular speed is under half the
## turn rate, falling to 0.1 at the full rate. A fixed mount turns with the hull (hull_turn_rate_deg) and only
## fires inside its arc. Arcing rounds are in the air a long time: a moving target dodges.
static func tracking(attacker: Dictionary, weapon: Dictionary, geometry: Dictionary) -> float:
	var omega := absf(float(geometry.get("angular_speed_deg", 0.0)))
	if weapon.get("kind", -1) == Weapons.Kind.ARC:
		return 1.0 if omega < 5.0 else 0.6
	var fixed := String(attacker.get("mount", "turret")) == "fixed"
	var rate := float(attacker.get("hull_turn_rate_deg" if fixed else "turret_turn_rate_deg", 110.0))
	var result := 1.0 if rate <= 0.0 else clampf(1.0 - (omega - 0.5 * rate) / (0.5 * rate), 0.1, 1.0)
	if fixed and not geometry.get("in_arc", true):
		result *= OUT_OF_ARC
	return result


## Seconds for `attacker` to destroy `defender` (hull `health` behind `shield`), ignoring shield recharge: the shield
## at the anti-shield rate, then the hull at the armor rate. NEVER if it can't.
static func time_to_kill(attacker: Dictionary, weapon: Dictionary, defender: Dictionary, geometry: Dictionary,
		health: float, shield: float) -> float:
	var hull_dps := effective_dps(attacker, weapon, defender, geometry, false) * prior(attacker, defender)
	if hull_dps <= 0.0:
		return NEVER
	var seconds := health / hull_dps
	if shield > 0.0:
		var shield_dps := effective_dps(attacker, weapon, defender, geometry, true) * prior(attacker, defender)
		seconds += NEVER if shield_dps <= 0.0 else shield / shield_dps
	return minf(seconds, NEVER)


## The catalog prior for `attacker` against `defender`: GOOD_VS if it lists the defender's role, WEAK_VS if it's
## weak against it, else 1.
static func prior(attacker: Dictionary, defender: Dictionary) -> float:
	var role := String(defender.get("role", defender.get("class", "")))
	if (attacker.get("good_vs", []) as Array).has(role):
		return GOOD_VS
	if (attacker.get("weak_vs", []) as Array).has(role):
		return WEAK_VS
	return 1.0


## How much better I do in a straight duel: the time it needs to kill me over the time I need to kill it (> 1: I
## win), clamped to [0.25, 4].
static func duel_advantage(my_time_to_kill: float, their_time_to_kill: float) -> float:
	if my_time_to_kill >= NEVER and their_time_to_kill >= NEVER:
		return 1.0
	if my_time_to_kill >= NEVER:
		return 0.25
	return clampf(their_time_to_kill / my_time_to_kill, 0.25, 4.0)
