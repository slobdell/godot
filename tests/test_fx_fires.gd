extends TestCase
## Burning kill sites (art stretch): a kill leaves a fire that feeds the pooled bursts and light pool, burns down and
## goes out; the tier caps how many burn at once.


func test_a_kill_site_burns_then_goes_out() -> void:
	var bursts := BurstSystem.new(64)
	add_to_tree(bursts)
	var lights := LightPool.new(4)
	add_to_tree(lights)
	var fires := FireSites.new()
	fires.ignite(Vector3(10, 0, 5), 0.0, bursts)
	assert_eq(fires.burning_count(), 1, "the kill site is burning")
	var before := bursts.started
	for step in 40:
		fires.update(step * 0.1, bursts, lights)
	assert_true(bursts.started - before >= 6, "it keeps feeding flames into the pooled bursts (%d in 4 s)" % (bursts.started - before))
	fires.update(FireSites.BURN_SECONDS + 1.0, bursts, lights)
	assert_eq(fires.burning_count(), 0, "after %d s the fire is out" % FireSites.BURN_SECONDS)


func test_the_tier_caps_how_many_sites_burn() -> void:
	var bursts := BurstSystem.new(64)
	add_to_tree(bursts)
	var previous := FxQuality.tier()
	FxQuality.set_tier(FxQuality.Tier.LOW, "test")
	var fires := FireSites.new()
	for i in 8:
		fires.ignite(Vector3(i * 10.0, 0, 0), float(i), bursts)
	assert_eq(fires.burning_count(), FireSites.PER_TIER[FxQuality.Tier.LOW], "phones keep only the newest few fires")
	assert_near((fires.sites[0]["position"] as Vector3).x, 50.0, 0.001, "the oldest went out first")
	FxQuality.set_tier(previous, "test")


func test_heat_haze_rises_over_the_nearest_fires_on_the_high_tier_only() -> void:
	var previous := FxQuality.tier()
	var haze: HeatHaze = add_to_tree(HeatHaze.new())
	var sites: Array = []
	for i in 12:
		sites.append({"position": Vector3(i * 10.0, 0, 0), "start": 0.0})
	FxQuality.set_tier(FxQuality.Tier.HIGH, "test")
	var nodes := haze.get_child_count()
	haze.update(sites, Vector3.ZERO, 5.0)
	assert_eq(haze.active_count(), HeatHaze.MAX_QUADS, "twelve fires, the %d nearest shimmer" % HeatHaze.MAX_QUADS)
	assert_eq(haze.get_child_count(), nodes, "one MultiMesh however many fires")
	FxQuality.set_tier(FxQuality.Tier.LOW, "test")
	haze.update(sites, Vector3.ZERO, 5.0)
	assert_eq(haze.active_count(), 0, "phones skip the screen-copy haze")
	FxQuality.set_tier(previous, "test")
