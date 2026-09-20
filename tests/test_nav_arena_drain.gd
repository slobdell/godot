extends TestCase
## Round 9 (nav, holding `game/arena/` while arena rests): **two arenas in one process must not share a navigation
## map.** `TestCase.teardown()` frees synchronously; `NavigationServer3D` drops the regions when it next syncs, a
## frame or two later; a test boundary is not a synchronisation point. So the next arena baked into the previous
## one's geometry and the engine said so:
##
##     Navigation map synchronization had 284 edge error(s).
##     More than 2 edges tried to occupy the same map rasterization space.
##
## `run_tests.gd` fails **every test running when that warning lands**, which is how combat's shard 0 lost 14 of 18
## to tests sharing nothing but timing, with the warning's neighbour (`test_theme_unit_scale`) building no arena at
## all. nav produced **4** of the same errors from building terminus twice inside one test.
##
## These tests are the guard. If `ArenaFixture` ever stops draining first, the second build raises the warning and
## the runner fails whichever test it lands on — so a green run here is the claim that it does not.


## The drain itself: after an arena is freed, the map empties, and it does so within the fixture's budget.
func test_a_freed_arenas_regions_leave_the_map() -> void:
	var map := (tree.root as Viewport).world_3d.navigation_map
	var arena: Arena = await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var with_arena := NavigationServer3D.map_get_regions(map).size()
	assert_true(with_arena > 0, "POSITIVE CONTROL: the arena put regions on the map (%d)" % with_arena)
	arena.free()
	var counts: Array[int] = []
	for frame in 4:
		await tree.physics_frame
		counts.append(NavigationServer3D.map_get_regions(map).size())
	print("MEASURE arena_drain: with_arena=%d then after free: %s" % [with_arena, str(counts)])
	assert_eq(NavigationServer3D.map_get_regions(map).size(), 0,
			"the freed arena's regions are gone within four frames (%s)" % str(counts))


## THE ONE THAT MATTERS: a second arena built after a first is freed does not bake into the first's geometry.
## If the fixture stops draining first, this raises the synchronization warning and the runner fails this test.
func test_a_second_arena_does_not_bake_into_the_first() -> void:
	var map := (tree.root as Viewport).world_3d.navigation_map
	var first: Arena = await ArenaFixture.build(self, Arena.DEFAULT_LAYOUT)
	var first_regions := NavigationServer3D.map_get_regions(map).size()
	first.free()
	# Build the second WITHOUT waiting ourselves - the fixture must do the draining, because every other test in
	# the suite reaches it through the fixture and none of them waits by hand.
	var second: Arena = await ArenaFixture.build(self, "foundry")
	var after := NavigationServer3D.map_get_regions(map)
	print("MEASURE arena_drain second: first had %d regions, map now holds %d" % [first_regions, after.size()])
	assert_true(first_regions > 0, "POSITIVE CONTROL: the first arena really was on the map")
	assert_true(after.size() > 0, "and the second arena is on the map (%d regions)" % after.size())
	# Every region on the map belongs to the SECOND arena: nothing of the first survived into its bake.
	var mine := {}
	for node in second.find_children("*", "NavigationRegion3D", true, false):
		mine[(node as NavigationRegion3D).get_rid()] = true
	var strangers := 0
	for rid: RID in after:
		if not mine.has(rid):
			strangers += 1
	assert_eq(strangers, 0,
			"no region from the freed arena is still on the map (%d strangers of %d)" % [strangers, after.size()])
