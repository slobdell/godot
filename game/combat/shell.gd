class_name Shell
extends Node3D
## A tank shell: a fast projectile that flies in a straight line.
##
## On the simulating peer it sweeps a ray along each tick's travel (so it can't
## tunnel through thin walls at speed) and reports the first thing it hits.
## Match decides what the hit means. On clients it just flies for show; the
## server despawns it when it hits, and the spawner removes it everywhere.

signal hit(shell: Shell, collider: Object, point: Vector3)
signal expired(shell: Shell)

const SPEED := 70.0
const MAX_RANGE := 110.0
## World (layer 1) + tanks (layer 2).
const HIT_MASK := 3

var direction := Vector3.FORWARD
var team := 0
var shooter_name := ""
var simulate := true
## Physics bodies the ray ignores (the shooter itself).
var exclude: Array[RID] = []
## The first sweep starts here (the turret center) instead of the muzzle, so a
## wall pressed against the barrel still stops the shell.
var ray_start := Vector3.ZERO

var _travelled := 0.0
var _first_step := true


func _ready() -> void:
	if direction.length_squared() > 0.0:
		look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	var step := direction * SPEED * delta
	var from := ray_start if _first_step else global_position
	_first_step = false
	var to := global_position + step
	if simulate:
		var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK, exclude)
		var result := get_world_3d().direct_space_state.intersect_ray(query)
		if not result.is_empty():
			global_position = result.position
			set_physics_process(false)
			hit.emit(self, result.collider, result.position)
			return
	global_position = to
	_travelled += step.length()
	if _travelled >= MAX_RANGE:
		set_physics_process(false)
		if simulate:
			expired.emit(self)
		else:
			visible = false  # the server will despawn it shortly
