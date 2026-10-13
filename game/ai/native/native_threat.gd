class_name NativeThreat
extends RefCounted
## Round 28 (native N7.2): the suppression field natively (native/src/threat_native.cpp): ThreatField's stamps and decay
## on the field's own packed arrays, and Match._update_suppression's settle (Tank.settle_suppression and its effects,
## the stats). The seams are the first lines of each; the GDScript stays the reference. BrainSwitches.native_threat.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_threat and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("threat")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available:
		return false
	_ok = NativeBridge.impl.threat_configure({"MARCH_FRACTION": ThreatField.MARCH_FRACTION,
			"EPSILON": ThreatField.EPSILON, "HALF_LIFE_SECONDS": ThreatField.HALF_LIFE_SECONDS,
			"TICK_RATE": float(SimClock.TICK_RATE), "SUPPRESSION_FULL_DENSITY": Match.SUPPRESSION_FULL_DENSITY,
			"PINNED_SUPPRESSION": Tank.PINNED_SUPPRESSION,
			"SUPPRESSION_RISE_PER_SECOND": Tank.SUPPRESSION_RISE_PER_SECOND,
			"SUPPRESSION_RECOVER_PER_SECOND": Tank.SUPPRESSION_RECOVER_PER_SECOND,
			"SUPPRESSION_SIGHT_PENALTY": Tank.SUPPRESSION_SIGHT_PENALTY,
			"SUPPRESSION_HULL_TURN_PENALTY": Tank.SUPPRESSION_HULL_TURN_PENALTY})
	return _ok
