class_name WeaponFx
extends RefCounted
## Effect families, one per K2 fire_model (feel X1). `fired(event)` draws the muzzle side of a shot, `impact(event)`
## the landing side, both from FxWorld's pooled systems: no nodes, meshes, materials, or lights per shot. Families
## are data (FAMILIES); the code below composes them into pieces. `last_pieces` names what the last event drew, for
## tests and the FX lab.
##
## The tank shell (X2) is the showpiece: the lead wants tanks to fire rarely and land devastating hits, so every shot
## is an event (a deep blast, smoke ring, dust, recoil, a boom with a tail), every hit sells devastation (shockwave,
## sparks, debris, smoke, a shake scaled by distance), a kill cooks off, and a miss throws dirt.

## Projectiles remembered between their weapon_fired and projectile_impact events (oldest forgotten first).
const MAX_TRACKED := 256
## A missed shell whines past vehicles whose center it passed within this band (meters from the line of flight).
const WHINE_MIN := 1.2
const WHINE_MAX := 7.0

## Per fire model. Sizes are meters, durations seconds, sounds are SfxSystem keys, shakes are trauma (0..1) with the
## radius (m) inside which they hit full strength.
const FAMILIES := {
	"shell": {"fire_sound": "tank_boom", "hit_sound": "shell_hit_armor", "miss_sound": "dirt_impact",
			"flash_size": 3.6, "light_energy": 4.0, "light_range": 8.0, "hit_size": 4.0,
			"fire_shake": 0.16, "hit_shake": 0.32, "kill_shake": 0.8, "miss_shake": 0.12, "shake_radius": 24.0,
			"recoil_deg": 3.5, "recoil_m": 0.35, "hit_rock_deg": 4.5},
	"burst": {"fire_sound": "autocannon_shot", "hit_sound": "bullet_hit_metal", "miss_sound": "", "ricochet_chance": 0.3,
			"flash_size": 1.6, "light_energy": 3.0, "light_range": 6.0, "hit_size": 1.3,
			"fire_shake": 0.0, "hit_shake": 0.0, "kill_shake": 0.5, "miss_shake": 0.0, "shake_radius": 16.0,
			"recoil_deg": 0.6, "recoil_m": 0.04, "hit_rock_deg": 0.5},
	"stream": {"fire_sound": "mg_loop", "hit_sound": "bullet_hit_metal", "miss_sound": "", "ricochet_chance": 0.2,
			"flash_size": 1.3, "light_energy": 2.5, "light_range": 5.0, "hit_size": 1.1,
			"fire_shake": 0.0, "hit_shake": 0.0, "kill_shake": 0.45, "miss_shake": 0.0, "shake_radius": 14.0,
			"recoil_deg": 0.0, "recoil_m": 0.0, "hit_rock_deg": 0.0},
	"beam": {"fire_sound": "laser_pulse", "hit_sound": "", "miss_sound": "",
			"flash_size": 0.0, "light_energy": 0.0, "light_range": 0.0, "hit_size": 1.4,
			"fire_shake": 0.0, "hit_shake": 0.0, "kill_shake": 0.55, "miss_shake": 0.0, "shake_radius": 16.0,
			"recoil_deg": 0.0, "recoil_m": 0.0, "hit_rock_deg": 1.0},
	"arc": {"fire_sound": "mortar_launch", "hit_sound": "explosion_small", "miss_sound": "dirt_impact",
			"flash_size": 2.4, "light_energy": 4.0, "light_range": 8.0, "hit_size": 4.5,
			"fire_shake": 0.0, "hit_shake": 0.3, "kill_shake": 0.7, "miss_shake": 0.22, "shake_radius": 24.0,
			"recoil_deg": 1.2, "recoil_m": 0.08, "hit_rock_deg": 3.0},
}
const NEUTRAL_GLOW := Color(1.0, 0.85, 0.6)
const FIRE_COLOR := Color(1.0, 0.72, 0.42)
const SPARK_COLOR := Color(1.0, 0.55, 0.18)
const SMOKE_COLOR := Color(0.5, 0.5, 0.53)
const DUST_COLOR := Color(0.52, 0.43, 0.33)
const DIRT_COLOR := Color(0.36, 0.27, 0.19)
const METAL_COLOR := Color(0.32, 0.31, 0.3)
## Weak-spot hits flare gold: the "critical hit" color, never a team color (cyan and magenta).
const CRIT_COLOR := Color(1.0, 0.8, 0.22)
## Weak-spot flare size per fire model (m).
const CRIT_SIZE := {"shell": 9.0, "arc": 8.0, "burst": 5.0, "stream": 3.6, "beam": 5.0}
## Two kill explosions this close in time and space are one death reported twice (a hit and the unit's died signal).
const KILL_DEDUPE_SECONDS := 0.8
const KILL_DEDUPE_METERS := 6.0
const CRIT_EVERY := 0.15

