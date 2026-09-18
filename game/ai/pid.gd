class_name Pid
extends RefCounted
## N6 (round 6): PID as the house control law. A small, deterministic, tick-based regulator:
##   output = kp * error + ki * integral(error) - kd * d(measurement)/dt, clamped to ±output_limit
## - the derivative is taken ON THE MEASUREMENT, not the error, so a setpoint that jumps (a new slot, a new order)
##   doesn't kick the output ("derivative kick");
## - the integral is clamped to ±integral_limit (anti-windup), and it stops integrating while the output is saturated
##   in the same direction (conditional integration), so a unit held back by a wall doesn't bank a surge;
## - `dt` is the fixed simulation tick, never a frame delta (invariant 7).
## Use it where there is a continuous error to regulate (station-keeping, speed matching), never for a discrete choice.
## Gains are data: ControlGains.

var kp := 1.0
var ki := 0.0
var kd := 0.0
var integral_limit := 1.0
var output_limit := 1.0

var integral := 0.0
var _last_measurement := 0.0
var _primed := false


func _init(gains: Dictionary = {}) -> void:
	configure(gains)


## Set gains from a ControlGains entry: {"kp", "ki", "kd", "integral_limit", "output_limit"}; missing keys keep theirs.
func configure(gains: Dictionary) -> void:
	kp = float(gains.get("kp", kp))
	ki = float(gains.get("ki", ki))
	kd = float(gains.get("kd", kd))
	integral_limit = float(gains.get("integral_limit", integral_limit))
	output_limit = float(gains.get("output_limit", output_limit))


func reset() -> void:
	integral = 0.0
	_primed = false


## One tick: regulate `measurement` toward `setpoint`.
func step(setpoint: float, measurement: float, dt: float) -> float:
	var rate := 0.0
	if _primed and dt > 0.0:
		rate = (measurement - _last_measurement) / dt
	_last_measurement = measurement
	_primed = true
	return step_with_rate(setpoint - measurement, rate, dt)


## One tick given the error and the measurement's own rate of change (when it is measured directly, e.g. a speed
## along a line or a yaw rate): the derivative term is -kd * rate.
func step_with_rate(error: float, measurement_rate: float, dt: float) -> float:
	var unclamped := kp * error + ki * integral - kd * measurement_rate
	var saturated_same_way := (unclamped >= output_limit and error > 0.0) or (unclamped <= -output_limit and error < 0.0)
	if not saturated_same_way:
		integral = clampf(integral + error * dt, -integral_limit, integral_limit)
	return clampf(kp * error + ki * integral - kd * measurement_rate, -output_limit, output_limit)
