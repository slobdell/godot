extends TestCase
## Round 36 (orders O2): DEPLOY_COMPACT, the deploy's herringbone staggered half as deep (OFF; `--deploy-compact=on`).
## The trace (references/round36/orders/o2-deploy-move-note.md): a 4-5 crew herringbone stands 33-48 m deep along the
## street, so the wing crews of the wedge it deploys from drive 20-47 m. Compacting halves the depth about the seats'
## middle and keeps the side offsets, so opposite-side neighbours stay more than a spacing apart. Pure:
## ElementPlan._deploy_compact.

const SPACING := 14.0


func _herringbone(count: int) -> Dictionary:
	var slots := {}
	var members: Array = []
	for i in count:
		members.append({"name": "c%d" % i, "unit": "law_ifv", "role": "tank", "position": Vector3.ZERO})
	for entry in TacticsFormation.place(members, "herringbone", Vector3(10, 0, 20), Vector3.FORWARD, SPACING, {"halt": true, "corridor_m": INF}):
		slots["c%d" % int(entry["index"])] = entry["to"]
	return slots


func _span(slots: Dictionary, axis: Vector3) -> float:
	var values: Array = slots.values().map(func(p: Vector3) -> float: return p.dot(axis))
	return float(values.max()) - float(values.min())


func test_the_depth_halves_and_the_sides_stay() -> void:
	var slots := _herringbone(5)
	var compact := ElementPlan._deploy_compact(slots, Vector3.FORWARD)
	assert_true(absf(_span(compact, Vector3.FORWARD) - 0.5 * _span(slots, Vector3.FORWARD)) < 0.01,
			"depth %.1f -> %.1f" % [_span(slots, Vector3.FORWARD), _span(compact, Vector3.FORWARD)])
	assert_true(absf(_span(compact, Vector3.RIGHT) - _span(slots, Vector3.RIGHT)) < 0.01, "the width is kept")


func test_the_middle_stays_on_the_spot_and_no_pair_crowds() -> void:
	var slots := _herringbone(5)
	var compact := ElementPlan._deploy_compact(slots, Vector3.FORWARD)
	var mid := func(d: Dictionary) -> float:
		var sum := 0.0
		for p: Vector3 in d.values():
			sum += p.dot(Vector3.FORWARD)
		return sum / d.size()
	assert_true(absf(float(mid.call(compact)) - float(mid.call(slots))) < 0.01, "centred where it was laid")
	var closest := INF
	var names := compact.keys()
	for i in names.size():
		for j in range(i + 1, names.size()):
			closest = minf(closest, (compact[names[i]] as Vector3).distance_to(compact[names[j]]))
	assert_true(closest >= 0.75 * SPACING, "no two crews closer than 0.75 spacing: %.1f m" % closest)
