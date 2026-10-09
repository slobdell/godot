class_name NativeTq
extends RefCounted
## Round 24 (native, C24.6): `TacticalQuery.find_cover` and `find_cover_fire` as one native call each
## (native/src/tq_native.cpp) over a CoverMap whose sight lines are already native (N1b: its `_native` twin). The seams
## are at the top of the two functions in tactical_query.gd (brains' file; the grant covers those two seams only);
## tests/test_native_tq.gd asks the live functions on random requests and on requests built from a real fight.

static var _configured := false


static func usable(map: CoverMap) -> bool:
	return BrainSwitches.native and BrainSwitches.native_tq and BrainSwitches.native_cover and map != null \
			and map._native != null and configure()


static func configure() -> bool:
	if _configured:
		return true
	if not NativeBridge.available:
		return false
	_configured = NativeBridge.impl.tq_configure({
		"SEARCH_RADIUS": TacticalQuery.SEARCH_RADIUS, "FRIEND_SPACING": TacticalQuery.FRIEND_SPACING,
		"PEEK_MAX": TacticalQuery.PEEK_MAX, "DRIVE_CLEARANCE": TacticalQuery.DRIVE_CLEARANCE,
		"STAND_CLEARANCE": TacticalQuery.STAND_CLEARANCE, "HULL_MARGIN": TacticalQuery.HULL_MARGIN,
		"PEEK_MARGIN": TacticalQuery.PEEK_MARGIN, "EDGE": CoverMap.EDGE, "CELL": CoverMap.CELL,
		"MAX_THREATS": TacticalQuery.MAX_THREATS, "MAX_CANDIDATES": TacticalQuery.MAX_CANDIDATES,
		"MAX_DEEP": TacticalQuery.MAX_DEEP, "PEEK_STEPS": TacticalQuery.PEEK_STEPS,
		"PEEK_ROTATIONS": TacticalQuery.PEEK_ROTATIONS,
	})
	return _configured


static func find_cover(map: CoverMap, request: Dictionary, count: int) -> Array:
	return NativeBridge.impl.tq_find_cover(map, request, count)


static func find_cover_fire(map: CoverMap, request: Dictionary) -> Dictionary:
	return NativeBridge.impl.tq_find_cover_fire(map, request)
