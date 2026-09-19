extends TestCase
## Water, pits and bridges (arena, round 7): ground a unit cannot cross but can fire over.
##
## The mechanism was measured before it was built (`make water-probe`), and these tests are that probe's findings
## turned into gates, because every one of them is a thing that would ship broken and look fine:
##   - carve the floor but forget the rim, and a shoved hull ends up in the water or out of the world;
##   - build the rim taller than 1.3 m and the "fire over it" half of the lead's request silently stops working;
##   - forget to cut the rim where a bridge crosses and the crossing is blocked by its own safety rail — which is
##     exactly what the probe's first bridge run did.

const ARENA := preload("res://game/arena/arena.tscn")
## A channel across the southern half, with a deck over it, and their mirrors.
## 320 m wide: the drivable arena is 232 m across, and the first version of this test used 200 m — so units drove
## round the channel's ends and the crossing was reachable after all. Correct behaviour, wrong fixture.
const CHANNEL := {"kind": "water", "name": "channel", "rect": [0.0, 40.0, 320.0, 24.0]}
const CHANNEL_MIRROR := {"kind": "water", "name": "channel (far)", "rect": [0.0, -40.0, 320.0, 24.0]}
const DECK := {"kind": "bridge", "name": "deck", "rect": [0.0, 40.0, 14.0, 24.0]}
const DECK_MIRROR := {"kind": "bridge", "name": "deck (far)", "rect": [0.0, -40.0, 14.0, 24.0]}


func _layout(terrain: Array) -> Dictionary:
	var layout: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	layout["terrain"] = terrain
	return layout


func test_a_carved_floor_covers_the_arena_except_its_water() -> void:
	var slabs := ArenaTerrain.slabs(160.0, [CHANNEL, CHANNEL_MIRROR])
	assert_true(not slabs.is_empty(), "the floor is still built")
	var covers := func(x: float, z: float) -> bool:
		for slab: Array in slabs:
			if absf(x - slab[0]) <= slab[2] / 2.0 and absf(z - slab[1]) <= slab[3] / 2.0:
				return true
		return false
	assert_true(covers.call(0.0, 0.0), "the middle is floor")
	assert_true(covers.call(0.0, 90.0), "so is the base")
	assert_true(not covers.call(150.0, 40.0), "and the channel reaches the arena's edge, so nothing drives round it")
	assert_true(not covers.call(0.0, 40.0), "the channel is not")
	assert_true(not covers.call(0.0, -40.0), "nor is its mirror")
	assert_true(covers.call(0.0, 56.0), "the bank just past it is floor again")
	# The decomposition must not leave overlapping boxes: they would be harmless but they mean the merge is wrong.
	var area := 0.0
	for slab: Array in slabs:
		area += slab[2] * slab[3]
	var expected := 320.0 * 320.0 - 2.0 * (320.0 * 24.0)
	assert_near(area, expected, 1.0, "the floor's area is the arena minus both channels (%d boxes)" % slabs.size())


func test_a_bridge_puts_the_floor_back() -> void:
	var slabs := ArenaTerrain.slabs(160.0, [CHANNEL, CHANNEL_MIRROR, DECK, DECK_MIRROR])
	var covers := func(x: float, z: float) -> bool:
		for slab: Array in slabs:
			if absf(x - slab[0]) <= slab[2] / 2.0 and absf(z - slab[1]) <= slab[3] / 2.0:
				return true
		return false
	assert_true(covers.call(0.0, 40.0), "the deck is floor")
	assert_true(not covers.call(40.0, 40.0), "the water beside it is not")


func test_the_rim_is_cut_where_a_bridge_crosses() -> void:
	var sealed := ArenaTerrain.rim_slabs(CHANNEL, [CHANNEL])
	var opened := ArenaTerrain.rim_slabs(CHANNEL, [CHANNEL, DECK])
	var spans_the_deck := func(slabs: Array) -> bool:
		for slab: Array in slabs:
			# A rim box running along x, covering the deck's centre line.
			if slab[3] <= ArenaTerrain.RIM_THICKNESS + 0.01 and absf(0.0 - slab[0]) < slab[2] / 2.0:
				return true
		return false
	assert_true(spans_the_deck.call(sealed), "with no bridge the rim runs unbroken across the channel's mouth")
	assert_true(not spans_the_deck.call(opened),
			"with a bridge it is cut there — otherwise the crossing is blocked by its own safety rail")


