class_name WeaponFx
extends RefCounted
## Effect families, one per K2 fire_model (feel X1). `fired(event)` draws the muzzle side of a shot, `impact(event)`
## the landing side, both from FxWorld's pooled systems: no nodes, meshes, materials, or lights per shot. Families
## are data (FAMILIES); the code below composes them into pieces. `last_pieces` names what the last event drew, for
## tests and the FX lab.

## Projectiles remembered between their weapon_fired and projectile_impact events (oldest forgotten first).
const MAX_TRACKED := 256

## Per fire model. Sizes are meters, durations seconds, sounds are SfxSystem keys.
const FAMILIES := {
	"shell": {"fire_sound": "cannon_shot", "flash_size": 3.2, "flash_seconds": 0.1, "glow_size": 7.0,
			"light_energy": 6.0, "light_range": 10.0, "hit_size": 3.2, "kill_shake": 0.55, "hit_shake": 0.12},
	"burst": {"fire_sound": "autocannon_shot", "flash_size": 1.5, "flash_seconds": 0.06, "glow_size": 3.0,
			"light_energy": 3.0, "light_range": 6.0, "hit_size": 1.2, "kill_shake": 0.45, "hit_shake": 0.0},
	"stream": {"fire_sound": "mg_round", "flash_size": 0.9, "flash_seconds": 0.04, "glow_size": 0.0,
			"light_energy": 2.0, "light_range": 4.0, "hit_size": 0.6, "kill_shake": 0.4, "hit_shake": 0.0},
	"beam": {"fire_sound": "laser_pulse", "flash_size": 0.0, "flash_seconds": 0.0, "glow_size": 0.0,
			"light_energy": 0.0, "light_range": 0.0, "hit_size": 1.4, "kill_shake": 0.5, "hit_shake": 0.0},
	"arc": {"fire_sound": "mortar_launch", "flash_size": 2.2, "flash_seconds": 0.12, "glow_size": 4.0,
			"light_energy": 4.0, "light_range": 8.0, "hit_size": 4.0, "kill_shake": 0.55, "hit_shake": 0.25},
}
const NEUTRAL_GLOW := Color(1.0, 0.85, 0.6)

## Events handled since load.
var events := 0
## What the last event drew (piece names), and which family drew it.
var last_pieces := PackedStringArray()
var last_family := ""
## unit name -> Node (the vehicle) or null; set by MatchFxLink.
var resolver: Callable

var _fx: FxWorld
## projectile_id -> {model, shooter, color, muzzle, direction}
var _projectiles := {}
var _order: Array[int] = []


func _init(fx: FxWorld) -> void:
	_fx = fx


func tracked_projectiles() -> int:
	return _projectiles.size()


## K2 weapon_fired: the muzzle side of a shot.
func fired(event: Dictionary) -> void:
	var model := _model_of(event)
	if not FAMILIES.has(model):
		return
	events += 1
	last_pieces = PackedStringArray()
	last_family = model
	var family: Dictionary = FAMILIES[model]
	var muzzle := K2Events.to_vector(event.get("muzzle"))
	var direction := K2Events.to_vector(event.get("direction"))
	var shooter := _unit(String(event.get("shooter", "")))
	var color := _team_glow(shooter)
	_track(int(event.get("projectile_id", -1)), {"model": model, "color": color, "muzzle": muzzle, "direction": direction})
	match model:
		"shell":
			_muzzle_blast(family, muzzle, direction, color)
		"beam":
			last_pieces.append("beam_slot")  # the fx.laser_beam slot knows both ends; it draws the pulse
		_:
			_muzzle_flash(family, muzzle, color)
	if model != "beam":
		_fx.sfx.play_at(String(family["fire_sound"]), muzzle)
		last_pieces.append("sound:" + String(family["fire_sound"]))


