class_name Tank
extends CharacterBody3D
## A single tank: hull that drives and turns, turret that tracks an aim point,
## a gun with a reload, and health.
##
## The tank only ever acts on `command`. It has no idea whether a human, a
## script, the network, or an AI produced it. It also doesn't decide what a hit
## means or when to respawn: it emits `fired` / `died` and the Match (the rules)
## decides.
##
## Networking (see _agents/architecture.md "Networking"):
##   simulate = true   offline / server: run physics and the gun, publish sync_*
##   simulate = false  networked client: never simulate; display replicated sync_*

signal fired(muzzle: Vector3, direction: Vector3)
## Cone weapons (flamethrower) emit this every physics tick the trigger is held.
signal sprayed(origin: Vector3, direction: Vector3, delta: float)
signal died

@export var max_forward_speed := 9.0
@export var max_reverse_speed := 4.0
@export var acceleration := 14.0
## K3 locomotion (Units.PROFILES): speed shed per second when slowing, "tracks" or "wheels", the tightest turning circle
## (wheels), and how much sideways slide the tires kill (1 = none, lower drifts).
@export var braking := 14.0
var locomotion := "tracks"
## X5 (round 3): units with deploy_seconds > 0 (artillery) must stand still and lower their outriggers before firing,
## and pack up before driving. 0 = packed (can drive), 1 = deployed (can fire). Simulating peer; visuals get
## set_deployed(ratio) every frame.
var deploy_ratio := 0.0
var deploy_seconds := 0.0
var pack_seconds := 0.0
## A stop order must hold this many ticks before the legs start down (stop-and-go driving never deploys).
const DEPLOY_SETTLE_TICKS := 15
## Below this speed (m/s) a hull counts as stopped for deploying.
const DEPLOY_MAX_SPEED := 0.3
var _still_ticks := 0
var min_turn_radius := 0.0
var lateral_grip := 1.0
@export var hull_turn_rate := deg_to_rad(80.0)
@export var turret_turn_rate := deg_to_rad(110.0)
## Hull. Tuned 2026-09-13 after the lead's first skirmish ("tanks die too quickly"): 100 → 400;
## 2026-09-14 (G6): 300 plus a recharging shield (see Units.PROFILES).
@export var max_health: int = Units.stat("tank", "max_health")
## G6 shield: absorbs damage before the hull and recharges after a quiet spell.
@export var max_shield: float = Units.stat("tank", "max_shield")
@export var shield_recharge_delay: float = Units.stat("tank", "shield_recharge_delay")
@export var shield_recharge_rate: float = Units.stat("tank", "shield_recharge_rate")
@export var reload_seconds := 2.0
## G1: how far this tank sees (inside the radius AND an unobstructed line of sight). Team vision is
## the union of its tanks' views (Match.intel).
@export var sight_radius: float = Units.stat("tank", "sight_radius")
## G7 heat (see Units.PROFILES "heat_capacity"/"heat_dissipation").
@export var heat_capacity: float = 0.0
@export var heat_dissipation: float = 0.0
## Client-side display smoothing toward replicated state. Higher = snappier.
@export var remote_smoothing := 18.0

## Set by a controller before this tank's physics tick (controllers run first —
## see `process_physics_priority` in the controller scripts).
var command := TankCommand.new()
var simulate := true
## Identity, fixed at spawn (see Match._build_tank).
var team := 0
var slot := 0
var owner_peer_id := 0
var display_name := ""
var weapon_id := Weapons.DEFAULT
var weapon: Dictionary = Weapons.profile(Weapons.DEFAULT)
## The unit type (Units.PROFILES id), fixed at spawn. Everything below comes from it (catalog v2).
var unit_id := Units.DEFAULT
## "turret" or "fixed" (C4). A fixed mount's gun swings only inside fire_arc_deg of the hull heading.
var mount := "turret"
var fire_arc_deg := 360.0
## Where rounds leave the gun, meters above the ground (C4).
var muzzle_height := 1.27
## This tick's commanded aim point (world). Indirect weapons (ARC) fire at it, not along the barrel.
var aim_point := Vector3.ZERO
## Shells a full load holds, or -1 for unlimited.
var max_ammo := -1
## Fractional cone damage not yet applied as whole hit points.
var damage_accumulator := 0.0
## What the tank's brain is doing ("ENGAGE Rust_2"); set by the simulating peer, shown on nameplates.
var intent := ""
## Whether the nameplate shows `intent` (skirmish hides it: enemy intents would leak through the fog).
var show_intent := true

