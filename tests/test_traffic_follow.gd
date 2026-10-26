extends TestCase
## Round 40, manoeuvre F1 (R40.21; `--traffic-on=follow`, Traffic.DEFAULT_OFF until its bar is judged): a WHEELED crew whose ORCA
## answer would steer it round a friend ahead on its route going its way queues instead: it keeps its route's steering and takes
## only ORCA's along-route speed. A stopped friend is passed as today. The bridge-pooled cause (rust t15 s2 on d385cd308): a
## Law Assault Gun moved round its leader at the deck mouth, past the entry, where its 8 m turning circle could not reach the deck.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("follow", Traffic.DEFAULT_OFF.has("follow"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## [leader, follower]: two wheeled law_tanks on yard_open in file going north (-z), the follower `gap` m behind; the leader at
## `leader_speed` of its top speed (0 = stopped), the follower at full speed.
func _stage(gap: float, leader_speed: float) -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var leader := _lab.gun(Match.Team.GREEN, "Green_Lead", Vector3(0.0, 0.0, -gap), 0.0, "law_tank")
	var follower := _lab.gun(Match.Team.GREEN, "Green_Follow", Vector3.ZERO, 0.0, "law_tank")
	await _lab.start()
	if leader_speed > 0.0:
		Movement.of(leader).ctl.set_orders({"type": "move_to", "x": 0.0, "z": -70.0, "speed": leader_speed}, {"type": "fire_at_will"})
	Movement.of(follower).ctl.set_orders({"type": "move_to", "x": 0.0, "z": -70.0}, {"type": "fire_at_will"})
	return [leader, follower]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("follow"), "F1 is opt-in until judged")


## The follow test, pure on the stage: a friend ahead going the follower's way is followed; behind, stopped or crossing is not.
func test_following_reads_a_moving_friend_ahead_going_my_way() -> void:
	var staged: Array = await _stage(9.0, 0.4)
	var follower := Movement.of(staged[1])
	for i in 2 * SimClock.TICK_RATE:
		await _lab.step()
	var here: Vector3 = (staged[1] as Tank).global_position
	print("MEASURE follow stage: leader at %s v %s, follower at %s" % [(staged[0] as Tank).global_position,
			(staged[0] as Tank).real_velocity, here])
	assert_true(follower._following(here, Vector2(0.0, -1.0)) != null, "the leader ahead, moving north: followed")
	assert_true(follower._following(here, Vector2(0.0, 1.0)) == null, "going south, the leader is behind: not followed")
	assert_true(follower._following(here, Vector2(1.0, 0.0)) == null, "going east, the leader is off the way: not followed")


func test_a_stopped_friend_is_not_followed() -> void:
	var staged: Array = await _stage(14.0, 0.0)
	var follower := Movement.of(staged[1])
	for i in 6:
		await _lab.step()
	print("MEASURE follow stopped leader: v %s, follower at %s" % [(staged[0] as Tank).real_velocity, (staged[1] as Tank).global_position])
	assert_true(follower._following((staged[1] as Tank).global_position, Vector2(0.0, -1.0)) == null,
			"a stopped friend is passed as today")


## Live: ON, the fast follower queues in the file behind the slow leader (never steered off its line); measured OFF beside it.
func test_on_the_follower_queues_behind_a_slower_leader() -> void:
	var lateral := {}
	for arm in ["off", "on"]:
		Traffic.set_off("follow", arm == "off")
		var staged: Array = await _stage(10.0, 0.35)
		var follower: Tank = staged[1]
		var leader: Tank = staged[0]
		var worst := 0.0
		var closest := INF
		for i in 8 * SimClock.TICK_RATE:
			await _lab.step()
			worst = maxf(worst, absf(follower.global_position.x))
			closest = minf(closest, Movement._flat_distance(follower.global_position, leader.global_position))
		lateral[arm] = worst
		print("MEASURE follow %s: follower's worst lateral %.2f m, closest to the leader %.1f m, ended at %s (leader %s); queued %d" % [
				arm, worst, closest, follower.global_position, leader.global_position, Movement.follow_queued])
		if arm == "on":
			assert_true(worst < 1.0, "ON: kept its line behind the leader (%.2f m)" % worst)
			assert_true(Movement.follow_queued > 0, "ON: the queue rule fired")
			print("MEASURE follow longest wait %s, waits >= %.0f s: %d" % [Movement.follow_longest, Movement.FOLLOW_LONG_S,
					Movement.follow_long_waits])
			assert_eq(String(Movement.follow_longest.get("crew", "")), "Green_Follow", "the longest wait is the follower's")
			assert_eq(String(Movement.follow_longest.get("behind", "")), "Green_Lead", "behind the leader")
			assert_true(follower.global_position.z > leader.global_position.z, "ON: still behind the leader")
		_lab.dispose()
		_lab = null


## Until twinned in C++, ON runs the GDScript drive (as M3); OFF leaves native_drive as it was.
func test_on_runs_the_gdscript_drive_until_twinned() -> void:
	var before := BrainSwitches.native_drive
	Traffic.set_off("follow", false)
	assert_true(not BrainSwitches.native_drive, "ON: the GDScript drive")
	Traffic.set_off("follow", true)
	assert_eq(BrainSwitches.native_drive, before, "OFF: native_drive back as it was")