## Events handled since load.
var events := 0
## What the last event drew (piece names), and which family drew it.
var last_pieces := PackedStringArray()
var last_family := ""
## unit name -> Node (the vehicle) or null; set by MatchFxLink.
var resolver: Callable
## () -> Array of vehicles (Node3D) for near-miss checks; set by MatchFxLink.
var units: Callable

var _fx: FxWorld
## projectile_id -> {model, shooter, color, muzzle, direction}
var _projectiles := {}
var _order: Array[int] = []
var _rng := RandomNumberGenerator.new()
## Draw hitscan rounds from weapon events (live K2). MatchFxLink turns it off in stub mode, where the fx.tracer slot
## knows both ends of each round and draws it instead.
var draw_hitscan := true
## The FX showcase only: treat every hit on a vehicle as a weak-spot hit (round 2 has no weak spots to show yet).
var showcase_weak_spots := false
## Hitscan rounds fired this frame, waiting for their impact (same tick) to know where they end: id -> shot.
var _pending_hitscan := {}
## Budgets for small rounds pouring into one hull: last spark and clank time per target, last ricochet sound.
var _last_spark := {}
var _last_clank := {}
var _last_ricochet_sound := -1.0
var _last_crit := {}
## [{position: Vector3, time: float}], recent kill explosions (for de-duplication).
var _recent_kills: Array[Dictionary] = []
## vehicle -> its ShieldEffect (or null), found once.
var _shield_cache := {}
## Small rounds on one target spark at most this often (s); a 11-rounds-a-second stream still reads as continuous.
const SPARK_EVERY := 0.07
const CLANK_EVERY := 0.09
const RICOCHET_SOUND_EVERY := 0.15


func _init(fx: FxWorld) -> void:
	_fx = fx
	_rng.seed = 2025


func tracked_projectiles() -> int:
	return _projectiles.size()


## K2 weapon_fired: the muzzle side of a shot.
func fired(event: Dictionary) -> void:
	var model := _model_of(event)
	var weapon := Weapons.profile(String(event.get("weapon", "")))
	# Combat's K2 announces flamethrower puffs as "stream" events; the flame slot draws fire, not machine-gun tracers.
	if not FAMILIES.has(model) or int(weapon.get("kind", -1)) == Weapons.Kind.CONE:
		return
	_begin(model)
	var family: Dictionary = FAMILIES[model]
	var muzzle := K2Events.to_vector(event.get("muzzle"))
	var direction := K2Events.to_vector(event.get("direction"))
	if direction.length() < 0.001:
		direction = Vector3.FORWARD
	direction = direction.normalized()
	var shooter_name := String(event.get("shooter", ""))
	var shooter := _unit(shooter_name)
	var color := _team_glow(shooter)
	_track(int(event.get("projectile_id", -1)), {"model": model, "shooter": shooter_name, "color": color, "muzzle": muzzle,
			"direction": direction})
	var speed := float(event.get("speed_mps", K2Events.projectile_speed(weapon)))
	if draw_hitscan and (model == "stream" or model == "burst") and speed <= 0.0:
		_pending_hitscan[int(event.get("projectile_id", -1))] = {"muzzle": muzzle, "direction": direction,
				"range": float(event.get("range", weapon.get("range", 45.0))), "color": color, "model": model}
	match model:
		"shell":
			_shell_blast(family, muzzle, direction, color)
		"beam":
			_piece("beam_slot")  # the fx.laser_beam slot knows both ends; it draws the pulse
		_:
			_muzzle_flash(family, muzzle, direction, color)
	if float(family["recoil_deg"]) > 0.0 and shooter is Node3D:
		_fx.jolts.kick(shooter, -direction, float(family["recoil_deg"]), float(family["recoil_m"]), _fx.now)
		_piece("recoil")
	if float(family["fire_shake"]) > 0.0:
		_fx.shake.add(float(family["fire_shake"]), muzzle, float(family["shake_radius"]) * 0.8)
	if model == "stream":
		# Held loops, not a click per round: the nearest few gunners get a brrrt that lasts as long as their trigger.
		_fx.gunfire.trigger(shooter_name if shooter_name != "" else str(muzzle.snapped(Vector3.ONE)), muzzle, _fx.now)
		_piece("sound:mg_loop")
	elif model != "beam":
		_sound(String(family["fire_sound"]), muzzle)


