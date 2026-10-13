class_name NativeIncoming
extends RefCounted
## Round 28 (native N7.1): Match.incoming_projectiles -- contract K2, the rounds in flight that will reach a unit,
## soonest first, with their damage estimates -- natively (native/src/incoming_native.cpp; the estimate over
## combat_native's terms), and IncomingFire._count_in_flight (the per-tick count over the tick's shell columns, the
## same geometry). Seams at the top of each; the GDScript stays the reference.
## BrainSwitches.native_incoming.

static var _configured := false
static var _ok := false


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_incoming and configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("incoming")
	return ok


static func configure() -> bool:
	if _configured:
		return _ok
	_configured = true
	if not NativeBridge.available or not NativeCombat.configure():
		return false
	_ok = NativeBridge.impl.incoming_configure({"INCOMING_MARGIN": Match.INCOMING_MARGIN, "ARC_HEIGHT": ArcRoundVisual.ARC_HEIGHT,
		"TICK_RATE": float(SimClock.TICK_RATE), "SITE": "incoming", "DEFAULT_WEAPON": Weapons.DEFAULT,
		"units": Units, "weapons": Weapons, "shell": Shell, "tank": Tank, "order": Match._incoming_before,
		"HORIZON_TICKS": float(IncomingFire.HORIZON_TICKS), "DANGER_RADIUS": IncomingFire.DANGER_RADIUS,
		"COUNT_SITE": IncomingFire.SITE})
	return _ok
