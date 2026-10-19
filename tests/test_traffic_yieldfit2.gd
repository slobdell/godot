extends TestCase
## Round 35 (traffic T9, R35.12/R35.14; `--traffic-on=yieldfit2`, DEFAULT_OFF until judged): a give-way that ends with the asker
## NOT past and the crew still in its way is not recorded as done, so the asker's next ask is honoured. The trace (law-605): a
## parked scout's give-way ended on the 6 s clock beside a pinned asker, and `_last_yielded_to` then refused that asker for 65 s.
## At most Movement.YIELD_RETRIES unfinished give-ways to one asker in YIELD_RETRY_WINDOW_S; the next is recorded as today.

var _lab: TacticsLab


func teardown() -> void:
	Traffic.set_off("yieldfit2", Traffic.DEFAULT_OFF.has("yieldfit2"))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## A parked Law tank at the origin and a squadmate 14 m south of it, sent north through it (under way when it asks).
func _stage() -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var parked := _lab.gun(Match.Team.GREEN, "Green_Parked", Vector3.ZERO, 0.0, "law_tank")
	var asker := _lab.unit(Match.Team.GREEN, "Green_Asker", Vector3(0.0, 0.0, 14.0), 0.0, "law_tank")
	await _lab.start()
	for i in 3:
		await _lab.step()
	_lab.element([String(asker.name)], "Go").assign({"verb": "move", "to": [0.0, -30.0]})
	for i in 6:
		await _lab.step()
	return [parked, asker, Movement.of(parked)]


func _ask(mover: Movement, asker: Tank) -> bool:
	return mover.ask(String(asker.name), asker.global_position, Vector2(0.0, -1.0))


func test_on_a_give_way_ended_with_the_asker_not_past_is_not_recorded() -> void:
	Traffic.set_off("yieldfit2", false)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	assert_true(Movement.of(asker).is_under_way(), "setup: the asker is under way")
	assert_true(_ask(mover, asker), "setup: the parked crew gives way")
	var unfinished := Movement.yields_unfinished
	mover._end_yield()  # ends at once: the asker is still behind it, the crew still on its line
	assert_eq(Movement.yields_unfinished, unfinished + 1, "counted as unfinished")
	assert_eq(mover._last_yielded_to, "", "and not recorded")
	assert_true(_ask(mover, asker), "so the asker's next ask is honoured")


func test_on_the_third_unfinished_give_way_to_one_asker_is_recorded() -> void:
	Traffic.set_off("yieldfit2", false)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	var capped := Movement.yields_unfinished_capped
	for i in Movement.YIELD_RETRIES:
		assert_true(_ask(mover, asker), "give-way %d" % (i + 1))
		mover._end_yield()
		assert_eq(mover._last_yielded_to, "", "unfinished %d not recorded" % (i + 1))
	assert_true(_ask(mover, asker), "give-way %d" % (Movement.YIELD_RETRIES + 1))
	mover._end_yield()
	assert_eq(Movement.yields_unfinished_capped, capped + 1, "the cap is counted")
	assert_eq(mover._last_yielded_to, String(asker.name), "and this one is recorded, as today")
	assert_true(not _ask(mover, asker), "so the next ask is refused as before (no shuffle forever)")


func test_on_a_give_way_ended_with_the_asker_past_is_recorded_as_today() -> void:
	Traffic.set_off("yieldfit2", false)
	var units: Array = await _stage()
	var parked: Tank = units[0]
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	assert_true(_ask(mover, asker), "setup: the parked crew gives way")
	asker.global_position = Vector3(0.0, 0.0, -12.0)  # the asker is past it
	var unfinished := Movement.yields_unfinished
	mover._end_yield()
	assert_eq(Movement.yields_unfinished, unfinished, "a finished give-way is not counted")
	assert_eq(mover._last_yielded_to, String(asker.name), "and is recorded (two movers still take turns)")
	assert_true(parked.is_alive(), "setup sanity")


func test_off_an_unfinished_give_way_is_recorded_as_before() -> void:
	Traffic.set_off("yieldfit2", true)
	var units: Array = await _stage()
	var asker: Tank = units[1]
	var mover: Movement = units[2]
	assert_true(_ask(mover, asker), "setup: the parked crew gives way")
	mover._end_yield()
	assert_eq(mover._last_yielded_to, String(asker.name), "switch off: recorded as before")
	assert_true(not _ask(mover, asker), "and the next ask refused as before")
