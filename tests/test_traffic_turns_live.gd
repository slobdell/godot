extends TestCase
## Round 28 (traffic T1b): the street head-on rule is REACHED on his case, through the game's own path. T1b's first judged
## run measured a null: Movement._avoid called Traffic only when `turns` or `streetright` was on, both off by default, so
## the one-lane bridge never ran and every pure test of Traffic.shape still passed (lessons 23/35: a rule's reach is its
## caller's). This drives his Terminus head-on case on the GDScript path (the rule has no C++ twin yet) and counts verdicts.

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	Traffic.set_off("streetturns", false)
	super.teardown()


func test_his_terminus_head_on_reaches_the_one_lane_bridge() -> void:
	_saved_native = BrainSwitches.native
	BrainSwitches.native = false
	Traffic.set_off("streetturns", false)
	for name: String in Traffic.OFF_BY_DEFAULT:
		assert_true(Traffic.off(name), "the game's defaults: %s off" % name)
	var report := await TrafficStage.run(self, 1, "terminus", "head", "both", 20.0)
	assert_true(int(report["tr_verdicts"]) > 0, "the squads meeting head-on in the street got a verdict: %s" % report["tr_verdicts"])
	assert_true(int(report["tr_yield_ticks"]) > 0, "and the waiting squad slowed: %s" % report["tr_yield_ticks"])