## Hitscan rounds that got no impact this frame hit nothing: they fly their full range. FxWorld calls it once per frame.
func flush(now: float) -> void:
	# A gun held down lights its muzzle with a hard flicker for as long as it fires, not just on the frame of each round.
	var gunners := _fx.gunfire.firing_positions(now)
	for i in gunners.size():
		var flicker := 0.35 + 0.65 * absf(sin(now * 71.0 + i * 1.7) * sin(now * 43.0 + i))
		_fx.lights.request(gunners[i] + Vector3.UP * 0.2, Color(1.0, 0.8, 0.45), 3.2 * flicker, 6.0, LightPool.PRIORITY_MUZZLE - 0.2)
	for id in _pending_hitscan:
		var shot: Dictionary = _pending_hitscan[id]
		var muzzle: Vector3 = shot["muzzle"]
		_fx.tracers.shoot(muzzle, muzzle + shot["direction"] * float(shot["range"]), shot["color"], shot["model"], now)
	_pending_hitscan.clear()


## Stub (round 2): a hitscan round drawn by the fx.tracer slot from `from` to `to`. `target` is the vehicle it struck
## ("" = none); `hit_world` means it stopped short on a wall or prop.
func hitscan(from: Vector3, to: Vector3, shooter_name: String, target: String, hit_world: bool, model := "stream") -> void:
	var color := _team_glow(_unit(shooter_name))
	_fx.tracers.shoot(from, to, color, model, _fx.now)
	if target != "":
		impact({"projectile_id": -1, "fire_model": model, "position": K2Events.from_vector(to), "target": target,
				"normal": K2Events.from_vector((from - to).normalized()), "killed": false, "weak_spot": false})
	elif hit_world:
		_begin(model)
		_small_miss(model, FAMILIES[model], to)


## K2 projectile_impact: the landing side.
func impact(event: Dictionary) -> void:
	var id := int(event.get("projectile_id", -1))
	var shot: Dictionary = _projectiles.get(id, {})
	if _pending_hitscan.has(id):
		var pending: Dictionary = _pending_hitscan[id]
		_fx.tracers.shoot(pending["muzzle"], K2Events.to_vector(event.get("position")), pending["color"], pending["model"], _fx.now)
		_pending_hitscan.erase(id)
	var model := String(shot.get("model", event.get("fire_model", "shell")))
	if not FAMILIES.has(model):
		model = "shell"
	_forget(id)
	_begin(model)
	var family: Dictionary = FAMILIES[model]
	var position := K2Events.to_vector(event.get("position"))
	var direction: Vector3 = shot.get("direction", -K2Events.to_vector(event.get("normal", [0.0, 0.0, 1.0])))
	var killed := bool(event.get("killed", false))
	var target_name := String(event.get("target", ""))
	var target := _unit(target_name)
	if target_name != "" or killed:
		var weak_spot := bool(event.get("weak_spot", false)) or (showcase_weak_spots and target_name != "")
		if not killed and _shielded(target):
			_shield_splash(model, family, position, direction, target)
		else:
			match model:
				"shell", "arc":
					_shell_hit(family, position, direction, killed)
				_:
					_small_hit(model, family, position, direction, weak_spot, target_name)
			if weak_spot:
				_weak_spot(model, position, direction, target_name)
		if killed:
			_kill(model, family, position, direction, target_name)
		if float(family["hit_rock_deg"]) > 0.0 and target is Node3D:
			_fx.jolts.kick(target, direction, float(family["hit_rock_deg"]) * (1.6 if killed else 1.0), 0.2, _fx.now, 15.0, 4.5)
			_piece("hit_rock")
	else:
		match model:
			"shell", "arc":
				_shell_miss(family, position, direction)
				if model == "shell" and shot.has("muzzle"):
					_near_miss(shot["muzzle"], position, String(shot.get("shooter", "")))
			_:
				_small_miss(model, family, position)


# ---- Shell family (X2) ---------------------------------------------------------------------------------------------

