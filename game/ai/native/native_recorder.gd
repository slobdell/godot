class_name NativeRecorder
extends RefCounted
## Round 28 (native N7.6): the black box's per-tick work natively (native/src/recorder_native.cpp): MatchRecorder's
## task scan, its once-a-second census and their rows, the same bytes. The seam is _physics_process's first lines; the
## GDScript stays the reference. The event rows stay GDScript handlers. BrainSwitches.native_recorder.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_recorder and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("recorder")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.recorder_configure({"CENSUS_S": MatchRecorder.CENSUS_S,
			"TICK_RATE": float(SimClock.TICK_RATE), "GREEN": Match.Team.GREEN, "RUST": Match.Team.RUST,
			"tank": Tank, "movement": Movement})
	return _ok
