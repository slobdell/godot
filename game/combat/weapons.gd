class_name Weapons
extends RefCounted
## Weapon profiles are DATA. A tank carries a weapon id; the rules (Match), the
## order layer (aiming/firing), and the brain (preferred range) all read the
## profile. Adding a weapon should mostly mean adding a row here.
## See _agents/tank_brain.md "Weapons v1".

enum Kind { PROJECTILE, CONE }

const DEFAULT := "cannon"

const PROFILES := {
	"cannon": {
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
	},
	"flamethrower": {
		"kind": Kind.CONE,
		"range": 20.0,
		"preferred_min": 6.0,
		"preferred_max": 16.0,
		"damage_per_second": 45.0,
		"cone_deg": 30.0,
		"reload": 0.0,
		"aim_tolerance_deg": 12.0,
		# Fire wraps around armor: facing matters much less than for shells.
		"armor": {"front": 0.8, "side": 1.0, "rear": 1.2},
	},
}


static func exists(weapon_id: String) -> bool:
	return PROFILES.has(weapon_id)


static func profile(weapon_id: String) -> Dictionary:
	return PROFILES.get(weapon_id, PROFILES[DEFAULT])


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