func _shell_blast(family: Dictionary, muzzle: Vector3, direction: Vector3, color: Color) -> void:
	var now := _fx.now
	var hot := color.lerp(Color(1.0, 0.92, 0.75), 0.6)
	var flat := Vector3(direction.x, 0.0, direction.z).normalized() if Vector2(direction.x, direction.z).length() > 0.01 else Vector3.FORWARD
	# The flash: a white-hot star, a tongue of fire ahead of the barrel, and a bright light that paints the tank and floor.
	_fx.bursts.spawn(BurstSystem.Kind.STAR, muzzle + direction * 1.2, float(family["flash_size"]), 0.13, hot, now)
	_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, muzzle + direction * 2.2, 3.4, 0.32, FIRE_COLOR, now, direction * 9.0, 7.0)
	_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, muzzle + direction * 1.0, 2.2, 0.26, FIRE_COLOR, now + 0.02, direction * 4.0, 6.0)
	_fx.lights.flash(muzzle + direction * 1.5, hot, float(family["light_energy"]), float(family["light_range"]), 0.16,
			LightPool.PRIORITY_EXPLOSION, now)
	_piece("muzzle_fireball")
	# The smoke ring: puffs flung outward perpendicular to the barrel, drifting forward, stalling, and hanging.
	var side := direction.cross(Vector3.UP).normalized() if absf(direction.y) < 0.95 else Vector3.RIGHT
	var up := side.cross(direction).normalized()
	var puffs := _count(8, 5)
	for i in puffs:
		var angle := TAU * (float(i) + _rng.randf_range(-0.2, 0.2)) / puffs
		var out := side * cos(angle) + up * sin(angle)
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, muzzle + direction * 1.6, _rng.randf_range(1.8, 2.6), _rng.randf_range(1.6, 2.2),
				Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.3), now + 0.03, out * 6.5 + direction * 5.0, 3.2, 0.0, 0.5)
	_fx.bursts.spawn(BurstSystem.Kind.SMOKE, muzzle + direction * 3.0, 3.2, 2.6, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.4),
			now + 0.05, direction * 7.0, 2.0, 0.0, 0.6)
	_piece("smoke_ring")
	# The blast kicks dust off the ground: a ring racing out under the barrel and low puffs rolling away.
	var ground := Vector3(muzzle.x, 0.0, muzzle.z) + flat * 2.5
	_fx.bursts.spawn(BurstSystem.Kind.SHOCKWAVE, ground, 16.0, 0.5, DUST_COLOR * 0.7, now)
	_fx.bursts.spawn(BurstSystem.Kind.GROUND_GLOW, ground, 6.0, 0.22, color * 0.35, now)
	var dust := _count(6, 3)
	for i in dust:
		var angle := lerpf(-1.3, 1.3, float(i) / maxf(dust - 1, 1)) + _rng.randf_range(-0.15, 0.15)
		var roll := flat.rotated(Vector3.UP, angle)
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, ground + roll * 1.5 + Vector3.UP * 0.6, _rng.randf_range(2.6, 3.6),
				_rng.randf_range(1.8, 2.6), Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.15), now + 0.04,
				roll * _rng.randf_range(6.0, 9.0), 2.4, 0.0, 0.4)
	_piece("dust_kick")


func _shell_hit(family: Dictionary, position: Vector3, direction: Vector3, killed: bool) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	# The strike: a white flash, a fireball punched along the shell's path, a spray of sparks and torn metal.
	_fx.bursts.spawn(BurstSystem.Kind.STAR, position - direction * 0.3, size * (1.0 if killed else 1.4), 0.12, Color(1.0, 0.9, 0.7), now)
	_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position + Vector3.UP * 0.5, size, 0.6, FIRE_COLOR, now, direction * 3.0, 3.0, 0.0, 0.8)
	_fx.bursts.spawn(BurstSystem.Kind.SPARKS, position + Vector3.UP * 0.8, size * 1.8, 0.7, SPARK_COLOR, now)
	_piece("sparks")
	_fx.bursts.spawn(BurstSystem.Kind.DEBRIS, position + Vector3.UP * 0.8, size * 1.5, 1.0, Color(METAL_COLOR.r, METAL_COLOR.g, METAL_COLOR.b, 1.0), now)
	_piece("debris")
	# The shockwave on the floor and a lingering black smoke from the wound.
	var ground := Vector3(position.x, 0.0, position.z)
	_fx.bursts.spawn(BurstSystem.Kind.SHOCKWAVE, ground, size * 4.5, 0.55, Color(1.0, 0.62, 0.3) * 0.55, now)
	_piece("shockwave")
	if not killed:
		_fx.bursts.spawn(BurstSystem.Kind.GROUND_GLOW, ground, size * 2.5, 0.45, Color(0.5, 0.2, 0.06), now)
	for i in _count(3, 2):
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, position + Vector3(_rng.randf_range(-0.6, 0.6), 1.0, _rng.randf_range(-0.6, 0.6)),
				_rng.randf_range(2.4, 3.4), _rng.randf_range(2.0, 2.8), Color(0.2, 0.2, 0.2, 0.75), now + 0.15 + i * 0.2,
				Vector3.ZERO, 0.0, 0.0, 1.6)
	_piece("smoke")
	if not killed:
		_fx.lights.flash(position + Vector3.UP * 1.5, Color(1.0, 0.6, 0.25), 6.0, 14.0, 0.35, LightPool.PRIORITY_EXPLOSION, now)
		_fx.shake.add(float(family["hit_shake"]), position, float(family["shake_radius"]))
		_sound(String(family["hit_sound"]), position)
		_fx.spectacle.emit(position, 0.3)


