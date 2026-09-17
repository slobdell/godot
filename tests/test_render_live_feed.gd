extends TestCase
## Render (round 5): the arena screens show the fight live, and replay kills from the frames they already recorded.
## The lead: "Live during, ads between." Pure state here; the frames themselves need a GPU (make perf-scene).


func test_the_ring_records_in_order_and_the_newest_slot_is_live() -> void:
	var ring := LiveFeed.Ring.new(4)
	assert_eq(ring.live_slot(), -1, "nothing recorded yet")
	for i in 6:
		ring.record()
	assert_eq(ring.live_slot(), 1, "six frames into four slots: the newest is slot 1")
	assert_eq(ring.oldest_first(), [2, 3, 0, 1], "a replay plays the ring oldest first")


func test_a_short_ring_replays_only_what_it_has() -> void:
	var ring := LiveFeed.Ring.new(8)
	for i in 3:
		ring.record()
	assert_eq(ring.oldest_first(), [0, 1, 2], "three frames recorded, three played")


func test_replay_plays_at_half_speed_then_goes_back_to_live() -> void:
	var ring := LiveFeed.Ring.new(4)
	for i in 4:
		ring.record()
	var replay := LiveFeed.Replay.new(ring.oldest_first(), LiveFeed.FEED_HZ * LiveFeed.REPLAY_SPEED)
	assert_eq(replay.slot_at(0.0), 0, "starts on the oldest frame")
	assert_eq(replay.slot_at(1.0 / (LiveFeed.FEED_HZ * LiveFeed.REPLAY_SPEED) * 2.5), 2, "advances at the slowed rate")
	assert_true(replay.finished_at(1.0), "four frames at 7.5 per second are done within a second")


func test_screens_go_live_only_while_a_match_is_being_fought() -> void:
	assert_true(LiveFeed.should_be_live(true, false, true), "a running match: live")
	assert_true(not LiveFeed.should_be_live(false, false, true), "no match (title, galleries): ads")
	assert_true(not LiveFeed.should_be_live(true, true, true), "match over: ads between matches")
	assert_true(not LiveFeed.should_be_live(true, false, false), "a tier without a feed: ads")


func test_a_kill_near_the_shot_asks_for_a_replay_and_one_far_away_doesnt() -> void:
	assert_true(LiveFeed.wants_replay(1.0, 10.0, 100.0), "a kill in shot, cooldown over")
	assert_true(not LiveFeed.wants_replay(0.3, 10.0, 100.0), "a hit isn't a replay")
	assert_true(not LiveFeed.wants_replay(1.0, LiveFeed.REPLAY_RANGE + 5.0, 100.0), "a kill out of shot")
	assert_true(not LiveFeed.wants_replay(1.0, 10.0, LiveFeed.REPLAY_COOLDOWN - 1.0), "not twice in a row")


func test_the_shot_picks_the_densest_mixed_scrap_and_recent_violence() -> void:
	# A lone pair near the centre, a big mixed brawl to the north, a big idle group to the south.
	var points: Array = [Vector3(0, 0, 0), Vector3(6, 0, 0)]
	var teams: Array = [0, 1]
	for i in 6:
		points.append(Vector3(i * 4.0, 0, -60)); teams.append(i % 2)
	for i in 6:
		points.append(Vector3(i * 4.0, 0, 70)); teams.append(0)
	var shot := LiveFeed.best_shot(points, teams, [])
	assert_true((shot["point"] as Vector3).z < -40.0, "the mixed brawl beats an idle group of the same size (%s)" % shot)
	assert_true(int(shot["count"]) >= 6, "and frames all of it")
	var events := [{"position": Vector3(70, 0, 70), "age": 0.5, "weight": 1.0}]
	points.append(Vector3(70, 0, 70)); teams.append(1)
	points.append(Vector3(74, 0, 70)); teams.append(0)
	points.append(Vector3(70, 0, 74)); teams.append(0)
	var hot := LiveFeed.best_shot(points, teams, events + events + events + events)
	assert_true((hot["point"] as Vector3).x > 50.0, "a fresh kill pulls the shot to a smaller scrap (%s)" % hot)


func test_empty_ground_is_never_recorded() -> void:
	assert_true(LiveFeed.worth_recording(3), "three vehicles in shot: record")
	assert_true(not LiveFeed.worth_recording(1), "a lone vehicle on asphalt: hold the last good frame")


func test_the_feed_skips_frames_that_are_already_late() -> void:
	# A locked rate that hitches is not locked: when the simulation is catching up, a feed render turns a slow frame
	# into a visible one. LiveFeed.LATE_FRAME is the multiple of the frame target it refuses to render in.
	assert_true(LiveFeed.LATE_FRAME > 1.0, "a frame has to be over the target to count as late")
	assert_true(LiveFeed.LATE_FRAME <= 1.5, "but not so far over that the feed only skips catastrophes")
