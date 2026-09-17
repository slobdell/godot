class_name TankCommand
extends RefCounted
## What a tank is being told to do for ONE simulation tick.
##
## This is the seam of the whole architecture: a Tank never reads the keyboard,
## the network, or an AI. Something else (a controller) fills in a TankCommand
## and hands it over. Keyboard, scripted demo, network peer, and — eventually —
## a squad skill compiled from a player's strategy all produce this same object.
## See _agents/architecture.md.

## -1 = full reverse, 0 = stop, 1 = full forward.
var throttle: float = 0.0
## -1 = turn left, 1 = turn right.
var turn: float = 0.0
## World-space point the turret should rotate to face.
var aim_point: Vector3 = Vector3.ZERO
## True for the tick(s) the trigger is held. Firing lands in Milestone 3.
var fire: bool = false


func _init(p_throttle := 0.0, p_turn := 0.0, p_aim_point := Vector3.ZERO, p_fire := false) -> void:
	throttle = p_throttle
	turn = p_turn
	aim_point = p_aim_point
	fire = p_fire


## Controllers may produce out-of-range values (two keys at once, noisy AI output,
## a hostile network client sending NaN). The simulation only ever consumes a
## clamped, finite copy.
func sanitized() -> TankCommand:
	return TankCommand.new(_finite_unit(throttle), _finite_unit(turn),
			aim_point if aim_point.is_finite() else Vector3.ZERO, fire)


## sanitized(), written into `target` instead of a new object (CP1: the tank's own per-tick copy, no allocation).
func sanitize_into(target: TankCommand) -> TankCommand:
	target.throttle = _finite_unit(throttle)
	target.turn = _finite_unit(turn)
	target.aim_point = aim_point if aim_point.is_finite() else Vector3.ZERO
	target.fire = fire
	return target


func is_finite_command() -> bool:
	return is_finite(throttle) and is_finite(turn) and aim_point.is_finite()


static func _finite_unit(value: float) -> float:
	return clampf(value, -1.0, 1.0) if is_finite(value) else 0.0