## K2 projectile_impact: the landing side.
func impact(event: Dictionary) -> void:
	var id := int(event.get("projectile_id", -1))
	var shot: Dictionary = _projectiles.get(id, {})
	var model := String(shot.get("model", event.get("fire_model", "shell")))
	if not FAMILIES.has(model):
		model = "shell"
	_forget(id)
	events += 1
	last_pieces = PackedStringArray()
	last_family = model
	var family: Dictionary = FAMILIES[model]
	var position := K2Events.to_vector(event.get("position"))
	var killed := bool(event.get("killed", false))
	var has_target := String(event.get("target", "")) != ""
	if killed:
		_kill(family, position)
	elif has_target:
		_armor_hit(family, position, bool(event.get("weak_spot", false)))
	else:
		_miss(family, position)


func _muzzle_blast(family: Dictionary, muzzle: Vector3, direction: Vector3, color: Color) -> void:
	var now := _fx.now
	_fx.bursts.spawn(BurstSystem.Kind.STAR, muzzle + direction * 0.8, float(family["flash_size"]), float(family["flash_seconds"]), color.lightened(0.5), now)
	_fx.bursts.spawn(BurstSystem.Kind.GROUND_GLOW, muzzle, float(family["glow_size"]), 0.25, color * 0.6, now)
	_fx.lights.flash(muzzle, color.lightened(0.3), float(family["light_energy"]), float(family["light_range"]), 0.12,
			LightPool.PRIORITY_MUZZLE, now)
	last_pieces.append("muzzle_blast")


func _muzzle_flash(family: Dictionary, muzzle: Vector3, color: Color) -> void:
	var now := _fx.now
	_fx.bursts.spawn(BurstSystem.Kind.STAR, muzzle, float(family["flash_size"]), float(family["flash_seconds"]), color.lightened(0.4), now)
	if float(family["glow_size"]) > 0.0:
		_fx.bursts.spawn(BurstSystem.Kind.GROUND_GLOW, muzzle, float(family["glow_size"]), 0.15, color * 0.5, now)
	_fx.lights.flash(muzzle, color, float(family["light_energy"]), float(family["light_range"]), 0.06,
			LightPool.PRIORITY_MUZZLE - 0.5, now)
	last_pieces.append("muzzle_flash")


func _kill(family: Dictionary, position: Vector3) -> void:
	_fx.explosion(position, true)
	_fx.shake.add(float(family["kill_shake"]) - 0.55, position, 30.0)  # explosion(big) already shakes 0.55
	last_pieces.append("kill_explosion")


func _armor_hit(family: Dictionary, position: Vector3, weak_spot: bool) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	_fx.bursts.spawn(BurstSystem.Kind.STAR, position, size * (1.6 if weak_spot else 1.0), 0.12, Color(1.0, 0.75, 0.4), now)
	if size >= 3.0:
		_fx.explosion(position, false)
	last_pieces.append("weak_spot_hit" if weak_spot else "armor_sparks")


func _miss(family: Dictionary, position: Vector3) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	_fx.bursts.spawn(BurstSystem.Kind.GROUND_GLOW, position, size * 1.5, 0.3, Color(0.5, 0.3, 0.15), now)
	if size >= 3.0:
		_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position + Vector3.UP * size * 0.2, size * 0.7, 0.5, Color(0.8, 0.7, 0.6), now)
	last_pieces.append("dirt_blast" if size >= 3.0 else "dirt_puff")


func _model_of(event: Dictionary) -> String:
	var model := String(event.get("fire_model", ""))
	if model == "" and event.has("weapon"):
		model = K2Events.fire_model(Weapons.profile(String(event["weapon"])))
	return model


func _unit(unit_name: String) -> Node:
	return resolver.call(unit_name) if resolver.is_valid() and unit_name != "" else null


func _team_glow(unit: Node) -> Color:
	if unit != null and unit.get("team") is int:
		return GameTheme.team_glow(int(unit.get("team")))
	return NEUTRAL_GLOW


func _track(id: int, shot: Dictionary) -> void:
	if id < 0:
		return
	if not _projectiles.has(id):
		_order.append(id)
	_projectiles[id] = shot
	while _order.size() > MAX_TRACKED:
		_projectiles.erase(_order.pop_front())


func _forget(id: int) -> void:
	if _projectiles.erase(id):
		_order.erase(id)