func _kill(model: String, family: Dictionary, position: Vector3, direction: Vector3, unit_name := "") -> void:
	var now := _fx.now
	if _killed_recently(position, now, unit_name):
		return
	_recent_kills.append({"position": position, "time": now, "unit": unit_name})
	# The round-2 kill explosion (fireballs, glow, a burning site, the crowd, the big boom), then more on top: whatever
	# killed it, the vehicle itself blows up. A tank shell or a mortar makes it bigger.
	var heavy := model == "shell" or model == "arc"
	_fx.explosion(position, true, 0.35)
	_piece("kill_explosion")
	_fx.shake.add(maxf(float(family["kill_shake"]) - 0.55, 0.0), position, float(family["shake_radius"]) * 1.25)
	# It cooks off: a second blast a beat later, a huge shockwave, debris thrown high, a column of black smoke.
	var offset := Vector3(_rng.randf_range(-1.0, 1.0), 2.2, _rng.randf_range(-1.0, 1.0))
	_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position + offset, 6.5 if heavy else 5.0, 1.0, FIRE_COLOR, now + 0.28, Vector3.ZERO, 0.0, 0.0, 1.5)
	_fx.bursts.spawn(BurstSystem.Kind.STAR, position + offset, 7.0, 0.14, Color(1.0, 0.85, 0.6), now + 0.28)
	_fx.bursts.spawn(BurstSystem.Kind.SPARKS, position + Vector3.UP * 2.0, 11.0, 1.1, SPARK_COLOR, now + 0.28)
	_fx.lights.flash(position + Vector3.UP * 2.0, Color(1.0, 0.5, 0.2), 7.0, 18.0, 0.6, LightPool.PRIORITY_EXPLOSION, now + 0.28)
	_piece("secondary_blast")
	var ground := Vector3(position.x, 0.0, position.z)
	_fx.bursts.spawn(BurstSystem.Kind.SHOCKWAVE, ground, 34.0 if heavy else 24.0, 0.8, Color(1.0, 0.55, 0.25) * 0.5, now + 0.05)
	_fx.bursts.spawn(BurstSystem.Kind.DEBRIS, position + Vector3.UP * 1.5, 12.0, 1.6, Color(METAL_COLOR.r, METAL_COLOR.g, METAL_COLOR.b, 1.0), now + 0.02)
	_fx.bursts.spawn(BurstSystem.Kind.DEBRIS, position + Vector3.UP * 1.0, 8.0, 1.3, Color(0.2, 0.18, 0.16, 1.0), now + 0.3)
	for i in _count(5, 3):
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, position + Vector3(_rng.randf_range(-1.2, 1.2), 1.5, _rng.randf_range(-1.2, 1.2)),
				_rng.randf_range(4.5, 6.5), _rng.randf_range(3.5, 4.5), Color(0.14, 0.13, 0.13, 0.9), now + 0.4 + i * 0.35,
				Vector3(direction.x, 0.0, direction.z) * 0.6, 0.3, 0.0, 2.4)
	_fx.decals.spawn(BurstSystem.Kind.SCORCH, ground, 9.0, 28.0, Color(0, 0, 0, 1), now)
	_piece("scorch")


## A vehicle died (its `died` signal): blow it up unless the hit that killed it already did (hazards, beams, and round-2
## hitscan kills have no killing impact).
func unit_destroyed(unit: Node3D) -> void:
	if unit == null or not unit.is_inside_tree():
		return
	var position := unit.global_position + Vector3.UP * 0.8
	if _killed_recently(position, _fx.now, String(unit.name)):
		return
	_begin("destroyed")
	_kill("burst", FAMILIES["burst"], position, -unit.global_basis.z, String(unit.name))


