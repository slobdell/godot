extends TestCase
## Round 45 (engage, R45.24): E2's "a hold with no point holds where the crew comes to rest" is HIS rule only. It tested the
## player's TEAM, so an element's pointless hold on his team (ElementPlan._hold's orders carry no point) was re-latched as the
## crew rolled on, and his squads' own holds settled differently from before E2 (his Gorge replay parted at 36 s under his
## squad's attack task). An element's hold keeps the spot Orders gave it at issue; his own still holds where it comes to rest.


func _goal_drift(source: String) -> float:
	var s := AiScenario.create(self, 4)
	s.game_match.set_meta("player_team", Match.Team.GREEN)
	var me := s.brain_tank(Match.Team.GREEN, "Green_A_1", Vector3(-100, 0, 40), 0.0, {}, "scout")
	AiScenario.make_durable(me)
	await s.start()
	var brain := s.brain_of(me)
	# Under way first, so a spot read at issue and the spot it comes to rest on are metres apart.
	assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "move", "to": [-100.0, -20.0], "source": source}), "",
			"setup: the move is accepted")
	for tick in SimClock.TICK_RATE * 2:
		await s.step()
	assert_true(me.estimated_velocity.length() > 3.0, "setup: the crew is driving (%.1f m/s)" % me.estimated_velocity.length())
	assert_eq(s.orders().issue({"units": ["Green_A_1"], "verb": "hold", "source": source}), "", "setup: the hold is accepted")
	await s.step()
	await s.step()
	var first: Vector3 = brain.order["goal"]
	for tick in SimClock.TICK_RATE * 2:
		await s.step()
	var last: Vector3 = brain.order["goal"]
	s.dispose()
	return first.distance_to(last)


func test_an_elements_hold_on_his_team_keeps_the_spot_it_was_given() -> void:
	var drift := await _goal_drift("element")
	assert_true(drift < 0.1, "an element's pointless hold is not re-latched by his rule (%.1f m)" % drift)


func test_his_own_hold_still_holds_where_the_crew_comes_to_rest() -> void:
	var drift := await _goal_drift("player")
	assert_true(drift > 1.0, "his hold's spot follows the crew until it comes to rest (%.1f m)" % drift)
