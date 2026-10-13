class_name NativeController
extends RefCounted
## Round 28 (native N7.3a): OrderController._physics_process natively (native/src/controller_native.cpp): the
## wall-contact observer's call, the stride hold, think (still GDScript) then compute_command, and every measurement
## branch (so a profiled run measures the native path). The seam is _physics_process's first lines; the GDScript stays
## the reference. BrainSwitches.native_controller.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_controller and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("controller")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.controller_configure({"order_controller": OrderController, "tank_brain": TankBrain,
			"sim_profile": SimProfile, "brains_ab": BrainsAB})
	return _ok
