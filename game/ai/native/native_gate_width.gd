class_name NativeGateWidth
extends RefCounted
## Round 45 (native N2, C45.4): RtsControls.gate_width natively (native/src/gate_width_native.cpp) for the group click's column lay,
## which reads it with SelectionSquads.crosses_or_edge(crosses_on(ground)) and drive_on(ground). Seam:
## RtsControls.gate_width_edge_on; the GDScript gate_width stays the reference (tests/test_native_gate_width.gd).
## BrainSwitches.native_gate_width. Rides on NativePathing's configured wrappers (the same find_path).


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_gate_width and NativePathing.configure()
	if ok and NativeBridge.counting:
		NativeBridge.took("gate_width")
	return ok


static func gate_width_edge(ground: Node3D, click: Vector3, across: Vector3, scan: float, past_posts: float) -> Array[float]:
	var out: Array[float] = []
	out.assign(NativeBridge.impl.gate_width_edge(ground, click, across, scan, past_posts, SlotGround.deck_boxes(),
			Orders.clamp_to_arena, RtsControls.GATE_STEP_M, RtsControls.GATE_DETOUR))
	return out
