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


func test_the_broadcast_camera_aims_where_the_armies_meet_not_between_them() -> void:
	var green := [Vector3(0, 0, 80), Vector3(10, 0, 20), Vector3(-10, 0, 90)]
	var rust := [Vector3(0, 0, -80), Vector3(12, 0, 10), Vector3(40, 0, -60)]
	assert_eq(LiveFeed.closest_pair_middle(green, rust, Vector3.ZERO), Vector3(11, 0, 15), "the closest opposing pair")
	assert_eq(LiveFeed.closest_pair_middle([], rust, Vector3(1, 0, 1)), Vector3(1, 0, 1), "one army gone: hold the shot")


func test_the_shot_frames_the_whole_scrap_around_the_meeting_point() -> void:
	var points := [Vector3(0, 0, 0), Vector3(10, 0, 0), Vector3(20, 0, 10), Vector3(200, 0, 0)]
	assert_eq(LiveFeed.cluster_middle(points, Vector3(5, 0, 0), 35.0), Vector3(10, 0, 10.0 / 3.0), "the three nearby, not the straggler")
	assert_eq(LiveFeed.cluster_middle(points, Vector3(-100, 0, 0), 35.0), Vector3(-100, 0, 0), "nobody near: keep the point")
