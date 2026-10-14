extends TestCase
## Round 29 (traffic T3): the crossing rule is REACHED on his case through the game's own path (lesson 300). Round 28's
## T1b judged a null because its caller's gate kept the rule off; this drives his Terminus crossing on the GDScript path
## (the crossing has no C++ twin until its port) and counts the rule's own verdicts and slowed wishes.

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	Traffic.set_off("turns", false)
	super.teardown()


func test_his_terminus_crossing_reaches_the_squad_pair_verdict() -> void:
	_saved_native = BrainSwitches.native
	BrainSwitches.native = false
	Traffic.set_off("turns", false)
	var report := await TrafficStage.run(self, 1, "terminus", "cross", "both", 30.0)
	assert_true(int(report["tr_cross_verdicts"]) > 0, "the squads crossing got a verdict: %s" % report["tr_cross_verdicts"])
	assert_true(int(report["tr_cross_slowed"]) > 0, "and the yielding squad slowed: %s" % report["tr_cross_slowed"])
