extends TestCase
## Round 31 (native, C31.2: traffic's T3b crossing, the pair). His Terminus crossing through traffic's own stage (the
## avenue against the ring road): the two squads meet, one squad pair's verdict, the yielding squad's wish slowed by
## Traffic.shape. The harness is TrafficTwin (tests/native/traffic_twin.gd): every crew's drive, GDScript then native from
## one snapshot, equal bit for bit (command, every mover, every Traffic static). This file: the native
## drive on the C++-owned state; the plain file on the live members.
## The rule must fire on the compared drives (lesson 300).

var _saved_native := false


func teardown() -> void:
	BrainSwitches.native = _saved_native
	BrainSwitches.native_drive = true
	NativeDrive.owned = false
	Traffic.set_off("turns", TrafficTwin.default_off("turns"))
	super.teardown()


func test_the_crossing_on_the_owned_state() -> void:
	if not NativeBridge.available:
		print("native: absent, the crossing's drive equality is not exercised in this run")
		return
	if not bool(NativeTraffic.drive_config().get("traffic_shape", false)):
		print("native: this tree's Traffic has no crossing (Traffic.shape, traffic T3b not merged): nothing to compare")
		return
	_saved_native = BrainSwitches.native
	Traffic.set_off("turns", false)
	var acc: Dictionary = await TrafficTwin.run(self, true, "terminus", "cross", 30.0)
	var report: Dictionary = acc["report"]
	print("native traffic turns (owned state): %d drives compared (%d shaped), %d unsticks, %d mismatches; the stage: %s" % [
			acc["drives"], acc["shaped"], acc["unsticks"], acc["mismatches"], report])
	assert_eq(int(acc["mismatches"]), 0, "the native drive crosses as the GDScript: %s" % acc["first"])
	assert_true(int(acc["drives"]) >= 2000, "a real sample (%d drives)" % acc["drives"])
	assert_true(int(acc["shaped"]) >= 30, "the crossing slowed a wish on the compared drives (%d)" % acc["shaped"])
	assert_true(int(report["tr_cross_verdicts"]) > 0, "the stage made a squad-pair verdict: %s" % report)