var health := 200
var alive := true
## Shield points (0..max_shield). Simulating peer.
var shield := 0.0
## Physics ticks since the last damage landed (shield recharge and base repair wait on it).
var ticks_since_hit := 1_000_000
## Shells left, or -1 for a weapon that never runs out (G7). Simulating peer.
var ammo := -1
## Current heat (0..heat_capacity). Simulating peer.
var heat := 0.0
## World-space velocity: exact on the simulating peer, estimated from snapshots on clients.
var estimated_velocity := Vector3.ZERO

## Replicated state. Written by the simulating peer, read by clients.
var sync_position := Vector3.ZERO
var sync_yaw := 0.0
var sync_turret_yaw := 0.0
var sync_health := 200
var sync_alive := true
## 0 = just fired, 1 = ready.
var sync_reload := 1.0
var sync_firing := false
var sync_intent := ""
var sync_ammo := -1
var sync_shield := 0
## Match base-service bookkeeping: ticks in the base zone toward the next shell / hull point.
var resupply_ticks := 0
var repair_ticks := 0
## Heat as a fraction of capacity, 0..1.
var sync_heat := 0.0

var _speed := 0.0
## X2 (round 3): weapon timing in whole physics ticks (deterministic). Ticks until the next trigger pull may fire,
## rounds of the current burst still to come, and ticks until the next of them.
var _reload_ticks := 0
var _burst_rounds_left := 0
var _burst_ticks := 0
var _previous_sync_position := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var turret: Node3D = $Turret
@onready var nameplate: Label3D = $Nameplate
@onready var _collision: CollisionShape3D = $Collision
@onready var _hull_visual: VisualSlot = $HullVisual
@onready var _turret_visual: VisualSlot = $Turret/TurretVisual
@onready var _weapon_visual: VisualSlot = $Turret/WeaponVisual


func _ready() -> void:
	apply_unit()
	_publish_state()
	_previous_sync_position = sync_position


## Catalog v2: every stat and the one weapon come from Units.PROFILES[unit_id]. Called once in _ready,
## from data set at spawn (identical on every peer).
func apply_unit() -> void:
	if not Units.exists(unit_id):
		push_error("unknown unit '%s'; spawning a %s" % [unit_id, Units.DEFAULT])
		unit_id = Units.DEFAULT
	var stat := func(key: String, fallback: float = 0.0) -> float: return float(Units.stat(unit_id, key, fallback))
	max_health = roundi(stat.call("max_health"))
	max_shield = stat.call("max_shield")
	shield_recharge_delay = stat.call("shield_recharge_delay")
	shield_recharge_rate = stat.call("shield_recharge_rate")
	max_forward_speed = stat.call("max_forward_speed")
	max_reverse_speed = stat.call("max_reverse_speed")
	hull_turn_rate = deg_to_rad(stat.call("hull_turn_rate_deg"))
	acceleration = stat.call("acceleration_mps2", 14.0)
	braking = stat.call("braking_mps2", acceleration)
	locomotion = String(Units.stat(unit_id, "locomotion", "tracks"))
	min_turn_radius = stat.call("min_turn_radius_m", 0.0)
	lateral_grip = stat.call("lateral_grip", 1.0)
	deploy_seconds = stat.call("deploy_seconds", 0.0)
	pack_seconds = stat.call("pack_seconds", 0.0)
	deploy_ratio = 0.0
	turret_turn_rate = deg_to_rad(stat.call("turret_turn_rate_deg"))
	sight_radius = stat.call("sight_radius")
	heat_capacity = stat.call("heat_capacity")
	heat_dissipation = stat.call("heat_dissipation")
	mount = String(Units.stat(unit_id, "mount"))
	fire_arc_deg = stat.call("fire_arc_deg", 360.0) if mount == "fixed" else 360.0
	muzzle_height = stat.call("muzzle_height", 1.27)
	# C6: per-unit art when the theme has it, else the shared tank scenes (scaled to this hull).
	var own_hull := GameTheme.slots.has("unit.%s.hull" % unit_id)
	if own_hull:
		_hull_visual.fill("unit.%s.hull" % unit_id)
	if GameTheme.slots.has("unit.%s.turret" % unit_id):
		_turret_visual.fill("unit.%s.turret" % unit_id)
	_apply_hull_size(Units.stat(unit_id, "hull_size"), own_hull)
	health = max_health
	shield = max_shield
	set_weapon(String(Units.stat(unit_id, "weapon")))


