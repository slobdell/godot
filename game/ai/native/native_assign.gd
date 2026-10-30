class_name NativeAssign
extends RefCounted
## Round 45 (native, R45.16): SelectionSquads._assign's exhaustive least-total search natively (native/src/assign_native.cpp),
## n <= SEARCH_LIMIT. Seam: the first line of _assign; its GDScript stays the reference (tests/test_native_assign.gd).
## BrainSwitches.native_assign.


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_assign and NativeBridge.available
	if ok and NativeBridge.counting:
		NativeBridge.took("assign")
	return ok


static func assign(centers: Array[Vector3], slots: Array[Vector3]) -> Array[int]:
	var out: Array[int] = []
	out.assign(Array(NativeBridge.impl.assign_least_total(PackedVector3Array(centers), PackedVector3Array(slots))))
	return out
