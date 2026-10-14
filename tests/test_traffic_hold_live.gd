extends TestCase
## Round 29 (traffic T1): the street hold is REACHED on his case, through the game's own path (lesson 300: an arm that
## never fires is a null A/B, and a pure test of a rule cannot see its caller's gate). His Terminus head-on case on the
## GDScript path (the hold has no C++ twin until T2): the squads get a verdict, the waiting squad's crews are sent to
## spots and hold there, and holding is visible to the gates (Traffic.holding).

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	Traffic.set_off("hold", false)
	super.teardown()


func test_his_terminus_head_on_holds_the_waiting_squad_at_the_mouth() -> void:
	_saved_native = BrainSwitches.native
	BrainSwitches.native = false
	Traffic.set_off("hold", false)
	var report := await TrafficStage.run(self, 1, "terminus", "head", "both", 30.0)
	assert_true(int(report["tr_verdicts"]) > 0, "the squads meeting head-on in the street got a verdict: %s" % report["tr_verdicts"])
	assert_true(int(report["tr_holds"]) > 0, "the waiting squad's crews were sent to spots: %s" % report["tr_holds"])
	assert_true(int(report["tr_hold_ticks"]) > 0, "and held: %s crew-ticks" % report["tr_hold_ticks"])
