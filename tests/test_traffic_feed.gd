extends TestCase
## Round 26 (traffic CP1a, C26.8): a crew's element slot that SLIDES while the formation travels is not a new call from
## its leader. Before this, the slot sat in ElementFeed's key as text, so every millimetre of slide re-read as a change,
## TankBrain interrupted its mover every ~0.3 s, and Movement's stall bookkeeping and avoidance's start-of-order grace
## never ran out: no give-way and no sidestep in any element move (his head-on jam, streams/traffic.md T0).
## A real re-seat — the slot jumping, a slot given or taken away — and a change of role, task, drill or technique still
## interrupt, exactly as before.


class FakeElement extends RefCounted:
	var value := {}

	func _init(p_state: Dictionary) -> void:
		value = p_state

	func state() -> Dictionary:
		return value


static func _context(overrides: Dictionary = {}, slot: Variant = [10.0, -20.0], unit := "Green_A_2") -> Dictionary:
	var state := {"id": "Alpha", "leader": "Green_A_1", "members": ["Green_A_1", "Green_A_2"], "formation": "wedge",
			"technique": "traveling", "drill": "", "task": "move"}
	if slot != null:
		state["slots"] = {unit: {"position": slot}}
	state.merge(overrides, true)
	return ElementFeed.normalize(FakeElement.new(state), unit)


func test_a_slot_sliding_under_the_threshold_is_not_a_new_call() -> void:
	Traffic.set_off("slide", false)
	var before := _context()
	assert_true(not ElementFeed.changed(before, _context({}, [10.003, -20.002])), "millimetres: the shape travelling")
	assert_true(not ElementFeed.changed(before, _context({}, [11.5, -20.8])), "1.7 m in one read is still a slide")
	assert_true(not ElementFeed.changed(before, before), "nothing changed at all")


func test_a_slot_that_jumps_is_a_re_seat_and_interrupts() -> void:
	Traffic.set_off("slide", false)
	var before := _context()
	assert_true(ElementFeed.changed(before, _context({}, [10.0, -22.5])), "2.5 m in one read: another slot")
	assert_true(ElementFeed.changed(before, _context({}, [22.0, -20.0])), "a whole pitch: a re-seat")


func test_a_slot_given_or_taken_away_interrupts() -> void:
	Traffic.set_off("slide", false)
	assert_true(ElementFeed.changed(_context({}, null), _context()), "given a slot")
	assert_true(ElementFeed.changed(_context(), _context({}, null)), "its slot taken away")
	assert_true(ElementFeed.changed({}, _context()), "joining an element")


func test_a_change_of_role_task_drill_or_technique_still_interrupts() -> void:
	Traffic.set_off("slide", false)
	var before := _context()
	assert_true(ElementFeed.changed(before, _context({"task": "attack"})), "the task")
	assert_true(ElementFeed.changed(before, _context({"drill": "react_to_contact"})), "the drill")
	assert_true(ElementFeed.changed(before, _context({"technique": "bounding_overwatch", "moving": ["Green_A_2"]})),
			"the technique (and with it the role)")
	var bounding := _context({"technique": "bounding_overwatch", "moving": ["Green_A_2"]})
	var covering := _context({"technique": "bounding_overwatch", "moving": ["Green_A_1"]})
	assert_true(ElementFeed.changed(bounding, covering), "the role alone: from the moving half to the covering one")


func test_switched_off_the_old_key_reads_every_slide_as_a_change() -> void:
	Traffic.set_off("slide", true)
	var before := _context()
	assert_true(ElementFeed.changed(before, _context({}, [10.003, -20.002])), "the measured bug, for the A/B")
	assert_true(not ElementFeed.changed(before, _context()), "the same slot is still no change")
	Traffic.set_off("slide", false)


## The behaviour itself on the real arena: a squad given a plain move 100 m across open ground. With the fix, a crew's
## mover keeps one order the whole way (its order clock runs past avoidance's start grace and the ask delay); switched
## off, the clock is reset every element update and never gets past ~10 ticks (the T0 trace: 8, 5, 2, 8, 5, 2 ...).
func test_a_travelling_crew_keeps_its_order_clock() -> void:
	for arm: bool in [false, true]:
		Traffic.set_off("slide", arm)
		var longest := await _longest_order_clock()
		if arm:
			assert_true(longest <= Movement.AVOID_GRACE_TICKS + 2,
					"switched off: the clock never outlives the grace (%d ticks)" % longest)
		else:
			assert_true(longest >= SimClock.TICK_RATE * 3, "a crew keeps one order for 3 s and more (%d ticks)" % longest)
	Traffic.set_off("slide", false)


func _longest_order_clock() -> int:
	var lab := TacticsLab.create(self, 3, "yard_open")
	var names: Array = []
	for i in 3:
		names.append(String(lab.unit(Match.Team.GREEN, "Green_T_%d" % (i + 1), Vector3(-9.0 + 9.0 * i, 0.0, 50.0), 0.0,
				"law_tank").name))
	lab.game_match.set_meta("player_team", Match.Team.GREEN)
	await lab.start()
	var element := lab.elements.form(names, "Trial")
	element.assign({"verb": "move", "to": [0.0, -50.0]})
	var longest := 0
	for tick in SimClock.TICK_RATE * 6:
		await lab.step()
		for unit_name: String in names:
			var mover := Movement.of(lab.tank_of(unit_name))
			if mover != null:
				longest = maxi(longest, mover._order_ticks)
	lab.dispose()
	return longest
