extends TestCase
## Round 41, manoeuvre M1 v3 (stretch; `--giveway-chain=v3` = givewaychain + chainarriving, Traffic.DEFAULT_OFF until judged): M1's
## give-way reach (a PARKED crew more than CHAIN_M off its seat takes no spot farther from it) is in play only while the crew's OWN
## element is still arriving; once its squad is settled (arrived, nothing queued) it gives way as today, so a later squad threading
## past parked squads is not wedged behind refusers (Bar M1 v2's G5 trace). Stage: a brain-driven crew of element Alpha parked
## 10 m east of its seat on yard_open, asked from the south.

var _lab: TacticsLab


func teardown() -> void:
	for name in ["givewaychain", "chainrelease", "chainside", "chainarriving"]:
		Traffic.set_off(name, Traffic.DEFAULT_OFF.has(name))
	if _lab != null:
		_lab.dispose()
		_lab = null
	super.teardown()


## [mover, element]: a brain crew parked at the origin whose face slot (its seat) is 10 m east, in an element of its own.
func _stage() -> Array:
	_lab = TacticsLab.create(self, 7, "yard_open")
	var parked := _lab.unit(Match.Team.GREEN, "Green_Parked", Vector3.ZERO, 0.0, "tank")
	await _lab.start()
	var element := _lab.element([String(parked.name)], "Alpha")
	var mover := Movement.of(parked)
	for i in 4 * SimClock.TICK_RATE:
		await _lab.step()
		if not mover.is_under_way() and i > SimClock.TICK_RATE:
			break
	mover.ctl.face_slot = Vector3(10.0, 0.0, 0.0)
	print("MEASURE chainarriving stage: phase %s under way %s order %s seat %s at %s" % [mover.phase, mover.is_under_way(),
			mover.ctl.move_order.get("type", ""), mover.yield_seat(), parked.global_position])
	assert_true(not mover.is_under_way(), "setup: the crew is parked")
	return [mover, element]


func test_off_by_default() -> void:
	assert_true(Traffic.DEFAULT_OFF.has("chainarriving"), "M1 v3 is opt-in until judged")


func test_the_reach_holds_while_the_own_squad_arrives_and_lifts_once_it_is_settled() -> void:
	Traffic.set_off("givewaychain", false)
	Traffic.set_off("chainarriving", false)
	var staged: Array = await _stage()
	var mover: Movement = staged[0]
	var element: Element = staged[1]
	element.arrived = false
	var passes := Movement.chain_settled_passes
	assert_true(not mover._own_squad_settled(), "its squad still arriving")
	var reach: Array = mover._chain_reach("Green_Asker")
	assert_true(not reach.is_empty(), "v3 while arriving: the reach is in play (10 m off the seat > CHAIN_M)")
	element.arrived = true
	element.queued_tasks.clear()
	assert_true(mover._own_squad_settled(), "its squad settled")
	assert_true(mover._chain_reach("Green_Asker").is_empty(), "v3 settled: no reach, it gives way as today")
	assert_eq(Movement.chain_settled_passes, passes + 1, "counted")
	Traffic.set_off("chainarriving", true)
	assert_true(not mover._chain_reach("Green_Asker").is_empty(), "M1 as before (v1 / v2): the reach stays whatever the squad does")


func test_v3_flag_turns_both_switches_on() -> void:
	Traffic.set_off("chainarriving", false)
	assert_true(not BrainSwitches.native_yield, "ON: the GDScript ask (no mirror yet)")
	Traffic.set_off("chainarriving", true)
