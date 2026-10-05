extends TestCase
## Round 18 (finale, decided 2026-10-04): the live feed keeps the arena's glow, so its shaders are the main view's and the
## warm-up needs no feed render. `--feed-glow=off` puts back exactly what was before: these tests hold the switch to it.


func _arena_environment() -> Environment:
	var environment := Environment.new()
	environment.glow_enabled = true
	environment.glow_intensity = 1.3
	environment.fog_enabled = true
	environment.fog_density = 0.004
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	var world := WorldEnvironment.new()
	world.environment = environment
	add_to_tree(world)
	return environment


func _feed_environment(keeps: int) -> Environment:
	var previous := LiveFeed.glow_override
	LiveFeed.glow_override = keeps
	var feed: LiveFeed = add_to_tree(LiveFeed.new())
	var environment: Environment = feed.call("_feed_environment")
	LiveFeed.glow_override = previous
	return environment


## Every stored property of `environment` (what a byte-for-byte comparison of two environments means here).
func _stored(environment: Environment) -> Dictionary:
	var values := {}
	for property in environment.get_property_list():
		if int(property["usage"]) & PROPERTY_USAGE_STORAGE:
			values[property["name"]] = environment.get(property["name"])
	return values


func test_the_off_switch_is_todays_feed_exactly() -> void:
	var arena := _arena_environment()
	var feed := _feed_environment(0)
	var today := arena.duplicate() as Environment
	today.glow_enabled = false  # what live_feed.gd did unconditionally before round 18
	assert_eq(_stored(feed), _stored(today), "--feed-glow=off: every stored setting is today's (a copy without glow)")
	assert_true(feed != arena, "still its own copy, not the arena's environment")


func test_the_default_keeps_the_arenas_glow_and_nothing_else_changes() -> void:
	var arena := _arena_environment()
	var feed := _feed_environment(1)
	assert_true(feed.glow_enabled, "the feed keeps the arena's glow")
	assert_eq(_stored(feed), _stored(arena), "and every other setting is the arena's, as before")


func test_the_warm_up_renders_the_feed_only_when_the_feed_drops_glow() -> void:
	var previous := LiveFeed.glow_override
	LiveFeed.glow_override = 1
	var keeping := ShaderWarmup.new()
	LiveFeed.glow_override = 0
	var dropping := ShaderWarmup.new()
	LiveFeed.glow_override = previous
	assert_true(not keeping.parts.has("feed"), "a feed with the arena's glow shares the main view's shaders: no feed render")
	assert_true(dropping.parts.has("feed"), "--feed-glow=off: the feed's own variants are warmed again, as before")
	assert_true(keeping.parts.has("unlit") and keeping.parts.has("lit"), "the world's two frames stay")
	keeping.free()
	dropping.free()