## The turret pivot sits MUZZLE_ABOVE_PIVOT below the muzzle (see muzzle_position).
const MUZZLE_ABOVE_PIVOT := 0.05


func _apply_hull_size(size_list: Variant, own_hull_art := false) -> void:
	var size := Vector3(size_list[0], size_list[1], size_list[2])
	turret.position.y = muzzle_height - MUZZLE_ABOVE_PIVOT
	var standard: Array = Units.PROFILES[Units.DEFAULT]["hull_size"]
	if size.is_equal_approx(Vector3(standard[0], standard[1], standard[2])):
		return
	# Scene sub-resources are shared by every instance (trip-up 13): resize a copy.
	var box := BoxShape3D.new()
	box.size = size
	_collision.shape = box
	_collision.position.y = size.y / 2.0
	var ratio := Vector3(size.x / float(standard[0]), size.y / float(standard[1]), size.z / float(standard[2]))
	if not own_hull_art:
		_hull_visual.scale = ratio
	turret.scale = Vector3.ONE * minf(ratio.x, ratio.z)


## Swap the weapon (the unit's own at spawn; tests use it to try a weapon on a standard hull).
func set_weapon(id: String) -> void:
	weapon_id = id
	weapon = Weapons.profile(id)
	reload_seconds = float(weapon.get("reload_s", weapon["reload"]))
	max_ammo = Weapons.max_ammo(weapon)
	ammo = max_ammo
	if _weapon_visual != null:
		_weapon_visual.fill(first_drawable_slot(["unit.%s.weapon" % unit_id, "weapon." + id, "weapon." + Weapons.DEFAULT]))
		_weapon_visual.invoke("setup", [weapon])


## The first slot id the active theme can draw (C6 fallbacks: per-unit art, then shared art).
static func first_drawable_slot(candidates: Array) -> String:
	for candidate: String in candidates:
		if GameTheme.slots.has(candidate):
			return candidate
	return candidates[-1]


func _physics_process(delta: float) -> void:
	if not simulate:
		# Snapshots arrive every other tick or so; average the jumps into a velocity estimate.
		var snapshot_velocity := (sync_position - _previous_sync_position) / delta
		_previous_sync_position = sync_position
		estimated_velocity = estimated_velocity.lerp(snapshot_velocity, 0.2)
		return
	if not alive:
		velocity = Vector3.ZERO
		estimated_velocity = Vector3.ZERO
		_publish_state()
		return
	var cmd := command.sanitized()
	aim_point = cmd.aim_point

	# X4 (K3): drive through the same pure model ai plans with (TankMotion.step_in_place): tracks pivot, wheels need
	# speed to turn and slide on low grip. Collisions stay with the physics body: the velocity after the slide feeds the
	# next tick, so a wall eats a wheeled unit's momentum.
	var drive_cmd := _deploy_step(cmd)
	_drive(drive_cmd, delta)

	var local_aim := to_local(cmd.aim_point)
	turret.rotation.y = TankMotion.step_yaw(turret.rotation.y, gun_yaw_toward(local_aim), turret_turn_rate, delta)

	sync_firing = false
	heat = maxf(0.0, heat - heat_dissipation * delta)
	ticks_since_hit += 1
	if shield < max_shield and ticks_since_hit >= roundi(shield_recharge_delay * 60.0):
		shield = minf(max_shield, shield + shield_recharge_rate * delta)
	if weapon["kind"] == Weapons.Kind.CONE:
		if cmd.fire:
			sync_firing = true
			sprayed.emit(muzzle_position(), turret_forward(), delta)
	else:
		_reload_ticks = maxi(0, _reload_ticks - 1)
		if _burst_rounds_left > 0:
			# X2: a started burst is committed; its rounds follow burst_interval_s apart whatever the trigger does.
			_burst_ticks -= 1
			if _burst_ticks <= 0 and ammo != 0:
				_burst_rounds_left -= 1
				_burst_ticks = _ticks_of(float(weapon.get("burst_interval_s", 0.0)))
				_fire_round()
		elif cmd.fire and _reload_ticks <= 0 and ammo != 0 and _heat_allows_shot(heat) and is_deployed():
			_reload_ticks = _ticks_of(reload_seconds)
			_burst_rounds_left = maxi(1, int(weapon.get("burst_count", 1))) - 1
			_burst_ticks = _ticks_of(float(weapon.get("burst_interval_s", 0.0)))
			heat += float(weapon.get("heat_per_shot", 0.0))
			_fire_round()
	_publish_state()


