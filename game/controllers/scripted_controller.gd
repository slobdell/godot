class_name ScriptedController
extends Node
## Drives a tank in a repeatable circle while sweeping the turret.
##
## Used by `make demo`, `make screenshot`, and tests. It is also the first proof
## of the architecture: a non-human source drives the exact same Tank. Squad AI
## skills will be controllers too.

@export var tank: Tank
@export var throttle := 1.0
@export var turn := 0.35
@export var aim_radius := 25.0
@export var aim_sweep_rate := 0.8

var _elapsed := 0.0


func _ready() -> void:
	process_physics_priority = -10


func _physics_process(delta: float) -> void:
	if tank == null:
		return
	_elapsed += delta
	var angle := _elapsed * aim_sweep_rate
	tank.command = TankCommand.new(throttle, turn, Vector3(cos(angle), 0.0, sin(angle)) * aim_radius)
