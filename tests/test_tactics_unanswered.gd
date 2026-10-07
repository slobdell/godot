extends TestCase
## Round 22 (brains B1, DECLARED, C22.6): A CREW UNDER FIRE IT CANNOT RETURN DOES NOT STAY ON ITS POST. His recording
## (build/recordings/2026-10-07T12-58-28.jsonl, foundry): a Limousine Gunship held its element's post for 22.5 s under a
## Condemned Lancer's laser from ~86 m and died without moving (shield 200 + hp 240). The rule is UnansweredFire; the
## stage (his gunship, the Lancer at 84 m) is tests/tactics/duck_stage.gd, the series `make duck-series`.

const T := SimClock.TICK_RATE


func _member(name: String, at: Vector3, since_hit: int, unit := "syn_ifv") -> Dictionary:
	return {"name": name, "position": at, "unit": unit, "range": 70.0, "effective_range": 55.0, "since_hit": since_hit,
			"taking_fire": since_hit < ElementSituation.FIRE_TICKS}


func _lancer(at: Vector3, visible := true, name := "Green_Charlie_1") -> Dictionary:
	return {"name": name, "position": at, "unit": "lancer", "visible": visible, "distance": at.length(), "strength": 320.0}


func _situation(tick: int, members: Array, contacts: Array, strength := 440.0, enemy := 320.0) -> Dictionary:
	return {"tick": tick, "members": members, "contacts": contacts, "strength": strength, "enemy_strength": enemy,
			"heading": Vector3.FORWARD}


func _hold_plan(names: Array) -> Dictionary:
	var orders := {}
	for name: String in names:
		orders[name] = {"verb": "hold", "to": null, "target": ""}
	return {"orders": orders, "slots": {}, "why": "holding", "drill": ""}


## Hit every tick from `from` to `to` (inclusive) by a Lancer at 84 m; returns the last plan and memory.
func _run(state: Dictionary, from: int, to: int, contacts: Array, strength := 440.0) -> Array:
	var memory := {}
	var plan := {}
	for tick in range(from, to + 1, 3):
		var situation := _situation(tick, [_member("G", Vector3.ZERO, 0)], contacts, strength)
		plan = _hold_plan(["G"])
		var s := state.duplicate()
		s["ducks"] = memory
		memory = UnansweredFire.apply(plan, situation, s)
	return [plan, memory]


func test_a_crew_under_fire_it_cannot_return_moves_after_the_grace() -> void:
	UnansweredFire.ENABLED = true
	var lancer := _lancer(Vector3(-84.0, 0.0, 0.0))
	var early: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS - 6, [lancer])
	assert_eq(String(early[0]["orders"]["G"]["verb"]), "hold", "inside the grace it stays: %s" % early[0]["orders"])
	var late: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS + 3, [lancer])
	# Seen, and we outweigh it (440 v 320): close to our own range and fight it.
	assert_eq(String(late[1]["G"]["outcome"]), "close", "past the grace it acts: %s" % late[1])
	assert_eq(String(late[0]["orders"]["G"]["verb"]), "attack", "closing is an attack on the shooter")
	assert_eq(String(late[0]["orders"]["G"]["target"]), "Green_Charlie_1", "on the shooter")
	assert_true(String(late[0]["why"]).begins_with("under fire from beyond range"), "the readout says why: %s" % late[0]["why"])


func test_outgunned_with_no_cover_it_falls_back_out_of_reach() -> void:
	UnansweredFire.ENABLED = true
	var lancer := _lancer(Vector3(-84.0, 0.0, 0.0))
	var out: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS + 3, [lancer], 200.0)
	var mine: Dictionary = out[1]["G"]
	assert_eq(String(mine["outcome"]), "fall_back", "outgunned, no cover map: fall back: %s" % mine)
	var point: Vector3 = mine["point"]
	assert_true(point.x > 0.0, "away from the shooter (it is to the west): %s" % point)
	assert_true(point.distance_to(Vector3(-84.0, 0.0, 0.0)) >= 90.0, "out of the laser's 90 m: %s" % point)
	assert_eq(String(out[0]["orders"]["G"]["verb"]), "move", "a fall-back is a move")


func test_unseen_shooter_is_not_closed_on() -> void:
	UnansweredFire.ENABLED = true
	var out: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS + 3,
			[_lancer(Vector3(-84.0, 0.0, 0.0), false)])
	assert_eq(String(out[1]["G"]["outcome"]), "fall_back", "a remembered (unseen) shooter is not charged: %s" % out[1])