## The same death reported twice: the same unit (when both reports name it), or the same spot when one doesn't.
func _killed_recently(position: Vector3, now: float, unit_name: String) -> bool:
	for i in range(_recent_kills.size() - 1, -1, -1):
		var kill: Dictionary = _recent_kills[i]
		if now - float(kill["time"]) > KILL_DEDUPE_SECONDS:
			_recent_kills.remove_at(i)
		elif unit_name != "" and String(kill["unit"]) != "":
			if String(kill["unit"]) == unit_name:
				return true
		elif (kill["position"] as Vector3).distance_to(position) <= KILL_DEDUPE_METERS:
			return true
	return false


## A weak-spot hit (K2 `weak_spot`): a gold four-point flare and ring, a gush of gold sparks, a sting you learn to want.
## A tank shell in the engine deck also blows a jet of fire out of the hull.
func _weak_spot(model: String, position: Vector3, direction: Vector3, target: String) -> void:
	var now := _fx.now
	var key := "%s/%s" % [target if target != "" else str(position.snapped(Vector3.ONE * 2.0)), model]
	if now - float(_last_crit.get(key, -1.0)) < CRIT_EVERY:
		return
	_last_crit[key] = now
	if _last_crit.size() > 64:
		_last_crit.clear()
	var size := float(CRIT_SIZE.get(model, 5.0))
	_fx.bursts.spawn(BurstSystem.Kind.FLARE, position - direction * 0.4 + Vector3.UP * 0.3, size, 0.45, CRIT_COLOR, now)
	_fx.bursts.spawn(BurstSystem.Kind.SPARKS, position + Vector3.UP * 0.5, size * 0.9, 0.7, CRIT_COLOR, now)
	_fx.lights.flash(position + Vector3.UP, CRIT_COLOR, 3.5 if model == "shell" else 2.5, 9.0, 0.25, LightPool.PRIORITY_EXPLOSION, now)
	if model == "shell" or model == "arc":
		_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position + Vector3.UP * 1.0, 3.5, 0.7, FIRE_COLOR, now + 0.05, Vector3.UP * 7.0, 2.5)
		_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position + Vector3.UP * 0.6, 2.8, 0.6, FIRE_COLOR, now + 0.12, Vector3.UP * 5.0 - direction * 2.0, 2.5)
	_piece("weak_spot_flare")
	_sound("weak_spot_hit", position)
	_fx.spectacle.emit(position, 0.5)


## The vehicle's shield took the round: an energy splash in its team's glow and a ripple across the shell from the struck
## point, instead of steel sparks. Heavy rounds still thump.
func _shield_splash(model: String, family: Dictionary, position: Vector3, direction: Vector3, target: Node) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	var glow := _team_glow(target).lerp(Color.WHITE, 0.3)
	_fx.bursts.spawn(BurstSystem.Kind.STAR, position - direction * 0.3, size * 1.6, 0.12, glow, now)
	_fx.bursts.spawn(BurstSystem.Kind.SPARKS, position, size * 2.2, 0.35, glow, now)
	if model == "shell" or model == "arc":
		_fx.bursts.spawn(BurstSystem.Kind.SHOCKWAVE, Vector3(position.x, 0.0, position.z), size * 3.0, 0.4, glow * 0.5, now)
		_fx.lights.flash(position, glow, 5.0, 12.0, 0.25, LightPool.PRIORITY_EXPLOSION, now)
		_fx.shake.add(float(family["hit_shake"]) * 0.6, position, float(family["shake_radius"]))
	var shield := _shield_effect(target)
	if shield != null:
		shield.hit_at(position)
	_piece("shield_splash")


func _shielded(unit: Node) -> bool:
	if unit == null:
		return false
	var value: Variant = unit.get("sync_shield")
	return value != null and float(value) > 0.0


func _shield_effect(unit: Node) -> ShieldEffect:
	if unit == null:
		return null
	if _shield_cache.has(unit) and is_instance_valid(_shield_cache[unit]):
		return _shield_cache[unit]
	var hull := unit.get_node_or_null("HullVisual")
	var found: ShieldEffect = null
	if hull != null:
		for node in hull.find_children("*", "MeshInstance3D", true, false):
			if node is ShieldEffect:
				found = node
				break
	if found != null:
		if _shield_cache.size() > 64:
			_shield_cache.clear()
		_shield_cache[unit] = found
	return found


