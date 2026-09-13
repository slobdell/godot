class_name FollowCamera
extends Camera3D
## Top-down-ish camera that trails a target at a fixed angle (it does not rotate
## with the tank, so mouse aiming stays intuitive).

@export var target: Node3D
@export var offset := Vector3(0.0, 16.0, 12.0)
## Higher = snappier. Frame-rate independent exponential smoothing.
@export var smoothing := 5.0


func _ready() -> void:
	if target != null:
		global_position = target.global_position + offset
	look_at(global_position - offset)


func _process(delta: float) -> void:
	if target == null:
		return
	var desired := target.global_position + offset
	global_position = global_position.lerp(desired, 1.0 - exp(-smoothing * delta))
