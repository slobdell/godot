class_name NativeContacts
extends RefCounted
## Round 48 (native N2): AiTickCache.contact_prototypes' table rebuild natively (native/src/contacts_native.cpp). Round 47's read
## (builder3 light, his Crossing at the cost cap): 0.156 ms a tick for both teams' tables, ~0.7 ms a frame on his laptop. Seam:
## contact_prototypes asks for AiTickCache._contact_table; its GDScript stays the reference (tests/test_native_contacts.gd).
## Weapons.profile's ranges arrive as a table (every PROFILES id, rebuilt when Weapons.tuning changes). BrainSwitches.native_contacts.

## TANK_NATIVE_CONTACTS_VERIFY=1 (env): every native table is also built in GDScript and compared (byte for byte); a mismatch prints
## "NativeContacts verify mismatch ..." and every VERIFY_EVERY calls a "NATIVE_CONTACTS verified N, M mismatches" line. Runs the C++
## even while native_contacts is OFF. Both write the same suppression memory (the same value, the same tick): idempotent.
static var verify := OS.get_environment("TANK_NATIVE_CONTACTS_VERIFY") == "1"
static var verified := 0
static var mismatches := 0
const VERIFY_EVERY := 500
static var _ranges := {}
static var _ranges_tuning := -1


static func usable() -> bool:
	var ok := BrainSwitches.native and (BrainSwitches.native_contacts or verify) and NativeBridge.available
	if ok and NativeBridge.counting:
		NativeBridge.took("contacts")
	return ok


## weapon id -> float(Weapons.profile(id)["range"]) for every profile, and the answer for an unknown id under "".
static func _range_table() -> Dictionary:
	var tuning_hash := Weapons.tuning.hash()
	if _ranges.is_empty() or _ranges_tuning != tuning_hash:
		_ranges = {}
		_ranges_tuning = tuning_hash
		for weapon_id: String in Weapons.PROFILES:
			_ranges[weapon_id] = float(Weapons.profile(weapon_id)["range"])
	return _ranges


static func table(game_match: Match, side: int, names: Array, by_name: Dictionary, fired: Dictionary, seen: Dictionary) -> Dictionary:
	var variant := BrainVariants.for_team(side)
	var ranges := _range_table()
	var opts := {"default_range": float(ranges[Weapons.DEFAULT]), "tick": game_match.tick,
			"physics_frames": Engine.get_physics_frames(), "reload_windows": bool(variant.get("reload_windows", false)),
			"pinned_exposed": bool(variant.get("pinned_exposed", false)), "SLOW_GUN_RELOAD": TankBrain.SLOW_GUN_RELOAD,
			"SUPPRESSION_RECOVER_PER_SECOND": Tank.SUPPRESSION_RECOVER_PER_SECOND, "TICK_RATE": float(SimClock.TICK_RATE)}
	var out: Dictionary = NativeBridge.impl.contact_table(game_match.intel[side], names, by_name, fired, seen, ranges, opts)
	if verify:
		verified += 1
		var live := AiTickCache._contact_table(game_match, side)
		if var_to_bytes(live) != var_to_bytes(out):
			mismatches += 1
			print("NativeContacts verify mismatch side %d tick %d: live %s native %s" % [side, game_match.tick,
					var_to_str(live).left(800), var_to_str(out).left(800)])
		if verified % VERIFY_EVERY == 0:
			print("NATIVE_CONTACTS verified %d, %d mismatches" % [verified, mismatches])
	return out