## One round leaves the gun (a shell, a beam pulse, a burst round, a lobbed round).
func _fire_round() -> void:
	if ammo > 0:
		ammo -= 1
	sync_firing = weapon["kind"] == Weapons.Kind.BEAM or int(weapon.get("burst_count", 1)) > 1
	fired.emit(muzzle_position(), turret_forward())


static func _ticks_of(seconds: float) -> int:
	return maxi(1, roundi(seconds * 60.0)) if seconds > 0.0 else 0


## X5: advance deploying or packing for this tick's command; returns the command driving may use (throttle and turn
## zeroed while the legs are down or moving).
func _deploy_step(cmd: TankCommand) -> TankCommand:
	if deploy_seconds <= 0.0:
		return cmd
	var wants_to_move := absf(cmd.throttle) > 0.05 or absf(cmd.turn) > 0.05
	if wants_to_move:
		_still_ticks = 0
		if deploy_ratio > 0.0:
			deploy_ratio = maxf(0.0, deploy_ratio - 1.0 / maxf(pack_seconds * 60.0, 1.0))
	else:
		if absf(_speed) < DEPLOY_MAX_SPEED:
			_still_ticks += 1
		if _still_ticks >= DEPLOY_SETTLE_TICKS:
			deploy_ratio = minf(1.0, deploy_ratio + 1.0 / maxf(deploy_seconds * 60.0, 1.0))
	# Snap float dust so "fully deployed" and "packed" are exact.
	if deploy_ratio > 0.9999:
		deploy_ratio = 1.0
	elif deploy_ratio < 0.0001:
		deploy_ratio = 0.0
	if deploy_ratio > 0.0:
		return TankCommand.new(0.0, 0.0, cmd.aim_point, cmd.fire)
	return cmd


## Whether this unit may fire: always for units that don't deploy; fully deployed for those that do.
func is_deployed() -> bool:
	return deploy_seconds <= 0.0 or deploy_ratio >= 1.0


## The motion state this tank steps every physics tick (TankMotion's K3 dictionary), built once per unit.
var _motion := {}


func _drive(cmd: TankCommand, delta: float) -> void:
	if _motion.is_empty():
		_motion = TankMotion.state_for(unit_id, global_position, -global_basis.z, _speed)
	_motion["position"] = global_position
	var facing := -global_basis.z  # re-read: spawns, respawns, and tests place hulls by setting rotation
	_motion["forward"] = Vector3(facing.x, 0.0, facing.z).normalized()
	_motion["speed"] = _speed
	_motion["max_forward_speed"] = max_forward_speed
	_motion["max_reverse_speed"] = max_reverse_speed
	_motion["hull_turn_rate_deg"] = rad_to_deg(hull_turn_rate)
	_motion["acceleration_mps2"] = acceleration
	_motion["braking_mps2"] = braking
	_motion["locomotion"] = locomotion
	_motion["min_turn_radius_m"] = min_turn_radius
	_motion["lateral_grip"] = lateral_grip
	TankMotion.step_in_place(_motion, cmd.throttle, cmd.turn, delta)
	var forward: Vector3 = _motion["forward"]
	global_basis = Basis.looking_at(forward, Vector3.UP)
	_speed = float(_motion["speed"])
	var planar: Vector3 = _motion["velocity"]
	velocity.x = planar.x
	velocity.z = planar.z
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	estimated_velocity = Vector3(velocity.x, 0.0, velocity.z)
	_motion["velocity"] = estimated_velocity
	if locomotion == "wheels":
		_speed = estimated_velocity.dot(forward)


