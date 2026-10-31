class_name NativeEsit
extends RefCounted
## Round 47 (native N4, R47.19): ElementSituation.build's member and intel-contact loops natively (native/src/esit_native.cpp):
## ~0.3 of build's 0.54 ms a tick on his Crossing (builder3 light, probe c22464f11, n 1). Seam: build's first line asks for
## ElementSituation._entries; its GDScript stays the reference (tests/test_native_esit.gd). Units.role_of arrives as a table
## (every catalogue id, built once). BrainSwitches.native_esit.

## TANK_NATIVE_ESIT_VERIFY=1 (env): every native call is also run in GDScript and compared (byte for byte); a mismatch prints
## "NativeEsit verify mismatch ..." and every VERIFY_EVERY calls a "NATIVE_ESIT verified N, M mismatches" line. Runs the C++
## even while native_esit is OFF (the proof before the switch ships ON). Measurement only: the GDScript answer is discarded.
static var verify := OS.get_environment("TANK_NATIVE_ESIT_VERIFY") == "1"
static var verified := 0
static var mismatches := 0
const VERIFY_EVERY := 500
static var _roles := {}


static func usable() -> bool:
	var ok := BrainSwitches.native and (BrainSwitches.native_esit or verify) and NativeBridge.available
	if ok and NativeBridge.counting:
		NativeBridge.took("esit")
	return ok


static func _role_table() -> Dictionary:
	if _roles.is_empty():
		for unit: String in Units.ids():
			_roles[unit] = Units.role_of(unit)
	return _roles


static func consts() -> Dictionary:
	return {"FIRE_TICKS": ElementSituation.FIRE_TICKS, "HOLD_THROTTLE": ElementSituation.HOLD_THROTTLE,
			"HOLD_SPEED_MPS": ElementSituation.HOLD_SPEED_MPS, "KNOWN_M": ElementSituation.KNOWN_M}


static func entries(game_match: Match, team: int, member_names: PackedStringArray, state: Dictionary) -> Dictionary:
	var out: Dictionary = NativeBridge.impl.esit_entries(game_match, team, member_names, state.get("heading", Vector3.FORWARD),
			state.get("known", {}), _role_table(), consts())
	if verify:
		verified += 1
		var live := ElementSituation._entries(game_match, team, member_names, state)
		if var_to_bytes(live) != var_to_bytes(out):
			mismatches += 1
			print("NativeEsit verify mismatch team %d %s: live %s native %s" % [team, member_names, live, out])
		if verified % VERIFY_EVERY == 0:
			print("NATIVE_ESIT verified %d, %d mismatches" % [verified, mismatches])
	return out
