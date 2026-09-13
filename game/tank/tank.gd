class_name Tank
extends CharacterBody3D
## A single tank: hull that drives and turns, turret that tracks an aim point.
##
## The tank only ever acts on `command`. It has no idea whether a human, a
## script, the network, or an AI skill produced it.
##
## Networking (see _agents/architecture.md "Networking"):
##   simulate = true   offline / server: run physics, then publish sync_* state
##   simulate = false  networked client: never simulate; smoothly display sync_*
##                     values replicated by the StateSync MultiplayerSynchronizer

@export var max_forward_speed := 9.0
@export var max_reverse_speed := 4.0
@export var acceleration := 14.0
@export var hull_turn_rate := deg_to_rad(80.0)
@export var turret_turn_rate := deg_to_rad(110.0)
## Client-side display smoothing toward replicated state. Higher = snappier.
@export var remote_smoothing := 18.0

## Set by a controller before this tank's physics tick (controllers run first —
## see `process_physics_priority` in the controller scripts).
var command := TankCommand.new()
var simulate := true

## Replicated state. Written by the simulating peer, read by clients.
var sync_position := Vector3.ZERO
var sync_yaw := 0.0
var sync_turret_yaw := 0.0

var _speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var turret: Node3D = $Turret


func _ready() -> void:
	_publish_state()


func _physics_process(delta: float) -> void:
	if not simulate:
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

	var local_aim := to_local(cmd.aim_point)
	turret.rotation.y = TankMotion.step_yaw(turret.rotation.y, TankMotion.yaw_toward(local_aim),
			turret_turn_rate, delta)
	_publish_state()


func _process(delta: float) -> void:
	if simulate:
		return
	var weight := 1.0 - exp(-remote_smoothing * delta)
	global_position = global_position.lerp(sync_position, weight)
	rotation.y = lerp_angle(rotation.y, sync_yaw, weight)
	turret.rotation.y = lerp_angle(turret.rotation.y, sync_turret_yaw, weight)


## Repaint hull and turret. The scene's materials are shared by every tank
## instance, so each repainted tank gets its own copies.
func set_paint(hull_color: Color) -> void:
	var parts := {$Hull: hull_color, $Turret/TurretBody: hull_color.lightened(0.15),
			$Turret/Barrel: hull_color.lightened(0.15)}
	for mesh_instance: MeshInstance3D in parts:
		var material := mesh_instance.mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = parts[mesh_instance]
		mesh_instance.material_override = material


## Current hull speed in m/s (negative when reversing). Server/offline only.
func speed() -> float:
	return _speed


func _publish_state() -> void:
	sync_position = global_position
	sync_yaw = rotation.y
	sync_turret_yaw = turret.rotation.y
