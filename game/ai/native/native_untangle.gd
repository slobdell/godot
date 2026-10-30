class_name NativeUntangle
extends RefCounted
## Round 45 (native N2b, R45.3): SelectionSquads.untangle_whole's permutation search natively (native/src/untangle_native.cpp).
## Seam: the first line of untangle_whole; its GDScript body stays the reference (tests/test_native_untangle.gd). The
## Callables are read here, every value the search can ask (each crew's start; arc(anchor) and misplaced(squad, anchor) for
## every squad and anchor: pure readings, n <= 7), so the C++ is geometry only. BrainSwitches.native_untangle.


static func usable() -> bool:
	var ok := BrainSwitches.native and BrainSwitches.native_untangle and NativeBridge.available
	if ok and NativeBridge.counting:
		NativeBridge.took("untangle")
	return ok


## untangle_whole's contract: re-deals `anchors` in place (the first squads.size()), adds to SelectionSquads.swapped_whole /
## whole_still_crossed, returns the squads moved.
static func untangle_whole(squads: Array, anchors: Array[Vector3], position: Callable, leads: Array, arc: Callable,
		misplaced: Callable) -> int:
	var n := squads.size()
	var by_lead := leads.size() == n and arc.is_valid()
	var starts: Array = []
	for i in n:
		var crews: Array = []
		for unit_name: String in squads[i]["units"]:
			var p: Vector3 = position.call(unit_name)
			crews.append(Vector2(p.x, p.z))
		starts.append(crews)
	var lead_values := PackedFloat64Array()
	var arc_values := PackedFloat64Array()
	if by_lead:
		for i in n:
			lead_values.append(float(leads[i]))
			arc_values.append(float(arc.call(anchors[i])))
	var wrong := PackedByteArray()
	if misplaced.is_valid():
		wrong.resize(n * n)
		for i in n:
			for j in n:
				wrong[i * n + j] = 1 if bool(misplaced.call(i, anchors[j])) else 0
	var result: Dictionary = NativeBridge.impl.untangle_whole(starts, anchors.slice(0, n), by_lead, lead_values, arc_values,
			wrong, SelectionSquads.LEAD_SLACK_M)
	var dealt: Array = result["anchors"]
	for i in n:
		anchors[i] = dealt[i]
	SelectionSquads.whole_still_crossed += int(result["still_crossed"])
	SelectionSquads.swapped_whole += int(result["moved"])
	return int(result["moved"])