func _shell_miss(family: Dictionary, position: Vector3, direction: Vector3) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	var ground := Vector3(position.x, 0.0, position.z)
	var low := position.y < 2.5
	# A geyser of dirt: clods thrown high, a column of dust punching up and rolling out, a dull flash where it dug in.
	_fx.bursts.spawn(BurstSystem.Kind.STAR, position, size * 0.9, 0.09, Color(1.0, 0.8, 0.55), now)
	_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position + Vector3.UP * 0.6, size * 0.6, 0.35, FIRE_COLOR, now)
	_fx.bursts.spawn(BurstSystem.Kind.DEBRIS, position + Vector3.UP * 1.5, size * 3.2, 1.4, Color(DIRT_COLOR.r, DIRT_COLOR.g, DIRT_COLOR.b, 0.0), now)
	_fx.bursts.spawn(BurstSystem.Kind.DEBRIS, position + Vector3.UP * 1.0, size * 2.0, 1.1, Color(DIRT_COLOR.r, DIRT_COLOR.g, DIRT_COLOR.b, 0.0), now + 0.06)
	_piece("dirt_spray")
	for i in _count(4, 2):
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, position + Vector3.UP * (1.0 + i * 1.2), size * (1.1 + i * 0.2), 2.0 + i * 0.3,
				Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.0), now + i * 0.05, Vector3.UP * (11.0 - i * 2.0), 2.4, 0.0, 0.5)
	for i in _count(5, 3):
		var roll := Vector3(direction.x, 0.0, direction.z).rotated(Vector3.UP, TAU * float(i) / _count(5, 3) + _rng.randf_range(-0.3, 0.3)).normalized()
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, position + Vector3.UP * 0.9, _rng.randf_range(3.8, 5.2), _rng.randf_range(2.4, 3.2),
				Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.0), now + 0.08, roll * _rng.randf_range(6.0, 9.0), 2.0, 0.0, 0.5)
	_piece("dust_cloud")
	if low:
		_fx.bursts.spawn(BurstSystem.Kind.SHOCKWAVE, ground, size * 2.6, 0.4, DUST_COLOR * 0.6, now)
		_fx.decals.spawn(BurstSystem.Kind.SCORCH, ground, size * 0.9, 14.0, Color(0, 0, 0, 1), now)
		_piece("scorch")
	_fx.lights.flash(position + Vector3.UP, Color(1.0, 0.65, 0.3), 4.0, 9.0, 0.2, LightPool.PRIORITY_MUZZLE, now)
	_fx.shake.add(float(family["miss_shake"]), position, float(family["shake_radius"]) * 0.7)
	_sound(String(family["miss_sound"]), position)


## A round that flew out of range without hitting anything (round-2 shells expire in mid-air): it drops into the dirt
## just beyond where it gave out.
func fizzle(position: Vector3, direction: Vector3, model: String, from: Variant = null, shooter := "") -> void:
	if not FAMILIES.has(model):
		model = "shell"
	_begin(model)
	var flat := Vector3(direction.x, 0.0, direction.z).normalized() if Vector2(direction.x, direction.z).length() > 0.01 else Vector3.ZERO
	var landing := Vector3(position.x, 0.2, position.z) + flat * 3.0
	match model:
		"shell", "arc":
			_shell_miss(FAMILIES[model], landing, direction)
			if model == "shell" and from is Vector3:
				_near_miss(from, position, shooter)
		_:
			_small_miss(model, FAMILIES[model], landing)


## The missed shell passed a vehicle closely on its way: play the whine at the closest point.
func _near_miss(from: Vector3, to: Vector3, shooter: String) -> void:
	if not units.is_valid():
		return
	var a := Vector2(from.x, from.z)
	var b := Vector2(to.x, to.z)
	var best := WHINE_MAX
	var best_point := Vector3.ZERO
	for node in units.call():
		var unit := node as Node3D
		if unit == null or String(unit.name) == shooter:
			continue
		var p := Vector2(unit.global_position.x, unit.global_position.z)
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		var closest := a + ab * t
		var distance := p.distance_to(closest)
		if distance >= WHINE_MIN and distance < best and t > 0.05 and t < 0.97:
			best = distance
			best_point = from.lerp(to, t)
	if best < WHINE_MAX:
		_sound("shell_whine", best_point)


# ---- Light rounds (X3): the 25 mm burst and the machine-gun stream -------------------------------------------------

