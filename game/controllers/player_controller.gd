class_name PlayerController
extends Node
## Keyboard + mouse -> TankCommand for one tank, every physics tick.
##
## Input actions (move_forward, turn_left, fire, ...) are defined in
## project.godot under [input], editable in Project Settings > Input Map.

@export var tank: Tank


func _ready() -> void:
	# Lower priority runs first: the command is ready before the tank consumes it.
	process_physics_priority = -10


func _physics_process(_delta: float) -> void:
	if tank == null:
		return
	var cmd := TankCommand.new()
	cmd.throttle = Input.get_axis("move_back", "move_forward")
	cmd.turn = Input.get_axis("turn_left", "turn_right")
	cmd.fire = Input.is_action_pressed("fire")
	cmd.aim_point = _mouse_ground_point()
	tank.command = cmd


## Where the mouse cursor hits the ground plane (y = 0).
func _mouse_ground_point() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return tank.command.aim_point
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
			camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	return hit if hit != null else tank.command.aim_point
