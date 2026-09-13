class_name Tank
extends CharacterBody3D
## A single tank: hull that drives and turns, turret that tracks an aim point.
##
## The tank only ever acts on `command`. It has no idea whether a human, a
## script, the network, or an AI skill produced it.

@export var max_forward_speed := 9.0
@export var max_reverse_speed := 4.0
@export var acceleration := 14.0
@export var hull_turn_rate := deg_to_rad(80.0)
@export var turret_turn_rate := deg_to_rad(110.0)

## Set by a controller before this tank's physics tick (controllers run first —
## see `process_physics_priority` in the controller scripts).
var command := TankCommand.new()

var _speed := 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var turret: Node3D = $Turret


func _physics_process(delta: float) -> void:
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


## Current hull speed in m/s (negative when reversing).
func speed() -> float:
	return _speed
