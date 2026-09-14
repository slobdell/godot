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
@export var hull_turn_rate := deg_to_rad(80.0)
@export var turret_turn_rate := deg_to_rad(110.0)
## Tuned 2026-09-13 after the lead's first skirmish ("tanks die too quickly"): 100 → 200.
@export var max_health := 400
@export var reload_seconds := 2.0
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
## Fractional cone damage not yet applied as whole hit points.
var damage_accumulator := 0.0
## What the tank's brain is doing ("ENGAGE Rust_2"); set by the simulating peer, shown on nameplates.
var intent := ""

var health := 200
var alive := true
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

var _speed := 0.0
var _reload_left := 0.0
var _previous_sync_position := Vector3.ZERO
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var turret: Node3D = $Turret
@onready var nameplate: Label3D = $Nameplate
@onready var _collision: CollisionShape3D = $Collision
@onready var _hull_visual: VisualSlot = $HullVisual
@onready var _turret_visual: VisualSlot = $Turret/TurretVisual
@onready var _weapon_visual: VisualSlot = $Turret/WeaponVisual


func _ready() -> void:
	health = max_health
	set_weapon(weapon_id)
	_publish_state()
	_previous_sync_position = sync_position


func set_weapon(id: String) -> void:
	weapon_id = id
	weapon = Weapons.profile(id)
	reload_seconds = weapon["reload"]
	if _weapon_visual != null:
		_weapon_visual.fill("weapon." + id)
		_weapon_visual.invoke("setup", [weapon])


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

	# Tank steering: turn in place or while moving; reversing does not invert.
	rotate_y(-cmd.turn * hull_turn_rate * delta)
	_speed = TankMotion.next_speed(_speed, cmd.throttle, max_forward_speed, max_reverse_speed,
			acceleration, delta)

	var forward := -global_basis.z
	velocity.x = forward.x * _speed
	velocity.z = forward.z * _speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()
	estimated_velocity = Vector3(velocity.x, 0.0, velocity.z)

	var local_aim := to_local(cmd.aim_point)
	turret.rotation.y = TankMotion.step_yaw(turret.rotation.y, TankMotion.yaw_toward(local_aim),
			turret_turn_rate, delta)

	sync_firing = false
	if weapon["kind"] == Weapons.Kind.CONE:
		if cmd.fire:
			sync_firing = true
			sprayed.emit(muzzle_position(), turret_forward(), delta)
	else:
		_reload_left = maxf(0.0, _reload_left - delta)
		if cmd.fire and _reload_left <= 0.0:
			_reload_left = reload_seconds
			fired.emit(muzzle_position(), turret_forward())
	_publish_state()


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
	if sync_intent != "":
		nameplate.text += "\n" + sync_intent
	_weapon_visual.invoke("set_firing", [sync_firing and alive])


# ---- Rules hooks (called by Match on the simulating peer) --------------------------

## Returns true if this hit destroyed the tank.
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
	_reload_left = 0.0
	health = max_health
	_set_alive(true)
	_publish_state()


# ---- Queries (valid on every peer) -------------------------------------------------

func is_alive() -> bool:
	return alive


## 0 = just fired, 1 = ready to fire.
func reload_fraction() -> float:
	return sync_reload


func muzzle_position() -> Vector3:
	return turret.global_transform * Vector3(0.0, 0.05, -3.2)


func turret_forward() -> Vector3:
	var forward := -turret.global_basis.z
	return Vector3(forward.x, 0.0, forward.z).normalized()


## Current hull speed in m/s (negative when reversing). Simulating peer only.
func speed() -> float:
	return _speed


## Paint this tank in a team color. What that looks like is up to the theme's visuals.
func set_paint(color: Color) -> void:
	for slot in [_hull_visual, _turret_visual, _weapon_visual]:
		(slot as VisualSlot).invoke("set_team_color", [color])


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
	sync_reload = 1.0 - (_reload_left / reload_seconds) if reload_seconds > 0.0 else 1.0
	sync_intent = intent