func test_the_rim_stops_a_hull_without_blocking_a_shot() -> void:
	assert_true(ArenaTerrain.RIM_HEIGHT < Perception.EYE_HEIGHT,
			"the rim (%.2f m) stays below eye level (%.2f m), or 'they could still fire over' stops being true"
			% [ArenaTerrain.RIM_HEIGHT, Perception.EYE_HEIGHT])
	assert_true(ArenaTerrain.RIM_HEIGHT >= 0.8, "and high enough that a hull cannot ride over it")


func test_water_is_off_the_navmesh_and_a_bridge_is_on_it() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout([CHANNEL, CHANNEL_MIRROR]))
	var map := arena.get_world_3d().navigation_map
	var mid := Vector3(40.0, 0.0, 40.0)
	assert_true(NavigationServer3D.map_get_closest_point(map, mid).distance_to(mid) > 2.0,
			"the channel is off the navmesh")
	var south := Vector3(0.0, 0.0, 60.0)
	var north := Vector3(0.0, 0.0, 20.0)
	var blocked := Pathing.find_path(arena, south, north)
	assert_true(not ArenaFixture.route_arrives(blocked, north), "and a channel across the arena cannot be crossed")
	arena.free()
	await tree.physics_frame

	var bridged := await ArenaFixture.build_layout(self, _layout([CHANNEL, CHANNEL_MIRROR, DECK, DECK_MIRROR]))
	var over := Pathing.find_path(bridged, south, north)
	assert_true(ArenaFixture.route_arrives(over, north), "a bridge makes the same crossing reachable")
	var beside := Vector3(40.0, 0.0, 40.0)
	assert_true(NavigationServer3D.map_get_closest_point(bridged.get_world_3d().navigation_map, beside).distance_to(beside) > 2.0,
			"and the water beside the deck is still water")


func test_a_bad_terrain_entry_is_refused() -> void:
	var narrow := _layout([CHANNEL, CHANNEL_MIRROR,
			{"kind": "bridge", "name": "thin", "rect": [0.0, 40.0, 3.0, 24.0]},
			{"kind": "bridge", "name": "thin (far)", "rect": [0.0, -40.0, 3.0, 24.0]}])
	assert_true(String(Arena.validate(narrow)).contains("agent radius"),
			"a deck too narrow to carry navmesh is refused: %s" % Arena.validate(narrow))
	var nowhere := _layout([{"kind": "bridge", "name": "lonely", "rect": [0.0, 40.0, 14.0, 24.0]},
			{"kind": "bridge", "name": "lonely (far)", "rect": [0.0, -40.0, 14.0, 24.0]}])
	assert_true(String(Arena.validate(nowhere)).contains("crosses no water"), "a bridge over nothing is refused")
	var lopsided := _layout([CHANNEL])
	assert_true(String(Arena.validate(lopsided)).contains("mirror"), "and a channel on one side only")
	var unknown := _layout([{"kind": "lava", "name": "x", "rect": [0.0, 0.0, 10.0, 10.0]}])
	assert_true(String(Arena.validate(unknown)).contains("unknown terrain kind"), "as is a kind we cannot build")


## Round 7, contract D: the perimeter handed to control (camera cutaway) and feel (walls, stands, gates) once at
## load. The spans exist because control's occlusion question is POSITIONAL -- feel's base side is stands, then the
## gate its army enters through, then stands again, and one value per edge could not describe the very first
## layout anyone tried to write with it.
func test_every_layout_today_is_a_square_and_nothing_had_to_change() -> void:
	for layout_name in Arena.layout_names():
		var layout: Dictionary = Arena.load_layout(layout_name)["layout"]
		var points := Arena.perimeter(layout)
		assert_eq(points.size(), 4, "%s is a square until it says otherwise" % layout_name)
		var edges := Arena.perimeter_edges(layout)
		assert_eq(edges.size(), 4, "%s has four edges" % layout_name)
		assert_eq(edges[0]["spans"].size(), 1, "%s: one span per edge by default" % layout_name)
		assert_eq(String(edges[0]["spans"][0]["kind"]), "stands", "%s: stands behind all of it" % layout_name)


