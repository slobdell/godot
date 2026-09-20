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
## `seconds` is a PATIENCE budget, not a correctness threshold. What proves the arena is ready is the predicate in
## `_ready_arena` — this arena's own regions on the map, and a point inside its cover off the mesh — and that
## predicate is unchanged. The timeout only bounds how long we wait for it, and the loop breaks the moment it holds.
##
## Raised 2.0 -> 5.0 in round 8, when the cityscape (8 city blocks at 40 x 40 plus 42 props on a 140 m hexagon)
## became the first layout whose navmesh does not finish baking in two seconds headless. **The evidence that this
## is bake TIME and not a broken layout, gathered before touching the number:** `make nav-maze ARENA=terminus`
## crosses the map — 7 of 10 units arrive inside a 30 s window with `no_progress` at 0.002 — so the mesh bakes,
## connects both bases, and carries traffic. A timeout raised without that evidence would be a test tuned until it
## passed, which is the failure mode this fixture exists to prevent.
static func build(test: TestCase, layout_name: String, seconds := 5.0) -> Arena:
	return await _ready_arena(test, layout_name, {}, seconds)


## The same wait, for a layout built in the test rather than shipped in arenas/.
static func build_layout(test: TestCase, layout: Dictionary, seconds := 5.0) -> Arena:
	return await _ready_arena(test, String(layout.get("name", "layout")), layout, seconds)


## Wait until the world's navigation map holds NO regions at all, before a new arena is built into it.
##
## `TestCase.teardown()` calls `free()`, which is **synchronous**; `NavigationServer3D` drops the freed arena's
## regions when it next **syncs**, a frame or two later. A test boundary is not a synchronisation point, so the next
## test's arena was baking into a map that still held the previous one's geometry — two full arenas of edges in one
## rasterization space. The engine reports it as
##
##     Navigation map synchronization had 284 edge error(s).
##     More than 2 edges tried to occupy the same map rasterization space.
##
## and `run_tests.gd` fails **every test running when that warning lands**, which is why combat's shard 0 had 14 of
## 18 failures sharing nothing but timing, and why the test standing next to the warning (`test_theme_unit_scale`)
## builds no arena at all. **The carrier is a server warning, not a test's own error**, so its position in the log
## marks the next sync and not the cause. nav hit the same bug at smaller scale — **4** edge errors from building
## terminus twice inside one test, against **284** from two full arenas across a boundary. Same mechanism, different
## overlap, one bug.
##
## **`_ready_arena`'s own predicate already knew foreign regions could be present and waited them out — but it waits
## AFTER `add_to_tree`, so the bake has already happened into the shared map.** This drains first.
##
## **The predicate is EMPTY, not "back to the count we started with".** scale's drain probe printed
## `before=2 with_arena=2 then after free: [2, 0, 0, 0]`: `before` and `with_arena` are equal, so a baseline guard
## would have been satisfied immediately having waited for nothing — and `before=2` **was itself the previous test's
## regions mid-drain**, so the baseline carried the very hazard it was meant to exclude. "Stops changing" is not
## enough either: a drain spanning two syncs reads `2, 2` as settled while both samples are pre-drain. Zero is the
## real resting state (their frame 1 onwards) and it is the only predicate with no false-satisfied case.
static func _drain_regions(test: TestCase, seconds: float) -> void:
	var map := (test.tree.root as Viewport).world_3d.navigation_map
	for frame in int(SimClock.TICK_RATE * seconds):
		if NavigationServer3D.map_get_regions(map).is_empty():
			return
		await test.tree.physics_frame
	var left := NavigationServer3D.map_get_regions(map).size()
	test.assert_true(left == 0,
			("setup: %d navigation region(s) from a previous arena never drained in %.0f s. Building into them "
			+ "raises 'more than 2 edges tried to occupy the same map rasterization space', and the runner then "
			+ "fails whatever test is running when the warning lands — which will not be this one.") % [left, seconds])


static func _ready_arena(test: TestCase, label: String, override: Dictionary, seconds: float) -> Arena:
	# BEFORE instantiating: the previous arena's regions must be gone, or this arena bakes into them.
	await _drain_regions(test, seconds)
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


## THE ONE PLACE arena decides whether a route arrived — now `Pathing.query().reachable`, which is exact.
##
## Why a helper at all: `map_get_path` to an unreachable goal returns a path to the CLOSEST REACHABLE POINT, which
## is non-empty and reads as success. This stream met that three times — the maze fixture, the slope probe and the
## water probe — and each time the wrong reading looked like a working one. It was a 4 m tolerance here until nav
## shipped `query`, kept behind one call site with a comment naming its replacement; **this is that replacement,
## and it was a one-line change because the tolerance was never allowed to spread.**
static func route_arrives(arena: Node3D, from: Vector3, goal: Vector3) -> bool:
	return bool(Pathing.query(arena, from, goal).get("reachable", false))


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
