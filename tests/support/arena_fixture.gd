class_name ArenaFixture
extends RefCounted
## Build an arena in a test and wait for ITS OWN navigation mesh (arena stream, round 6).
##
## `Pathing.is_ready()` only answers "does the world's navigation map have polygons". The previous test's arena is
## freed a frame or two before NavigationServer3D drops its regions, so `is_ready()` comes back true immediately
## against the OLD map and every path is a straight line through the new arena's walls. Nothing fails loudly: a
## connectivity test passes (the stale map is connected), a route length is wrong, a detour reads 1.00x.
##
## Round 6 hit this in tests/test_arena_maze.gd -- the file passed alone and failed after test_arena_layouts, with
## the maze reporting a straight base-to-base run and a dead end with no walls. It is luck of ordering, so the
## all-layouts connectivity test in test_arena_kit.gd has the same exposure and no symptom.
##
## The fix is to wait for geometry only THIS layout has: a point inside one of its own collision boxes must be off
## the navmesh. Waiting for polygons is not the same as waiting for this arena's polygons.
##
##   var arena := await ArenaFixture.build(self, "yard")

const ARENA := preload("res://game/arena/arena.tscn")


## An arena of `layout_name`, in the tree, with its own navigation synced. Fails the test and returns the arena
## anyway if it never syncs, so the caller's assertions report the real problem rather than a cascade of nulls.
static func build(test: TestCase, layout_name: String, seconds := 2.0) -> Arena:
	return await _ready_arena(test, layout_name, {}, seconds)


## The same wait, for a layout built in the test rather than shipped in arenas/.
static func build_layout(test: TestCase, layout: Dictionary, seconds := 2.0) -> Arena:
	return await _ready_arena(test, String(layout.get("name", "layout")), layout, seconds)


static func _ready_arena(test: TestCase, label: String, override: Dictionary, seconds: float) -> Arena:
	var arena: Arena = ARENA.instantiate()
	if override.is_empty():
		arena.layout_name = label
	else:
		arena.layout_override = override
	test.add_to_tree(arena)
	var found: Variant = inside_cover(arena.layout)
	var probe: Vector3 = found if found != null else Vector3.ZERO
	var have_probe := found != null
	var map := arena.get_world_3d().navigation_map
	var ready := func() -> bool:
		if not Pathing.is_ready(arena):
			return false
		# THE regions on the map must be exactly this arena's. The cover probe below cannot tell two arenas apart
		# when both are built from the same base layout — which is precisely what a test that varies only `terrain`
		# or `shape` does — so it would happily hand back the PREVIOUS arena's navmesh. Region identity can.
		var mine := _region_rids(arena)
		if mine.is_empty():
			return false
		for rid: RID in NavigationServer3D.map_get_regions(map):
			if not mine.has(rid):
				return false
		if NavigationServer3D.map_get_regions(map).size() < mine.size():
			return false
		if not have_probe:
			return true
		return NavigationServer3D.map_get_closest_point(map, probe).distance_to(probe) > 1.0
	for frame in int(SimClock.TICK_RATE * seconds):
		if ready.call():
			break
		await test.tree.physics_frame
	test.assert_true(ready.call(),
			"setup: %s's OWN navigation synced within %.0f s (a point inside its cover is off the mesh)"
			% [label, seconds])
	return arena


## THE ONE PLACE arena decides whether a route arrived. **Replace this with `Pathing.query(from, to).reachable`
## when nav ships it** (it is doing the scout standoff first, correctly) — one function, not a tolerance scattered
## through every check.
##
## Why a helper at all: `map_get_path` to an unreachable goal returns a path to the CLOSEST REACHABLE POINT, which
## is non-empty and reads as success. This stream has met that three times — the maze fixture, the slope probe and
## the water probe — and each time the wrong reading looked like a working one.
##
## The 4 m is a heuristic and is the thing nav's version removes. It is loose enough to allow the navmesh's own
## edge quantisation and tight enough to reject a route that stopped at a bank.
const ARRIVED_M := 4.0


static func route_arrives(path: PackedVector3Array, goal: Vector3) -> bool:
	return path.size() >= 2 and path[path.size() - 1].distance_to(goal) < ARRIVED_M


## This arena's own navigation regions: the baked half and its 180° mirror.
static func _region_rids(arena: Arena) -> Array:
	var out: Array = []
	var main := arena.get_node_or_null("Navigation") as NavigationRegion3D
	if main != null:
		out.append(main.get_region_rid())
	var mirror := arena.get_node_or_null("NavigationMirror") as NavigationRegion3D
	if mirror != null:
		out.append(mirror.get_region_rid())
	return out


## A point buried inside one of the layout's own collision boxes, or null if it has none big enough to be sure of.
## Picked as the widest piece of cover, so the probe is well clear of the box's edges and of the 1 m tolerance.
static func inside_cover(layout: Dictionary) -> Variant:
	var best: Dictionary = {}
	var best_size := 0.0
	for obstacle: Dictionary in layout.get("obstacles", []):
		var size := Arena.obstacle_size(obstacle)
		if minf(size.x, size.z) > best_size:
			best_size = minf(size.x, size.z)
			best = obstacle
	for prop: Dictionary in layout.get("props", []):
		if not ArenaKit.collides(prop["type"]):
			continue
		var size := ArenaKit.size_of(prop)
		if minf(size.x, size.z) > best_size:
			best_size = minf(size.x, size.z)
			best = prop
	if best.is_empty() or best_size < 2.0:
		return null
	return Vector3(best["position"][0], 0.0, best["position"][1])