func _muzzle_flash(family: Dictionary, muzzle: Vector3, direction: Vector3, color: Color) -> void:
	var now := _fx.now
	# Every round flashes a little differently, so a stream flickers instead of glowing steadily.
	var flicker := _rng.randf_range(0.7, 1.25)
	var hot := color.lerp(Color(1.0, 0.9, 0.7), 0.5)
	_fx.bursts.spawn(BurstSystem.Kind.STAR, muzzle + direction * 0.4, float(family["flash_size"]) * flicker, 0.05, hot, now)
	_fx.lights.flash(muzzle + direction * 0.5, hot, float(family["light_energy"]) * flicker, float(family["light_range"]), 0.05,
			LightPool.PRIORITY_MUZZLE - 0.5, now)
	if family == FAMILIES["burst"]:
		# The 25 mm's gas: a small puff that drifts off the barrel, one per round, so a burst leaves a little haze.
		_fx.bursts.spawn(BurstSystem.Kind.SMOKE, muzzle + direction * 0.9, 1.1, 0.8, Color(SMOKE_COLOR.r, SMOKE_COLOR.g, SMOKE_COLOR.b, 0.2),
				now, direction * 3.0, 3.0, 0.0, 0.4)
	_piece("muzzle_flash")


func _small_hit(model: String, family: Dictionary, position: Vector3, direction: Vector3, weak_spot: bool, target: String) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	var key := target if target != "" else str(position.snapped(Vector3.ONE * 2.0))
	if now - float(_last_spark.get(key, -1.0)) >= SPARK_EVERY or weak_spot:
		_last_spark[key] = now
		_fx.bursts.spawn(BurstSystem.Kind.STAR, position - direction * 0.2, size * (1.6 if weak_spot else 1.0), 0.1, Color(1.0, 0.8, 0.5), now)
		_fx.bursts.spawn(BurstSystem.Kind.SPARKS, position, size * 3.0, 0.3 if model == "stream" else 0.4, SPARK_COLOR, now)
		if model == "burst":
			# High-explosive 25 mm rounds pop on contact.
			_fx.bursts.spawn(BurstSystem.Kind.FIREBALL, position, 1.4, 0.3, FIRE_COLOR, now)
		_piece("weak_spot_hit" if weak_spot else "armor_sparks")
	if _rng.randf() < float(family.get("ricochet_chance", 0.0)):
		# Glancing off: a hot streak skipping away off the armor, and now and then its zing.
		var away := direction.bounce(Vector3.UP).rotated(Vector3.UP, _rng.randf_range(-1.2, 1.2)) \
				+ Vector3.UP * _rng.randf_range(0.1, 0.6)
		_fx.tracers.shoot(position, position + away.normalized() * _rng.randf_range(6.0, 11.0), SPARK_COLOR, "ricochet", now,
				_rng.randf_range(45.0, 70.0))
		_piece("ricochet")
		if now - _last_ricochet_sound >= RICOCHET_SOUND_EVERY:
			_last_ricochet_sound = now
			_sound("ricochet", position)
	if String(family["hit_sound"]) != "" and now - float(_last_clank.get(key, -1.0)) >= CLANK_EVERY:
		_last_clank[key] = now
		_sound(String(family["hit_sound"]), position)
	if _last_spark.size() > 64:
		_last_spark.clear()
		_last_clank.clear()


func _small_miss(model: String, family: Dictionary, position: Vector3) -> void:
	var now := _fx.now
	var size := float(family["hit_size"])
	_fx.bursts.spawn(BurstSystem.Kind.SMOKE, Vector3(position.x, maxf(position.y, 0.4), position.z), size * 2.2, 0.7,
			Color(DUST_COLOR.r, DUST_COLOR.g, DUST_COLOR.b, 0.0), now, Vector3.ZERO, 0.0, 0.0, 1.0)
	if model == "burst":
		_fx.bursts.spawn(BurstSystem.Kind.STAR, position, 1.0, 0.05, Color(1.0, 0.8, 0.5), now)
		_fx.bursts.spawn(BurstSystem.Kind.DEBRIS, position + Vector3.UP * 0.3, 2.2, 0.6, Color(DIRT_COLOR.r, DIRT_COLOR.g, DIRT_COLOR.b, 0.0), now)
	_piece("dirt_puff")


# ---- Bookkeeping ---------------------------------------------------------------------------------------------------

func _begin(model: String) -> void:
	events += 1
	last_pieces = PackedStringArray()
	last_family = model


func _piece(piece: String) -> void:
	last_pieces.append(piece)


func _sound(sound: String, position: Vector3) -> void:
	if sound == "":
		return
	_fx.sfx.play_at(sound, position)
	_piece("sound:" + sound)


## Pieces per effect by tier: `high` on desktops, `low` on phones.
func _count(high: int, low: int) -> int:
	return low if FxQuality.tier() == FxQuality.Tier.LOW else high


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
	if unit != null and unit.has_meta("team"):
		return GameTheme.team_glow(int(unit.get_meta("team")))  # the FX lab's stand-in vehicles
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
