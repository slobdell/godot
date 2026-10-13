class_name NativePathing
extends RefCounted
## Round 28 (native N6.4): Pathing's wrappers natively (native/src/pathing_native.cpp): is_ready, query and find_path,
## the think side's entries to the navmesh. Seams at the top of each in pathing.gd; the GDScript stays the reference.
## BrainSwitches.native_pathing. With the detailed profile on (OrderController.profile_detail) the GDScript runs: its
## laps are what that profile counts.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_pathing and not OrderController.profile_detail and configure()


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.pathing_configure({"MESH_EPSILON": Pathing.MESH_EPSILON, "pathing": Pathing,
		"switches": BrainSwitches, "nav": NativeBridge.nav})
	return _ok