func _process(delta: float) -> void:
	if not simulate:
		if sync_alive != alive:
			_set_alive(sync_alive)
			if alive:  # respawned: jump, don't glide across the map
				global_position = sync_position
				rotation.y = sync_yaw
		var weight := 1.0 - exp(-remote_smoothing * delta)
		global_position = global_position.lerp(sync_position, weight)
		rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
		turret.rotation.y = lerp_angle(turret.rotation.y, sync_turret_yaw, weight)
	nameplate.text = "%s  %d" % [display_name, sync_health]
	if max_shield > 0.0:
		nameplate.text += " +%d" % sync_shield
	_hull_visual.invoke("set_shield", [float(sync_shield) / max_shield if max_shield > 0.0 else 0.0])
	if sync_intent != "" and show_intent:
		nameplate.text += "\n" + sync_intent
	_weapon_visual.invoke("set_firing", [sync_firing and alive])
	_weapon_visual.invoke("set_heat", [sync_heat])
	if deploy_seconds > 0.0:
		for visual: VisualSlot in [_hull_visual, _turret_visual, _weapon_visual]:
			visual.invoke("set_deployed", [deploy_ratio])


# ---- Rules hooks (called by Match on the simulating peer) --------------------------

## A weapon hit (G6): the shield absorbs first (see Armor.split_shield), the rest hits the hull.
## Fractions carry over between hits (flames deal a little every tick).
## Returns {"shield": float, "hull": int, "killed": bool}.
func take_hit(raw: float, shield_multiplier: float, armor_multiplier: float) -> Dictionary:
	if not alive or raw <= 0.0:
		return {"shield": 0.0, "hull": 0, "killed": false}
	ticks_since_hit = 0
	var split := Armor.split_shield(raw, shield, shield_multiplier, armor_multiplier)
	shield = shield - split.x
	if shield < 0.01:
		shield = 0.0  # no float dust: "shield down" must read as exactly 0
	damage_accumulator += split.y
	var whole := int(damage_accumulator + 0.0001)
	damage_accumulator = maxf(0.0, damage_accumulator - whole)
	var hull := mini(whole, health)
	var killed := apply_damage(whole) if whole > 0 else false
	if whole == 0:
		_publish_state()
	return {"shield": split.x, "hull": hull, "killed": killed}


## Hull points back (base repair). Simulating peer.
func repair(amount: int) -> void:
	if alive and amount > 0:
		health = mini(max_health, health + amount)
		_publish_state()


## Direct hull damage, ignoring the shield. Returns true if this destroyed the tank.
func apply_damage(amount: int) -> bool:
	if not alive:
		return false
	health = maxi(0, health - amount)
	if health == 0:
		_set_alive(false)
		_publish_state()
		died.emit()
		return true
	_publish_state()
	return false


func respawn(at_position: Vector3, yaw: float) -> void:
	global_position = at_position
	rotation.y = yaw
	turret.rotation.y = 0.0
	velocity = Vector3.ZERO
	_speed = 0.0
	_motion = {}
	deploy_ratio = 0.0
	_still_ticks = 0
	_reload_ticks = 0
	_burst_rounds_left = 0
	health = max_health
	shield = max_shield
	ticks_since_hit = 1_000_000
	damage_accumulator = 0.0
	ammo = max_ammo
	heat = 0.0
	_set_alive(true)
	_publish_state()


