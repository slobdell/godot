class_name NativeMatchups
extends RefCounted
## Round 24 (native, N3d): `TankBrain.matchups_for` (70 % of `decide`'s cost) with `Matchups`' math and `Armor.facing`
## as one native call (native/src/matchups_native.cpp). The seam is at the top of `matchups_for`;
## tests/test_native_matchups.gd holds it to the live GDScript on real situations, and the C++'s constants to
## matchups.gd's and armor.gd's.

static var _constants := PackedFloat64Array()


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_matchups


static func constants() -> PackedFloat64Array:
	if _constants.is_empty():
		_constants = PackedFloat64Array([TankBrain.ORBIT_RADIUS, TankBrain.ORBIT_MEMORY_TICKS, TankBrain.CONTACT_FRESH_TICKS,
				TankBrain.DECK_SEEK_GAIN])
	return _constants


static func matchups_for(s: Dictionary) -> Dictionary:
	return NativeBridge.impl.matchups_for(s, Units, Weapons, constants())


## matchups.gd's and armor.gd's constants in drive order of matchups_native.cpp's matchups_constants().
static func live_constants() -> PackedFloat64Array:
	return PackedFloat64Array([Matchups.PENETRATION_FLOOR, Matchups.PENETRATION_CAP, Matchups.WEAK_SPOT_COS,
			Matchups.WEAK_SPOT_ARMOR_FRACTION, Matchups.TARGET_HALF_WIDTH, Matchups.GOOD_VS, Matchups.WEAK_VS,
			Matchups.OUT_OF_ARC, Matchups.NEVER, Matchups.SHIELD_FACING["front"], Matchups.SHIELD_FACING["side"],
			Matchups.SHIELD_FACING["rear"], Weapons.Kind.ARC, Armor.ARC_DEG])