func test_a_crew_that_can_answer_fights_where_it_stands() -> void:
	UnansweredFire.ENABLED = true
	# An enemy inside the gunship's 55 m: it shoots back, nothing changes.
	var near := _lancer(Vector3(-40.0, 0.0, 0.0), true, "Green_Bravo_2")
	var out: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS * 2, [near, _lancer(Vector3(-84.0, 0.0, 0.0))])
	assert_eq(String(out[0]["orders"]["G"]["verb"]), "hold", "answerable: holds and fights")
	assert_true((out[1] as Dictionary).is_empty(), "no memory kept: %s" % out[1])


func test_his_hold_holds_and_the_readout_says_so() -> void:
	UnansweredFire.ENABLED = true
	for verb: String in UnansweredFire.PLAYER_POSTS:
		var task := {"verb": verb}
		var out: Array = _run({"task": task, "player": true}, 0, UnansweredFire.GRACE_TICKS + 3,
				[_lancer(Vector3(-84.0, 0.0, 0.0))])
		assert_eq(String(out[0]["orders"]["G"]["verb"]), "hold", "%s: his order wins" % verb)
		assert_eq(String(out[0]["why"]), UnansweredFire.WHY_HELD, "%s: the readout" % verb)
	# The same crew under the COMPUTER's hold (or his move, arrived: the element's halt) acts.
	var cpu: Array = _run({"task": {"verb": "hold"}, "player": false}, 0, UnansweredFire.GRACE_TICKS + 3,
			[_lancer(Vector3(-84.0, 0.0, 0.0))])
	assert_eq(String(cpu[0]["orders"]["G"]["verb"]), "attack", "the leader's hold may be left")
	var his_move: Array = _run({"task": {"verb": "move", "to": [0, 0]}, "player": true}, 0, UnansweredFire.GRACE_TICKS + 3,
			[_lancer(Vector3(-84.0, 0.0, 0.0))])
	assert_eq(String(his_move[0]["orders"]["G"]["verb"]), "attack", "his move, arrived: the halt is the element's")


func test_off_is_round_21() -> void:
	UnansweredFire.ENABLED = false
	var out: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS * 2, [_lancer(Vector3(-84.0, 0.0, 0.0))])
	UnansweredFire.ENABLED = true
	assert_eq(String(out[0]["orders"]["G"]["verb"]), "hold", "off: holds")


func test_a_crew_driving_somewhere_is_not_on_a_post() -> void:
	assert_true(not UnansweredFire.on_post({"position": Vector3.ZERO}, {"verb": "move", "to": Vector3(30, 0, 0)}),
			"driving to a point 30 m off")
	assert_true(UnansweredFire.on_post({"position": Vector3.ZERO}, {"verb": "move", "to": Vector3(5, 0, 0)}),
			"standing on the point it was sent to")
	assert_true(not UnansweredFire.on_post({"position": Vector3.ZERO}, {"verb": "attack", "target": "x"}), "attacking")


## The stage from his recording, both arms (C22.6). The computer's gunship moves within 3 s of the first hit, ends in its
## own range of the Lancer, out of the Lancer's reach or behind cover, and loses less than the recording's 440.
func test_his_recording_the_computers_gunship_answers() -> void:
	UnansweredFire.ENABLED = true
	var report := await DuckStage.run(self, 1, "cpu", "ambush", 1, 12.0)
	assert_true(float(report["first_hit_s"]) >= 0.0, "the Lancer hits it: %s" % report)
	assert_true(float(report["react_s"]) >= 0.0 and float(report["react_s"]) <= 3.0, "moves within 3 s of the first hit: %s" % report)
	assert_true(bool(report["answered"]), "ends in its range, out of reach or behind cover: %s" % report)
	assert_true(float(report["lost"]) < 440.0, "loses less than the recording's 440: %s" % report)


func test_his_recording_his_gunship_under_his_hold_holds() -> void:
	UnansweredFire.ENABLED = true
	var report := await DuckStage.run(self, 1, "his", "ambush", 1, 8.0)
	assert_eq(float(report["moved_s"]), -1.0, "his hold: it does not move: %s" % report)
	assert_true(String(report["readout"]).contains(UnansweredFire.WHY_HELD), "the readout says why: %s" % report)
