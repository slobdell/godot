extends TestCase
## Round 26 (brains, the orchestrator's relay of orders' trace, builder0 ba541b96): a squad re-given its task WITHOUT a
## facing, or with a different one, kept the OLD heading on every crew already moving (issued_tick 5 for 6 s):
## Element._should_issue compared verb, place and target but not the heading, so the leader never re-issued. He sees it
## as a squad he re-ordered still swinging round to the way he first drew. Orders' repro, end to end, both ways round.

const Fixture := preload("res://tests/support/control_fixture.gd")
const BRAVO := ["Green_Bravo_1", "Green_Bravo_2"]
## A player's re-order lands at once: the leader issues every crew on the first update after a task (`force`, R2).
## 60 physics frames (1 s) is several element updates.
const PROMPT_FRAMES := 60


func _bravo() -> Array:
	var f := Fixture.new(self)
	await f.build(false)
	f.controls.elements = Elements.install(f.game_match, f.orders)
	var element: Element = f.controls.elements.form(BRAVO, "Bravo")
	return [f, element]


## Frames until every crew's current order carries `want` (null = no facing at all), or -1 past `limit`.
func _frames_until(f: Fixture, want: Variant, limit: int, label: String) -> int:
	var waited := 0
	while waited <= limit:
		var all_ok := true
		var seen := []
		for unit_name: String in BRAVO:
			var order: Dictionary = f.orders.current(unit_name)
			var facing: Variant = order.get("facing")
			seen.append("%s id %s %s" % [unit_name, order.get("id", "-"), facing])
			if want == null:
				all_ok = all_ok and facing == null
			else:
				all_ok = all_ok and facing is Array and Vector2(float(facing[0]), float(facing[1])).normalized() \
						.dot((want as Vector2).normalized()) > 0.99
		if waited % 30 == 0:
			print("TRACE reorder_heading %s frame %d: %s" % [label, waited, seen])
		if all_ok:
			return waited
		await wait_physics_frames(5)
		waited += 5
	return -1


func test_a_squad_re_given_its_task_without_a_heading_sheds_the_old_one_at_once() -> void:
	var made: Array = await _bravo()
	var f: Fixture = made[0]
	var element: Element = made[1]
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [0.0, -1.0], "drills": false})
	assert_true(await _frames_until(f, Vector2(0.0, -1.0), 60, "setup") >= 0, "setup: the crews carry the drawn heading")
	element.assign({"verb": "move", "to": [30.0, 10.0], "drills": false})
	var took := await _frames_until(f, null, 360, "shed")
	print("MEASURE reorder_heading shed_frames %d" % took)
	assert_true(took >= 0 and took <= PROMPT_FRAMES, "every crew dropped the old heading within 1 s (%d frames)" % took)


func test_a_squad_re_given_its_task_with_a_new_heading_takes_it_at_once() -> void:
	var made: Array = await _bravo()
	var f: Fixture = made[0]
	var element: Element = made[1]
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [0.0, -1.0], "drills": false})
	assert_true(await _frames_until(f, Vector2(0.0, -1.0), 60, "setup") >= 0, "setup: the crews carry the drawn heading")
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [1.0, 0.0], "drills": false})
	var took := await _frames_until(f, Vector2(1.0, 0.0), 360, "turn")
	print("MEASURE reorder_heading turn_frames %d" % took)
	assert_true(took >= 0 and took <= PROMPT_FRAMES, "every crew took the new heading within 1 s (%d frames)" % took)


func test_a_squad_re_given_its_task_with_a_heading_it_had_not_takes_it_at_once() -> void:
	var made: Array = await _bravo()
	var f: Fixture = made[0]
	var element: Element = made[1]
	element.assign({"verb": "move", "to": [30.0, 10.0], "drills": false})
	await wait_physics_frames(30)
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [1.0, 0.0], "drills": false})
	var took := await _frames_until(f, Vector2(1.0, 0.0), 360, "given")
	print("MEASURE reorder_heading given_frames %d" % took)
	assert_true(took >= 0 and took <= PROMPT_FRAMES, "every crew took the heading within 1 s (%d frames)" % took)


func test_a_heading_given_taken_away_or_turned_is_a_new_intention_and_drift_is_not() -> void:
	var faced := {"verb": "move", "to": Vector3(30, 0, 10), "facing": Vector3(0, 0, -1)}
	var plain := {"verb": "move", "to": Vector3(30, 0, 10)}
	var drifted := {"verb": "move", "to": Vector3(30, 0, 10), "facing": Vector3(0.17, 0, -0.98)}
	var turned := {"verb": "move", "to": Vector3(30, 0, 10), "facing": Vector3(1, 0, 0)}
	assert_true(Element._heading_changed(faced, plain), "a heading taken away")
	assert_true(Element._heading_changed(plain, faced), "a heading given")
	assert_true(Element._heading_changed(faced, turned), "a heading turned 90 deg")
	assert_true(not Element._heading_changed(faced, drifted), "a heading drifting 10 deg is the same intention (no churn)")
	assert_true(not Element._heading_changed(plain, plain.duplicate()), "no heading either side: the old rule")
	assert_true(not Element._heading_changed({}, faced), "nothing issued yet is the first-issue rule's, not this one's")
	Element.HEADING_REISSUE_ENABLED = false
	assert_true(not Element._heading_changed(faced, plain), "--reissue-heading=off is the old rule")
	Element.HEADING_REISSUE_ENABLED = true



## His own path: the match says the player commands green, so a task's first update issues every crew (`force`, R2)
## and carries the task's id (control_fixture sets no player team, so the tests above are an element's own path).
func _player_shed(label: String) -> int:
	var made: Array = await _bravo()
	var f: Fixture = made[0]
	var element: Element = made[1]
	f.game_match.set_meta("player_team", Match.Team.GREEN)
	element.assign({"verb": "move", "to": [30.0, 10.0], "facing": [0.0, -1.0], "drills": false})
	assert_true(await _frames_until(f, Vector2(0.0, -1.0), 60, "player setup %s" % label) >= 0, "setup %s" % label)
	element.assign({"verb": "move", "to": [30.0, 10.0], "drills": false})
	return await _frames_until(f, null, 360, "player shed %s" % label)


func test_on_the_players_own_team_a_re_given_task_sheds_the_old_heading_at_once() -> void:
	var took := await _player_shed("on")
	print("MEASURE reorder_heading player_team shed_frames on %d" % took)
	assert_true(took >= 0 and took <= PROMPT_FRAMES, "every crew dropped the old heading within 1 s (%d frames)" % took)


## The control arm, measured and not asserted: what the old rule does on his own team (`--reissue-heading=off`).
func test_on_the_players_own_team_the_old_rule_is_measured() -> void:
	Element.HEADING_REISSUE_ENABLED = false
	var took := await _player_shed("off")
	Element.HEADING_REISSUE_ENABLED = true
	print("MEASURE reorder_heading player_team shed_frames off %d" % took)
	assert_true(true, "measured")
