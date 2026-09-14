class_name ArcRoundVisual
extends Node3D
## Client-side look of an indirect round in flight: the fx.shell visual slot flown along a parabola from
## the muzzle to the landing point, pointing along its path. Purely visual; Match resolves the burst.

## Peak height as a fraction of the horizontal distance.
const ARC_HEIGHT := 0.35

var from := Vector3.ZERO
var to := Vector3.ZERO
var seconds := 1.0

var _age := 0.0
var _shell: VisualSlot


func _ready() -> void:
	_shell = VisualSlot.new()
	_shell.slot = "fx.shell"
	add_child(_shell)
	global_position = from


func _process(delta: float) -> void:
	_age += delta
	var t := clampf(_age / maxf(seconds, 0.01), 0.0, 1.0)
	var here := ArcRoundVisual.point_at(from, to, t)
	var ahead := ArcRoundVisual.point_at(from, to, minf(t + 0.02, 1.0))
	global_position = here
	if ahead.distance_to(here) > 0.01:
		look_at(ahead, Vector3.UP if absf((ahead - here).normalized().y) < 0.99 else Vector3.RIGHT)
	if t >= 1.0:
		queue_free()


## Where the round is at fraction t of its flight.
static func point_at(start: Vector3, end: Vector3, t: float) -> Vector3:
	var flat := Vector2(end.x - start.x, end.z - start.z).length()
	return start.lerp(end, t) + Vector3.UP * (4.0 * ARC_HEIGHT * flat * t * (1.0 - t))
