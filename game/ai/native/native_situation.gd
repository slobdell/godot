class_name NativeSituation
extends RefCounted
## Round 24 (native, N3d): the first part of `TankBrain.build_situation` (the allies, which contacts to look at, each
## contact's entry) as one native call (`TankNative.situation_core`, native/src/situation_native.cpp). The seam is in
## `build_situation`; tests/test_native_situation.gd builds situations both ways on real brains in a fight.

static var _constants := PackedFloat64Array()


static func usable() -> bool:
	return BrainSwitches.native and BrainSwitches.native_situation


## TankBrain's and Tank's constants the core reads, from the live scripts.
static func constants() -> PackedFloat64Array:
	if _constants.is_empty():
		_constants = PackedFloat64Array([TankBrain.MAX_CONTACTS, TankBrain.COS_AIMED_AT_ME, TankBrain.COS_WATCHING,
				TankBrain.COS_ARMOR_ARC, Tank.PINNED_SUPPRESSION, Match.INTEL_EVERY_TICKS, AiTickCache.COS_30])
	return _constants
