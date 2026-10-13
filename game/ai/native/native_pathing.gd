class_name NativePathing
extends RefCounted
## Round 28 (native N6.4): Pathing's wrappers natively (native/src/pathing_native.cpp): is_ready, query and find_path,
## the think side's entries to the navmesh. Seams at the top of each in pathing.gd; the GDScript stays the reference.
## BrainSwitches.native_pathing. The detailed profile's per-query laps (nav.path, nav.is_ready) are the GDScript's
## only: natively they are not taken (the tick profile turns profile_detail on, and a seam that stepped aside for it
## priced GDScript against GDScript; found 2026-10-13, N7).

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_pathing and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("pathing")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.pathing_configure({"MESH_EPSILON": Pathing.MESH_EPSILON, "pathing": Pathing,
		"switches": BrainSwitches, "nav": NativeBridge.nav})
	return _ok
