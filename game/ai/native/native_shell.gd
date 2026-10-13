class_name NativeShell
extends RefCounted
## Round 28 (native N7.1c): Shell._fly natively (native/src/shell_native.cpp): one shell's tick of flight -- the swept
## ray, the hit and its signal, the step, the burn-out -- called from the shell's own _physics_process, so the shells
## fly in the scene's order as before. The seam is _fly's first lines; the GDScript stays the reference.
## BrainSwitches.native_shell.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_shell and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("shell")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.shell_configure({"HIT_MASK": Shell.HIT_MASK})
	return _ok
