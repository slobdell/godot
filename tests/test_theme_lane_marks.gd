extends TestCase
## Research rows B10 / C11 (round 10, feel, on arena's list): kerb paint, centre dashes (scale anchors) and warm junction
## pools on the Terminus's certified lanes. Art, so: flat, no collider, three draws; paint never crosses another
## street; a pool at every junction arena listed.

## arena's list (2026-09-22): the 11 junction points of the post-CP2 Terminus lanes.
const ARENA_CORNERS := [Vector2(0, 30), Vector2(0, -30), Vector2(0, 0), Vector2(-70, 30), Vector2(-70, -30),
		Vector2(70, 30), Vector2(70, -30), Vector2(-12, 30), Vector2(12, -30), Vector2(12, 30), Vector2(-12, -30)]


func _lanes() -> Array:
	return Arena.load_layout("terminus")["layout"].get("lanes", [])


func test_a_pool_at_every_junction_arena_listed() -> void:
	var corners := LaneMarks.corners_of(_lanes())
	for wanted: Vector2 in ARENA_CORNERS:
		var best := INF
		for c: Vector2 in corners:
			best = minf(best, c.distance_to(wanted))
		assert_true(best < 1.0, "a junction pool at %s (nearest %.1f m)" % [wanted, best])
	assert_eq(corners.size(), ARENA_CORNERS.size(), "and no junction arena did not list")


func test_paint_never_crosses_another_street() -> void:
	var lanes := _lanes()
	var plan := LaneMarks.plan_for(lanes)
	assert_true((plan["kerbs"] as Array).size() > 500, "kerbs along the lanes (%d pieces)" % (plan["kerbs"] as Array).size())
	assert_true((plan["dashes"] as Array).size() > 50, "dashes down the lanes (%d)" % (plan["dashes"] as Array).size())
	# Positive control: without the junction rule, some kerb pieces WOULD lie inside another lane.
	var crossing := 0
	for piece: Array in plan["kerbs"]:
		var mid: Vector2 = ((piece[0] as Vector2) + (piece[1] as Vector2)) / 2.0
		var inside := 0
		for lane: Dictionary in lanes:
			var pts: Array = lane["points"]
			for k in range(1, pts.size()):
				var a := Vector2(pts[k - 1][0], pts[k - 1][1])
				var b := Vector2(pts[k][0], pts[k][1])
				if mid.distance_to(Geometry2D.get_closest_point_to_segment(mid, a, b)) < float(lane["width"]) / 2.0:
					inside += 1
					break
		if inside > 1:
			crossing += 1
	assert_eq(crossing, 0, "no kerb piece lies on a second street's carriageway")


func test_the_dashes_are_a_ruler() -> void:
	## C11's scale anchor: on a straight lane every dash is DASH_PITCH_M from the next.
	var avenue: Array = []
	for lane: Dictionary in _lanes():
		if String(lane["name"]) == "the avenue":
			avenue = [lane]
	var plan := LaneMarks.plan_for(avenue)
	var starts: Array = []
	for piece: Array in plan["dashes"]:
		starts.append((piece[0] as Vector2).y)
	starts.sort()
	assert_true(starts.size() > 10, "the avenue carries dashes")
	for i in range(1, starts.size()):
		assert_near(absf(float(starts[i]) - float(starts[i - 1])), LaneMarks.DASH_PITCH_M, 0.01, "dash %d is one pitch on" % i)


func test_it_is_flat_art_three_draws_no_collider() -> void:
	var marks := LaneMarks.new(_lanes())
	add_to_tree(marks)
	for class_kind in ["CollisionObject3D", "CollisionShape3D", "Light3D"]:
		assert_eq(marks.find_children("*", class_kind, true, false).size(), 0, "no %s" % class_kind)
	var draws := marks.find_children("*", "MultiMeshInstance3D", true, false)
	assert_eq(draws.size(), 3, "kerbs, dashes, pools: three MultiMeshes")
	for d: MultiMeshInstance3D in draws:
		var box := d.get_aabb()
		assert_true(box.size.y < 0.1, "%s is flat (%.2f m tall)" % [d.name, box.size.y])


## arena's catch (2026-09-22): the kerb lines ran UNDER kerb furniture -- the avenue's into a two-high container --
## telling him the road went on where a box stood. Every kerb piece now stops FOOTPRINT_CLEAR_M short of every collider
## footprint the layout places; arena's named overlaps are the positive control (without footprints they ARE hit).
func test_kerb_paint_stops_short_of_the_kerb_furniture() -> void:
	var layout: Dictionary = Arena.load_layout("terminus")["layout"]
	var footprints := LaneMarks.footprints_of(layout)
	assert_true(footprints.size() > 0, "the Terminus places collider footprints (%d)" % footprints.size())
	var near := func(plan: Dictionary) -> int:
		var hits := 0
		for piece: Array in plan["kerbs"]:
			for fp: Array in footprints:
				for t in [0.0, 0.5, 1.0]:
					var p: Vector2 = (piece[0] as Vector2).lerp(piece[1] as Vector2, t)
					if ArenaKit.distance_to_footprint(p, fp[0], fp[1], float(fp[2])) < LaneMarks.FOOTPRINT_CLEAR_M:
						hits += 1
		return hits
	var without: int = near.call(LaneMarks.plan_for(_lanes()))
	assert_true(without > 0, "control: blind to footprints, kerb paint runs under furniture (%d samples)" % without)
	assert_eq(near.call(LaneMarks.plan_for(_lanes(), footprints)), 0, "with them, no kerb paint within %.1f m of one"
			% LaneMarks.FOOTPRINT_CLEAR_M)
