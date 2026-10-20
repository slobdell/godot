extends TestCase
## Round 35, manoeuvre W1c (R35.12): **against a friendly hull, unstick's stall rule reads the drive's intent.** Traced
## (references/round35/manoeuvre/w1c-trace): law-605 Green_Eyes_4 sat 70 s blocked by a parked crew of another squad with ORCA's
## pace at 0.05, so its command was 0.05 and `|throttle| > 0.5` never ran the stall clock: no escape, no second ask. With
## `stallintent` a routed move touching or blocked by a FRIENDLY hull is tested on |throttle| / pace; everything else keeps the
## command. `--nav-off=stallintent` flips the default.

const LANE_X := TacticsScenarios.LANE_X


static func _controller_of(lab: TacticsLab, tank: Tank) -> OrderController:
	for child in lab.game_match.brains.get_children():
		if child is OrderController and (child as OrderController).tank == tank:
			return child
	return null


func _arm(on: bool) -> PackedStringArray:
	return PackedStringArray([]) if on == Manoeuvre.STALL_INTENT_DEFAULT else PackedStringArray(["stallintent"])


## A scout blocked by `blocker_team`'s parked hull, ORCA's pace 0.05, command 0.05: the throttle the stall rule tests.
## `same_element`: both crews formed into one element (R35.39: against an own squadmate the element's re-seat is the way out).
func _reading(on: bool, blocker_team: int, order: Dictionary, same_element := false) -> float:
	var was := Movement._off
	var lab := TacticsLab.create(self, 31)
	var scout := lab.gun(Match.Team.GREEN, "Green_A_1", Vector3(LANE_X, 0, 30), 0.0, "scout")
	var other := lab.gun(blocker_team, "Other_1", Vector3(LANE_X, 0, 20), 0.0, "scout")
	await lab.start()
	if same_element:
		lab.elements.form([String(scout.name), String(other.name)], "Alpha")
	else:
		lab.elements.form([String(scout.name)], "Alpha")
		if blocker_team == Match.Team.GREEN:
			lab.elements.form([String(other.name)], "Bravo")
	await lab.step()
	var ctl := _controller_of(lab, scout)
	var mover := ctl.movement
	mover.pace_now = 0.05
	mover.phase = "blocked"
	mover.blocked_by = String(other.name)
	Movement._off = _arm(on)
	var reading := Manoeuvre.stall_throttle(mover, TankCommand.new(0.05, 0.0), order)
	Movement._off = was
	lab.dispose()
	return reading


func test_a_routed_move_blocked_by_a_friend_reads_its_intent() -> void:
	var before := Manoeuvre.stall_intent_ticks
	var on := await _reading(true, Match.Team.GREEN, {"type": "move_to", "x": LANE_X, "z": -20.0})
	var off := await _reading(false, Match.Team.GREEN, {"type": "move_to", "x": LANE_X, "z": -20.0})
	print("MEASURE w1c_stall_intent blocked by a friend at pace 0.05, command 0.05: ON %.2f OFF %.2f" % [on, off])
	assert_true(on > 0.5, "ON: the intent (%.2f) passes the stall rule's gate" % on)
	assert_true(absf(off - 0.05) < 0.001, "OFF: the command, as today (%.2f)" % off)
	assert_true(Manoeuvre.stall_intent_ticks > before, "the arm counter moves")


func test_everything_else_keeps_the_command() -> void:
	var enemy := await _reading(true, Match.Team.RUST, {"type": "move_to", "x": LANE_X, "z": -20.0})
	assert_true(absf(enemy - 0.05) < 0.001, "an enemy blocker: the command (%.2f)" % enemy)
	var hop := await _reading(true, Match.Team.GREEN, {"type": "move_to", "x": LANE_X, "z": -20.0, "direct": true})
	assert_true(absf(hop - 0.05) < 0.001, "a direct hop (CombatMotion's): the command (%.2f)" % hop)
	var back := await _reading(true, Match.Team.GREEN, {"type": "move_to", "x": LANE_X, "z": 60.0, "reverse": true})
	assert_true(absf(back - 0.05) < 0.001, "a reverse move: the command (%.2f)" % back)


## R35.39: against a squadmate of the SAME element the intent reading does not apply (the element's re-seat, round 18 D5, is
## the way out; the joint dev's Sumps four tanks rocked nose-on to a parked squadmate for 40 s with it applied).
func test_an_own_squadmate_keeps_the_command() -> void:
	var own := await _reading(true, Match.Team.GREEN, {"type": "move_to", "x": LANE_X, "z": -20.0}, true)
	var other := await _reading(true, Match.Team.GREEN, {"type": "move_to", "x": LANE_X, "z": -20.0}, false)
	print("MEASURE w1c_stall_intent own element %.2f, another element %.2f" % [own, other])
	assert_true(absf(own - 0.05) < 0.001, "own squadmate: the command (%.2f)" % own)
	assert_true(other > 0.5, "another element's crew: the intent (%.2f)" % other)
