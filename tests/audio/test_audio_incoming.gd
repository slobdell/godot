extends TestCase
## Round 17 G6 (the audit: ~100 mortar rounds a minute land in an artillery match, and none was heard coming down).
## A round in flight is an ArcRoundVisual (from, to, seconds); SfxSystem hears it appear and plays the falling whistle
## at the landing point so it ends as the round lands.


func test_a_falling_round_is_heard_before_it_lands() -> void:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	sfx.listener = Vector3.ZERO
	var round_visual := ArcRoundVisual.new()
	round_visual.from = Vector3(0, 1, -60)
	round_visual.to = Vector3(0, 0, 10)
	round_visual.seconds = 3.0
	sfx.track_incoming(round_visual, 0.0)
	var lead := sfx.incoming_lead_s()
	assert_true(lead > 0.5 and lead < 3.0, "the whistle starts %.1f s before landing" % lead)
	sfx.tick_incoming(3.0 - lead - 0.05)
	assert_eq(sfx.incoming_played, 0, "not yet")
	sfx.tick_incoming(3.0 - lead + 0.05)
	assert_eq(sfx.incoming_played, 1, "then once, at the landing point")
	sfx.tick_incoming(3.5)
	assert_eq(sfx.incoming_played, 1, "and only once")
	round_visual.free()


func test_a_short_lob_still_whistles_at_once() -> void:
	var sfx := SfxSystem.new()
	add_to_tree(sfx)
	var round_visual := ArcRoundVisual.new()
	round_visual.to = Vector3(0, 0, 10)
	round_visual.seconds = 0.4
	sfx.track_incoming(round_visual, 10.0)
	sfx.tick_incoming(10.0)
	assert_eq(sfx.incoming_played, 1, "a round shorter than the whistle whistles from the start")
	round_visual.free()
