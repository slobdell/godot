extends TestCase
## Round 37 (orders O1, R36.26): a parked squad's halt shape does not flicker when its crews straddle a terrain edge.
## The halt's shape and spacing come from ElementSituation.terrain_at (cover within 45 m). Read at the crews' CENTROID
## (main's rule, HALT_TERRAIN "centre") a crew's own creep moved the centroid across a feature's 45 m line and the halt
## flipped herringbone <-> coil, every flip re-seating the crews (locks/3/click s3664, builder0: Bravo_2 sent between its
## seat and a point ~15 m off, every second). Read at the fixed ANCHOR once arrived ("anchor") it cannot flip.
## The lab: three tanks hold on open ground a few metres from a lanes edge; every 2 s the whole squad is nudged across
## the edge and back (a creep, exaggerated). The centre arm must flip (the counter: the case really straddles the edge),
## the anchor arm must not.

const MAP := "locks"
const NUDGE_EVERY := SimClock.TICK_RATE * 2
const NUDGES := 6


## An open spot clear of cover by CLEAR_M whose terrain turns to cover a few metres away: {at, dir, r}.
const CLEAR_M := 16.0
func _edge() -> Dictionary:
	var features := ElementSituation._arena_features()
	var dirs: Array[Vector3] = []
	for k in 8:
		dirs.append(Vector3(cos(k * PI / 4.0), 0.0, sin(k * PI / 4.0)))
	for x in range(-120, 121, 4):
		for z in range(-120, 121, 4):
			var at := Vector3(x, 0.0, z)
			if ElementSituation.terrain_at(at) != "open" or Orders.clamp_to_arena(at).distance_to(at) > 0.1:
				continue
			var clear := true
			for feature: Dictionary in features:
				for p: Vector3 in feature.get("positions", [feature.get("position", Vector3.INF)]):
					clear = clear and Vector2(p.x - at.x, p.z - at.z).length() >= CLEAR_M
			if not clear:
				continue
			for dir: Vector3 in dirs:
				for step in range(2, 9):
					var r := step * 0.5
					if ElementSituation.terrain_at(at + dir * r) != "open":
						return {"at": at, "dir": dir, "r": r}
	return {}


func _flips(mode: String) -> Dictionary:
	ElementSituation.HALT_TERRAIN = mode
	var lab := TacticsLab.create(self, 7, MAP)
	ElementSituation.forget_terrain()
	var edge := _edge()
	assert_true(not edge.is_empty(), "setup: %s has an open spot within 4 m of a cover edge" % MAP)
	if edge.is_empty():
		lab.dispose()
		return {}
	var at: Vector3 = edge["at"]
	var names: Array = []
	for i in 3:
		var n := "Green_H_%d" % i
		lab.unit(Match.Team.GREEN, n, at + Vector3((i - 1) * 9.0, 0.0, 0.0), 0.0)
		names.append(n)
	var element := lab.element(names, "Alpha")
	element.assign({"verb": "hold", "to": [at.x, at.z]})
	await lab.start()
	for tick in SimClock.TICK_RATE * 6:
		await lab.step()
	var first := element.formation
	var anchor: Variant = element.anchor
	var shapes := {first: true}
	var flips := 0
	var last := first
	var shift: Vector3 = edge["dir"] * (float(edge["r"]) + 1.0)
	for nudge in NUDGES:
		for n: String in names:
			var tank := lab.tank_of(n)
			var offset := shift if nudge % 2 == 0 else -shift
			tank.place(tank.global_position + offset, tank.rotation.y)
		for tick in NUDGE_EVERY:
			await lab.step()
			if element.formation != last:
				flips += 1
				last = element.formation
				shapes[last] = true
	var out := {"flips": flips, "shapes": shapes.keys(), "first": first, "anchor_kept": anchor is Vector3
			and element.anchor is Vector3 and (anchor as Vector3).distance_to(element.anchor) < 0.5, "edge": edge}
	lab.dispose()
	ElementSituation.HALT_TERRAIN = ElementSituation._halt_terrain_flag()
	return out


func test_a_halt_read_at_its_centroid_flips_on_a_terrain_edge_and_one_read_at_its_anchor_does_not() -> void:
	var centre := await _flips("centre")
	var anchored := await _flips("anchor")
	if centre.is_empty() or anchored.is_empty():
		return
	print("HALT_TERRAIN_LAB centre %s | anchor %s" % [centre, anchored])
	assert_true(int(centre["flips"]) >= 2, "counter: read at the centroid the halt flips across the edge (%s)" % centre)
	assert_eq(int(anchored["flips"]), 0, "read at the anchor the halt keeps its shape (%s)" % anchored)
	assert_true(bool(anchored["anchor_kept"]), "the anchor stays where he parked it (%s)" % anchored)


func test_the_terrain_point_is_the_anchor_only_once_arrived_under_anchor() -> void:
	var saved := ElementSituation.HALT_TERRAIN
	var centre := Vector3(1, 0, 2)
	var anchor := Vector3(10, 0, 20)
	ElementSituation.HALT_TERRAIN = "anchor"
	assert_eq(ElementSituation.terrain_point(centre, {"arrived": true, "anchor": anchor}), anchor, "arrived: the anchor")
	assert_eq(ElementSituation.terrain_point(centre, {"arrived": false, "anchor": anchor}), centre, "travelling: the centre")
	assert_eq(ElementSituation.terrain_point(centre, {"arrived": true, "anchor": null}), centre, "no anchor: the centre")
	assert_eq(ElementSituation.terrain_point(centre, {}), centre, "no state (a lone crew's situation): the centre")
	ElementSituation.HALT_TERRAIN = "centre"
	assert_eq(ElementSituation.terrain_point(centre, {"arrived": true, "anchor": anchor}), centre, "main's rule: the centre")
	ElementSituation.HALT_TERRAIN = saved
