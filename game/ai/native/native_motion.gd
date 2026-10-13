class_name NativeMotion
extends RefCounted
## Round 28 (native N6.1): TankMotion.step_in_place as one native call (native/src/motion_native.cpp), the same bits as the
## GDScript (tests/test_native_motion.gd). The seam is the first line of `TankMotion.step_in_place`; the GDScript below it
## stays the reference (the web build, NATIVE=off). BrainSwitches.native_motion.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_motion and configure()


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.motion_configure({
		"WHEEL_CREEP_THROTTLE": TankMotion.WHEEL_CREEP_THROTTLE, "CREEP_REVERSE_SPEED": TankMotion.CREEP_REVERSE_SPEED,
		"CREEP_DRIFT_M": TankMotion.CREEP_DRIFT_M, "WHEELS_SETTLE_RADII": Movement.WHEELS_SETTLE_RADII,
		"WHEELS_SETTLE_MAX": Movement.WHEELS_SETTLE_MAX, "CREEP_LEG_TICKS": TankMotion.CREEP_LEG_TICKS,
		"YAW_RAMP_SECONDS": TankMotion.YAW_RAMP_SECONDS, "creepbound_off": Movement.switched_off("creepbound"),
	})
	if not _ok:
		push_error("NativeMotion: the native motion model refused the live constants (YAW_RAMP_SECONDS changed?)")
	return _ok


static func step_in_place(state: Dictionary, throttle: float, turn: float, delta: float) -> void:
	NativeBridge.impl.motion_step(state, throttle, turn, delta)
