class_name K2Events
extends RefCounted
## The K2 weapon-event shapes as the feel stream reads them (_agents/workstreams.md, K2), plus the stub mapping from
## today's weapon profiles to fire models until combat's profile v3 lands (CP2). Pure helpers: no nodes, no renderer.
##
## weapon_fired:      {tick, shooter, weapon, fire_model, muzzle [x,y,z], direction [x,y,z], projectile_id}
## projectile_impact: {tick, projectile_id, position, normal, target?, face?: "front"|"side"|"rear", weak_spot, damage,
##                     killed}

const FIRE_MODELS: Array[String] = ["shell", "burst", "stream", "beam", "arc"]


## A weapon profile's fire model: its own `fire_model` (profile v3), else the round-2 stub mapping by kind and id.
static func fire_model(weapon: Dictionary) -> String:
	var own := String(weapon.get("fire_model", ""))
	if own in FIRE_MODELS:
		return own
	match int(weapon.get("kind", Weapons.Kind.PROJECTILE)):
		Weapons.Kind.ARC:
			return "arc"
		Weapons.Kind.CONE:
			return ""  # flamethrowers spray every tick: their visual slot draws them, not weapon events
		Weapons.Kind.BEAM:
			# The round-2 machine gun is a hitscan "beam" drawn as tracers; lasers are real beams.
			return "stream" if String(weapon.get("fx", "")) == "fx.tracer" else "beam"
	return "burst" if float(weapon.get("reload", weapon.get("reload_s", 3.0))) < 1.0 else "shell"


## How fast a weapon's rounds fly (m/s); 0 = hitscan. Profile v3's `projectile_speed_mps`, else round 2's kinds.
static func projectile_speed(weapon: Dictionary) -> float:
	if weapon.has("projectile_speed_mps"):
		return float(weapon["projectile_speed_mps"])
	return 0.0 if int(weapon.get("kind", Weapons.Kind.PROJECTILE)) == Weapons.Kind.BEAM else Shell.SPEED


## K2 carries positions as [x, y, z] arrays (serializable); tests and adapters may pass vectors.
static func to_vector(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Array and (value as Array).size() >= 3:
		return Vector3(float(value[0]), float(value[1]), float(value[2]))
	return Vector3.ZERO


static func from_vector(value: Vector3) -> Array:
	return [value.x, value.y, value.z]


static func fired_event(tick: int, shooter: String, weapon_id: String, weapon: Dictionary, muzzle: Vector3,
		direction: Vector3, projectile_id: int) -> Dictionary:
	return {"tick": tick, "shooter": shooter, "weapon": weapon_id, "fire_model": fire_model(weapon),
			"muzzle": from_vector(muzzle), "direction": from_vector(direction), "projectile_id": projectile_id}


static func impact_event(tick: int, projectile_id: int, position: Vector3, normal: Vector3, target: String,
		killed: bool) -> Dictionary:
	var event := {"tick": tick, "projectile_id": projectile_id, "position": from_vector(position),
			"normal": from_vector(normal), "weak_spot": false, "damage": 0.0, "killed": killed}
	if target != "":
		event["target"] = target
	return event
