class_name NativeTank
extends RefCounted
## Round 28 (native N6.1): `Tank._drive` as one native call per tank per tick (native/src/tank_drive_native.cpp): the
## motion model with no crossing, move_and_slide called from C++. The seam is the first line of `Tank._drive`; the GDScript
## below it stays the reference (the web build, NATIVE=off, the drive-trace instrument). BrainSwitches.native_tank.

static var _configured := false
static var _ok := false


static func usable(tank: Tank) -> bool:
	if not (BrainSwitches.native and BrainSwitches.native_tank and configure()):
		return false
	if not Tank._drive_trace_read:
		tank._read_drive_trace()
	return Tank.drive_trace.is_empty()  # the trace instrument is the GDScript's


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available or not NativeMotion.configure():
		return false
	_ok = NativeBridge.impl.tank_drive_configure({"OFF_FLOOR_M": Tank.OFF_FLOOR_M, "tank_motion": TankMotion,
			"sim_profile": SimProfile})
	return _ok


static func drive(tank: Tank, cmd: TankCommand, delta: float) -> void:
	NativeBridge.impl.tank_drive(tank, cmd, delta)
