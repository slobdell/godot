class_name NativePlace
extends RefCounted
## Round 47 (native N2, R46.16): TacticsFormation.place natively (native/src/place_native.cpp): ElementPlan.build's one hot body on
## his Crossing (place 0.39 of build's 1.05 ms a tick, builder3 light, probe 128f9b2a9, n 1). Seam: the first line of place; its
## GDScript stays the reference (tests/test_native_place.gd). What reads the unit catalogue is computed here and handed over as
## data: hull_extent(members), toughness_of per member and each entry's role, with TacticsFormation's static switches.
## The A8 deformation (DEFORM_ENABLED, OFF since round 9) has no C++: with it on the seam steps aside. BrainSwitches.native_place.


## TANK_NATIVE_PLACE_VERIFY=1 (env): every native place is also run in GDScript and compared (byte for byte); a mismatch prints
## "NativePlace verify mismatch ..." and every VERIFY_EVERY calls a "NATIVE_PLACE verified N, M mismatches" line (make
## native-verify-scenarios greps both; his replays: REPLAY_ENV). Measurement only: the GDScript answer is discarded.
static var verify := OS.get_environment("TANK_NATIVE_PLACE_VERIFY") == "1"
static var verified := 0
static var mismatches := 0
const VERIFY_EVERY := 500


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_place and NativeBridge.available and not TacticsFormation.DEFORM_ENABLED
	if ok and NativeBridge.counting:
		NativeBridge.took("place")
	return ok


static func flags() -> PackedInt32Array:
	return PackedInt32Array([int(TacticsFormation.SEAT_BOUND), int(TacticsFormation.SEAT_ORDER), int(TacticsFormation.SEAT_LAST_OPEN),
			int(TacticsFormation.TRAVEL_SUM_FIRST), int(TacticsFormation.SHORT_SWAP_ENABLED), int(TacticsFormation.SQUARED_ALONG_ROUTE),
			int(TacticsFormation.NEAREST_ENABLED)])


static func place(members: Array, formation: String, anchor: Vector3, heading: Vector3, spacing: float,
		opts: Dictionary) -> Array[Dictionary]:
	var tough := PackedFloat64Array()
	var roles := PackedStringArray()
	for member: Dictionary in members:
		tough.append(TacticsFormation.toughness_of(member))
		var unit := String(member.get("unit", ""))
		roles.append(String(member.get("role", Units.role_of(unit) if unit != "" else "")))
	var out: Array[Dictionary] = []
	out.assign(NativeBridge.impl.formation_place(members, formation, anchor, heading, spacing, opts,
			TacticsFormation.hull_extent(members), tough, roles, flags(), TacticsFormation.LATERAL_FLOOR))
	if verify:
		_verify(out, members, formation, anchor, heading, spacing, opts)
	return out


static func _verify(out: Array[Dictionary], members: Array, formation: String, anchor: Vector3, heading: Vector3, spacing: float,
		opts: Dictionary) -> void:
	BrainSwitches.native_place = false
	var live := TacticsFormation.place(members, formation, anchor, heading, spacing, opts)
	BrainSwitches.native_place = true
	verified += 1
	if var_to_bytes(live) != var_to_bytes(out):
		mismatches += 1
		print("NativePlace verify mismatch %s %d members at %s: live %s native %s" % [formation, members.size(), anchor, live, out])
	if verified % VERIFY_EVERY == 0:
		print("NATIVE_PLACE verified %d, %d mismatches" % [verified, mismatches])