# ---- Queries (valid on every peer) -------------------------------------------------

func is_alive() -> bool:
	return alive


## 0 = just fired, 1 = ready to fire.
func reload_fraction() -> float:
	return sync_reload


## Loaded, not out of ammo, and cool enough for one more shot. Valid on every peer.
func ready_to_fire() -> bool:
	var current_heat := heat if simulate else sync_heat * heat_capacity
	return sync_reload >= 1.0 and shells_left() != 0 and _heat_allows_shot(current_heat) and is_deployed()


## Shells left (-1 = unlimited): exact on the simulating peer, replicated elsewhere.
func shells_left() -> int:
	return ammo if simulate else sync_ammo


## Ammo left as a fraction of a full load (1.0 for weapons that never run out).
func ammo_fraction() -> float:
	return 1.0 if max_ammo <= 0 else float(maxi(shells_left(), 0)) / max_ammo


## Add shells, up to a full load. Returns how many were added. Simulating peer (Match resupply).
func resupply(shells: int) -> int:
	if max_ammo < 0 or not alive:
		return 0
	var added := mini(shells, max_ammo - ammo)
	ammo += added
	_publish_state()
	return added


func _heat_allows_shot(current_heat: float) -> bool:
	return current_heat + float(weapon.get("heat_per_shot", 0.0)) <= heat_capacity + 0.001


## R2 fixed mounts: the hull-relative yaw the gun swings toward to aim at `local_target` (hull space). A
## turret reaches any yaw; a fixed mount stops at the edge of its fire arc, so the hull must turn to aim.
func gun_yaw_toward(local_target: Vector3) -> float:
	var yaw := TankMotion.yaw_toward(local_target)
	if mount != "fixed":
		return yaw
	var half_arc := deg_to_rad(fire_arc_deg / 2.0)
	return clampf(yaw, -half_arc, half_arc)


## Whether this unit's gun can point at `point` without turning the hull (C4: fixed mounts only inside
## fire_arc_deg of the hull heading; turrets always). Valid on every peer.
func can_bear_on(point: Vector3) -> bool:
	if mount != "fixed":
		return true
	var yaw := TankMotion.yaw_toward(to_local(point))
	return absf(yaw) <= deg_to_rad(fire_arc_deg / 2.0) + 0.0001


func muzzle_position() -> Vector3:
	return turret.global_transform * Vector3(0.0, 0.05, -3.2)


func turret_forward() -> Vector3:
	var forward := -turret.global_basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


## Current hull speed in m/s (negative when reversing). Simulating peer only.
func speed() -> float:
	return _speed


## The team's identity color as an accent (lights, trim): visuals implement set_team_accent if they can.
## The team's color: friend or foe (accent lights in the cyberpunk theme, the whole body in `default`).
## Slot contract: set_team_color(color).
func set_team_accent(color: Color) -> void:
	for slot in [_hull_visual, _turret_visual, _weapon_visual]:
		(slot as VisualSlot).invoke("set_team_color", [color])


## The garage's full-body paint. Slot contract: set_paint(color), optional; a theme without it keeps
## showing team colors (the placeholder `default` boxes).
func set_paint(color: Color) -> void:
	for slot in [_hull_visual, _turret_visual, _weapon_visual]:
		(slot as VisualSlot).invoke("set_paint", [color])


func _set_alive(value: bool) -> void:
	alive = value
	visible = value
	# Wrecks don't block movement, shells, or sight. Deferred: may run mid physics callback.
	_collision.set_deferred("disabled", not value)


func _publish_state() -> void:
	sync_position = global_position
	sync_yaw = rotation.y
	sync_turret_yaw = turret.rotation.y
	sync_health = health
	sync_alive = alive
	var reload_ticks := _ticks_of(reload_seconds)
	sync_reload = 1.0 - float(_reload_ticks) / reload_ticks if reload_ticks > 0 else 1.0
	sync_intent = intent
	sync_ammo = ammo
	sync_shield = roundi(shield)
	sync_heat = snappedf(heat / heat_capacity, 0.01) if heat_capacity > 0.0 else 0.0