func test_a_hexagon_is_the_shape_that_varies_most() -> void:
	var bound := Match.ARENA_HALF_SIZE
	var width_at := func(kind: String, z: float) -> float:
		var v := ArenaShape.vertices(kind, bound)
		var xs: Array = []
		for i in v.size():
			var a: Vector2 = v[i]
			var b: Vector2 = v[(i + 1) % v.size()]
			if (a.y - z) * (b.y - z) <= 0.0 and not is_equal_approx(a.y, b.y):
				xs.append(a.x + (z - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		return float(xs[xs.size() - 1]) - float(xs[0]) if xs.size() >= 2 else 0.0
	# The PINCH RATIO is the discriminator, not raw width: how much narrower the arena gets between its middle and
	# its approaches. That is the shape doing tactical work — an open midfield and two funnels — and it is why the
	# hexagon was chosen over the octagon. Kept as a gate so nobody "simplifies" the shape without seeing the cost.
	var pinch := func(kind: String) -> float:
		var mid: float = width_at.call(kind, 0.0)
		return float(width_at.call(kind, 60.0)) / mid if mid > 0.0 else 1.0
	var hexagon: float = pinch.call("hexagon")
	var octagon: float = pinch.call("octagon")
	assert_true(hexagon < 0.75, "a hexagon narrows to %.0f%% of its midfield width at the approaches" % [hexagon * 100.0])
	assert_true(octagon > 0.85, "an octagon barely narrows at all (%.0f%%) — it is the most uniform shape available"
			% [octagon * 100.0])
	assert_true(hexagon < octagon - 0.1, "so the hexagon varies materially more than the octagon")
	# And it keeps the square's room to manoeuvre where the fighting happens.
	assert_true(float(width_at.call("hexagon", 0.0)) >= bound * 2.0 - 0.5,
			"while giving up no lateral room at midfield (%.0f m)" % [width_at.call("hexagon", 0.0)])


func test_a_base_side_can_be_stands_then_gate_then_stands() -> void:
	var apothem := Match.ARENA_HALF_SIZE
	var side := ArenaShape.edge_length("hexagon", apothem)
	var gate_from := side / 2.0 - 9.25
	var gate_to := side / 2.0 + 9.25
	var base_side := {"spans": [{"kind": "stands", "to_m": gate_from}, {"kind": "gate", "to_m": gate_to},
			{"kind": "stands", "to_m": side}]}
	var plain := {"spans": [{"kind": "stands", "to_m": side}]}
	var shape := {"kind": "hexagon", "edges": [base_side, plain, plain, base_side, plain, plain]}
	assert_eq(ArenaShape.validate(shape, apothem), "", "a base side with a gate in the middle validates")
	var edges := ArenaShape.edges(shape, apothem)
	assert_eq(edges[0]["spans"].size(), 3, "and reads back as three spans")
	assert_eq(edges[0]["spans"][1]["kind"], "gate", "with the gate in the middle")
	assert_near(float(edges[0]["spans"][1]["from_m"]), gate_from, 0.01, "carrying an explicit from_m")
	# Contiguity is structural: spans are authored by where they END, so a gap is not expressible.
	var cursor := 0.0
	for span: Dictionary in edges[0]["spans"]:
		assert_near(float(span["from_m"]), cursor, 0.01, "spans are contiguous by construction")
		cursor = float(span["to_m"])
	assert_near(cursor, side, 0.01, "and cover the whole edge")


func test_an_asymmetric_perimeter_is_refused() -> void:
	var apothem := Match.ARENA_HALF_SIZE
	var side := ArenaShape.edge_length("hexagon", apothem)
	var plain := {"spans": [{"kind": "stands", "to_m": side}]}
	var gated := {"spans": [{"kind": "gate", "to_m": 20.0}, {"kind": "stands", "to_m": side}]}
	# Rotating 180 degrees maps edge k onto edge k+3, so a gate on one base side and not the other is a gate only
	# one army has. An asymmetric perimeter is an asymmetric navmesh bake, which is worth 64% of matches.
	var lopsided := {"kind": "hexagon", "edges": [gated, plain, plain, plain, plain, plain]}
	assert_true(String(ArenaShape.validate(lopsided, apothem)).contains("point-symmetric"),
			"a gate on one side only is refused: %s" % ArenaShape.validate(lopsided, apothem))
	var short := {"kind": "hexagon", "edges": [{"spans": [{"kind": "stands", "to_m": 10.0}]}, plain, plain,
			{"spans": [{"kind": "stands", "to_m": 10.0}]}, plain, plain]}
	assert_true(String(ArenaShape.validate(short, apothem)).contains("but the edge is"),
			"and spans that do not cover the edge")
	assert_true(String(ArenaShape.validate({"kind": "pentagon"}, apothem)).contains("unknown arena shape"),
			"as is a shape whose bake we cannot mirror")


## The hexagon as BUILT, not as data. The bake is the risk: the navmesh is carved by whatever the perimeter walls
## enclose and is baked as the southern half plus its 180° mirror, so a new shape must still produce a mesh that
## reaches the walls, connects the bases, and is identical under rotation. An asymmetric bake is worth 64% of
## matches to whichever base it favours (trip-up 21), and it is invisible without measuring it.
func _hexagon(extra: Dictionary = {}) -> Dictionary:
	var layout: Dictionary = Arena.load_layout("foundry")["layout"].duplicate(true)
	layout["shape"] = {"kind": "hexagon"} if extra.is_empty() else extra
	return layout


func test_a_shape_must_fit_inside_the_arena_bound() -> void:
	# A regular polygon's VERTICES sit further out than its flat sides. Built with apothem = half_size a hexagon
	# would reach 138.6 m on the x axis, outside a radar and fog sized for |x| <= 120 — so ArenaShape builds to the
	# BOUND instead (circumradius = half_size), and the flat sides come in to 103.9 m. That costs area, which is a
	# real constraint worth stating: the hexagon is 37,412 m2 against the square's 57,600.
	var layout := _hexagon()
	assert_eq(Arena.validate(layout), "", "a hexagon inside the bound validates")
	# The bound is a SQUARE EXTENT, not a radius: the radar and the fog are sized for |x| and |z| <= half_size, and
	# today's square arena already has corners 164 m from the centre. So what a new shape must respect is that no
	# point exceeds half_size on either axis — which for a hexagon means its vertices, at half_size on the x axis.
	for point: Vector2 in ArenaShape.vertices("hexagon", Match.ARENA_HALF_SIZE):
		assert_true(absf(point.x) <= Match.ARENA_HALF_SIZE + 0.05 and absf(point.y) <= Match.ARENA_HALF_SIZE + 0.05,
				"vertex %s is inside the arena's |x|,|z| <= %.0f bound" % [point, Match.ARENA_HALF_SIZE])


func test_a_hexagon_bakes_a_navmesh_that_reaches_its_walls_and_connects_its_bases() -> void:
	var arena := await ArenaFixture.build_layout(self, _hexagon())
	var map := arena.get_world_3d().navigation_map
	var apothem := Match.ARENA_HALF_SIZE
	var on_mesh := func(p: Vector3) -> bool:
		return NavigationServer3D.map_get_closest_point(map, p).distance_to(p) < 3.0
	# The widest points of a flat-side-to-base hexagon are its left and right vertices, well outside a square's
	# reach: if the mesh stops at +-120 the walls were built but the floor was not extended to meet them.
	var radius := apothem / cos(PI / 6.0)
	assert_true(on_mesh.call(Vector3(radius - 8.0, 0.0, 0.0)), "the mesh reaches the east vertex (%.0f m out)" % radius)
	assert_true(on_mesh.call(Vector3(-(radius - 8.0), 0.0, 0.0)), "and the west one")
	# NOT asserting that the mesh stops at the wall: it never has. The ground is a 320 m slab and the bake covers
	# it, so on foundry today the navmesh is still 0.5 m away at x = 155 — 35 m outside the wall. Units cannot
	# reach it because the walls enclose them, and the hexagon behaves exactly the same way. An assertion here
	# would have been testing something the game has never done.
	var green: Vector3 = Arena.spawn_spot(true, 0)
	var rust: Vector3 = Arena.spawn_spot(false, 0)
	assert_true(ArenaFixture.route_arrives(Pathing.find_path(arena, green, rust), rust),
			"the bases are connected across a hexagon")


func test_a_hexagons_bake_is_still_symmetric() -> void:
	var arena := await ArenaFixture.build_layout(self, _hexagon())
	var length := func(path: PackedVector3Array) -> float:
		var total := 0.0
		for i in range(1, path.size()):
			total += path[i - 1].distance_to(path[i])
		return total
	# The fairness invariant the half-plus-mirror bake exists to protect. Trips near the pinched approaches and
	# across the wide middle, each against its own 180° mirror.
	for trip: Array in [[Vector3(0, 0, 100), Vector3(0, 0, -100)], [Vector3(90, 0, 40), Vector3(-60, 0, -20)],
			[Vector3(-110, 0, 10), Vector3(70, 0, -60)]]:
		var there: float = length.call(Pathing.find_path(arena, trip[0], trip[1]))
		var back: float = length.call(Pathing.find_path(arena, -trip[0], -trip[1]))
		assert_true(there > 0.0, "trip %s has a path" % [trip])
		assert_near(there, back, 0.05, "trip %s is exactly as long as its 180° mirror" % [trip])


func test_a_square_layout_keeps_the_walls_it_always_had() -> void:
	var arena := await ArenaFixture.build(self, "foundry")
	var wall := arena.get_node("Perimeter")
	var live := 0
	for child in wall.get_children():
		if not (child as CollisionShape3D).disabled:
			live += 1
	assert_eq(live, 4, "a square layout uses the four colliders authored in arena.tscn, untouched")


## The two ways a player can give an impossible order on a map with water, which nav's `Pathing.query` will
## distinguish as `goal_on_mesh` and `reachable`. They are different failures and should feel different: clicking
## INTO the water is "you cannot go there at all", while clicking across a channel with no bridge is "there is no
## way round". Today both come back as a path that stops early; the assertions below pin the distinction so the
## behaviour is already specified when the exact answer arrives.
func test_the_two_impossible_orders_water_creates() -> void:
	var arena := await ArenaFixture.build_layout(self, _layout([CHANNEL, CHANNEL_MIRROR]))
	var map := arena.get_world_3d().navigation_map
	var bank := Vector3(0.0, 0.0, 60.0)

	# 1. A goal INSIDE the water: not on the navmesh at all.
	var in_water := Vector3(0.0, 0.0, 40.0)
	assert_true(NavigationServer3D.map_get_closest_point(map, in_water).distance_to(in_water) > 2.0,
			"a point in the channel is not on the mesh (goal_on_mesh: false)")
	assert_true(not ArenaFixture.route_arrives(Pathing.find_path(arena, bank, in_water), in_water),
			"so an order into the water cannot arrive")

	# 2. A goal on the FAR BANK: on the mesh, but on the other island.
	var far_bank := Vector3(0.0, 0.0, 20.0)
	assert_true(NavigationServer3D.map_get_closest_point(map, far_bank).distance_to(far_bank) < 2.0,
			"the far bank IS on the mesh (goal_on_mesh: true)")
	assert_true(not ArenaFixture.route_arrives(Pathing.find_path(arena, bank, far_bank), far_bank),
			"but with no bridge there is no way round (reachable: false)")
