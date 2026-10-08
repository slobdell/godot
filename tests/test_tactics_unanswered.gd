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
	# 65 m: beyond the gunship's 55, inside the laser's 90, and its own band 15.5 m away (inside CLOSE_LEASH_M).
	var lancer := _lancer(Vector3(-65.0, 0.0, 0.0))
	var early: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS - 6, [lancer])
	assert_eq(String(early[0]["orders"]["G"]["verb"]), "hold", "inside the grace it stays: %s" % early[0]["orders"])
	var late: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS + 3, [lancer])
	# Seen, and we outweigh it (440 v 320): close to our own range and fight it.
	assert_eq(String(late[1]["G"]["outcome"]), "close", "past the grace it acts: %s" % late[1])
	assert_eq(String(late[1]["G"]["target"]), "Green_Charlie_1", "on the shooter")
	var close: Dictionary = late[0]["orders"]["G"]
	assert_eq(String(close["verb"]), "attack_move", "closing is an attack-move to its own band (no chase)")
	var to: Vector3 = close["to"]
	assert_true(to.distance_to(Vector3(-65.0, 0.0, 0.0)) <= 55.0 and to.distance_to(Vector3(-65.0, 0.0, 0.0)) >= 40.0,
			"inside its own 55 m of the shooter, not on top of it: %s" % to)
	# The same Lancer at 84 m: its band is 35 m away, past the leash: the crew does not drive off its ground to close.
	var far: Array = _run({"task": {"verb": "hold"}}, 0, UnansweredFire.GRACE_TICKS + 3, [_lancer(Vector3(-84.0, 0.0, 0.0))])
	assert_true(String(far[1]["G"]["outcome"]) != "close", "a 35 m drive is not a close: %s" % far[1])
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
	assert_true(String(cpu[0]["orders"]["G"]["verb"]) != "hold", "the leader's hold may be left: %s" % cpu[0]["orders"])
	var his_move: Array = _run({"task": {"verb": "move", "to": [0, 0]}, "player": true}, 0, UnansweredFire.GRACE_TICKS + 3,
			[_lancer(Vector3(-84.0, 0.0, 0.0))])
	assert_true(String(his_move[0]["orders"]["G"]["verb"]) != "hold", "his move, arrived: the halt is the element's: %s"
			% his_move[0]["orders"])


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
	var report := await DuckStage.run(self, 1, "cpu", "ambush", 1, 20.0)
	assert_true(float(report["first_hit_s"]) >= 0.0, "the Lancer hits it: %s" % report)
	assert_true(float(report["react_s"]) >= 0.0 and float(report["react_s"]) <= 3.0, "moves within 3 s of the first hit: %s" % report)
	assert_true(bool(report["answered"]), "ends in its range, out of reach or behind cover: %s" % report)
	assert_true(float(report["lost"]) < 440.0, "loses less than the recording's 440: %s" % report)


func test_his_recording_his_gunship_under_his_hold_holds() -> void:
	UnansweredFire.ENABLED = true
	var report := await DuckStage.run(self, 1, "his", "ambush", 1, 8.0)
	assert_eq(float(report["moved_s"]), -1.0, "his hold: it does not move: %s" % report)
	assert_true(String(report["readout"]).contains(UnansweredFire.WHY_HELD), "the readout says why: %s" % report)


## Round 23 (B3): UNDER THREE GUNS, ACT INSIDE THE GRACE. A crew that has lost a quarter of its hull + shield since
## its unanswered fire began does not wait the grace out; one gun's trickle still does.
func _run_losing(from: int, to: int, contacts: Array, loss_per_tick: float) -> Array:
	var memory := {}
	var plan := {}
	for tick in range(from, to + 1, 3):
		var member := _member("G", Vector3.ZERO, 0)
		member["left"] = maxf(1.0 - loss_per_tick * tick, 0.0)
		var situation := _situation(tick, [member], contacts)
		plan = _hold_plan(["G"])
		memory = UnansweredFire.apply(plan, situation, {"task": {"verb": "hold"}, "ducks": memory})
		if String((memory.get("G", {}) as Dictionary).get("outcome", "")) != "":
			return [plan, memory, tick]
	return [plan, memory, -1]


func test_losing_a_quarter_inside_the_grace_acts_at_once() -> void:
	UnansweredFire.ENABLED = true
	UnansweredFire.URGENT_ENABLED = true
	var lancer := _lancer(Vector3(-65.0, 0.0, 0.0))
	# Three Lancers' rate: 440 in ~3 s = a third a second: a quarter is gone at 0.75 s, half the grace.
	var fast: Array = _run_losing(0, UnansweredFire.GRACE_TICKS + 3, [lancer], 1.0 / (3.0 * T))
	assert_true(int(fast[2]) >= 0 and int(fast[2]) < UnansweredFire.GRACE_TICKS, "acted inside the grace: tick %d" % int(fast[2]))
	assert_true(int(fast[2]) >= int(0.25 * 3.0 * T) - 3, "but not before a quarter was gone: tick %d" % int(fast[2]))
	# One Lancer's trickle (440 in 22 s): the grace as before.
	var slow: Array = _run_losing(0, UnansweredFire.GRACE_TICKS + 3, [lancer], 1.0 / (22.0 * T))
	assert_true(int(slow[2]) >= UnansweredFire.GRACE_TICKS, "one gun: waits the grace out: tick %d" % int(slow[2]))
	# The arm off: the grace whatever the rate.
	UnansweredFire.URGENT_ENABLED = false
	var off: Array = _run_losing(0, UnansweredFire.GRACE_TICKS + 3, [lancer], 1.0 / (3.0 * T))
	assert_true(int(off[2]) >= UnansweredFire.GRACE_TICKS, "--duck-urgent=off: the grace: tick %d" % int(off[2]))
	UnansweredFire.URGENT_ENABLED = true
