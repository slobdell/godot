class_name Lethality
extends RefCounted
## Round 5 combat X5: how long one unit's gun takes to destroy another, straight from the rules: rounds per second
## (burst size over reload, capped by heat for energy weapons, damage per second for cones), the shield it must strip
## first (weapon shield multiplier x the face's shield factor), and the hull behind it (penetration against that
## face's armor, Armor.penetration_multiplier). Every hit lands and shields don't regrow: it's a ceiling on lethality,
## the number a crew would guess from what it knows about both vehicles, not a simulation.
##
## Brains use it without the matchup table (ai's SUPPRESS gate: "I can't kill this quickly, so pin it instead").
## Pure and static; reads Units and Weapons data (and their --tune overrides).

## A kill slower than this (seconds of perfect fire) is slow going: suppress it, flank it, or leave it to a better gun.
const SLOW_KILL_SECONDS := 20.0


## Rounds (or, for cones, damage-per-second "rounds" of 1 damage) this unit's weapon lands per second, sustained.
static func rounds_per_second(shooter_unit: String) -> float:
	var weapon := Weapons.profile(String(Units.stat(shooter_unit, "weapon")))
	if int(weapon["kind"]) == Weapons.Kind.CONE:
		return float(weapon.get("damage_per_second", 0.0))
	var reload := maxf(float(weapon.get("reload_s", weapon.get("reload", 1.0))), 0.01)
	var rate := maxf(1.0, float(weapon.get("burst_count", 1))) / reload
	var heat := float(weapon.get("heat_per_shot", 0.0))
	var dissipation := float(Units.stat(shooter_unit, "heat_dissipation", 0.0))
	if heat > 0.0 and dissipation > 0.0:
		rate = minf(rate, dissipation / heat)
	return rate


## Seconds of perfect fire for `shooter_unit` to destroy `target_unit` hitting its `face` ("front"/"side"/"rear").
## `health` / `shield` default to the target's full values. INF when the weapon can't hurt it at all.
static func seconds_to_kill(shooter_unit: String, target_unit: String, face: String, health := -1, shield := -1.0) -> float:
	var weapon := Weapons.profile(String(Units.stat(shooter_unit, "weapon")))
	var is_cone := int(weapon["kind"]) == Weapons.Kind.CONE
	var raw := 1.0 if is_cone else float(weapon.get("damage", 0.0))
	var rate := rounds_per_second(shooter_unit)
	if raw <= 0.0 or rate <= 0.0:
		return INF
	var effective_face := "side" if int(weapon["kind"]) == Weapons.Kind.ARC else face
	var hull := float(Units.stat(target_unit, "max_health")) if health < 0 else float(health)
	var shield_left := float(Units.stat(target_unit, "max_shield", 0.0)) if shield < 0.0 else shield
	var against_shield := raw * float(weapon.get("shield_multiplier", 1.0)) * float(Armor.SHIELD_FACING[effective_face])
	var through_armor := raw * Match.armor_multiplier(weapon, target_unit, effective_face)
	var seconds := 0.0
	if shield_left > 0.0 and against_shield > 0.0:
		seconds += shield_left / (against_shield * rate)
	if through_armor <= 0.0:
		return INF
	return seconds + hull / (through_armor * rate)


static func is_slow_kill(shooter_unit: String, target_unit: String, face: String, health := -1, shield := -1.0) -> bool:
	return seconds_to_kill(shooter_unit, target_unit, face, health, shield) > SLOW_KILL_SECONDS
